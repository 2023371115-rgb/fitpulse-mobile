import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

/// Cliente HTTP de FitPulse (Dart puro, sin dependencias de Flutter).
///
/// - Agrega el token JWT en `Authorization: Bearer ...`.
/// - Envía la zona horaria del teléfono para que "hoy" y "esta semana" se
///   calculen con el día local del usuario.
/// - Convierte errores de red y del servidor en [ApiException] con mensajes
///   genéricos (no muestra detalles técnicos ni datos sensibles).
class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient, this.timeout = const Duration(seconds: 15)})
      : baseUrl = _trim(baseUrl),
        _http = httpClient ?? http.Client();

  String baseUrl;
  final http.Client _http;
  final Duration timeout;
  String? token;

  /// Se llama cuando el servidor rechaza el token (sesión vencida).
  void Function()? onUnauthorized;

  static String _trim(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  set url(String value) => baseUrl = _trim(value);

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

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body: body);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    try {
      final future = switch (method) {
        'GET' => _http.get(uri, headers: _headers),
        'POST' => _http.post(uri, headers: _headers, body: encoded),
        'PUT' => _http.put(uri, headers: _headers, body: encoded),
        'PATCH' => _http.patch(uri, headers: _headers, body: encoded),
        _ => _http.delete(uri, headers: _headers, body: encoded),
      };
      res = await future.timeout(timeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
    } on HandshakeException {
      throw ApiException('No se pudo establecer una conexión segura con el servidor.');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final serverMessage = data is Map && data['error'] is String ? data['error'] as String : null;
    if (res.statusCode == 401) {
      if (token != null && !path.startsWith('/auth/')) onUnauthorized?.call();
      throw ApiException(serverMessage ?? 'Tu sesión expiró. Vuelve a iniciar sesión.', statusCode: 401);
    }
    if (res.statusCode >= 500) {
      throw ApiException('Ocurrió un problema en el servidor. Intenta más tarde.', statusCode: res.statusCode);
    }
    throw ApiException(serverMessage ?? 'No se pudo completar la solicitud.', statusCode: res.statusCode);
  }

  void close() => _http.close();
}
