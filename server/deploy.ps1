# Script para construir y desplegar el servidor Steel Titans en DigitalOcean
# Ejecutar desde el directorio raíz del proyecto

param(
    [string]$ServerIP = "",
    [string]$SSHKey = "~/.ssh/id_rsa",
    [switch]$BuildOnly = $false,
    [switch]$DeployOnly = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Steel Titans Server Deploy Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "project.godot")) {
    Write-Host "ERROR: Ejecutar desde el directorio raiz del proyecto (donde esta project.godot)" -ForegroundColor Red
    exit 1
}

# Crear directorio de exports si no existe
$exportsDir = "exports"
if (-not (Test-Path $exportsDir)) {
    New-Item -ItemType Directory -Path $exportsDir | Out-Null
    Write-Host "Creado directorio: $exportsDir" -ForegroundColor Green
}

# Función para exportar el servidor
function Export-Server {
    Write-Host ""
    Write-Host "=== PASO 1: Exportar servidor ===" -ForegroundColor Yellow
    Write-Host ""
    
    # Crear preset de exportación para Linux si no existe
    $exportPresetsContent = @"
[preset.1]

name="Linux Server"
platform="Linux"
runnable=false
dedicated_server=true
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="./exports/Steel Titans_Server.x86_64"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host=""
ssh_remote_deploy/port=22
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script=""
ssh_remote_deploy/cleanup_script=""
"@

    # Verificar si ya existe el preset de Linux
    $existingPresets = Get-Content "export_presets.cfg" -Raw -ErrorAction SilentlyContinue
    if ($existingPresets -notmatch "Linux Server") {
        Write-Host "Anadiendo preset de exportacion Linux Server..." -ForegroundColor Cyan
        Add-Content -Path "export_presets.cfg" -Value $exportPresetsContent
    }
    
    Write-Host "Exportando servidor para Linux..." -ForegroundColor Cyan
    Write-Host "NOTA: Necesitas tener los export templates de Linux instalados" -ForegroundColor Yellow
    Write-Host ""
    
    # Exportar usando Godot
    # Asumimos que Godot está en el PATH o en la ubicación estándar
    $godotPath = "godot"
    
    # Intentar encontrar Godot
    $possiblePaths = @(
        "godot",
        "C:\Program Files\Godot\Godot.exe",
        "$env:USERPROFILE\scoop\apps\godot\current\godot.exe",
        "$env:LOCALAPPDATA\Godot\godot.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Get-Command $path -ErrorAction SilentlyContinue) {
            $godotPath = $path
            break
        }
    }
    
    Write-Host "Usando Godot: $godotPath" -ForegroundColor Gray
    
    # Exportar
    & $godotPath --headless --export-pack "Linux Server" "exports/Steel Titans_Server.pck"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo al exportar. Verifica que tienes los export templates instalados." -ForegroundColor Red
        Write-Host "Puedes descargarlos desde: https://godotengine.org/download" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Servidor exportado correctamente!" -ForegroundColor Green
}

# Función para construir la imagen Docker
function Build-DockerImage {
    Write-Host ""
    Write-Host "=== PASO 2: Construir imagen Docker ===" -ForegroundColor Yellow
    Write-Host ""
    
    # Verificar que Docker está disponible
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Docker no encontrado. Instala Docker Desktop." -ForegroundColor Red
        exit 1
    }
    
    # Construir imagen
    docker build -t Steel Titans-server:latest -f server/Dockerfile .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo al construir la imagen Docker" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Imagen Docker construida!" -ForegroundColor Green
}

# Función para desplegar en DigitalOcean
function Deploy-ToDigitalOcean {
    param([string]$IP)
    
    Write-Host ""
    Write-Host "=== PASO 3: Desplegar en DigitalOcean ===" -ForegroundColor Yellow
    Write-Host ""
    
    if ([string]::IsNullOrEmpty($IP)) {
        Write-Host "ERROR: Debes proporcionar la IP del servidor con -ServerIP" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Desplegando en: $IP" -ForegroundColor Cyan
    
    # Guardar la imagen Docker
    Write-Host "Guardando imagen Docker..." -ForegroundColor Gray
    docker save Steel Titans-server:latest | gzip > Steel Titans-server.tar.gz
    
    # Copiar archivos al servidor
    Write-Host "Copiando archivos al servidor..." -ForegroundColor Gray
    scp -i $SSHKey Steel Titans-server.tar.gz "root@${IP}:/tmp/"
    scp -i $SSHKey server/docker-compose.yml "root@${IP}:/opt/Steel Titans/"
    
    # Cargar y ejecutar en el servidor
    Write-Host "Iniciando contenedor en el servidor..." -ForegroundColor Gray
    ssh -i $SSHKey "root@$IP" @"
        mkdir -p /opt/Steel Titans
        cd /opt/Steel Titans
        docker load < /tmp/Steel Titans-server.tar.gz
        docker-compose down 2>/dev/null || true
        docker-compose up -d
        docker logs Steel Titans-server
"@
    
    # Limpiar archivo local
    Remove-Item Steel Titans-server.tar.gz -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SERVIDOR DESPLEGADO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "El servidor esta corriendo en: $IP`:7777" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Comandos utiles:" -ForegroundColor Yellow
    Write-Host "  Ver logs:    ssh root@$IP 'docker logs -f Steel Titans-server'" -ForegroundColor Gray
    Write-Host "  Reiniciar:   ssh root@$IP 'cd /opt/Steel Titans && docker-compose restart'" -ForegroundColor Gray
    Write-Host "  Detener:     ssh root@$IP 'cd /opt/Steel Titans && docker-compose down'" -ForegroundColor Gray
}

# Ejecutar según los flags
if (-not $DeployOnly) {
    Export-Server
    Build-DockerImage
}

if (-not $BuildOnly) {
    if (-not [string]::IsNullOrEmpty($ServerIP)) {
        Deploy-ToDigitalOcean -IP $ServerIP
    } else {
        Write-Host ""
        Write-Host "Para desplegar, ejecuta con -ServerIP:" -ForegroundColor Yellow
        Write-Host "  .\server\deploy.ps1 -ServerIP TU_IP_DIGITALOCEAN" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Listo!" -ForegroundColor Green
