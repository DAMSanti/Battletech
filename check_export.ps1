# Script simple para diagnosticar exportación Android
Write-Host "=== Diagnóstico de Exportación Android ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar templates
Write-Host "1. Verificando templates de Godot 4.5..." -ForegroundColor Cyan
$templatesPath = "$env:APPDATA\Godot\export_templates\4.5.stable"

if (Test-Path $templatesPath) {
    Write-Host "   OK - Templates encontrados" -ForegroundColor Green
} else {
    Write-Host "   ERROR - Templates NO encontrados" -ForegroundColor Red
    Write-Host ""
    Write-Host "   SOLUCIÓN: En Godot, ve a Editor → Manage Export Templates → Download" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 2. Verificar APK
Write-Host "2. Verificando APK generado..." -ForegroundColor Cyan
$apkFiles = Get-ChildItem -Filter "*.apk"

if ($apkFiles.Count -eq 0) {
    Write-Host "   ERROR - No se encontró ningún APK" -ForegroundColor Red
    Write-Host ""
    Write-Host "   SOLUCIÓN: Exporta el proyecto desde Godot:" -ForegroundColor Yellow
    Write-Host "   - Project → Export → Export Project" -ForegroundColor White
    Write-Host "   - Guarda como: BattleTech.apk" -ForegroundColor White
    Write-Host "   - Marca 'Export With Debug'" -ForegroundColor White
} else {
    foreach ($apk in $apkFiles) {
        $sizeMB = [Math]::Round($apk.Length / 1MB, 2)
        Write-Host "   OK - APK encontrado: $($apk.Name) ($sizeMB MB)" -ForegroundColor Green
        
        if ($apk.Length -lt 5MB) {
            Write-Host "   ADVERTENCIA - APK muy pequeño, puede estar corrupto" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# 3. Verificar configuración
Write-Host "3. Verificando export_presets.cfg..." -ForegroundColor Cyan
if (Test-Path "export_presets.cfg") {
    $content = Get-Content "export_presets.cfg" -Raw
    
    if ($content -match "com.damsanti.battletech") {
        Write-Host "   OK - Package name configurado" -ForegroundColor Green
    } else {
        Write-Host "   ADVERTENCIA - Package name puede estar mal configurado" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ERROR - No existe export_presets.cfg" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== SIGUIENTES PASOS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si todo está OK arriba:" -ForegroundColor White
Write-Host "1. Abre Godot" -ForegroundColor White
Write-Host "2. Project → Export → Export Project" -ForegroundColor White
Write-Host "3. Guarda como: BattleTech.apk" -ForegroundColor White
Write-Host "4. MARCA la casilla 'Export With Debug'" -ForegroundColor Yellow
Write-Host "5. Espera a que termine (1-2 minutos)" -ForegroundColor White
Write-Host ""
Write-Host "Luego copia el APK a tu móvil y ábrelo para instalar" -ForegroundColor Cyan
