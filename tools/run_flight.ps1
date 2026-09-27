param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $GodotPath) {
    $localEngine = Join-Path $repo '.local/godot/Godot_v4.4.1-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) {
        $GodotPath = $localEngine
    } else {
        $engineCommand = Get-Command godot -ErrorAction SilentlyContinue
        if (-not $engineCommand) { throw 'Godot was not found. Pass -GodotPath with your Godot executable.' }
        $GodotPath = $engineCommand.Source
    }
}
& $GodotPath --path (Join-Path $repo 'flight_sandbox')
