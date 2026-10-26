[CmdletBinding()]
param(
    [string]$GodotPath = 'godot'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$engine = (Get-Command $GodotPath -CommandType Application -ErrorAction Stop).Source
$versionOutput = & $engine --version 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the Godot version.'
}
$actualVersion = ($versionOutput | Out-String).Trim()
if ($actualVersion -notmatch ('^' + [regex]::Escape($expectedVersion) + '\.stable(?:\.|$)')) {
    throw "Expected Godot $expectedVersion stable; found $actualVersion."
}
Write-Host "Using Godot $actualVersion"

$logDirectory = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
# Prevent development output from becoming engine resources on later imports.
New-Item -ItemType File -Path (Join-Path $logDirectory '.gdignore') -Force | Out-Null

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$EngineArguments)

    $logPath = Join-Path $logDirectory "$Name.log"
    & $engine --headless --path $projectRoot --log-file $logPath @EngineArguments | Out-Host
    $engineExitCode = $LASTEXITCODE
    if ($engineExitCode -ne 0) {
        throw "$Name failed with exit code $engineExitCode. See $logPath."
    }
    if (-not (Test-Path -LiteralPath $logPath)) {
        throw "$Name did not produce its expected log: $logPath."
    }
    # Godot can report resource or script errors without a nonzero exit code.
    $reportedErrors = Select-String -LiteralPath $logPath -Pattern '^\s*(SCRIPT ERROR:|ERROR:)'
    if ($reportedErrors) {
        $reportedErrors | ForEach-Object { Write-Host $_.Line }
        throw "$Name reported engine errors. See $logPath."
    }
    Write-Host "$Name passed."
}

Invoke-GodotCheck -Name 'import' -EngineArguments @('--editor', '--import')
Invoke-GodotCheck -Name 'identity-regression' -EngineArguments @('--script', 'res://game/identity/tests/identity_regression.gd')
Invoke-GodotCheck -Name 'startup' -EngineArguments @('--quit-after', '3')
