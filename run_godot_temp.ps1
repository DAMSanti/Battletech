# Script para ejecutar Godot con directorio temporal en G:\
Write-Host "Iniciando Godot con directorio temporal en G:\..." -ForegroundColor Cyan

# Crear directorio temporal en G:\
$tempDir = "G:\Temp"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

# Buscar Godot
$godotPaths = @(
    "C:\Program Files\Godot\Godot.exe",
    "C:\Godot\Godot.exe",
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
Write-Host "Directorio temporal: $tempDir" -ForegroundColor Green
Write-Host ""

# Configurar variables de entorno y ejecutar Godot
$env:TEMP = $tempDir
$env:TMP = $tempDir

Write-Host "Iniciando Godot con TEMP en G:\..." -ForegroundColor Cyan
& $godot --path "G:\Battletech"
