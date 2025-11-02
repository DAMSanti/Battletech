# Script para crear un keystore para firmar el APK de Android
# Uso: .\create_keystore.ps1

Write-Host "=== Creador de Keystore para Android ===" -ForegroundColor Cyan
Write-Host ""

# Buscar keytool en Java JDK instalado
$possibleJavaPaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "C:\Program Files\Eclipse Adoptium\jdk-17*\bin\keytool.exe",
    "C:\Program Files\Java\jdk*\bin\keytool.exe",
    "C:\Program Files (x86)\Java\jdk*\bin\keytool.exe"
)

$keytoolPath = $null
foreach ($path in $possibleJavaPaths) {
    $resolved = Get-Item $path -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolved) {
        $keytoolPath = $resolved.FullName
        break
    }
}

if (-not $keytoolPath) {
    Write-Host "ERROR: No se encontró keytool.exe" -ForegroundColor Red
    Write-Host "Por favor, instala Java JDK 17 desde: https://adoptium.net/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "O establece la variable de entorno JAVA_HOME" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Java keytool encontrado en: $keytoolPath" -ForegroundColor Green
Write-Host ""

# Configuración del keystore
$keystoreName = "battletech-release.keystore"
$keystorePath = Join-Path $PSScriptRoot $keystoreName
$alias = "battletech"
$validity = 10000  # días de validez (27 años)

Write-Host "Configuración:" -ForegroundColor Cyan
Write-Host "  Archivo: $keystorePath"
Write-Host "  Alias: $alias"
Write-Host "  Validez: $validity días (~27 años)"
Write-Host ""

# Verificar si ya existe
if (Test-Path $keystorePath) {
    Write-Host "ADVERTENCIA: Ya existe un keystore en $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "¿Deseas sobrescribirlo? (s/N)"
    if ($overwrite -ne "s" -and $overwrite -ne "S") {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $keystorePath -Force
}

Write-Host ""
Write-Host "IMPORTANTE: Anota estos datos en un lugar seguro." -ForegroundColor Yellow
Write-Host "Necesitarás la contraseña para firmar futuras actualizaciones del juego." -ForegroundColor Yellow
Write-Host ""

# Crear keystore
Write-Host "Creando keystore..." -ForegroundColor Cyan
Write-Host "Se te pedirán algunos datos:" -ForegroundColor Gray
Write-Host ""

& $keytoolPath -v -genkey -keystore $keystorePath -alias $alias -keyalg RSA -keysize 2048 -validity $validity

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Keystore creado exitosamente!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Cyan
    Write-Host "1. Ve a Godot: Project → Export → Android" -ForegroundColor White
    Write-Host "2. En la sección 'Keystore':" -ForegroundColor White
    Write-Host "   - Release: $keystorePath" -ForegroundColor Gray
    Write-Host "   - Release User: $alias" -ForegroundColor Gray
    Write-Host "   - Release Password: (la contraseña que acabas de ingresar)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. En export_presets.cfg, asegúrate de que 'package/signed=true'" -ForegroundColor White
    Write-Host ""
    Write-Host "GUARDA LA CONTRASEÑA DE FORMA SEGURA." -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Sin ella no podrás publicar actualizaciones en Google Play Store." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "✗ Error al crear el keystore" -ForegroundColor Red
    exit 1
}
