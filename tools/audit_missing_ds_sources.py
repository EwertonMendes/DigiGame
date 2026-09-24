#!/usr/bin/env python3
"""Audit database Digimon that still lack DS field sprites.

The audit downloads the same WithTheWill archive used by the existing deterministic
sprite builders, resolves database names against the thread's original/dub names,
extracts candidate 4x3 overworld movement groups, and renders review sheets. It
never writes runtime assets: semantic facing review happens before materialization.
"""
from __future__ import annotations

import html
import io
import json
import re
import tempfile
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

from build_early_rank_ds_fields import WTW_THREAD, fetch, load_wtw_archive
from build_additional_ds_fields import movement_groups

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database/base-digimon-list.json"
CONFIG = ROOT / "database/ds-additional-sources.json"
RESOURCE_ROOT = ROOT / "assets/resources"
OUT = Path(tempfile.gettempdir()) / "ds-missing-source-audit"
TARGET_RANKS = {"Champion", "Ultimate", "Mega"}

# Canonical database names whose source-topic naming is not an exact original or
# dub alias in the numbered list. These are source identity aliases only; they
# do not encode any runtime facing behavior.
SOURCE_ID_OVERRIDES: dict[str, int] = {
    "Creepymon": 305,
    "VenomMyotismon": 312,
    "Cherubimon (Good)": 321,
    "Cherubimon (Evil)": 322,
    "Preciomon": 331,
    "SL Angemon": 345,
    "ZeedMillenniummon": 355,
    "MoonMillenniummon": 371,
    "Lotosmon": 389,
    "Beelzemon (Blast Mode)": 392,
    "Lucemon Chaos Mode": 265,
    "Lanksmon": 281,
    "Shaujinmon": 282,
    "RockChessmon": 285,
    "Argomon Ultimate": 296,
    "Argomon Mega": 394,
}

UNNUMBERED_SOURCE_ALIASES: dict[str, str] = {
    "Agnimon": "Agnimon",
    "Grademon": "Grademon",
}

PROFILE_PREFERENCE = [
    "two_rows_of_six",
    "single_row_four_triples",
    "four_rows_rightmost_triples",
    "four_rows_leftmost_triples",
    "two_rows_right_region_of_six",
    "two_rows_lower_region_of_six",
]

FRAME_BOX = 52
NAME_W = 240
HEADER_H = 34
ROW_H = 74
ROWS_PER_PAGE = 10


