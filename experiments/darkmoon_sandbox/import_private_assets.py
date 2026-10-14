"""Import only the supplied city atlases; never publish their pixels.

Requires Pillow for the optional native-pixel palette assembly. All output stays
in the repository's ignored, Godot-excluded local asset directory.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT / "assets/local/darkmoon_sandbox"
PREFIX = "Darkmoon_City_Assets/"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip", type=Path)
    args = parser.parse_args()
    from PIL import Image

    PRIVATE.mkdir(parents=True, exist_ok=True)
    (PRIVATE / ".gitignore").write_text("*\n!.gitignore\n!.gdignore\n")
    (PRIVATE / ".gdignore").touch()
    with zipfile.ZipFile(args.zip) as archive:
        info_bytes = archive.read(PREFIX + "atlas_info.json")
        info = json.loads(info_bytes)
        for entry in info["atlases"]:
            name = entry["file"]
            if name not in {f"darkmoon_city/tiles_{size}x{size}.png" for size in (8, 16, 32)}:
                continue
            data = archive.read(PREFIX + name)
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise ValueError(f"Atlas integrity check failed: {name}")
            target = PRIVATE / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (PRIVATE / "atlas_info.json").write_bytes(info_bytes)

    atlas = Image.open(PRIVATE / "darkmoon_city/tiles_32x32.png").convert("RGBA")
    fine_atlas = Image.open(PRIVATE / "darkmoon_city/tiles_8x8.png").convert("RGBA")
    palette = Image.new("RGBA", (1024, 512))
    brushes = json.loads((Path(__file__).parent / "brushes.json").read_text())
    for brush in brushes.values():
        x, y, width, height = brush["rect"]
        fine = "private_cells" in brush
        rows = brush["private_cells"] if fine else brush["private_chunks"]
        cell_size = 8 if fine else 32
        source = fine_atlas if fine else atlas
        assert len(rows) * cell_size == height and all(len(row) * cell_size == width for row in rows)
        for row_index, row in enumerate(rows):
            for column_index, tile in enumerate(row):
                if tile is None:
                    continue
                assert 0 <= tile < (3825 if fine else 2058)
                sx, sy = tile % 32 * cell_size, tile // 32 * cell_size
                palette.paste(source.crop((sx, sy, sx + cell_size, sy + cell_size)),
                              (x + column_index * cell_size, y + row_index * cell_size))
    palette.save(PRIVATE / "palette.png")
    print("Private city atlases verified. Native palette assembled without resampling.")


if __name__ == "__main__":
    main()
