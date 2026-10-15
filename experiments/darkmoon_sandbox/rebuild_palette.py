"""Rebuild the module palette with Pillow and the committed native atlas only."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/scenery/darkmoon_city"


def rebuild() -> None:
    source = Image.open(FOLDER / "tiles_8x8.png").convert("RGBA")
    palette = Image.new("RGBA", (1024, 512))
    occupied = set()
    brushes = json.loads(Path(__file__).with_name("brushes.json").read_text())
    for name, brush in brushes.items():
        left, top, width, height = brush["rect"]
        rows = brush["private_cells"]
        assert len(rows) == height // 8, name
        for y, row in enumerate(rows):
            assert len(row) == width // 8, name
            for x, index in enumerate(row):
                destination = (left + x * 8, top + y * 8)
                assert destination not in occupied, f"Overlapping module: {name}"
                assert 0 <= destination[0] < 1024 and 0 <= destination[1] < 512
                occupied.add(destination)
                if index is None:
                    continue
                assert 0 <= index < 3825, name
                sx, sy = index % 32 * 8, index // 32 * 8
                palette.paste(source.crop((sx, sy, sx + 8, sy + 8)), destination)
    palette.save(FOLDER / "pieces.png")
    manifest_path = FOLDER / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["files"]["pieces.png"] = hashlib.sha256((FOLDER / "pieces.png").read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Native city palette rebuilt; module bounds and native cell IDs verified.")


if __name__ == "__main__":
    rebuild()
