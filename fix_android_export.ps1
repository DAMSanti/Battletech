# Script para verificar y configurar la exportación Android en Godot
# Uso: .\fix_android_export.ps1

Write-Host "=== Diagnóstico y Reparación de Exportación Android ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar templates de Godot
Write-Host "[1/5] Verificando templates de exportación..." -ForegroundColor Cyan

$godotVersion = "4.5"
$templatesPath = "$env:APPDATA\Godot\export_templates\$godotVersion.stable"

if (Test-Path $templatesPath) {
    Write-Host "✓ Templates encontrados en: $templatesPath" -ForegroundColor Green
    
    # Verificar que existan los templates de Android
    $androidLib = "$templatesPath\android_source.zip"
    $androidDebugApk = "$templatesPath\android_debug.apk"
    $androidReleaseApk = "$templatesPath\android_release.apk"
    
    if ((Test-Path $androidLib) -or (Test-Path $androidDebugApk)) {
        Write-Host "✓ Templates de Android encontrados" -ForegroundColor Green
    } else {
        Write-Host "✗ Templates de Android NO encontrados" -ForegroundColor Red
        Write-Host ""
        Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
        Write-Host "1. Abre Godot Engine" -ForegroundColor White
        Write-Host "2. Ve a Editor → Manage Export Templates" -ForegroundColor White
        Write-Host "3. Haz clic en 'Download and Install'" -ForegroundColor White
        Write-Host "4. Espera a que descargue" -ForegroundColor White
        Write-Host "5. Vuelve a ejecutar este script" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "✗ Templates NO encontrados" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
    Write-Host "1. Abre Godot Engine" -ForegroundColor White
    Write-Host "2. Ve a Editor → Manage Export Templates" -ForegroundColor White
    Write-Host "3. Haz clic en 'Download and Install'" -ForegroundColor White
    Write-Host "4. Espera a que descargue" -ForegroundColor White
    Write-Host "5. Vuelve a ejecutar este script" -ForegroundColor White
    exit 1
}

Write-Host ""

# 2. Verificar export_presets.cfg
Write-Host "[2/5] Verificando configuración de exportación..." -ForegroundColor Cyan

$presetPath = ".\export_presets.cfg"
if (Test-Path $presetPath) {
    $presetContent = Get-Content $presetPath -Raw
    
    # Verificar package name
    if ($presetContent -match 'package/unique_name="([^"]+)"') {
        $packageName = $matches[1]
        if ($packageName -like '*$genname*' -or $packageName -eq 'com.example.') {
            Write-Host "✗ Package name inválido: $packageName" -ForegroundColor Red
            Write-Host "  Ya debería estar corregido a: com.damsanti.battletech" -ForegroundColor Yellow
        } else {
            Write-Host "✓ Package name válido: $packageName" -ForegroundColor Green
        }
    }
    
    # Verificar nombre de app
    if ($presetContent -match 'package/name="([^"]*)"') {
        $appName = $matches[1]
        if ($appName -eq "") {
            Write-Host "⚠ Nombre de app vacío (se usará el del project.godot)" -ForegroundColor Yellow
        } else {
            Write-Host "✓ Nombre de app: $appName" -ForegroundColor Green
        }
    }
} else {
    Write-Host "✗ No se encontró export_presets.cfg" -ForegroundColor Red
    Write-Host "  Crea un preset de Android en Godot primero" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 3. Verificar que exista el APK
Write-Host "[3/5] Buscando APK generado..." -ForegroundColor Cyan

$apkFiles = Get-ChildItem -Path . -Filter "*.apk" -ErrorAction SilentlyContinue

if ($apkFiles.Count -eq 0) {
    Write-Host "✗ No se encontró ningún APK" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
    Write-Host "1. Abre Godot Engine" -ForegroundColor White
    Write-Host "2. Ve a Project → Export" -ForegroundColor White
    Write-Host "3. Selecciona el preset 'Battletech'" -ForegroundColor White
    Write-Host "4. Haz clic en 'Export Project'" -ForegroundColor White
    Write-Host "5. Guarda como 'BattleTech.apk'" -ForegroundColor White
    Write-Host "6. Asegúrate de marcar 'Export With Debug' para pruebas" -ForegroundColor White
    exit 1
} else {
    Write-Host "✓ APK encontrado(s):" -ForegroundColor Green
    foreach ($apk in $apkFiles) {
        $size = [Math]::Round($apk.Length / 1MB, 2)
        Write-Host "  - $($apk.Name) ($size MB)" -ForegroundColor Gray
        
        # Verificar tamaño mínimo (un APK de Godot válido debería ser >10MB)
        if ($apk.Length -lt 10MB) {
            Write-Host "    ⚠ ADVERTENCIA: APK muy pequeño, puede estar corrupto" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# 4. Verificar Android SDK (opcional para debugging)
Write-Host "[4/5] Verificando Android SDK (opcional)..." -ForegroundColor Cyan

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
if (Test-Path $sdkPath) {
    Write-Host "✓ Android SDK encontrado" -ForegroundColor Green
    
    $adbPath = "$sdkPath\platform-tools\adb.exe"
    if (Test-Path $adbPath) {
        Write-Host "✓ ADB disponible" -ForegroundColor Green
    } else {
        Write-Host "⚠ ADB no encontrado (no es crítico)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Android SDK no instalado (no es necesario para exportar)" -ForegroundColor Yellow
}

Write-Host ""

# 5. Resumen y siguientes pasos
Write-Host "[5/5] Resumen" -ForegroundColor Cyan
Write-Host ""

Write-Host "Para exportar correctamente:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Abre Godot Engine" -ForegroundColor White
Write-Host "2. Asegúrate de NO tener errores en el proyecto" -ForegroundColor White
Write-Host "3. Ve a Project → Export" -ForegroundColor White
Write-Host "4. Selecciona el preset 'Battletech' (Android)" -ForegroundColor White
Write-Host "5. Haz clic en 'Export Project' (NO 'Export PCK/ZIP')" -ForegroundColor White
Write-Host "6. Guarda como: BattleTech.apk" -ForegroundColor White
Write-Host "7. Marca 'Export With Debug' ✓" -ForegroundColor White
Write-Host "8. Espera a que termine (puede tardar 1-2 minutos)" -ForegroundColor White
Write-Host ""

Write-Host "Luego, para instalar en tu móvil:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Opción A (más fácil):" -ForegroundColor Cyan
Write-Host "  - Copia BattleTech.apk a tu móvil" -ForegroundColor White
Write-Host "  - Abre el archivo en el móvil" -ForegroundColor White
Write-Host "  - Permite instalación desde fuentes desconocidas" -ForegroundColor White
Write-Host "  - Instala" -ForegroundColor White
Write-Host ""
Write-Host "Opción B (con cable USB y ADB):" -ForegroundColor Cyan
Write-Host "  - Ejecuta: .\install_adb.ps1 (si no tienes ADB)" -ForegroundColor White
Write-Host "  - Conecta el móvil con USB" -ForegroundColor White
Write-Host "  - Ejecuta: .\install_apk_on_phone.ps1" -ForegroundColor White
Write-Host ""

Write-Host "Opción C (más rápida):" -ForegroundColor Cyan
Write-Host "  - Conecta el móvil con USB" -ForegroundColor White
Write-Host "  - En Godot, haz clic en el ícono de Android (junto al Play)" -ForegroundColor White
Write-Host "  - Godot instalará automáticamente" -ForegroundColor White

Write-Host ""
Write-Host "=== Diagnóstico completado ===" -ForegroundColor Green
