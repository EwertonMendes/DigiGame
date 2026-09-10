#!/usr/bin/env python3
"""Rebuild DigiGame's local combat VFX atlases from vendored CC0 source packs.

This tool is intentionally NOT part of normal CI: committed runtime atlases are the
source of truth for builds. It exists so a contributor can reproducibly curate or
extend the library without downloading anything. Requires Pillow.
"""
from __future__ import annotations

import json
import re
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - developer helper
    raise SystemExit("Pillow is required: python -m pip install Pillow") from exc

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vendor" / "vfx-source"
OUT = ROOT / "assets" / "vfx" / "library" / "atlas"
DB = ROOT / "database" / "vfx-library.json"
ATLAS_MAX_WIDTH = 2048
PADDING = 2


@dataclass
class Frame:
    image: Image.Image
    pivot: tuple[float, float] | None = None
    duration_ms: float | None = None


@dataclass
class Effect:
    effect_id: str
    pack: str
    frames: list[Frame]
    fps: float


def slug(value: str) -> str:
    value = value.lower().replace("missle", "missile")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value


def extract_zip(path: Path, dest: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        archive.extractall(dest)


def pixel_art_spells(root: Path) -> list[Effect]:
    png_dir = root / "Pixelart Spells" / "PNG Files"
    effects: list[Effect] = []
    for path in sorted(png_dir.glob("*.png")):
        strip = Image.open(path).convert("RGBA")
        frame_size = strip.height
        if strip.width % frame_size != 0:
            raise RuntimeError(f"non-square strip cells in {path}: {strip.size}")
        frames = [
            Frame(strip.crop((x, 0, x + frame_size, frame_size)))
            for x in range(0, strip.width, frame_size)
        ]
        effects.append(Effect(f"pixel-spells/{slug(path.stem)}", "pixel-art-spells", frames, 14.0))
    return effects


def foozle(root: Path) -> list[Effect]:
    pack_root = root / "Foozle_2DE0001_Pixel_Magic_Effects"
    effects: list[Effect] = []
    for folder in sorted(p for p in pack_root.iterdir() if p.is_dir() and p.name != "Icons"):
        images = [Image.open(p).convert("RGBA") for p in sorted(folder.glob("*.png"))]
        if not images:
            continue
        effects.append(Effect(f"foozle/{slug(folder.name)}", "foozle-pixel-magic", [Frame(i) for i in images], 18.0))
    return effects


def pvfx(root: Path) -> list[Effect]:
    effects: list[Effect] = []
    for folder in sorted((root / "effects").iterdir()):
        manifest_path = folder / "grid" / "manifest.json"
        sheet_path = folder / "grid" / "sprite-sheet.png"
        if not manifest_path.is_file() or not sheet_path.is_file():
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        sheet = Image.open(sheet_path).convert("RGBA")
        frames: list[Frame] = []
        durations: list[float] = []
        for entry in manifest["frames"]:
            placement = entry["sheet"]
            x, y = int(placement["x"]), int(placement["y"])
            w, h = int(placement["width"]), int(placement["height"])
            duration = entry.get("duration", {})
            numerator = float(duration.get("numerator_ms", 1000.0))
            denominator = max(1.0, float(duration.get("denominator", 20.0)))
            duration_ms = numerator / denominator
            durations.append(duration_ms)
            pivot_raw = entry.get("pivot", [w / 2.0, h / 2.0])
            frames.append(
                Frame(
                    sheet.crop((x, y, x + w, y + h)),
                    (float(pivot_raw[0]), float(pivot_raw[1])),
                    duration_ms,
                )
            )
        average_ms = sum(durations) / len(durations) if durations else 50.0
        fps = 1000.0 / average_ms if average_ms > 0 else 20.0
        effects.append(Effect(f"pvfx/{folder.name}", "pvfx-foundry", frames, fps))
    return effects


def nature(root: Path) -> list[Effect]:
    names = {
        "0": "vine-orb-trail",
        "1": "leaf-gate",
        "2": "vine-crown",
        "3": "heart-vines",
    }
    effects: list[Effect] = []
    for prefix, name in names.items():
        paths = sorted(root.glob(f"{prefix}-*.png"), key=lambda p: int(p.stem.split("-")[1]))
        images = [Image.open(p).convert("RGBA") for p in paths]
        # Nature Magic ships trimmed frames whose canvas grows during the cast.
        # Normalize each sequence to a shared bottom-centered canvas so the effect
        # stays anchored instead of visibly jumping between frames in Godot.
        max_width = max(image.width for image in images)
        max_height = max(image.height for image in images)
        normalized: list[Image.Image] = []
        for image in images:
            canvas = Image.new("RGBA", (max_width, max_height), (0, 0, 0, 0))
            x = (max_width - image.width) // 2
            y = max_height - image.height
            canvas.alpha_composite(image, (x, y))
            normalized.append(canvas)
        effects.append(Effect(f"nature/{name}", "nature-magic", [Frame(i) for i in normalized], 12.0))
    return effects


def pack_atlas(effects: list[Effect], atlas_path: Path) -> dict[str, dict]:
    # Shelf pack. Frames stay in deterministic effect/frame order and never rotate.
    placements: dict[str, dict] = {}
    x = PADDING
    y = PADDING
    row_height = 0
    max_x = 0
    frame_locations: dict[tuple[str, int], tuple[int, int, int, int]] = {}

    for effect in effects:
        for index, frame in enumerate(effect.frames):
            w, h = frame.image.size
            if x + w + PADDING > ATLAS_MAX_WIDTH:
                x = PADDING
                y += row_height + PADDING
                row_height = 0
            frame_locations[(effect.effect_id, index)] = (x, y, w, h)
            x += w + PADDING
            row_height = max(row_height, h)
            max_x = max(max_x, x)
    atlas_height = y + row_height + PADDING
    atlas_width = min(ATLAS_MAX_WIDTH, max(2, max_x))
    atlas = Image.new("RGBA", (atlas_width, atlas_height), (0, 0, 0, 0))

    for effect in effects:
        output_frames = []
        for index, frame in enumerate(effect.frames):
            px, py, w, h = frame_locations[(effect.effect_id, index)]
            atlas.alpha_composite(frame.image, (px, py))
            output = {"region": [px, py, w, h]}
            if frame.pivot is not None:
                output["pivot"] = [round(frame.pivot[0], 3), round(frame.pivot[1], 3)]
            if frame.duration_ms is not None:
                output["duration_ms"] = round(frame.duration_ms, 3)
            output_frames.append(output)
        placements[effect.effect_id] = {
            "pack": effect.pack,
            "atlas": "res://" + str(atlas_path.relative_to(ROOT)).replace("\\", "/"),
            "fps": effect.fps,
            "frames": output_frames,
        }

    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(atlas_path, format="PNG", optimize=False)
    return placements


def main() -> None:
    expected = {
        "pixel-art-spells": SOURCE / "pixel-art-spells.zip",
        "foozle-pixel-magic": SOURCE / "foozle-pixel-magic.zip",
        "pvfx-foundry": SOURCE / "pvfx-foundry-0.7.0.zip",
        "nature-magic": SOURCE / "nature-magic.zip",
    }
    for name, path in expected.items():
        if not path.is_file():
            raise RuntimeError(f"missing vendored source pack {name}: {path.relative_to(ROOT)}")

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()

    all_definitions: dict[str, dict] = {}
    with tempfile.TemporaryDirectory(prefix="digigame-vfx-") as temp_text:
        temp = Path(temp_text)
        extracted = {}
        for name, archive in expected.items():
            destination = temp / name
            destination.mkdir()
            extract_zip(archive, destination)
            extracted[name] = destination

        packs = {
            "pixel-art-spells": pixel_art_spells(extracted["pixel-art-spells"]),
            "foozle-pixel-magic": foozle(extracted["foozle-pixel-magic"]),
            "pvfx-foundry": pvfx(extracted["pvfx-foundry"]),
            "nature-magic": nature(extracted["nature-magic"]),
        }
        for pack_name, effects in packs.items():
            atlas_path = OUT / f"{pack_name}.png"
            definitions = pack_atlas(effects, atlas_path)
            overlap = set(all_definitions).intersection(definitions)
            if overlap:
                raise RuntimeError(f"duplicate VFX ids: {sorted(overlap)}")
            all_definitions.update(definitions)
            print(f"built {atlas_path.relative_to(ROOT)}: {len(effects)} effects")

    payload = {
        "schema": "digigame.vfx-library/1",
        "effects": dict(sorted(all_definitions.items())),
    }
    DB.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {DB.relative_to(ROOT)} with {len(all_definitions)} effects")


if __name__ == "__main__":
    main()
