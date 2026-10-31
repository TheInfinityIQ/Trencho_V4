[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This local resource guard is for Windows; use the bounded GitHub job elsewhere.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $version = (Get-Content (Join-Path $projectRoot '.godot-version') -Raw).Trim()
    $GodotPath = Join-Path $projectRoot ".tools/godot/Godot_v$version-stable_win64.exe"
}
$engine = (Get-Command $GodotPath -CommandType Application -ErrorAction Stop).Source
if (-not ('WindowsCurrentCheckProcess' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'windows_current_check_process.cs') }
$reports = Join-Path $projectRoot '.artifacts/gdunit4/local-supply'
New-Item -ItemType Directory -Path $reports -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $projectRoot '.artifacts/.gdignore') -Force | Out-Null
& (Join-Path $PSScriptRoot 'setup_gdunit4.ps1')
$versionLog = Join-Path $reports 'version.log'
if ([WindowsCurrentCheckProcess]::Run($engine,@('--headless','--version'),$projectRoot,$versionLog,5000) -ne 0) { throw 'Engine version check failed.' }
$expected = (Get-Content (Join-Path $projectRoot '.godot-version') -Raw).Trim()+'.'
if (-not ((Get-Content $versionLog -Raw).StartsWith($expected))) { throw 'Use the exact project Godot version.' }
$importLog = Join-Path $reports 'import.log'
$importArgs = @('--headless','--single-threaded-scene','--path',$projectRoot,'--editor','--import')
$temporaryIgnores = @()
try {
    # Old suites are not needed for this current component. Import production
    # globals and the pinned framework; the explicit case loads from its path.
    foreach ($directory in Get-ChildItem (Join-Path $projectRoot 'game') -Directory -Recurse -Filter tests) {
        $marker = Join-Path $directory.FullName '.gdignore'
        if (-not (Test-Path -LiteralPath $marker)) {
            New-Item -ItemType File -Path $marker | Out-Null
            $temporaryIgnores += $marker
        }
    }
    if ([WindowsCurrentCheckProcess]::Run($engine,$importArgs,$projectRoot,$importLog,30000) -ne 0) { throw "Bounded local import failed; see $importLog" }
} finally {
    foreach ($marker in $temporaryIgnores) { Remove-Item -LiteralPath $marker }
}
if (Select-String -LiteralPath $importLog -Pattern '^\s*(SCRIPT ERROR:|ERROR:)') { throw "Local import reported errors; see $importLog" }
& (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $engine -Suite SupplyComponent -ReportName local-supply -LocalResourceLimits
