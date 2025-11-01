# Test Runner con Coverage para Battletech
# Ejecuta tests y muestra cobertura de código

param(
    [string]$TestFile = "",
    [switch]$Coverage = $false,
    [switch]$Verbose = $false
)

Write-Host "`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "          BATTLETECH - Test Runner" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Buscar Godot en rutas comunes
$godotPaths = @(
    "G:\Godot\Godot_v4.5.1-stable_win64.exe",
    "G:\Godot\Godot_v4.3-stable_win64.exe",
    "G:\Godot\Godot.exe",
    "C:\Program Files\Godot\Godot.exe",
    "C:\Program Files (x86)\Godot\Godot.exe",
    "C:\Godot\Godot.exe",
    "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.exe",
    "G:\SteamLibrary\steamapps\common\Godot Engine\godot.exe"
)

$godotExe = $null
foreach ($path in $godotPaths) {
    if (Test-Path $path) {
        $godotExe = $path
        Write-Host "✅ Godot encontrado: $path`n" -ForegroundColor Green
        break
    }
}

if (-not $godotExe) {
    Write-Host "❌ ERROR: No se encontró Godot.exe" -ForegroundColor Red
    Write-Host "Por favor instala Godot 4.x o edita este script con la ruta correcta`n" -ForegroundColor Yellow
    exit 1
}

# Determinar qué tests ejecutar
$testsToRun = @()

if ($TestFile -ne "") {
    # Ejecutar test específico
    $testsToRun += $TestFile
    Write-Host "📋 Ejecutando test específico: $TestFile`n" -ForegroundColor Cyan
} else {
    # Ejecutar todos los tests
    $testsToRun = Get-ChildItem -Path "G:\Battletech\tests\unit" -Filter "test_*.gd" | Select-Object -ExpandProperty FullName
    Write-Host "📋 Ejecutando TODOS los tests ($($testsToRun.Count) archivos)`n" -ForegroundColor Cyan
}

# Contador de resultados
$totalTests = 0
$passedTests = 0
$failedTests = 0
$testResults = @()

# Ejecutar cada test
foreach ($test in $testsToRun) {
    $testName = Split-Path $test -Leaf
    Write-Host "🧪 Ejecutando: $testName..." -ForegroundColor Yellow
    
    # Ejecutar Godot en modo headless con el test
    $output = & $godotExe --headless --path "G:\Battletech" --script $test 2>&1 | Out-String
    
    if ($Verbose) {
        Write-Host $output -ForegroundColor DarkGray
    }
    
    # Parsear resultados
    if ($output -match "RESULTS: (\d+) tests") {
        $tests = [int]$Matches[1]
        $totalTests += $tests
    }
    
    if ($output -match "Passed: (\d+)") {
        $passed = [int]$Matches[1]
        $passedTests += $passed
    }
    
    if ($output -match "Failed: (\d+)") {
        $failed = [int]$Matches[1]
        $failedTests += $failed
    }
    
    # Extraer detalles de tests
    $lines = $output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "(✅|❌) (PASS|FAIL): (.+)") {
            $status = $Matches[2]
            $description = $Matches[3]
            $testResults += [PSCustomObject]@{
                File = $testName
                Status = $status
                Description = $description
            }
        }
    }
    
    Write-Host "  Completado`n" -ForegroundColor Green
}

# Mostrar resumen
Write-Host "`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    RESUMEN" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Total de tests ejecutados: $totalTests" -ForegroundColor White
Write-Host "✅ Tests pasados: $passedTests" -ForegroundColor Green
Write-Host "❌ Tests fallados: $failedTests" -ForegroundColor Red

if ($totalTests -gt 0) {
    $successRate = [math]::Round(($passedTests / $totalTests) * 100, 2)
    Write-Host "`nTasa de éxito: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })
}

# Mostrar tabla de resultados si hay fallos
if ($failedTests -gt 0) {
    Write-Host "`n❌ TESTS FALLADOS:" -ForegroundColor Red
    $testResults | Where-Object { $_.Status -eq "FAIL" } | Format-Table -AutoSize
}

