#!/usr/bin/env python3
"""Materialize pinned external sources used by project-supplied sprite pipelines.

External source URLs are data, not runtime behavior. Each downloaded file is pinned
by its Git blob SHA so a moved or changed upstream asset can never silently alter
DigiGame's generated visuals.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "database/project-supplied-sources.json"


def local_res(value: str) -> Path:
    if not value.startswith("res://"):
        raise RuntimeError(f"Expected res:// path, got {value!r}")
    return ROOT / value.removeprefix("res://")


def git_blob_sha(payload: bytes) -> str:
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


def fetch(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "DigiGame-project-supplied-source-materializer"})
    with urlopen(request, timeout=90) as response:
        return response.read()


def materialize_source(path: Path, url: str, expected_blob_sha: str, label: str) -> None:
    if path.is_file():
        payload = path.read_bytes()
        actual = git_blob_sha(payload)
        if actual != expected_blob_sha:
            raise RuntimeError(f"{label}: committed source blob changed ({actual}, expected {expected_blob_sha})")
        print(f"{label}: pinned source already materialized -> {path.relative_to(ROOT)}")
        return

    payload = fetch(url)
    actual = git_blob_sha(payload)
    if actual != expected_blob_sha:
        raise RuntimeError(f"{label}: downloaded source blob is {actual}, expected {expected_blob_sha}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    print(f"{label}: materialized pinned source -> {path.relative_to(ROOT)}")


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    for spec in config.get("species", []):
        name = str(spec.get("name", "project-supplied species"))
        portrait = spec.get("portrait", {})
        if not isinstance(portrait, dict) or str(portrait.get("mode", "sheet_frame")) != "animated_webp":
            continue
        source_webp = str(portrait.get("source_webp", ""))
        source_url = str(portrait.get("source_url", ""))
        expected_blob_sha = str(portrait.get("source_git_blob_sha", ""))
        if not source_webp or not source_url or not expected_blob_sha:
            raise RuntimeError(f"{name}: animated_webp portrait requires source_webp, source_url and source_git_blob_sha")
        materialize_source(local_res(source_webp), source_url, expected_blob_sha, f"{name} portrait")


if __name__ == "__main__":
    main()
