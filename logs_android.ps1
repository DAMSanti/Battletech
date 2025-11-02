# Script para ver logs de Android en tiempo real
# Uso: .\logs_android.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  BATTLETECH - Android Logs       " -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Yellow
Write-Host ""

# Buscar ADB
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
    Write-Host "ERROR: No se encuentra ADB" -ForegroundColor Red
    exit 1
}

# Limpiar logs anteriores
& $adb logcat -c

# Mostrar logs en tiempo real filtrando por Godot
Write-Host "Mostrando logs de Godot/Battletech:" -ForegroundColor Green
Write-Host ""

& $adb logcat | Select-String "Godot|battletech|TurnManager|BattleScene" --Context 0,0
