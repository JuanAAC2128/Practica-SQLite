# Configura el proyecto en Windows: genera carpetas de plataforma, dependencias,
# codigo de drift, recursos web y ejecuta analisis + pruebas.
# Uso (desde esta carpeta):
#   powershell -ExecutionPolicy Bypass -File .\configurar.ps1

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Paso($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }
function Ejecutar($comando) {
    Write-Host "   $comando" -ForegroundColor DarkGray
    Invoke-Expression $comando
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $comando (codigo $LASTEXITCODE)" }
}

Paso 'Version de Flutter (se requiere Dart 3.10+ / Flutter 3.38+)'
Ejecutar 'flutter --version'

Paso 'Generando carpetas android/ ios/ web/ windows/ linux/ macos/ (no sobrescribe lib/ ni test/)'
Ejecutar 'flutter create --project-name gestor_tareas_local --org mx.edu.uaa --platforms android,ios,web,windows,linux,macos .'

Paso 'Instalando dependencias'
Ejecutar 'flutter pub get'

Paso 'Generando codigo de drift (lib/data/app_database.g.dart)'
Ejecutar 'dart run build_runner build --delete-conflicting-outputs'

Paso 'Comprobando sqlite3.wasm y drift_worker.js para la version de drift instalada'
$lock = Get-Content pubspec.lock -Raw
$incluida = '2.35.4'
if ($lock -match '(?ms)^  drift:\r?\n.*?version: "([^"]+)"') {
    $version = $Matches[1]
    Write-Host "   drift instalado: $version (recursos incluidos: $incluida)"
    if ($version -ne $incluida) {
        $base = "https://github.com/simolus3/drift/releases/download/drift-$version"
        try {
            Invoke-WebRequest "$base/sqlite3.wasm" -OutFile 'web/sqlite3.wasm' -UseBasicParsing
            Invoke-WebRequest "$base/drift_worker.js" -OutFile 'web/drift_worker.js' -UseBasicParsing
            Write-Host "   Recursos web actualizados a drift-$version" -ForegroundColor Green
        } catch {
            Write-Warning "No se pudieron descargar los recursos de drift-$version; se conservan los de $incluida (compatibles dentro de drift 2.x)."
        }
    }
}

Paso 'Analisis estatico'
Ejecutar 'flutter analyze'

Paso 'Pruebas automatizadas'
Ejecutar 'flutter test'

Write-Host "`nListo. Ejecuta la app con:" -ForegroundColor Green
Write-Host '   flutter run -d windows'
Write-Host '   flutter run -d chrome'
