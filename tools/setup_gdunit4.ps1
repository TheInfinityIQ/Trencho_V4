[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pin = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'gdunit4.lock.json') -Raw | ConvertFrom-Json
$cache = Join-Path $projectRoot '.tools/gdunit4'
$addon = [IO.Path]::GetFullPath((Join-Path $projectRoot 'addons/gdUnit4'))
$archivePath = Join-Path $cache ($pin.commit + '.zip')
New-Item -ItemType Directory -Path $cache -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $projectRoot '.tools/.gdignore') -Force | Out-Null
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri $pin.archive_url -OutFile $archivePath
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $pin.sha256) {
    throw "GdUnit4 archive checksum mismatch: $archivePath. Do not import this archive."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$expectedFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
try {
    foreach ($entry in $archive.Entries) {
        if (-not $entry.FullName.StartsWith($pin.archive_prefix, [StringComparison]::Ordinal) -or -not $entry.Name) { continue }
        $relative = $entry.FullName.Substring($pin.archive_prefix.Length)
        $target = [IO.Path]::GetFullPath((Join-Path $addon $relative))
        if (-not $target.StartsWith($addon + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) {
            throw 'GdUnit4 archive contains an unsafe path.'
        }
        [void]$expectedFiles.Add($relative)
        $stream = $entry.Open()
        try { $expectedHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) } finally { $stream.Dispose() }
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $expectedHash) {
                throw "Generated GdUnit4 dependency differs from the pin: $target. Preserve intentional edits before rebuilding this ignored dependency."
            }
        } else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target)
        }
    }
    if (-not $expectedFiles.Contains('bin/GdUnitCmdTool.gd') -or -not $expectedFiles.Contains('LICENSE')) {
        throw 'GdUnit4 archive is missing its runner or license.'
    }
    foreach ($file in Get-ChildItem -LiteralPath $addon -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($addon, $file.FullName).Replace('\', '/')
        # Godot generates sidecars during import; extra executable/source content is not accepted.
        if (-not $expectedFiles.Contains($relative) -and $file.Extension -notin '.uid', '.import') {
            throw "Unexpected file in generated GdUnit4 dependency: $relative"
        }
    }
} finally { $archive.Dispose() }
Write-Host "Verified GdUnit4 $($pin.version) at $($pin.commit); $($expectedFiles.Count) pinned files."
