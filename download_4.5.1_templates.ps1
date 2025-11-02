# Script para descargar plantillas de Godot 4.5.1
Write-Host "Descargando plantillas de Godot 4.5.1..." -ForegroundColor Cyan

$version = "4.5.1-stable"
$url = "https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz"

Write-Host ""
Write-Host "Abre tu navegador y descarga desde:" -ForegroundColor Yellow
Write-Host $url -ForegroundColor Cyan
Write-Host ""
Write-Host "O busca en: https://godotengine.org/download/archive/4.5.1-stable/" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Presiona ENTER cuando hayas descargado el archivo"

# Buscar el archivo
$searchPaths = @(
    "G:\Downloads\Godot_v4.5*_export_templates.tpz",
    "$env:USERPROFILE\Downloads\Godot_v4.5*_export_templates.tpz"
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
    Write-Host "No se encuentra el archivo. Indica la ruta:" -ForegroundColor Red
    $tpzPath = Read-Host "Ruta completa del archivo .tpz"
}

if (-not (Test-Path $tpzPath)) {
    Write-Host "ERROR: Archivo no existe" -ForegroundColor Red
    exit 1
}

Write-Host "Archivo encontrado: $tpzPath" -ForegroundColor Green

# Extraer
$extractPath = "G:\Godot\export_templates"
$templateDir = "$extractPath\4.5.1.stable"

Write-Host "Extrayendo plantillas..." -ForegroundColor Cyan

$tempDir = "$extractPath\temp_install"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tpzPath, $tempDir)
    
    if (Test-Path $templateDir) {
        Remove-Item $templateDir -Recurse -Force
    }
    
    Move-Item "$tempDir\templates" $templateDir
    Remove-Item $tempDir -Recurse -Force
    
    # Crear enlace simbolico
    $linkPath = "$env:APPDATA\Godot\export_templates\4.5.1.stable"
    if (Test-Path $linkPath) {
        Remove-Item $linkPath -Force
    }
    
    cmd /c mklink /D $linkPath $templateDir
    
    Write-Host ""
    Write-Host "OK Plantillas instaladas!" -ForegroundColor Green
    Write-Host "Cierra y vuelve a abrir Godot" -ForegroundColor Yellow
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
