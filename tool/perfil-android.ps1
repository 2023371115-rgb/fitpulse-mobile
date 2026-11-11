# Práctica 12 · Profiling de la app FitPulse en el teléfono (Fase 2: CPU, memoria, tiempos y jank)
#
#   powershell -ExecutionPolicy Bypass -File tool\perfil-android.ps1 -Etiqueta antes
#   powershell -ExecutionPolicy Bypass -File tool\perfil-android.ps1 -Etiqueta despues
#
# Requisitos: teléfono conectado por USB con depuración activada y el APK compilado con
#   flutter build apk --release --dart-define=FP_PERF=true
# (FP_PERF hace que la app escriba en logcat el tiempo de cada solicitud, operación y cuadro).
#
# Qué hace:
#   1. Cierra la app, limpia logcat y las estadísticas de cuadros, y la abre en frío (mide el arranque).
#   2. Registra cada segundo el %CPU y la memoria residente (RES) del proceso con 'top'.
#   3. Te guía por las 6 pruebas obligatorias; tú haces cada una en el teléfono y presionas Enter.
#      Después de cada paso toma la memoria PSS con 'dumpsys meminfo'.
#   4. Al final junta todo: CPU prom/máx, RAM inicial/máx/final, tiempos por solicitud y operación,
#      cuadros con jank (FrameTiming de Flutter y 'dumpsys gfxinfo').
# Resultados en la carpeta perfil-<etiqueta>-<fecha>\ (resumen.txt más los datos crudos).
param(
  [string]$Etiqueta = 'antes',
  [string]$Adb = 'D:\AndroidStudio\platform-tools\adb.exe',
  [string]$Pkg = 'com.example.fitpulse_mobile'
)
$ErrorActionPreference = 'Continue'   # adb escribe avisos en stderr; no deben detener el script
if (-not (Test-Path $Adb)) { $Adb = 'adb' }
function A { & $Adb @args 2>$null }

$state = (A get-state) -join ''
if ($state -ne 'device') { Write-Host 'No hay teléfono conectado (adb get-state). Conéctalo y acepta la depuración USB.' -ForegroundColor Red; exit 1 }
$model = ((A shell getprop ro.product.model) -join '').Trim()
$sdk = ((A shell getprop ro.build.version.sdk) -join '').Trim()
$cores = [int](((A shell nproc) -join '').Trim())
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dir = Join-Path (Get-Location) "perfil-$Etiqueta-$stamp"
New-Item -ItemType Directory -Path $dir | Out-Null
$out = New-Object System.Collections.Generic.List[string]
function Log([string]$s = '') { Write-Host $s; $out.Add($s) }

function Get-Pss {
  $txt = (A shell dumpsys meminfo $Pkg) -join "`n"
  $m = [regex]::Match($txt, 'TOTAL PSS:\s+(\d+)')
  if (-not $m.Success) { $m = [regex]::Match($txt, '(?m)^\s*TOTAL\s+(\d+)') }
  if ($m.Success) { return [math]::Round([int64]$m.Groups[1].Value / 1024, 1) }
  return $null
}
function Mark([string]$s) { A shell log -p i -t flutter "FP-PERF paso $s" | Out-Null }

Log "FitPulse · Práctica 12 · Profiling en el teléfono · $Etiqueta"
Log "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') · $model · Android API $sdk · $cores núcleos · paquete $Pkg"

# 1. Arranque en frío
A shell am force-stop $Pkg | Out-Null
A logcat -c | Out-Null
A shell dumpsys gfxinfo $Pkg reset | Out-Null
Start-Sleep -Seconds 1
A logcat -b events,main -c | Out-Null
$start = (& $Adb shell am start -W -n "$Pkg/.MainActivity" 2>&1) -join "`n"
Set-Content -Path (Join-Path $dir 'arranque.txt') -Value $start -Encoding UTF8
$cold = [regex]::Match($start, '(?:TotalTime|WaitTime):\s+(\d+)').Groups[1].Value
if (-not $cold) {
  # Algunos teléfonos no imprimen TotalTime: se toma la línea "Displayed …: +1s234ms" del sistema
  Start-Sleep -Seconds 2
  $disp = (A logcat -d -s ActivityTaskManager:I ActivityManager:I) -join "`n"
  $m = [regex]::Match($disp, 'Displayed [^:]*' + [regex]::Escape($Pkg) + '[^:]*: \+(?:(\d+)s)?(\d+)ms')
  if ($m.Success) { $cold = [string]([int]('0' + $m.Groups[1].Value) * 1000 + [int]$m.Groups[2].Value) }
  else { $cold = 'no disponible' }
}
Start-Sleep -Seconds 2
$appPid = ((A shell pidof $Pkg) -join '').Trim()
if (-not $appPid) { Log 'La app no arrancó (pidof vacío).'; exit 1 }
Log "Arranque en frío (am start -W / Displayed): $cold ms · pid $appPid"

