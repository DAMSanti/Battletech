# Script para instalar plantillas de exportacion descargadas manualmente
Write-Host "Instalador de plantillas de Godot" -ForegroundColor Cyan
Write-Host ""

# Buscar el archivo TPZ en varias ubicaciones
$searchPaths = @(
    "G:\Downloads\Godot_v*_export_templates.tpz",
    "$env:USERPROFILE\Downloads\Godot_v*_export_templates.tpz",
    "C:\Users\*\Downloads\Godot_v*_export_templates.tpz"
)

$tpzPath = $null
foreach ($pattern in $searchPaths) {
    $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $tpzPath = $found.FullName
        break
    }
}

if (-not $tpzPath) {
    Write-Host "No se encuentra el archivo TPZ automaticamente" -ForegroundColor Red
    Write-Host "Por favor indica la ruta completa del archivo .tpz:" -ForegroundColor Yellow
    Write-Host "Ejemplo: G:\Downloads\Godot_v4.3-stable_export_templates.tpz" -ForegroundColor Gray
    $tpzPath = Read-Host "Ruta del archivo .tpz"
} else {
    Write-Host "Archivo encontrado: $tpzPath" -ForegroundColor Green
}

if (-not (Test-Path $tpzPath)) {
    Write-Host "ERROR: Archivo no existe" -ForegroundColor Red
    exit 1
}

# Extraer version del nombre
$version = "4.3-stable"
if ($tpzPath -match "Godot_v([^_]+)_export") {
    $version = $matches[1]
}

Write-Host "Version detectada: $version" -ForegroundColor Cyan

# Extraer
$extractPath = "G:\Godot\export_templates"  # Cambiado a G:\ porque C:\ esta lleno
$templateDir = "$extractPath\$version"

Write-Host "Extrayendo plantillas en G:\ (C:\ esta lleno)..." -ForegroundColor Cyan

# Crear directorio temporal
$tempDir = "$extractPath\temp_install"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Extraer (el .tpz es realmente un ZIP)
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tpzPath, $tempDir)
    
    # Mover a la ubicacion correcta
    if (Test-Path $templateDir) {
        Remove-Item $templateDir -Recurse -Force
    }
    
    Move-Item "$tempDir\templates" $templateDir
    
    # Limpiar
    Remove-Item $tempDir -Recurse -Force
    
    Write-Host ""
    Write-Host "OK Plantillas instaladas en: $templateDir" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ahora en Godot:" -ForegroundColor Yellow
    Write-Host "  1. Cierra y vuelve a abrir Godot" -ForegroundColor Cyan
    Write-Host "  2. Project -> Export" -ForegroundColor Cyan
    Write-Host "  3. Add -> Android" -ForegroundColor Cyan
    Write-Host "  4. Configura y exporta" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR al extraer: $_" -ForegroundColor Red
    exit 1
}