# Calcular y mostrar cobertura si se solicitó
if ($Coverage) {
    Write-Host "`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "              COBERTURA DE CÓDIGO" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Mapear tests a archivos de código
    $coverageMap = @{
        "test_main_menu.gd" = @("ui/screens/main_menu.gd")
        "test_initiative_screen.gd" = @("ui/screens/initiative_screen.gd")
        "test_weapon_system.gd" = @("core/combat/weapon_system.gd")
        "test_physical_attack_system.gd" = @("core/combat/physical_attack_system.gd")
    }
    
    # Archivos de producción
    $productionFiles = Get-ChildItem -Path "G:\Battletech\scripts" -Recurse -Filter "*.gd" -Exclude "mech.gd" | 
        Where-Object { $_.FullName -notmatch "\\tests\\" }
    
    $coveredFiles = @()
    $uncoveredFiles = @()
    
    foreach ($file in $productionFiles) {
        $relativePath = $file.FullName.Replace("G:\Battletech\scripts\", "")
        $isCovered = $false
        
        foreach ($testFile in $coverageMap.Keys) {
            if ($coverageMap[$testFile] -contains $relativePath) {
                $isCovered = $true
                break
            }
        }
        
        if ($isCovered) {
            $coveredFiles += $relativePath
        } else {
            $uncoveredFiles += $relativePath
        }
    }
    
    $totalFiles = $productionFiles.Count
    $coveredCount = $coveredFiles.Count
    $coveragePercent = if ($totalFiles -gt 0) { [math]::Round(($coveredCount / $totalFiles) * 100, 2) } else { 0 }
    
    Write-Host "📁 Archivos de producción: $totalFiles" -ForegroundColor White
    Write-Host "✅ Archivos con tests: $coveredCount" -ForegroundColor Green
    Write-Host "❌ Archivos sin tests: $($totalFiles - $coveredCount)" -ForegroundColor Red
    Write-Host "`nCobertura de archivos: $coveragePercent%`n" -ForegroundColor $(if ($coveragePercent -gt 75) { "Green" } elseif ($coveragePercent -gt 50) { "Yellow" } else { "Red" })
    
    if ($coveredFiles.Count -gt 0) {
        Write-Host "✅ ARCHIVOS CUBIERTOS:" -ForegroundColor Green
        $coveredFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    }
    
    if ($uncoveredFiles.Count -gt 0) {
        Write-Host "`n❌ ARCHIVOS SIN COBERTURA:" -ForegroundColor Red
        $uncoveredFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
    }
    
    # Generar reporte HTML
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Battletech - Test Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #4ec9b0; }
        .summary { background: #252526; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #858585; }
        .green { color: #4ec9b0; }
        .red { color: #f48771; }
        .yellow { color: #dcdcaa; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #252526; }
        th { background: #37373d; padding: 12px; text-align: left; }
        td { padding: 10px; border-top: 1px solid #37373d; }
        .covered { color: #4ec9b0; }
        .uncovered { color: #f48771; }
    </style>
</head>
<body>
    <h1>🎯 Battletech - Test Coverage Report</h1>
    <div class="summary">
        <div class="metric">
            <div class="metric-value green">$coveragePercent%</div>
            <div class="metric-label">Cobertura de Archivos</div>
        </div>
        <div class="metric">
            <div class="metric-value green">$passedTests</div>
            <div class="metric-label">Tests Pasados</div>
        </div>
        <div class="metric">
            <div class="metric-value $(if ($failedTests -eq 0) { 'green' } else { 'red' })">$failedTests</div>
            <div class="metric-label">Tests Fallados</div>
        </div>
        <div class="metric">
            <div class="metric-value">$totalTests</div>
            <div class="metric-label">Total Tests</div>
        </div>
    </div>
    
    <h2>📊 Cobertura por Archivo</h2>
    <table>
        <tr><th>Archivo</th><th>Estado</th></tr>
"@
    
    foreach ($file in $coveredFiles) {
        $htmlReport += "<tr><td>$file</td><td class='covered'>✅ Cubierto</td></tr>`n"
    }
    
    foreach ($file in $uncoveredFiles) {
        $htmlReport += "<tr><td>$file</td><td class='uncovered'>❌ Sin cobertura</td></tr>`n"
    }
    
    $htmlReport += @"
    </table>
    
    <h2>🧪 Resultados de Tests</h2>
    <table>
        <tr><th>Test</th><th>Estado</th><th>Descripción</th></tr>
"@
    
    foreach ($result in $testResults) {
        $statusClass = if ($result.Status -eq "PASS") { "covered" } else { "uncovered" }
        $statusIcon = if ($result.Status -eq "PASS") { "✅" } else { "❌" }
        $htmlReport += "<tr><td>$($result.File)</td><td class='$statusClass'>$statusIcon $($result.Status)</td><td>$($result.Description)</td></tr>`n"
    }
    
    $htmlReport += @"
    </table>
    <p style="color: #858585; margin-top: 40px;">Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
</body>
</html>
"@
    
    $reportPath = "G:\Battletech\tests\coverage_report.html"
    $htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`n📄 Reporte HTML generado: $reportPath" -ForegroundColor Cyan
    Write-Host "   Ábrelo en tu navegador para ver el reporte completo`n" -ForegroundColor Yellow
}

Write-Host "`n════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Exit code basado en resultados
if ($failedTests -eq 0) {
    exit 0
} else {
    exit 1
}