# 2. Muestreo de CPU/RES y captura de logcat en segundo plano
$topFile = Join-Path $dir 'top.txt'
$logFile = Join-Path $dir 'logcat.txt'
$topProc = Start-Process -FilePath $Adb -ArgumentList @('shell', "top -b -d 1 -q -p $appPid -o %CPU,RES") -RedirectStandardOutput $topFile -NoNewWindow -PassThru
$logProc = Start-Process -FilePath $Adb -ArgumentList @('logcat', '-v', 'time', '-s', 'flutter:I') -RedirectStandardOutput $logFile -NoNewWindow -PassThru
$pss = [ordered]@{ 'inicio' = (Get-Pss) }
Log "Memoria PSS al iniciar: $($pss['inicio']) MB"

# 3. Pruebas guiadas
$steps = @(
  @('1-consulta', 'CONSULTA REPETIDA: abre el Buscador (lupa) y busca "carrera" 5 veces (borra el texto y vuelve a escribirlo).'),
  @('2-escritura', 'ESCRITURA: registra una sesión manual (Actividad > + ) y guárdala.'),
  @('3-navegacion', 'NAVEGACIÓN: recorre las 4 pestañas (Inicio, Actividad, Metas, Perfil) 3 veces seguidas.'),
  @('4-procesamiento', 'PROCESAMIENTO: abre Métricas y cambia el rango Semana → Mes → Año → Semana (cálculo de gráficas).'),
  @('5-desplazamiento', 'UI: en Actividad desliza la lista de sesiones rápido hasta abajo y de regreso, 3 veces.'),
  @('6-recarga', 'CONSULTA: en Inicio jala hacia abajo para actualizar 5 veces.')
)
$t0 = Get-Date
foreach ($s in $steps) {
  Write-Host ''
  Write-Host "Paso $($s[1])" -ForegroundColor Cyan
  Mark "$($s[0]) inicio"
  $ts = Get-Date
  Read-Host '  Presiona Enter cuando termines' | Out-Null
  Mark "$($s[0]) fin"
  $pss[$s[0]] = Get-Pss
  Log ("Paso {0}: {1:N1} s · PSS después: {2} MB" -f $s[0], ((Get-Date) - $ts).TotalSeconds, $pss[$s[0]])
}
Start-Sleep -Seconds 6   # deja salir el último resumen de cuadros (cada 5 s)
$pss['final'] = Get-Pss
$dur = ((Get-Date) - $t0).TotalSeconds
Stop-Process -Id $topProc.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $logProc.Id -Force -ErrorAction SilentlyContinue
$gfx = (A shell dumpsys gfxinfo $Pkg) -join "`n"
Set-Content -Path (Join-Path $dir 'gfxinfo.txt') -Value $gfx -Encoding UTF8
(A shell dumpsys meminfo $Pkg) | Set-Content -Path (Join-Path $dir 'meminfo-final.txt') -Encoding UTF8

