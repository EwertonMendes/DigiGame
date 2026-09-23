param(
    [string]$RootDir = "assets/external/central_city",
    [string]$CacheDir = ".cache/external-city-assets"
)

$ErrorActionPreference = "Stop"
$ItchVersion = "1.3.0"

function Resolve-Python {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @{ Exe = "py"; Prefix = @("-3") }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        return @{ Exe = "python"; Prefix = @() }
    }
    throw "Python 3 was not found. Install Python 3 and retry."
}

function Invoke-Python {
    param([string[]]$Arguments)
    $python = Resolve-Python
    & $python.Exe @($python.Prefix + $Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed with exit code $LASTEXITCODE."
    }
}

function Ensure-Pillow {
    $python = Resolve-Python
    & $python.Exe @($python.Prefix + @("-c", "import PIL"))
    if ($LASTEXITCODE -eq 0) {
        return
    }
    Write-Host "[CityAssets] Installing Pillow 11.3.0 for local preprocessing..."
    & $python.Exe @($python.Prefix + @("-m", "pip", "install", "--user", "Pillow==11.3.0"))
    if ($LASTEXITCODE -ne 0) {
        throw "Could not install Pillow 11.3.0."
    }
}

function Stage-Pack {
    param(
        [string]$Slug,
        [string]$Url
    )

    $dest = Join-Path $RootDir $Slug
    $cache = Join-Path $CacheDir $Slug

    if (Test-Path $dest) {
        Remove-Item $dest -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    New-Item -ItemType Directory -Force -Path $cache | Out-Null

    $archives = @(Get-ChildItem $cache -Recurse -File -Filter *.zip -ErrorAction SilentlyContinue)
    if ($archives.Count -eq 0) {
        if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
            throw "Node.js/npm (npx) was not found. Install Node.js LTS and retry."
        }
        Write-Host "[CityAssets] Downloading $Slug from $Url"
        & npx --yes "itchio-downloader@$ItchVersion" --url $Url --downloadDirectory $cache
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed for $Slug."
        }
        $archives = @(Get-ChildItem $cache -Recurse -File -Filter *.zip -ErrorAction SilentlyContinue)
    }
    else {
        Write-Host "[CityAssets] Reusing cached archive for $Slug"
    }

    if ($archives.Count -eq 0) {
        throw "No ZIP archive was found for $Slug."
    }

    foreach ($archive in $archives) {
        Expand-Archive -LiteralPath $archive.FullName -DestinationPath $dest -Force
    }

    Get-ChildItem $dest -Recurse -File -Filter "._*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "[CityAssets] $Slug staged."
}

New-Item -ItemType Directory -Force -Path $RootDir | Out-Null
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

Stage-Pack "dystopian" "https://systemfehler-ich.itch.io/dystopian-city-starter-pack"
Stage-Pack "future" "https://morithedaichi.itch.io/future-assets-free"

Ensure-Pillow
Invoke-Python @("tools/prepare_external_city_assets.py", $RootDir)
Invoke-Python @("tools/validate_external_city_assets.py")

Write-Host "[CityAssets] Central City external assets are ready for Godot."
