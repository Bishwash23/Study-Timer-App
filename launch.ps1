# ============================================================
#  Study Timer launcher — serves Timer.html on localhost
# ============================================================
$ErrorActionPreference = 'Stop'

# --- config ---
$port         = 8765          # change if something else uses it
$useAppWindow = $true         # $false = open in your default browser instead
# --------------

$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$index = Join-Path $root 'Timer.html'

if (-not (Test-Path $index)) {
    Write-Host "Timer.html not found next to launch.ps1." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# If a server is already running on the port, just open a new window.
$alreadyRunning = $false
try {
    $probe = New-Object Net.Sockets.TcpClient
    $probe.Connect('localhost', $port)
    $probe.Close()
    $alreadyRunning = $true
} catch { }

function Open-Timer {
    $url = "http://localhost:$port/"
    if ($useAppWindow) {
        $edge = @(
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($edge) { Start-Process $edge "--app=$url"; return }
    }
    Start-Process $url
}

if ($alreadyRunning) {
    Write-Host "Study Timer is already running. Opening window..." -ForegroundColor Green
    Open-Timer
    Start-Sleep -Seconds 1
    exit 0
}

$bytes    = [IO.File]::ReadAllBytes($index)
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
} catch {
    Write-Host "Could not start server on port $port." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "Another program may be using this port."
    Write-Host "Edit `$port at the top of launch.ps1, then run again."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  Study Timer is live at http://localhost:$port/" -ForegroundColor Green
Write-Host "  Close this window to stop the server." -ForegroundColor DarkGray
Write-Host ""

Open-Timer

try {
    while ($listener.IsListening) {
        $ctx = $null
        try { $ctx = $listener.GetContext() } catch { break }

        $req = $ctx.Request
        $res = $ctx.Response
        try {
            $path = $req.Url.AbsolutePath
            if ($req.HttpMethod -eq 'GET' -and $path -in @('/', '/Timer.html', '/index.html')) {
                $res.StatusCode      = 200
                $res.ContentType     = 'text/html; charset=utf-8'
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $res.StatusCode = 404
            }
        } catch {
            # ignore client-disconnect races
        } finally {
            try { $res.OutputStream.Close() } catch {}
        }
    }
} finally {
    try { $listener.Stop() } catch {}
    Write-Host "Server stopped." -ForegroundColor DarkGray
}