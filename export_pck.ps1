# Script para exportar Battletech como PCK
Write-Host "Exportando Battletech como PCK..." -ForegroundColor Cyan

# Buscar Godot
$godotPaths = @(
    "C:\Program Files\Godot\Godot_v4.3-stable_win64.exe",
    "C:\Godot\Godot_v4.3-stable_win64.exe",
    "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$godot = $null
foreach ($path in $godotPaths) {
    if (Test-Path $path) {
        $godot = $path
        break
    }
}

if (-not $godot) {
    Write-Host "No se encuentra Godot. Por favor indica la ruta:" -ForegroundColor Yellow
    $godot = Read-Host "Ruta completa a Godot.exe"
    
    if (-not (Test-Path $godot)) {
        Write-Host "ERROR: Ruta invalida" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Godot encontrado: $godot" -ForegroundColor Green

# Exportar
Write-Host "Exportando proyecto..." -ForegroundColor Cyan
& $godot --headless --export-pack "Windows Desktop" "Battletech.pck"

if (Test-Path "Battletech.pck") {
    Write-Host ""
    Write-Host "OK - Exportacion completada!" -ForegroundColor Green
    Write-Host "Archivo creado: Battletech.pck" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "ERROR: No se pudo exportar" -ForegroundColor Red
}
