param(
    [string]$Godot,
    [switch]$Capture
)

$ErrorActionPreference = 'Stop'
$sandboxRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sandboxOutput = Join-Path $sandboxRoot '.tmp'
if (-not $Godot) {
    $Godot = Join-Path $sandboxRoot '.tmp/godot/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $Godot)) {
    throw 'Pass -Godot with the path to a Godot 4.7 executable.'
}
$Godot = [IO.Path]::GetFullPath($Godot)
$sandboxRoaming = Join-Path $sandboxOutput 'local-profile/roaming'
$sandboxCache = Join-Path $sandboxOutput 'local-profile/local'
New-Item -ItemType Directory -Force $sandboxRoaming,$sandboxCache | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
Push-Location $sandboxRoot
try {
    # Keep test saves, logs, editor preferences and caches in the ignored workspace.
    $env:APPDATA = $sandboxRoaming
    $env:LOCALAPPDATA = $sandboxCache
    $sandboxLog = Join-Path $sandboxOutput 'city-local-runtime.log'
    $sandboxTest = Join-Path $sandboxOutput 'city-local-test.log'
    & $Godot --headless --path $sandboxRoot --script experiments/darkmoon_sandbox/test_sandbox.gd --quit-after 180 --log-file $sandboxLog -- --private *> $sandboxTest
    $sandboxExit = $LASTEXITCODE
    $sandboxText = Get-Content -LiteralPath $sandboxTest -Raw
    if ($sandboxExit -ne 0 -or $sandboxText -match 'SCRIPT ERROR|Parse Error|ERROR:' -or $sandboxText -notmatch '\[DarkmoonSandboxTest\] PASS') {
        throw $sandboxText
    }
    Write-Output 'Local headless city checks passed.'
    if ($Capture) {
        $sandboxArguments = '--path "' + $sandboxRoot + '" --script experiments/darkmoon_sandbox/test_sandbox.gd --quit-after 180 --resolution 1280x720 --position -3000,-3000 --audio-driver Dummy --log-file "' + $sandboxLog + '" -- --private'
        $sandboxProcess = Start-Process -FilePath $Godot -ArgumentList $sandboxArguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $sandboxOutput 'city-local-capture.log') -RedirectStandardError (Join-Path $sandboxOutput 'city-local-capture.err.log') -Wait -PassThru
        $sandboxErrors = Get-Content -LiteralPath (Join-Path $sandboxOutput 'city-local-capture.err.log') -Raw
        $sandboxCaptureText = Get-Content -LiteralPath (Join-Path $sandboxOutput 'city-local-capture.log') -Raw
        if ($sandboxProcess.ExitCode -ne 0 -or ($sandboxErrors + $sandboxCaptureText) -match 'SCRIPT ERROR|Parse Error|ERROR:' -or $sandboxCaptureText -notmatch '\[DarkmoonSandboxTest\] PASS') {
            throw ($sandboxErrors + $sandboxCaptureText)
        }
        Write-Output 'Local GPU captures saved to .tmp/sandbox-private-*.png.'
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    Pop-Location
}
