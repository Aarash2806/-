# Downloads the three built-in UCI engine binaries (latest GitHub releases)
# into engines-bin/<name>/<name>.exe so the Flutter build output can bundle
# them. Best-effort: a failed download is reported but does NOT fail the
# build - the app simply won't list that engine until it is present.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $root 'engines-bin'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$UA = @{ 'User-Agent' = 'chessyar-build' }

function Get-LatestAsset($repo, $patterns) {
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $UA
        foreach ($pat in $patterns) {
            $asset = $rel.assets | Where-Object { $_.name -match $pat } | Select-Object -First 1
            if ($asset) { return $asset }
        }
        Write-Warning "[$repo] release '$($rel.tag_name)' has no asset matching: $($patterns -join ', ')"
        Write-Warning "[$repo] available assets: $($rel.assets.name -join ', ')"
    } catch {
        Write-Warning "[$repo] GitHub API request failed: $($_.Exception.Message)"
    }
    return $null
}

function Install-Engine($name, $repo, $patterns, $exeHint) {
    $destDir = Join-Path $out $name
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $asset = Get-LatestAsset $repo $patterns
    if (-not $asset) { Write-Warning "[$name] SKIPPED"; return }

    Write-Host "[$name] downloading $($asset.name) ..."
    $file = Join-Path $env:TEMP $asset.name
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -Headers $UA -ErrorAction Stop
    } catch {
        Write-Warning "[$name] download failed: $($_.Exception.Message)"; return
    }

    if ($asset.name -match '\.zip$') {
        $tmp = Join-Path $env:TEMP ("ex_" + $name)
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $file -DestinationPath $tmp -Force
        $exe = Get-ChildItem $tmp -Recurse -Filter '*.exe' |
               Where-Object { $_.Name -match $exeHint } | Select-Object -First 1
        if (-not $exe) {
            $exe = Get-ChildItem $tmp -Recurse -Filter '*.exe' | Select-Object -First 1
        }
        if ($exe) { Copy-Item $exe.FullName (Join-Path $destDir "$name.exe") -Force }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    } elseif ($asset.name -match '\.exe$') {
        Copy-Item $file (Join-Path $destDir "$name.exe") -Force
    } else {
        Write-Warning "[$name] unexpected asset type: $($asset.name)"
    }
    Remove-Item $file -Force -ErrorAction SilentlyContinue

    if (Test-Path (Join-Path $destDir "$name.exe")) {
        Write-Host "[$name] OK -> engines-bin/$name/$name.exe" -ForegroundColor Green
    } else {
        Write-Warning "[$name] no engine exe was extracted - SKIPPED"
    }
}

# Pattern lists are tried in order; first match wins.
Install-Engine 'stockfish'  'official-stockfish/Stockfish' @('stockfish-windows-x86-64-avx2\.zip$', 'stockfish-windows-x86-64-sse41-popcnt\.zip$') 'stockfish'
Install-Engine 'berserk'    'jhonnold/berserk'             @('windows.*x64.*\.zip$', 'windows.*\.zip$', 'win.*\.zip$') 'berserk'
Install-Engine 'viridithas' 'cosmobobak/viridithas'        @('windows.*\.exe$', 'windows.*\.zip$') 'viridithas'

Write-Host ""
Write-Host "engines-bin contents:"
Get-ChildItem $out -Recurse -Filter '*.exe' | ForEach-Object { Write-Host "  $($_.FullName)" }
