# Script para instalar el APK en el móvil Android
# Uso: .\install_apk_on_phone.ps1

Write-Host "=== Instalador de APK en Móvil Android ===" -ForegroundColor Cyan
Write-Host ""

# Buscar ADB (Android Debug Bridge)
$possibleAdbPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "C:\Android\Sdk\platform-tools\adb.exe",
    "$env:ProgramFiles\Android\android-sdk\platform-tools\adb.exe"
)

$adbPath = $null
foreach ($path in $possibleAdbPaths) {
    if (Test-Path $path) {
        $adbPath = $path
        break
    }
}

if (-not $adbPath) {
    Write-Host "ERROR: No se encontró ADB (Android Debug Bridge)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Opciones:" -ForegroundColor Yellow
    Write-Host "1. Instala Android Studio desde: https://developer.android.com/studio" -ForegroundColor White
    Write-Host "2. O instala solo las Platform Tools desde:" -ForegroundColor White
    Write-Host "   https://developer.android.com/tools/releases/platform-tools" -ForegroundColor White
    Write-Host ""
    Write-Host "Alternativamente, puedes:" -ForegroundColor Cyan
    Write-Host "- Copiar el APK al móvil manualmente y abrirlo" -ForegroundColor White
    Write-Host "- Usar Google Drive o correo electrónico para transferirlo" -ForegroundColor White
    exit 1
}

Write-Host "✓ ADB encontrado en: $adbPath" -ForegroundColor Green
Write-Host ""

# Buscar el APK
$apkPath = Join-Path $PSScriptRoot "BattleTech.apk"
if (-not (Test-Path $apkPath)) {
    $apkPath = Join-Path $PSScriptRoot "BattleTech-debug.apk"
}
if (-not (Test-Path $apkPath)) {
    Write-Host "ERROR: No se encontró el archivo APK" -ForegroundColor Red
    Write-Host "Asegúrate de haber exportado el proyecto desde Godot primero" -ForegroundColor Yellow
    Write-Host "Buscado en:" -ForegroundColor Gray
    Write-Host "  - BattleTech.apk" -ForegroundColor Gray
    Write-Host "  - BattleTech-debug.apk" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ APK encontrado: $apkPath" -ForegroundColor Green
$apkSize = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Host "  Tamaño: $apkSize MB" -ForegroundColor Gray
Write-Host ""

# Verificar dispositivos conectados
Write-Host "Verificando dispositivos conectados..." -ForegroundColor Cyan
$devices = & $adbPath devices

Write-Host $devices
Write-Host ""

# Contar dispositivos
$deviceCount = ($devices | Select-String "device$" | Measure-Object).Count

if ($deviceCount -eq 0) {
    Write-Host "ERROR: No hay dispositivos Android conectados" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para conectar tu móvil:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. En tu móvil Android:" -ForegroundColor Cyan
    Write-Host "   a) Ve a Ajustes → Acerca del teléfono" -ForegroundColor White
    Write-Host "   b) Toca 7 veces en 'Número de compilación'" -ForegroundColor White
    Write-Host "   c) Aparecerá 'Ahora eres desarrollador'" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Ve a Ajustes → Sistema → Opciones de desarrollador" -ForegroundColor Cyan
    Write-Host "   a) Activa 'Depuración USB'" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Conecta el móvil al PC con cable USB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "4. En el móvil, acepta la solicitud de depuración USB" -ForegroundColor Cyan
    Write-Host "   (Marca 'Confiar siempre en este ordenador')" -ForegroundColor White
    Write-Host ""
    Write-Host "5. Vuelve a ejecutar este script" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Alternativa sin cable USB:" -ForegroundColor Yellow
    Write-Host "- Copia el APK al móvil (por cable, correo, Drive, etc.)" -ForegroundColor White
    Write-Host "- Abre el archivo APK en el móvil" -ForegroundColor White
    Write-Host "- Permite instalar desde fuentes desconocidas si te lo pide" -ForegroundColor White
    exit 1
}

Write-Host "✓ Dispositivo(s) encontrado(s): $deviceCount" -ForegroundColor Green
Write-Host ""

# Instalar APK
Write-Host "Instalando APK en el dispositivo..." -ForegroundColor Cyan
Write-Host "(Esto puede tardar un momento)" -ForegroundColor Gray
Write-Host ""

# Usar -r para reinstalar si ya existe
& $adbPath install -r $apkPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ ¡APK instalado exitosamente!" -ForegroundColor Green
    Write-Host ""
    Write-Host "El juego 'Battletech' debería aparecer ahora en la lista de aplicaciones" -ForegroundColor Cyan
    Write-Host "de tu móvil." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "✗ Error al instalar el APK" -ForegroundColor Red
    Write-Host ""
    Write-Host "Si el error es por firma incompatible, ejecuta:" -ForegroundColor Yellow
    Write-Host "  adb uninstall com.example.battletech" -ForegroundColor Gray
    Write-Host "  y luego vuelve a ejecutar este script" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "Comandos útiles:" -ForegroundColor Cyan
Write-Host "  Ver logs del juego: adb logcat | Select-String 'Godot'" -ForegroundColor Gray
Write-Host "  Desinstalar: adb uninstall com.example.battletech" -ForegroundColor Gray
Write-Host "  Ver dispositivos: adb devices" -ForegroundColor Gray
