# Script para instalar Android Platform Tools (ADB)
# Uso: .\install_adb.ps1

Write-Host "=== Instalador de Android Platform Tools (ADB) ===" -ForegroundColor Cyan
Write-Host ""

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$platformToolsPath = "$sdkPath\platform-tools"
$adbPath = "$platformToolsPath\adb.exe"

# Verificar si ya está instalado
if (Test-Path $adbPath) {
    Write-Host "✓ ADB ya está instalado en: $adbPath" -ForegroundColor Green
    & $adbPath version
    exit 0
}

Write-Host "Descargando Android Platform Tools..." -ForegroundColor Cyan
Write-Host "(Esto incluye ADB, Fastboot, etc.)" -ForegroundColor Gray
Write-Host ""

# URL de descarga oficial de Google
$url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
$zipPath = "$env:TEMP\platform-tools.zip"

try {
    # Descargar
    Write-Host "Descargando desde: $url" -ForegroundColor Gray
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    
    Write-Host "✓ Descarga completada" -ForegroundColor Green
    Write-Host ""
    
    # Crear directorio si no existe
    if (-not (Test-Path $sdkPath)) {
        New-Item -Path $sdkPath -ItemType Directory -Force | Out-Null
    }
    
    # Extraer
    Write-Host "Extrayendo archivos..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $sdkPath -Force
    
    Write-Host "✓ Extracción completada" -ForegroundColor Green
    Write-Host ""
    
    # Agregar al PATH
    Write-Host "Agregando ADB al PATH del sistema..." -ForegroundColor Cyan
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$platformToolsPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$platformToolsPath", "User")
        Write-Host "✓ ADB agregado al PATH" -ForegroundColor Green
    } else {
        Write-Host "✓ ADB ya está en el PATH" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "✓ ¡Instalación completada!" -ForegroundColor Green
    Write-Host ""
    Write-Host "ADB instalado en: $adbPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Yellow
    Write-Host "1. CIERRA Y VUELVE A ABRIR PowerShell (para actualizar el PATH)" -ForegroundColor White
    Write-Host "2. Conecta tu móvil Android con cable USB" -ForegroundColor White
    Write-Host "3. Ejecuta: .\install_apk_on_phone.ps1" -ForegroundColor White
    
    # Limpiar
    Remove-Item $zipPath -Force
    
} catch {
    Write-Host ""
    Write-Host "✗ Error al descargar o instalar ADB" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    Write-Host ""
    Write-Host "Solución alternativa:" -ForegroundColor Yellow
    Write-Host "1. Descarga manualmente desde:" -ForegroundColor White
    Write-Host "   https://developer.android.com/tools/releases/platform-tools" -ForegroundColor Cyan
    Write-Host "2. Extrae el ZIP" -ForegroundColor White
    Write-Host "3. Mueve la carpeta 'platform-tools' a: $sdkPath" -ForegroundColor White
    exit 1
}
