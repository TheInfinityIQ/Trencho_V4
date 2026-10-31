[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [switch]$SceneInput
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

& (Join-Path $PSScriptRoot 'setup_gdunit4.ps1')
Invoke-GodotCheck -Name 'import' -EngineArguments @('--editor', '--import')
Invoke-GodotCheck -Name 'identity-regression' -EngineArguments @('--script', 'res://game/identity/tests/identity_regression.gd')
Invoke-GodotCheck -Name 'receiving-regression' -EngineArguments @('--script', 'res://game/procurement/tests/receiving_regression.gd')
Invoke-GodotCheck -Name 'receiving-ui' -EngineArguments @('--script', 'res://game/procurement/tests/receiving_ui_regression.gd')
Invoke-GodotCheck -Name 'rear-regression' -EngineArguments @('--script', 'res://game/staffing/tests/rear_regression.gd')
Invoke-GodotCheck -Name 'construction-regression' -EngineArguments @('--script', 'res://game/construction/tests/construction_regression.gd')
Invoke-GodotCheck -Name 'construction-ui' -EngineArguments @('--script', 'res://game/construction/tests/construction_ui_smoke.gd')
Invoke-GodotCheck -Name 'vehicle-regression' -EngineArguments @('--script', 'res://game/vehicles/tests/vehicle_regression.gd')
Invoke-GodotCheck -Name 'dispatch-regression' -EngineArguments @('--script', 'res://game/dispatch/tests/dispatch_regression.gd')
Invoke-GodotCheck -Name 'rear-start-regression' -EngineArguments @('--script', 'res://game/scenario/tests/rear_start_regression.gd')
Invoke-GodotCheck -Name 'battlefield-start-regression' -EngineArguments @('--script', 'res://game/scenario/tests/battlefield_start_regression.gd')
Invoke-GodotCheck -Name 'farmland-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/farmland_regression.gd')
Invoke-GodotCheck -Name 'route-regression' -EngineArguments @('--script', 'res://game/routes/tests/route_regression.gd')
Invoke-GodotCheck -Name 'route-contact-regression' -EngineArguments @('--script', 'res://game/routes/tests/route_contact_regression.gd')
Invoke-GodotCheck -Name 'hq-regression' -EngineArguments @('--script', 'res://game/hq/tests/hq_regression.gd')
Invoke-GodotCheck -Name 'military-regression' -EngineArguments @('--script', 'res://game/military/tests/military_regression.gd')
Invoke-GodotCheck -Name 'crew-casualty-regression' -EngineArguments @('--script', 'res://game/military/tests/crew_casualty_regression.gd')
Invoke-GodotCheck -Name 'troop-transport-regression' -EngineArguments @('--script', 'res://game/military/tests/troop_transport_regression.gd')
Invoke-GodotCheck -Name 'combat-regression' -EngineArguments @('--script', 'res://game/combat/tests/combat_regression.gd')
Invoke-GodotCheck -Name 'vehicle-combat-regression' -EngineArguments @('--script', 'res://game/vehicle_combat/tests/vehicle_combat_regression.gd')
Invoke-GodotCheck -Name 'recovery-regression' -EngineArguments @('--script', 'res://game/vehicle_recovery/tests/recovery_regression.gd')
Invoke-GodotCheck -Name 'recovery-mines-regression' -EngineArguments @('--script', 'res://game/vehicle_recovery/tests/recovery_mines_regression.gd')
Invoke-GodotCheck -Name 'order-regression' -EngineArguments @('--script', 'res://game/orders/tests/order_regression.gd')
Invoke-GodotCheck -Name 'occupant-observation-regression' -EngineArguments @('--script', 'res://game/orders/tests/occupant_observation_regression.gd')
Invoke-GodotCheck -Name 'observation-range-regression' -EngineArguments @('--script', 'res://game/orders/tests/observation_range_regression.gd')
Invoke-GodotCheck -Name 'objective-regression' -EngineArguments @('--script', 'res://game/objectives/tests/objective_regression.gd')
Invoke-GodotCheck -Name 'field-regression' -EngineArguments @('--script', 'res://game/field_structures/tests/field_regression.gd')
Invoke-GodotCheck -Name 'bridge-regression' -EngineArguments @('--script', 'res://game/bridges/tests/bridge_regression.gd')
Invoke-GodotCheck -Name 'mine-regression' -EngineArguments @('--script', 'res://game/mines/tests/mine_regression.gd')
Invoke-GodotCheck -Name 'demolition-regression' -EngineArguments @('--script', 'res://game/bridges/tests/demolition_regression.gd')
Invoke-GodotCheck -Name 'rear-ui' -EngineArguments @('--script', 'res://game/staffing/tests/rear_ui_regression.gd')
Invoke-GodotCheck -Name 'terrain-regression' -EngineArguments @('--script', 'res://game/terrain/tests/terrain_regression.gd')
Invoke-GodotCheck -Name 'route-sweep-regression' -EngineArguments @('--script', 'res://game/terrain/tests/route_sweep_regression.gd')
Invoke-GodotCheck -Name 'route-tile-reuse-regression' -EngineArguments @('--script', 'res://game/terrain/tests/route_tile_reuse_regression.gd')
Invoke-GodotCheck -Name 'terrain-ui' -EngineArguments @('--script', 'res://game/terrain/tests/terrain_ui_regression.gd')
Invoke-GodotCheck -Name 'world-data-probe' -EngineArguments @('--script', 'res://game/world_probe/full_size_probe.gd')
Invoke-GodotCheck -Name 'battlefield-session-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/session_regression.gd')
Invoke-GodotCheck -Name 'ui-refresh-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/ui_refresh_regression.gd')
Invoke-GodotCheck -Name 'hq-location-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/hq_location_regression.gd')
Invoke-GodotCheck -Name 'army-hierarchy-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/army_hierarchy_regression.gd')
Invoke-GodotCheck -Name 'battlefield-presentation-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/presentation_regression.gd')
Invoke-GodotCheck -Name 'objective-ownership-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/objective_ownership_regression.gd')
Invoke-GodotCheck -Name 'squad-execution-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/squad_execution_regression.gd')
Invoke-GodotCheck -Name 'vehicle-execution-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/vehicle_execution_regression.gd')
Invoke-GodotCheck -Name 'execution-safety-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/execution_safety_regression.gd')
Invoke-GodotCheck -Name 'observed-armour-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/observed_armour_regression.gd')
Invoke-GodotCheck -Name 'sustained-rifle-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/sustained_rifle_regression.gd')
Invoke-GodotCheck -Name 'forward-supply-regression' -EngineArguments @('--script', 'res://game/forward_supply/tests/forward_supply_regression.gd')
Invoke-GodotCheck -Name 'vehicle-rack-issue-regression' -EngineArguments @('--script', 'res://game/forward_supply/tests/vehicle_rack_issue_regression.gd')
Invoke-GodotCheck -Name 'forward-transport-regression' -EngineArguments @('--script', 'res://game/forward_supply/tests/forward_transport_regression.gd')
Invoke-GodotCheck -Name 'forward-clock-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/forward_clock_regression.gd')
Invoke-GodotCheck -Name 'startup' -EngineArguments @('--quit-after', '3')

