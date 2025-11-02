# Script para instalar Battletech en Android
# Uso: .\install_android.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  BATTLETECH - Android Installer  " -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que existe el APK
$apkPath = "G:\Battletech\Battletech-debug.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "ERROR: No se encuentra el APK en $apkPath" -ForegroundColor Red
    Write-Host "Primero debes exportar el juego desde Godot:" -ForegroundColor Yellow
    Write-Host "  1. Project -> Export" -ForegroundColor Yellow
    Write-Host "  2. Selecciona Android" -ForegroundColor Yellow
    Write-Host "  3. Export Project -> Guarda como Battletech-debug.apk" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK APK encontrado: $apkPath" -ForegroundColor Green

# Buscar ADB (Android Debug Bridge)
$adbPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "C:\Android\Sdk\platform-tools\adb.exe",
    "C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe"
)

$adb = $null
foreach ($path in $adbPaths) {
    if (Test-Path $path) {
        $adb = $path
        break
    }
}

if (-not $adb) {
    Write-Host "ERROR: No se encuentra ADB (Android Debug Bridge)" -ForegroundColor Red
    Write-Host "Instala Android Studio desde: https://developer.android.com/studio" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK ADB encontrado: $adb" -ForegroundColor Green
Write-Host ""

# Verificar dispositivos conectados
Write-Host "Buscando dispositivos Android conectados..." -ForegroundColor Cyan
& $adb devices

$devices = & $adb devices | Select-String "device$" | Measure-Object
if ($devices.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No hay dispositivos Android conectados" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para conectar tu movil:" -ForegroundColor Yellow
    Write-Host "  1. Habilita 'Modo Desarrollador':" -ForegroundColor Yellow
    Write-Host "     - Ajustes -> Acerca del telefono" -ForegroundColor Yellow
    Write-Host "     - Toca 7 veces en 'Numero de compilacion'" -ForegroundColor Yellow
    Write-Host "  2. Habilita 'Depuracion USB':" -ForegroundColor Yellow
    Write-Host "     - Ajustes -> Sistema -> Opciones de desarrollador" -ForegroundColor Yellow
    Write-Host "  3. Conecta el movil con cable USB" -ForegroundColor Yellow
    Write-Host "  4. Autoriza la depuracion USB en el movil" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK Dispositivo(s) encontrado(s)" -ForegroundColor Green
Write-Host ""

# Desinstalar version anterior si existe
Write-Host "Desinstalando version anterior (si existe)..." -ForegroundColor Cyan
& $adb uninstall com.tusitio.battletech 2>$null

# Instalar APK
Write-Host "Instalando Battletech..." -ForegroundColor Cyan
& $adb install -r $apkPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "  OK INSTALACION COMPLETADA" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "El juego esta instalado en tu movil." -ForegroundColor Green
    Write-Host "Busca 'Battletech' en tu lista de aplicaciones." -ForegroundColor Green
    Write-Host ""
    
    # Preguntar si quiere ejecutar el juego
    $run = Read-Host "Quieres ejecutar el juego ahora? (S/N)"
    if ($run -eq "S" -or $run -eq "s") {
        Write-Host "Iniciando Battletech..." -ForegroundColor Cyan
        & $adb shell am start -n com.tusitio.battletech/com.godot.game.GodotApp
        
        Write-Host ""
        Write-Host "Para ver los logs del juego en tiempo real:" -ForegroundColor Yellow
        Write-Host "  .\logs_android.ps1" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "ERROR: La instalacion fallo" -ForegroundColor Red
    Write-Host "Verifica que:" -ForegroundColor Yellow
    Write-Host "  - El movil tiene espacio suficiente" -ForegroundColor Yellow
    Write-Host "  - La depuracion USB esta habilitada" -ForegroundColor Yellow
    Write-Host "  - El APK no esta corrupto" -ForegroundColor Yellow
}
