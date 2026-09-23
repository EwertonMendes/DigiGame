#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-assets/external/central_city}"
CACHE_DIR="${2:-.cache/external-city-assets}"
ITCH_VERSION="1.3.0"

mkdir -p "$ROOT_DIR" "$CACHE_DIR"

download_pack() {
  local slug="$1"
  local url="$2"
  local dest="$ROOT_DIR/$slug"
  local cache="$CACHE_DIR/$slug"

  rm -rf "$dest"
  mkdir -p "$dest" "$cache"

  mapfile -t archives < <(find "$cache" -type f \( -iname '*.zip' -o -iname '*.7z' -o -iname '*.rar' \) | sort)
  if [[ ${#archives[@]} -eq 0 ]]; then
    echo "[CityAssets] Downloading $slug from $url"
    npx --yes "itchio-downloader@${ITCH_VERSION}" \
      --url "$url" \
      --downloadDirectory "$cache"
    mapfile -t archives < <(find "$cache" -type f \( -iname '*.zip' -o -iname '*.7z' -o -iname '*.rar' \) | sort)
  else
    echo "[CityAssets] Reusing cached archive for $slug"
  fi
  if [[ ${#archives[@]} -eq 0 ]]; then
    echo "::error::No downloadable archive found for $slug"
    find "$cache" -maxdepth 3 -type f -print || true
    exit 1
  fi

  local extracted=0
  for archive in "${archives[@]}"; do
    case "${archive,,}" in
      *.zip)
        unzip -oq "$archive" -d "$dest"
        extracted=1
        ;;
      *)
        echo "::warning::Skipping unsupported archive during CI staging: $archive"
        ;;
    esac
  done

  if [[ "$extracted" -ne 1 ]]; then
    echo "::error::No ZIP archive could be extracted for $slug"
    exit 1
  fi

  find "$dest" -type f -name '._*' -delete || true
  find "$dest" -type d -name '__MACOSX' -prune -exec rm -rf {} + || true
  echo "[CityAssets] $slug staged with $(find "$dest" -type f | wc -l) files"
}

download_pack "dystopian" "https://systemfehler-ich.itch.io/dystopian-city-starter-pack"
download_pack "future" "https://morithedaichi.itch.io/future-assets-free"

echo "[CityAssets] External city assets staged successfully."


if ! python3 -c 'import PIL' >/dev/null 2>&1; then
  echo "::error::Pillow is required to prepare optimized city assets. Install Pillow 11.3.0."
  exit 1
fi

python3 tools/prepare_external_city_assets.py "$ROOT_DIR"