# 4. Resumen
function Pct($arr, [double]$q) { if ($arr.Count -eq 0) { return $null }; $s = $arr | Sort-Object; return $s[[math]::Min($s.Count - 1, [math]::Ceiling($q * $s.Count) - 1)] }
function Mb([string]$v, [string]$u) { $n = [double]::Parse($v, [Globalization.CultureInfo]::InvariantCulture); switch ($u) { 'G' { $n * 1024 } 'K' { $n / 1024 } '' { $n / 1048576 } default { $n } } }
$cpu = @(); $res = @()
foreach ($l in (Get-Content $topFile)) {
  $m = [regex]::Match($l, '^\s*([\d.]+)\s+([\d.]+)([KMG]?)\s*$')
  if ($m.Success) { $cpu += [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture); $res += (Mb $m.Groups[2].Value $m.Groups[3].Value) }
}
Log ''
Log "== PER-01 CPU de la app ($($cpu.Count) muestras de 1 s, 'top'; 100 % = un núcleo, $($cores * 100) % = todo el teléfono) =="
if ($cpu.Count) {
  $avg = ($cpu | Measure-Object -Average).Average; $max = ($cpu | Measure-Object -Maximum).Maximum
  Log ("CPU promedio {0:N1} %  · máximo {1:N1} %  · equivalente del teléfono completo: prom {2:N1} %  máx {3:N1} %" -f $avg, $max, ($avg / $cores), ($max / $cores))
  Log ("Segundos con CPU > 50 % de un núcleo: {0} de {1}" -f @($cpu | Where-Object { $_ -gt 50 }).Count, $cpu.Count)
}
Log ''
Log '== PER-02 Memoria =='
if ($res.Count) { Log ("RES (top): inicial {0:N0} MB · máxima {1:N0} MB · final {2:N0} MB" -f $res[0], ($res | Measure-Object -Maximum).Maximum, $res[-1]) }
Log ('PSS (dumpsys meminfo) por paso: ' + (($pss.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ' · ') + ' MB')

$lines = Get-Content $logFile | Where-Object { $_ -match 'FP-PERF' }
$http = @{}; $ops = @{}; $errs = @()
$frames = 0; $jank = 0; $slow = 0; $bmax = 0.0; $rmax = 0.0; $tp90 = @()
foreach ($l in $lines) {
  $m = [regex]::Match($l, 'FP-PERF http (\S+) (\S+) (\d+) red=(\d+)ms json=(\d+)ms bytes=(\d+)')
  if ($m.Success) { $k = "$($m.Groups[1].Value) $($m.Groups[2].Value) $($m.Groups[3].Value)"; if (-not $http.ContainsKey($k)) { $http[$k] = @() }; $http[$k] += , @([int]$m.Groups[4].Value, [int]$m.Groups[5].Value, [int]$m.Groups[6].Value); continue }
  $m = [regex]::Match($l, 'FP-PERF http (\S+) (\S+) ERROR=(\S+) tras=(\d+)ms'); if ($m.Success) { $errs += "$($m.Groups[1].Value) $($m.Groups[2].Value) $($m.Groups[3].Value) tras $($m.Groups[4].Value) ms"; continue }
  $m = [regex]::Match($l, 'FP-PERF op (\S+) (\d+)ms'); if ($m.Success) { $k = $m.Groups[1].Value; if (-not $ops.ContainsKey($k)) { $ops[$k] = @() }; $ops[$k] += [int]$m.Groups[2].Value; continue }
  $m = [regex]::Match($l, 'FP-PERF cuadros n=(\d+) jank=(\d+) lentos100=(\d+) .*build_max=([\d.]+) .*raster_max=([\d.]+) total_p90=([\d.]+)')
  if ($m.Success) {
    $frames += [int]$m.Groups[1].Value; $jank += [int]$m.Groups[2].Value; $slow += [int]$m.Groups[3].Value
    $bmax = [math]::Max($bmax, [double]::Parse($m.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture))
    $rmax = [math]::Max($rmax, [double]::Parse($m.Groups[5].Value, [Globalization.CultureInfo]::InvariantCulture))
    $tp90 += [double]::Parse($m.Groups[6].Value, [Globalization.CultureInfo]::InvariantCulture)
  }
}
Log ''
Log '== PER-03 Tiempo por operación (medido dentro de la app) =='
Log 'solicitud                                   n   red prom  red P90  red máx  json prom  bytes prom'
foreach ($k in ($http.Keys | Sort-Object)) {
  $v = $http[$k]; $red = @($v | ForEach-Object { $_[0] }); $js = @($v | ForEach-Object { $_[1] }); $by = @($v | ForEach-Object { $_[2] })
  Log ("{0,-42} {1,3} {2,8:N0} {3,8:N0} {4,8:N0} {5,9:N1} {6,10:N0}" -f $k, $v.Count, ($red | Measure-Object -Average).Average, (Pct $red 0.9), ($red | Measure-Object -Maximum).Maximum, ($js | Measure-Object -Average).Average, ($by | Measure-Object -Average).Average)
}
foreach ($k in ($ops.Keys | Sort-Object)) { $v = $ops[$k]; Log ("operación {0,-20} n={1,3}  prom {2,6:N0} ms  máx {3,6:N0} ms" -f $k, $v.Count, ($v | Measure-Object -Average).Average, ($v | Measure-Object -Maximum).Maximum) }
if ($errs.Count) { Log 'Errores de red:'; $errs | ForEach-Object { Log "  $_" } }
if (-not $lines) { Log '(No hay líneas FP-PERF: compila el APK con --dart-define=FP_PERF=true)' }

Log ''
Log '== Bloqueos o retrasos de la interfaz (jank) =='
if ($frames) {
  Log ("Flutter FrameTiming: {0} cuadros · {1} con jank ({2:N1} %) · {3} congelados > 100 ms · build máx {4:N1} ms · raster máx {5:N1} ms · P90 por ventana (mediana) {6:N1} ms" -f $frames, $jank, (100.0 * $jank / $frames), $slow, $bmax, $rmax, (Pct $tp90 0.5))
}
$g = @{}
foreach ($n in @('Total frames rendered', 'Janky frames', '50th percentile', '90th percentile', '95th percentile', '99th percentile', 'Number Slow UI thread', 'Number Frozen frames')) {
  $m = [regex]::Match($gfx, [regex]::Escape($n) + ':\s*([^\n]+)'); if ($m.Success) { $g[$n] = $m.Groups[1].Value.Trim() }
}
Log ('dumpsys gfxinfo (hilo de Android): ' + (($g.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join ' · '))
Log ("Duración de las pruebas guiadas: {0:N0} s" -f $dur)
$out | Set-Content -Path (Join-Path $dir 'resumen.txt') -Encoding UTF8
Write-Host ''
Write-Host "Listo. Resumen y datos crudos en: $dir" -ForegroundColor Green
