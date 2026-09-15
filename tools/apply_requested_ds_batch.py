#!/usr/bin/env python3
"""Apply the audited requested DS batch to the production generator inputs."""
from __future__ import annotations

import json
from pathlib import Path

CONFIG_PATH = Path("database/ds-additional-sources.json")
BUILDER_PATH = Path("tools/build_additional_ds_fields.py")

REQUESTED = {
    "Veedramon": {
        "source_id": 188,
        "source_member": "sprite thread/188_V-dramon.png",
        "source_sha256": "c0fc38f10cffcc21b713ba9b7ff24929aa41300edcafa6c044cd755f2d9e88e1",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Adult/188_V-dramon.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
    "AeroVeedramon": {
        "source_id": 276,
        "source_member": "sprite thread/276_AeroV-Dramon.png",
        "source_sha256": "c2b930245dbb17a66969caec47bb90cadcb9edadab3c22cdfd6b796018903c63",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Perfect/276_AeroV-Dramon.png",
        "profile": "two_rows_of_six",
        "pattern": "rear_rows_first",
    },
    "Goldramon": {
        "source_id": 354,
        "source_member": "sprite thread/354_Goddramon.png",
        "source_sha256": "e17f8438ef1f03aac3979a776a4d18a0f27c10f74a18bd08fd69e92e1a5637d1",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Ultimate/354_Goddramon.png",
        "profile": "two_rows_lower_region_of_six",
        "pattern": "rear_rows_first",
    },
    "ExVeemon": {
        "source_id": 108,
        "source_member": "sprite thread/108_XV-mon.png",
        "source_sha256": "6759542002383cbf6a517fc05b8d95d0c83a1bc8ea4a13923ce7404e433bd310",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Adult/108_XV-mon.png",
        "profile": "four_rows_rightmost_triples",
        "pattern": "compact_interleaved",
    },
    "Magnamon": {
        "source_id": 289,
        "source_member": "sprite thread/289_Magnamon.png",
        "source_sha256": "857ff42ecb79461facd5fc8111e09accf4b0bf321c24da010c8c180ef1939181",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Perfect/289_Magnamon.png",
        "profile": "four_rows_rightmost_triples",
        "pattern": "compact_interleaved",
    },
    "Flamedramon": {
        "source_id": 288,
        "source_member": "sprite thread/288_Fladramon.png",
        "source_sha256": "a7e81eec536a0e3b1221305e359229fa7b9a32b9c73aa1d1f3c7179e31d0a355",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Perfect/288_Fladramon.png",
        "profile": "two_rows_of_six",
        "pattern": "rear_rows_first",
    },
    "Dinohumon": {
        "source_id": 120,
        "source_member": "sprite thread/120_Dinohumon.png",
        "source_sha256": "78a317d064a199ce629ee9093dacfe4c7713f3744e56dff21e03db76c5a652ae",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Adult/120_Dinohumon.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
    "Paildramon": {
        "source_id": 224,
        "source_member": "sprite thread/224_Paildramon.png",
        "source_sha256": "01dad02510695805a60b95f16344b2274e76c4c981c027c71843bc99f4d9a8cd",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Perfect/224_Paildramon.png",
        "profile": "four_rows_rightmost_triples",
        "pattern": "compact_interleaved",
    },
    "Imperialdramon (Dragon Mode)": {
        "source_id": 314,
        "source_member": "sprite thread/314_ImperialdramonDragon.png",
        "source_sha256": "0f9cd75e43534a9fae24260bc98e094a9c3133096ff1af86415d8698e6679d5e",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Ultimate/314_ImperialdramonDragon.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
    "Imperialdramon (Fighter Mode)": {
        "source_id": 315,
        "source_member": "sprite thread/315_ImperialdramonFighter.png",
        "source_sha256": "825f96a1574b1852ea2911e107716745a170dd5a9da117cbe4df6cadfe84fe70",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Ultimate/315_ImperialdramonFighter.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
    "Cyberdramon": {
        "source_id": 222,
        "source_member": "sprite thread/222_Cyberdramon.png",
        "source_sha256": "55ba1d21d657df02a83b737d1591f8f76c84947da3d75e43e4f4c74c9da0bbd7",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Perfect/222_Cyberdramon.png",
        "profile": "two_rows_of_six",
        "pattern": "rear_rows_first",
    },
    "Justimon": {
        "source_id": 361,
        "source_member": "sprite thread/361_Justimon.png",
        "source_sha256": "1b6ccc1105ccb25fedb949f676421c257f9696f5e7a3a2a5a4550fde2aeec10b",
        "source_url": "https://i874.photobucket.com/albums/ab308/WtWSprites/Ultimate/361_Justimon.png",
        "profile": "two_rows_of_six",
        "pattern": "canonical_rows",
    },
}


def update_config() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    config.setdefault("profiles", {})["two_rows_lower_region_of_six"] = {
        "kind": "two_rows_of_six",
        "min_cy_ratio": 0.65,
    }
    species = config.setdefault("species", {})
    for name, spec in REQUESTED.items():
        species[name] = spec
    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def update_builder() -> None:
    text = BUILDER_PATH.read_text(encoding="utf-8")
    if 'min_cy_ratio = float(profile.get("min_cy_ratio", 0.0))' in text:
        return

    old_range = '''    min_cx_ratio = float(profile.get("min_cx_ratio", 0.0))
    max_cx_ratio = float(profile.get("max_cx_ratio", 1.0))
    if not 0.0 <= min_cx_ratio < max_cx_ratio <= 1.0:
        raise RuntimeError(
            f"Invalid structural profile x-range: min_cx_ratio={min_cx_ratio} max_cx_ratio={max_cx_ratio}"
        )
    min_cx = image.width * min_cx_ratio
    max_cx = image.width * max_cx_ratio
'''
    new_range = '''    min_cx_ratio = float(profile.get("min_cx_ratio", 0.0))
    max_cx_ratio = float(profile.get("max_cx_ratio", 1.0))
    min_cy_ratio = float(profile.get("min_cy_ratio", 0.0))
    max_cy_ratio = float(profile.get("max_cy_ratio", 1.0))
    if not 0.0 <= min_cx_ratio < max_cx_ratio <= 1.0:
        raise RuntimeError(
            f"Invalid structural profile x-range: min_cx_ratio={min_cx_ratio} max_cx_ratio={max_cx_ratio}"
        )
    if not 0.0 <= min_cy_ratio < max_cy_ratio <= 1.0:
        raise RuntimeError(
            f"Invalid structural profile y-range: min_cy_ratio={min_cy_ratio} max_cy_ratio={max_cy_ratio}"
        )
    min_cx = image.width * min_cx_ratio
    max_cx = image.width * max_cx_ratio
    min_cy = image.height * min_cy_ratio
    max_cy = image.height * max_cy_ratio
'''
    if text.count(old_range) != 1:
        raise RuntimeError("Could not uniquely locate movement_groups structural range block")
    text = text.replace(old_range, new_range, 1)

    old_candidate = '''        and min_cx <= item["cx"] <= max_cx
    ]
'''
    new_candidate = '''        and min_cx <= item["cx"] <= max_cx
        and min_cy <= item["cy"] <= max_cy
    ]
'''
    if text.count(old_candidate) != 1:
        raise RuntimeError("Could not uniquely locate movement_groups candidate range check")
    text = text.replace(old_candidate, new_candidate, 1)
    BUILDER_PATH.write_text(text, encoding="utf-8")


def main() -> None:
    update_config()
    update_builder()
    print(f"configured {len(REQUESTED)} requested DS species")


if __name__ == "__main__":
    main()
