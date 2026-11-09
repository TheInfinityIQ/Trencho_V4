[CmdletBinding()]
param([switch]$Check, [switch]$OpenUiMap)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pythonCommand = Get-Command py.exe -ErrorAction SilentlyContinue
$pythonArguments = @()
$installedPython = Join-Path $env:USERPROFILE 'AppData/Local/Python/pythoncore-3.13-64/python.exe'
if (Test-Path -LiteralPath $installedPython) {
    $python = $installedPython
} elseif ($pythonCommand -and $pythonCommand.Source -notlike '*\Microsoft\WindowsApps\*') {
    $python = $pythonCommand.Source
    $pythonArguments = @('-3')
} else {
    $python = (Get-Command python -ErrorAction Stop).Source
    if ($python -like '*\Microsoft\WindowsApps\*') { throw 'Install Python 3.10 or newer; the Windows Store launcher alias cannot run this tool.' }
}
$localParser = Join-Path $root '.tools/gdscript-parser/gdtoolkit'
$mapParser = Join-Path $root '.tools/system-map-deps/gdtoolkit'
if (!(Test-Path -LiteralPath $localParser) -and !(Test-Path -LiteralPath $mapParser)) {
    & $python @pythonArguments -m pip install --disable-pip-version-check --target (Join-Path $root '.tools/system-map-deps') -r (Join-Path $PSScriptRoot 'system_map_requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Could not install the pinned source parser.' }
}
$mode = if ($Check) { '--check' } else { '--update' }
if ($OpenUiMap) {
    & $python @pythonArguments (Join-Path $root 'tools/ui_function_map.py') --check --diagram-only
    if ($LASTEXITCODE -eq 0) {
        Start-Process -FilePath (Join-Path $root 'docs/ui_function_map.html')
        exit 0
    }
    Write-Output 'Refreshing source locations before opening the UI function map.'
}
& $python @pythonArguments (Join-Path $PSScriptRoot 'system_map.py') $mode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $python @pythonArguments (Join-Path $root 'tools/ui_function_map.py') $mode --diagram-only
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$atlasArguments = if ($Check) { @('--check') } else { @() }
& $python @pythonArguments (Join-Path $root 'tools/system_atlas.py') @atlasArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# The generated HTML is itself part of the living map. Fingerprint it after
# regeneration; checking stays read-only and never rewrites either document.
if (!$Check) {
    & $python @pythonArguments (Join-Path $PSScriptRoot 'system_map.py') --update
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if ($OpenUiMap) { Start-Process -FilePath (Join-Path $root 'docs/ui_function_map.html') }
exit 0
