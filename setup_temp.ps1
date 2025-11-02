# Script para exportar desde Godot con directorio temporal en G:\
Write-Host "Configurando directorio temporal en G:\ para exportar..." -ForegroundColor Cyan

# Crear carpeta temporal en G:\
$tempDir = "G:\Temp"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

Write-Host "Carpeta temporal creada: $tempDir" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE: Ejecuta este comando ANTES de abrir Godot:" -ForegroundColor Yellow
Write-Host ""
Write-Host '  $env:TEMP = "G:\Temp"; $env:TMP = "G:\Temp"; & "C:\Program Files\Godot\Godot.exe"' -ForegroundColor Cyan
Write-Host ""
Write-Host "O ejecuta el script: .\run_godot_temp.ps1" -ForegroundColor Yellow
