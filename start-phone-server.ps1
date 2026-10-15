# start-phone-server.ps1 - Robust HTTP Server for Pocket Ledger PWA
# Supports Cloudflare Tunnel, Chrome Android, Samsung Internet, and WebAPK minting
param([int]$Port = 8899)

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = Get-Location }

$listener = New-Object System.Net.HttpListener

# Listen on 127.0.0.1 and localhost (works without admin rights)
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Prefixes.Add("http://localhost:$Port/")

# Try adding wildcard prefix if running with elevated privileges
try {
    $listener.Prefixes.Add("http://*:$Port/")
} catch {
    # Non-elevated: wildcard ignored, localhost and 127.0.0.1 remain active
}

try {
    $listener.Start()
} catch {
    # If wildcard failed on Start, retry with localhost only
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
}

$ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1
$ip = if ($ipObj) { $ipObj.IPAddress } else { "127.0.0.1" }

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  POCKET LEDGER PHONE SERVER RUNNING!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Port: $Port"
Write-Host "  Local URL:   http://127.0.0.1:$Port"
Write-Host "  Network URL: http://$($ip):$Port"
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Listening for incoming requests... Press Ctrl+C to stop.`n"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response

        # CORS headers
        $res.AddHeader("Access-Control-Allow-Origin", "*")
        $res.AddHeader("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        $res.AddHeader("Access-Control-Allow-Headers", "*")
        $res.AddHeader("Service-Worker-Allowed", "/")
        $res.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")

        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 204
            $res.Close()
            continue
        }

        $rawPath = $req.Url.AbsolutePath
        $relPath = $rawPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)

        if ([string]::IsNullOrEmpty($relPath) -or $relPath -eq "index.html") {
            $filePath = Join-Path $baseDir "index.html"
        } else {
            $filePath = Join-Path $baseDir $relPath
        }

        # Prevent directory traversal
        $fullPath = [System.IO.Path]::GetFullPath($filePath)
        if (-not $fullPath.StartsWith($baseDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $res.StatusCode = 403
            $res.ContentType = "text/plain"
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $res.ContentLength64 = $errBytes.Length
            $res.OutputStream.Write($errBytes, 0, $errBytes.Length)
            $res.Close()
            continue
        }

        if (Test-Path $fullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $mime = switch ($ext) {
                ".html"        { "text/html; charset=utf-8" }
                ".css"         { "text/css; charset=utf-8" }
                ".js"          { "application/javascript; charset=utf-8" }
                ".json"        { "application/manifest+json; charset=utf-8" }
                ".webmanifest" { "application/manifest+json; charset=utf-8" }
                ".png"         { "image/png" }
                ".svg"         { "image/svg+xml" }
                ".ico"         { "image/x-icon" }
                default        { "application/octet-stream" }
            }

            $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
            $res.StatusCode = 200
            $res.ContentType = $mime
            $res.ContentLength64 = $fileBytes.Length

            if ($req.HttpMethod -ne "HEAD") {
                $res.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
            }
            $res.Close()
        } else {
            $res.StatusCode = 404
            $res.ContentType = "text/plain"
            $notFound = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $res.ContentLength64 = $notFound.Length
            if ($req.HttpMethod -ne "HEAD") {
                $res.OutputStream.Write($notFound, 0, $notFound.Length)
            }
            $res.Close()
        }
    } catch {
        # Keep listening even if a single client aborts or disconnects prematurely
    }
}

if ($listener.IsListening) { $listener.Stop() }
$listener.Close()
