param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$records = @()
foreach ($relative in (& git -C $Root ls-files --cached --others --exclude-standard | Sort-Object -Unique)) {
    if (-not $relative.EndsWith('.ps1')) { continue }
    $absolute = Join-Path $Root $relative
    if (!(Test-Path -LiteralPath $absolute -PathType Leaf)) { continue }
    $tokens = $null
    $parseErrors = $null
    $tree = [System.Management.Automation.Language.Parser]::ParseFile($absolute, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "Cannot map invalid PowerShell: $relative : $parseErrors" }
    $functions = @()
    $names = @{}
    $blockCounts = @{}
    foreach ($definition in $tree.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -or ($node -is [System.Management.Automation.Language.ScriptBlockAst] -and $node.Parent -is [System.Management.Automation.Language.ScriptBlockExpressionAst])}, $true)) {
        $owner = ''
        $ancestor = $definition.Parent
        while ($ancestor) {
            $offset = [string]$ancestor.Extent.StartOffset
            if ($names.ContainsKey($offset)) { $owner = $names[$offset]; break }
            $ancestor = $ancestor.Parent
        }
        $isFunction = $definition -is [System.Management.Automation.Language.FunctionDefinitionAst]
        if ($isFunction) {
            $name = $(if ($owner) { $owner + '.' } else { '' }) + $definition.Name
            $body = $definition.Body
        } else {
            if (!$blockCounts.ContainsKey($owner)) { $blockCounts[$owner] = 0 }
            $blockCounts[$owner]++
            $name = $owner + '/<scriptblock#' + $blockCounts[$owner] + '>'
            $body = $definition
        }
        $names[[string]$definition.Extent.StartOffset] = $name
        $calls = @()
        foreach ($command in $body.FindAll({param($node) $node -is [System.Management.Automation.Language.CommandAst]}, $true)) {
            $scope = $command.Parent
            while ($scope -and $scope -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $scope = $scope.Parent }
            if ($scope -ne $body) { continue }
            $commandName = $command.GetCommandName()
            if (!$commandName -and $command.CommandElements.Count) { $commandName = $command.CommandElements[0].Extent.Text }
            if ($commandName) { $calls += $commandName }
        }
        $functions += @{name=$name; kind=$(if ($isFunction) {'function'} else {'lambda'}); parent=$owner; line=$definition.Extent.StartLineNumber; end_line=$definition.Extent.EndLineNumber; source=$definition.Extent.Text; calls=@($calls | Sort-Object -Unique)}
    }
    $records += @{path=$relative.Replace('\','/'); functions=$functions}
}
ConvertTo-Json -InputObject @($records) -Depth 12 -Compress