def compact(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", html.unescape(value).lower())


def archive_member_for_id(archive, source_id: int) -> str:
    prefix = f"sprite thread/{source_id:03d}_"
    matches = [
        name for name in archive.namelist()
        if name.startswith(prefix) and name.lower().endswith((".png", ".gif"))
    ]
    if len(matches) != 1:
        raise RuntimeError(f"{source_id:03d}: expected one source member, found {matches}")
    return matches[0]


def topic_alias_index() -> dict[str, int]:
    raw = fetch(WTW_THREAD).decode("utf-8", "ignore")
    # XenForo keeps the numeric roster and linked name in the post body. Capture
    # original names and the immediate parenthetical dub aliases when present.
    pattern = re.compile(
        r"(?P<id>\d{3})\s*-\s*<a\b[^>]*>(?P<name>.*?)</a>(?P<tail>[^<\r\n]{0,120})",
        re.IGNORECASE | re.DOTALL,
    )
    result: dict[str, int] = {}
    for match in pattern.finditer(raw):
        source_id = int(match.group("id"))
        name = re.sub(r"<[^>]+>", "", match.group("name"))
        aliases = [name]
        tail = html.unescape(match.group("tail"))
        paren = re.search(r"\(([^)]+)\)", tail)
        if paren:
            aliases.extend(part.strip() for part in paren.group(1).split(","))
        for alias in aliases:
            key = compact(alias)
            if key:
                result.setdefault(key, source_id)
    return result


def missing_database_rows() -> list[dict[str, Any]]:
    database = json.loads(DATABASE.read_text(encoding="utf-8"))
    existing = {
        compact(path.stem)
        for path in RESOURCE_ROOT.glob("*.tres")
    }
    rows = [
        entry for entry in database
        if str(entry.get("rank", "")) in TARGET_RANKS
        and compact(str(entry.get("name", ""))) not in existing
    ]
    return rows


def normalized_member_stem(member: str) -> str:
    stem = Path(member).stem
    stem = re.sub(r"^\d{3}_", "", stem)
    return compact(stem)


def resolve_unnumbered_member(archive, species: str) -> str | None:
    target = compact(UNNUMBERED_SOURCE_ALIASES.get(species, species))
    candidates: list[tuple[float, str]] = []
    for member in archive.namelist():
        if not member.lower().endswith((".png", ".gif")):
            continue
        if not member.startswith("sprite thread/"):
            continue
        stem = normalized_member_stem(member)
        if not stem:
            continue
        score = SequenceMatcher(None, target, stem).ratio()
        if target == stem:
            score = 1.0
        candidates.append((score, member))
    candidates.sort(key=lambda item: (-item[0], item[1]))
    if not candidates or candidates[0][0] < 0.86:
        return None
    if len(candidates) > 1 and candidates[0][0] == candidates[1][0]:
        return None
    return candidates[0][1]


def extract_candidates(image: Image.Image, config: dict[str, Any]) -> dict[str, list[list[dict[str, int]]]]:
    result: dict[str, list[list[dict[str, int]]]] = {}
    for profile_name in PROFILE_PREFERENCE:
        profile = config["profiles"].get(profile_name)
        if not isinstance(profile, dict):
            continue
        try:
            groups = movement_groups(image, profile)
        except Exception:
            continue
        signature = json.dumps(groups, sort_keys=True)
        if any(json.dumps(existing, sort_keys=True) == signature for existing in result.values()):
            continue
        result[profile_name] = groups
    return result


def source_crop(image: Image.Image, box: dict[str, int]) -> Image.Image:
    x, y, w, h = (int(box[key]) for key in ("x", "y", "w", "h"))
    crop = image.crop((max(0, x - 2), max(0, y - 2), min(image.width, x + w + 2), min(image.height, y + h + 2))).convert("RGBA")
    bbox = crop.getbbox()
    return crop.crop(bbox) if bbox else crop


def render_frame(frame: Image.Image) -> Image.Image:
    if frame.width <= 0 or frame.height <= 0:
        return Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    scale = max(1, min(3, (FRAME_BOX - 4) // max(frame.width, frame.height)))
    scaled = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME_BOX, FRAME_BOX), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((FRAME_BOX - scaled.width) // 2, FRAME_BOX - scaled.height - 2))
    return canvas


def checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (230, 230, 230, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 8):
        for x in range(0, size[0], 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(205, 205, 205, 255))
    return image


def render_pages(rows: list[dict[str, Any]]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()
    page_w = NAME_W + FRAME_BOX * 12 + 12
    manifest_pages = []
    for page_start in range(0, len(rows), ROWS_PER_PAGE):
        page_rows = rows[page_start:page_start + ROWS_PER_PAGE]
        page = checker((page_w, HEADER_H + ROW_H * len(page_rows)))
        draw = ImageDraw.Draw(page)
        draw.rectangle((0, 0, page_w, HEADER_H), fill=(250, 250, 250, 255))
        draw.text((8, 7), "RAW SOURCE GROUPS — G0 | G1 | G2 | G3 — assign DL/DR/UL/UR only after visual review", fill=(0, 0, 0, 255), font=font)
        for row_index, row in enumerate(page_rows):
            y = HEADER_H + row_index * ROW_H
            draw.rectangle((0, y, page_w, y + ROW_H - 1), outline=(90, 90, 90, 255), width=1)
            draw.rectangle((0, y, NAME_W, y + ROW_H - 1), fill=(248, 248, 248, 255))
            draw.text((6, y + 6), f"{row['name']} · {row['rank']}", fill=(0, 0, 0, 255), font=font)
            draw.text((6, y + 22), f"{row['source']} · {row['profile']}", fill=(50, 50, 50, 255), font=font)
            image = Image.open(io.BytesIO(row["source_bytes"])).convert("RGBA")
            groups = row["groups"]
            for group_index, group in enumerate(groups):
                group_x = NAME_W + group_index * FRAME_BOX * 3
                draw.text((group_x + 2, y + 2), f"G{group_index}", fill=(0, 0, 0, 255), font=font)
                if group_index:
                    draw.line((group_x, y, group_x, y + ROW_H - 1), fill=(70, 70, 70, 255), width=2)
                for frame_index, box in enumerate(group):
                    frame = source_crop(image, box)
                    page.alpha_composite(render_frame(frame), (group_x + frame_index * FRAME_BOX, y + 18))
        filename = f"page-{page_start // ROWS_PER_PAGE + 1:02d}.png"
        page.save(OUT / filename)
        manifest_pages.append({"file": filename, "names": [row["name"] for row in page_rows]})
    (OUT / "pages.json").write_text(json.dumps(manifest_pages, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    alias_index = topic_alias_index()
    archive = load_wtw_archive()
    rows = missing_database_rows()
    audited: list[dict[str, Any]] = []
    unresolved: list[str] = []
    unresolved_candidates: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []

    for entry in rows:
        name = str(entry["name"])
        source_id = SOURCE_ID_OVERRIDES.get(name)
        if source_id is None:
            source_id = alias_index.get(compact(name))
        member: str | None = None
        if source_id is not None:
            try:
                member = archive_member_for_id(archive, source_id)
            except RuntimeError:
                member = None
        if member is None:
            member = resolve_unnumbered_member(archive, name)
        if member is None:
            unresolved.append(name)
            unresolved_candidates.append({"name": name, "candidates": suggest_archive_members(archive, name)})
            continue

        payload = archive.read(member)
        image = Image.open(io.BytesIO(payload)).convert("RGBA")
        candidates = extract_candidates(image, config)
        if not candidates:
            unresolved_dir = OUT / "unresolved-sources"
            unresolved_dir.mkdir(parents=True, exist_ok=True)
            safe_name = re.sub(r"[^a-zA-Z0-9._-]+", "_", name).strip("_") or "species"
            image.save(unresolved_dir / f"{safe_name}.png", "PNG")
            unresolved.append(f"{name} [source={member}, no 4x3 movement profile]")
            continue
        profile_name = next(name for name in PROFILE_PREFERENCE if name in candidates)
        if len(candidates) > 1:
            ambiguous.append({"name": name, "source": member, "profiles": list(candidates)})
        audited.append({
            "name": name,
            "rank": str(entry["rank"]),
            "source": member,
            "source_id": source_id,
            "source_sha256": hashlib.sha256(payload).hexdigest(),
            "profile": profile_name,
            "groups": candidates[profile_name],
            "source_bytes": payload,
        })

    OUT.mkdir(parents=True, exist_ok=True)
    serializable = [
        {key: value for key, value in row.items() if key != "source_bytes"}
        for row in audited
    ]
    (OUT / "manifest.json").write_text(json.dumps(serializable, indent=2) + "\n", encoding="utf-8")
    (OUT / "unresolved.json").write_text(json.dumps(unresolved, indent=2) + "\n", encoding="utf-8")
    (OUT / "unresolved-candidates.json").write_text(json.dumps(unresolved_candidates, indent=2) + "\n", encoding="utf-8")
    (OUT / "ambiguous-profiles.json").write_text(json.dumps(ambiguous, indent=2) + "\n", encoding="utf-8")
    render_pages(audited)
    print(f"missing database species: {len(rows)}")
    print(f"source-resolved and structurally auditable: {len(audited)}")
    print(f"unresolved: {len(unresolved)}")
    if unresolved:
        print("unresolved species:")
        for name in unresolved:
            print(f"  - {name}")


def suggest_archive_members(archive, species: str, limit: int = 6) -> list[dict[str, Any]]:
    target = compact(UNNUMBERED_SOURCE_ALIASES.get(species, species))
    scored: list[tuple[float, str]] = []
    for member in archive.namelist():
        if not member.startswith("sprite thread/") or not member.lower().endswith((".png", ".gif")):
            continue
        stem = normalized_member_stem(member)
        if not stem:
            continue
        scored.append((SequenceMatcher(None, target, stem).ratio(), member))
    scored.sort(key=lambda item: (-item[0], item[1]))
    return [{"score": round(score, 4), "member": member} for score, member in scored[:limit]]


if __name__ == "__main__":
    main()

