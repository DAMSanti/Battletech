# Script para descargar plantillas de exportacion de Godot 4.3
Write-Host "Descargando plantillas de exportacion de Godot..." -ForegroundColor Cyan

$version = "4.3-stable"
$url = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
$outputPath = "$env:TEMP\godot_export_templates.tpz"
$extractPath = "$env:APPDATA\Godot\export_templates"

Write-Host "Descargando desde GitHub..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
    Write-Host "OK Descarga completada" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se pudo descargar" -ForegroundColor Red
    Write-Host "Descarga manualmente desde:" -ForegroundColor Yellow
    Write-Host "  $url" -ForegroundColor Cyan
    exit 1
}

# Extraer
Write-Host "Extrayendo plantillas..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, "$extractPath\temp")

# Mover a la ubicacion correcta
$templateDir = "$extractPath\$version"
if (Test-Path $templateDir) {
    Remove-Item $templateDir -Recurse -Force
}
Move-Item "$extractPath\temp\templates" $templateDir

# Limpiar
Remove-Item "$extractPath\temp" -Recurse -Force
Remove-Item $outputPath -Force

Write-Host ""
Write-Host "OK Plantillas instaladas correctamente!" -ForegroundColor Green
Write-Host "Ahora puedes exportar desde Godot:" -ForegroundColor Yellow
Write-Host "  Project -> Export -> Add -> Android" -ForegroundColor Cyan
