#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path("assets/external/central_city/processed")
MANIFEST = ROOT / "manifest.json"
REQUIRED = {
    "future_06", "future_11", "future_12", "future_18", "future_19",
    "future_13", "future_20", "future_21", "future_22", "future_24", "future_26", "future_27",
    "future_29", "future_32", "future_33", "future_34", "future_35",
    "future_36", "dystopian_road_a", "dystopian_road_b",
    "dystopian_street_lamp_a", "dystopian_street_lamp_b",
    "dystopian_terminal_a", "dystopian_terminal_b",
}

if not MANIFEST.exists():
    raise SystemExit("external city asset manifest is missing")

data = json.loads(MANIFEST.read_text(encoding="utf-8"))
assets = data.get("assets", {})
missing = sorted(REQUIRED - set(assets))
if missing:
    raise SystemExit(f"missing required external city assets: {missing}")

for name, entry in assets.items():
    path = Path(entry["path"])
    if not path.exists():
        raise SystemExit(f"{name}: processed PNG is missing: {path}")
    with Image.open(path) as image:
        if image.width <= 0 or image.height <= 0:
            raise SystemExit(f"{name}: invalid image dimensions")
        if name.startswith("future_") and max(image.size) > 480:
            raise SystemExit(f"{name}: future asset was not optimized: {image.size}")
        if image.mode not in ("RGBA", "LA", "P"):
            image.convert("RGBA")

print(
    f"[CityAssetsValidation] PASS assets={len(assets)} "
    f"required={len(REQUIRED)}"
)
