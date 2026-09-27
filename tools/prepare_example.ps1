param([string]$GutPath = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$hostPath = Join-Path $repo '.local/example'
$pluginPath = Join-Path $hostPath 'addons/skelerealms'
# Build a disposable host from an explicit allowlist. Never follow the example's
# repository symlink: on Windows it may instead be a plain text placeholder.
New-Item -ItemType Directory -Force $hostPath, $pluginPath | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repo 'example') | Where-Object Name -ne 'addons' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $hostPath -Recurse -Force
}
foreach ($folder in @('scripts', 'tools')) {
    Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination $pluginPath -Recurse -Force
}
Get-ChildItem -LiteralPath $repo -File | Where-Object { $_.Extension -in '.gd', '.tscn', '.cfg', '.svg', '.png', '.obj', '.mtl' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $pluginPath -Force
}
foreach ($folder in @('doors', 'networks', 'mods')) {
    New-Item -ItemType Directory -Force (Join-Path $hostPath $folder) | Out-Null
}
if ($GutPath) {
    $resolvedGut = (Resolve-Path -LiteralPath $GutPath).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedGut 'gut_cmdln.gd'))) { throw 'GutPath must point to addons/gut.' }
    Copy-Item -LiteralPath $resolvedGut -Destination (Join-Path $hostPath 'addons') -Recurse -Force
    # GUT 9.4's inner Option class collides with the framework's public Option.
    # Rename only that private test-runner symbol in the disposable host.
    $cliPath = Join-Path $hostPath 'addons/gut/cli/optparse.gd'
    $cli = [IO.File]::ReadAllText($cliPath) -replace '\bOption\b', 'GutCliOption'
    [IO.File]::WriteAllText($cliPath, $cli)
    $testPath = Join-Path $hostPath 'tests'
    New-Item -ItemType Directory -Force $testPath | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'tests') -Filter '*.gd' | ForEach-Object {
        $content = [IO.File]::ReadAllText($_.FullName).Replace('res://scripts/', 'res://addons/skelerealms/scripts/')
        [IO.File]::WriteAllText((Join-Path $testPath $_.Name), $content)
    }
}
Write-Output "Prepared $hostPath/project.godot"
