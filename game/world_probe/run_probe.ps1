[CmdletBinding()]
param([string]$GodotPath='godot')
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'This process-memory runner requires Windows; the Godot probe itself is cross-platform.'}
$projectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$engine=(Get-Command $GodotPath -CommandType Application -ErrorAction Stop).Source
$version=(& $engine --version | Out-String).Trim()
if($version -notmatch '^4\.7\.2\.stable(?:\.|$)'){throw "Expected pinned Godot4.7.2; found $version"}
$artifactRoot=Join-Path $projectRoot '.artifacts/d01'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $projectRoot '.artifacts/.gdignore') -Force | Out-Null
function Invoke-Probe {
    param([string]$Name,[switch]$Baseline)
    $output=Join-Path $artifactRoot "$Name.json"
    $stdout=Join-Path $artifactRoot "$Name.stdout.log"
    $stderr=Join-Path $artifactRoot "$Name.stderr.log"
    $arguments=@('--headless','--path',('"'+$projectRoot+'"'),'--script','res://game/world_probe/full_size_probe.gd','--',('"--out='+$output+'"'))
    if($Baseline){$arguments+='--baseline'}
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $peakWorking=0L
    $maxPrivate=0L
    $samples=0
    while(-not $process.HasExited){
        try{$process.Refresh();$peakWorking=[Math]::Max($peakWorking,[long]$process.PeakWorkingSet64);$maxPrivate=[Math]::Max($maxPrivate,[long]$process.PrivateMemorySize64);$samples++}catch [System.InvalidOperationException]{}
        $null=$process.WaitForExit(10)
    }
    $process.WaitForExit()
    if($process.ExitCode -ne 0){throw "$Name failed; inspect its ignored logs"}
    $errors=Select-String -LiteralPath $stdout,$stderr -Pattern '^\s*(ERROR:|SCRIPT ERROR:|FAIL:)'
    if($errors){throw "$Name reported an engine/probe error; inspect its ignored logs"}
    $result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    if(-not $result.valid){throw "$Name failed data checks"}
    $result | Add-Member -NotePropertyName process_observations -NotePropertyValue @{peak_working_set_bytes=$peakWorking;sampled_max_private_bytes=$maxPrivate;poll_samples=$samples;poll_interval_ms=10}
    Write-Host "$Name valid; allocation/fill=$($result.allocate_fill_ms)ms queries=$($result.indexed_queries_ms)ms peakWorkingSet=$peakWorking bytes"
    return $result
}
$baseline=Invoke-Probe -Name 'baseline' -Baseline
$runs=@(1..3 | ForEach-Object {Invoke-Probe -Name ('run-'+$_)})
if(@($runs.query_checksum | Select-Object -Unique).Count -ne 1){throw 'Fresh-process query checksums differ'}
$os=Get-CimInstance Win32_OperatingSystem
$hardware=@{cpu=(Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name);installed_ram_bytes=(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum;os_reported_physical_ram_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;os=$os.Caption;os_version=$os.Version;os_build=$os.BuildNumber;gpu=@(Get-CimInstance Win32_VideoController | ForEach-Object {@{name=$_.Name;driver_version=$_.DriverVersion}})}
$summary=@{scope='D01 headless calibration, no rendering or production target claim';engine=$version;hardware=$hardware;baseline=$baseline;runs=$runs;memory_note='Process OS lifetime peak working set and sampled private allocation; baseline is a separate empty-probe process, not an exact allocation delta. Engine static counters are separate. GPU is not exercised.'}
$summary | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath (Join-Path $artifactRoot 'measurements.json') -Encoding utf8
Write-Host 'Three fresh-process runs agree; sanitized measurements saved under .artifacts/d01/measurements.json'