& (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $engine -Suite Domain
if ($SceneInput) {
    & (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $engine -Suite Input
} else {
    Write-Host 'Scene-input pilot NOT RUN: requires a display. CI runs check.ps1 -SceneInput under Xvfb.'
}


Invoke-GodotCheck -Name 'forward-delivery-ui-regression' -EngineArguments @('--script', 'res://game/forward_supply/tests/forward_delivery_ui_regression.gd')
Invoke-GodotCheck -Name 'opening-regression' -EngineArguments @('--script', 'res://game/scenario/tests/opening_regression.gd')
Invoke-GodotCheck -Name 'opening-queued-refusal-regression' -EngineArguments @('--script', 'res://game/scenario/tests/opening_regression.gd','--','--refuse-first-lift')
Invoke-GodotCheck -Name 'hq-affiliation-regression' -EngineArguments @('--script', 'res://game/orders/tests/hq_affiliation_regression.gd')
Invoke-GodotCheck -Name 'mass-inspection-regression' -EngineArguments @('--script', 'res://game/identity/tests/mass_inspection_regression.gd')
Invoke-GodotCheck -Name 'opening-resupply-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/opening_resupply_regression.gd')
Invoke-GodotCheck -Name 'opening-resupply-edges-regression' -EngineArguments @('--script', 'res://game/battlefield/tests/opening_resupply_edges_regression.gd')
