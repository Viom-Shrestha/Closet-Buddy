$ErrorActionPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = Join-Path $Root ".venv\Scripts\python.exe"
$BackendDir = Join-Path $Root "backend"
$FrontendExe = Join-Path $Root "frontend\build\windows\x64\runner\Release\closet_buddy.exe"
$LogFile = Join-Path $Root "backend_demo.log"

function Test-PortOpen {
    param([int]$Port)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(1000)
        if ($ok -and $client.Connected) { $client.Close(); return $true }
        $client.Close()
        return $false
    } catch {
        return $false
    }
}

if (-not (Test-Path $PythonExe)) { exit 1 }
if (-not (Test-Path $FrontendExe)) { exit 1 }

$startedBackend = $false
if (-not (Test-PortOpen -Port 8000)) {
    $startedBackend = $true
    $argStr = "/c `"`"$PythonExe`" manage.py runserver 127.0.0.1:8000 --noreload > `"$LogFile`" 2>&1`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $argStr -WorkingDirectory $BackendDir -WindowStyle Hidden | Out-Null

    $tries = 0
    while (-not (Test-PortOpen -Port 8000) -and $tries -lt 90) {
        Start-Sleep -Seconds 2
        $tries++
    }
}

Start-Process -FilePath $FrontendExe -WorkingDirectory (Split-Path $FrontendExe) -Wait

if ($startedBackend) {
    $listeners = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
    foreach ($l in $listeners) {
        Stop-Process -Id $l.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}
