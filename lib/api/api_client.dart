import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../utils/perf_log.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.timedOut = false, this.inProgress = false});

  final String message;
  final int? statusCode;

  /// La solicitud se envió pero no llegó respuesta a tiempo: el servidor pudo haberla procesado.
  final bool timedOut;

  /// 409 de idempotencia: otra copia de esta misma escritura sigue en proceso en el servidor.
  final bool inProgress;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

/// Reintento controlado con espera progresiva (exponential backoff + jitter). Práctica 12.
///
/// Solo se reintenta lo que es seguro repetir:
///  - GET (no cambia nada en el servidor);
///  - escrituras que llevan `Idempotency-Key`: el servidor reconoce la clave y, si ya
///    procesó la solicitud, devuelve la misma respuesta en lugar de crear un duplicado.
/// Errores reintentables: sin conexión, 500/502/503/504 y 409 "en proceso" (otra copia de la
/// misma escritura todavía se está procesando). Los timeouts no se reintentan aquí: ya
/// esperaron 15 s y repetir alargaría demasiado la espera; el usuario puede volver a guardar
/// y, con la misma clave, no se duplica.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 4),
    this.budget = const Duration(seconds: 12),
  });

  /// Sin reintentos (comportamiento anterior a la Práctica 12).
  static const none = RetryPolicy(maxRetries: 0);

  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Tiempo total máximo: no se inicia un reintento que terminaría de esperar después de esto.
  final Duration budget;

  /// Espera antes del reintento [attempt] (1, 2, 3…): base·2^(n-1), con jitter de ±25 %.
  Duration delay(int attempt, Random rnd) {
    final ms = min(baseDelay.inMilliseconds * pow(2, attempt - 1), maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: (ms * (0.75 + rnd.nextDouble() * 0.5)).round());
  }

  static bool retryableStatus(int status) => status == 500 || status == 502 || status == 503 || status == 504;
}

/// Cliente HTTP de FitPulse (Dart puro, sin dependencias de Flutter).
///
/// - Agrega el token JWT en `Authorization: Bearer ...`.
/// - Envía la zona horaria del teléfono para que "hoy" y "esta semana" se
///   calculen con el día local del usuario.
/// - Convierte errores de red y del servidor en [ApiException] con mensajes
///   genéricos (no muestra detalles técnicos ni datos sensibles).
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.retry = const RetryPolicy(),
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : baseUrl = _trim(baseUrl),
        _http = httpClient ?? http.Client(),
        _sleep = sleep ?? Future<void>.delayed,
        _rnd = random ?? Random();

  final RetryPolicy retry;
  final Future<void> Function(Duration) _sleep;
  final Random _rnd;

  /// Clave única para una escritura (32 caracteres hex). Se genera una vez por operación del
  /// usuario y se reutiliza en cada reintento y si vuelve a presionar "Guardar".
  static String newIdempotencyKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String baseUrl;
  final http.Client _http;
  final Duration timeout;
  String? token;

  /// Se llama cuando el servidor rechaza el token (sesión vencida).
  void Function()? onUnauthorized;

  static String _trim(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  set url(String value) => baseUrl = _trim(value);

  Map<String, String> _headersFor(String? idempotencyKey) => {
        ..._headers,
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Timezone-Offset': DateTime.now().timeZoneOffset.inMinutes.toString(),
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) => _withRetry('GET', path, null, () => _send('GET', path, query: query));
  Future<dynamic> post(String path, [Object? body, String? idempotencyKey]) =>
      _withRetry('POST', path, idempotencyKey, () => _send('POST', path, body: body, idempotencyKey: idempotencyKey));
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body: body);

  /// Número de reintentos hechos desde que se creó el cliente (para pruebas y métricas).
  int retries = 0;

  Future<dynamic> _withRetry(String method, String path, String? idempotencyKey, Future<dynamic> Function() call) async {
    final safe = method == 'GET' || idempotencyKey != null;
    final sw = Stopwatch()..start();
    var waited = Duration.zero;
    for (var attempt = 0;; attempt++) {
      try {
        return await call();
      } on ApiException catch (e) {
        final retryable = !e.timedOut && !e.isUnauthorized && (e.isNetwork || e.inProgress || RetryPolicy.retryableStatus(e.statusCode!));
        if (!safe || !retryable || attempt >= retry.maxRetries) rethrow;
        final wait = retry.delay(attempt + 1, _rnd);
        // Tiempo gastado: el real, o la suma de esperas si el reloj no avanzó (sleep simulado en pruebas)
        final spent = sw.elapsed > waited ? sw.elapsed : waited;
        if (spent + wait > retry.budget) rethrow;
        waited += wait;
        retries++;
        PerfLog.event('reintento ${attempt + 1} $method $path tras ${e.statusCode ?? 'sin conexión'} · espera ${wait.inMilliseconds}ms');
        await _sleep(wait);
      }
    }
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, String? idempotencyKey}) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    final sw = Stopwatch()..start();
    try {
      final future = switch (method) {
        'GET' => _http.get(uri, headers: _headers),
        'POST' => _http.post(uri, headers: _headersFor(idempotencyKey), body: encoded),
        'PUT' => _http.put(uri, headers: _headers, body: encoded),
        'PATCH' => _http.patch(uri, headers: _headers, body: encoded),
        _ => _http.delete(uri, headers: _headers, body: encoded),
      };
      res = await future.timeout(timeout);
    } on TimeoutException {
      PerfLog.httpError(method, path, 'timeout', sw.elapsedMilliseconds);
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.', timedOut: true);
    } on SocketException {
      PerfLog.httpError(method, path, 'socket', sw.elapsedMilliseconds);
      throw ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
    } on http.ClientException {
      PerfLog.httpError(method, path, 'cliente', sw.elapsedMilliseconds);
      throw ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
    } on HandshakeException {
      PerfLog.httpError(method, path, 'tls', sw.elapsedMilliseconds);
      throw ApiException('No se pudo establecer una conexión segura con el servidor.');
    }
    final netMs = sw.elapsedMilliseconds;

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }
    PerfLog.http(method, path, res.statusCode, netMs, sw.elapsedMilliseconds - netMs, res.bodyBytes.length);

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final serverMessage = data is Map && data['error'] is String ? data['error'] as String : null;
    if (res.statusCode == 401) {
      if (token != null && !path.startsWith('/auth/')) onUnauthorized?.call();
      throw ApiException(serverMessage ?? 'Tu sesión expiró. Vuelve a iniciar sesión.', statusCode: 401);
    }
    if (res.statusCode == 409 && data is Map && data['code'] == 'IDEMPOTENCY_IN_PROGRESS') {
      throw ApiException('Tu solicitud anterior todavía se está procesando. Espera un momento.', statusCode: 409, inProgress: true);
    }
    if (res.statusCode >= 500) {
      throw ApiException('Ocurrió un problema en el servidor. Intenta más tarde.', statusCode: res.statusCode);
    }
    throw ApiException(serverMessage ?? 'No se pudo completar la solicitud.', statusCode: res.statusCode);
  }

  void close() => _http.close();
}
