# run_tests.ps1 - Script para ejecutar tests de GUT en Steel Titans
# Uso: .\run_tests.ps1 [-Filter "test_name"] [-Verbose]
#
# El crash al final (signal 11) es un bug conocido de Godot 4.5.1 en headless mode
# y no afecta los resultados de los tests.

param(
    [string]$Filter = "",
    [switch]$Verbose
)

$GodotPath = "G:\Godot\Godot_v4.5.1-stable_win64_console.exe"
$ProjectPath = "G:\Battletech"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Steel Titans - Test Runner" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$args_list = @(
    "--headless",
    "--path", $ProjectPath,
    "--script", "res://addons/gut/gut_cmdln.gd",
    "-gdir=res://tests/unit",
    "-gexit"
)

if ($Filter -ne "") {
    $args_list += "-gselect=$Filter"
    Write-Host "Filtro: $Filter" -ForegroundColor Yellow
}

Write-Host "Ejecutando tests..." -ForegroundColor Green
Write-Host ""

# Ejecutar Godot y capturar output
$output = & $GodotPath $args_list 2>&1

# Filtrar líneas relevantes (excluir spam de Sentry y crash al final)
$relevant_lines = $output | Where-Object {
    $_ -notmatch "^Sentry:" -and
    $_ -notmatch "CrashHandlerException" -and
    $_ -notmatch "no debug info in PE/COFF" -and
    $_ -notmatch "END OF C\+\+ BACKTRACE"
}

if ($Verbose) {
    $relevant_lines | ForEach-Object { Write-Host $_ }
} else {
    # Mostrar solo resumen y fallos
    $in_summary = $false
    $in_failures = $false
    
    foreach ($line in $relevant_lines) {
        if ($line -match "^Totals|^------|^Scripts|^Tests|^Passing|^Failing|^Asserts|^Orphans|^Time|^\[Failed\]|^-\s+test_|failing tests") {
            $in_summary = $true
        }
        if ($line -match "^\[WARNING\]|^ERROR:") {
            continue  # Skip warnings/errors individuales
        }
        if ($in_summary -or $line -match "passed\.$|failed\.$") {
            if ($line -match "Failing.*[1-9]") {
                Write-Host $line -ForegroundColor Red
            } elseif ($line -match "Passing") {
                Write-Host $line -ForegroundColor Green
            } elseif ($line -match "\[Failed\]") {
                Write-Host $line -ForegroundColor Red
            } else {
                Write-Host $line
            }
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Extraer resultados
$passing = ($output | Select-String "Passing Tests\s+(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
$failing = ($output | Select-String "Failing Tests\s+(\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })

if ($failing -gt 0) {
    Write-Host "  RESULTADO: $passing pasaron, $failing fallaron" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  RESULTADO: $passing tests pasaron" -ForegroundColor Green
    exit 0
}
