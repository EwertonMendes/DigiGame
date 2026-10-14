"""Fork the exported package's main scene without changing project.godot.

Official Web templates disable command-line scene overrides. Preserve the normal
package, fork its project.binary setting, and share the same JavaScript/Wasm.
PCK V3/V4 and ECFG layouts follow Godot 4.7's file_access_pack.cpp and
project_settings.cpp. Fail closed for unsupported/encrypted formats.
"""
from pathlib import Path
import argparse
import hashlib
import struct

SCENE = "res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn"


def package_entries(data):
    magic, version, major, minor, patch, flags, base, directory = struct.unpack_from("<6I2Q", data)
    if magic != 0x43504447 or version not in (3, 4) or flags != 2:
        raise ValueError("Expected an unencrypted, non-sparse Godot PCK V3/V4")
    count = struct.unpack_from("<I", data, directory)[0]
    cursor = directory + 4
    entries = {}
    for _ in range(count):
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        name = data[cursor:cursor + length].rstrip(b"\0").decode("utf-8")
        cursor += length
        offset, size, digest, file_flags = struct.unpack_from("<QQ16sI", data, cursor)
        if file_flags != 0 or base + offset + size > len(data):
            raise ValueError(f"Unsupported or invalid package entry: {name}")
        entries[name.removeprefix("res://")] = (cursor, base + offset, size, digest)
        cursor += 36
    if any(name.startswith("assets/local/darkmoon_sandbox/") for name in entries):
        raise ValueError("Private assets leaked into the exported package")
    return base, entries


def replace_main_scene(binary):
    if binary[:4] != b"ECFG":
        raise ValueError("Expected Godot ECFG project.binary")
    count = struct.unpack_from("<I", binary, 4)[0]
    cursor = 8
    result = bytearray(binary[:8])
    replacements = 0
    for _ in range(count):
        start = cursor
        name_length = struct.unpack_from("<I", binary, cursor)[0]
        cursor += 4
        name = binary[cursor:cursor + name_length].decode("utf-8")
        cursor += name_length
        value_length = struct.unpack_from("<I", binary, cursor)[0]
        value = binary[cursor + 4:cursor + 4 + value_length]
        cursor += 4 + value_length
        if name == "application/run/main_scene":
            if struct.unpack_from("<I", value)[0] != 4:
                raise ValueError("Expected a String main scene setting")
            encoded = SCENE.encode("utf-8")
            replacement = struct.pack("<II", 4, len(encoded)) + encoded
            replacement += b"\0" * (-len(replacement) % 4)
            result += binary[start:cursor - value_length - 4]
            result += struct.pack("<I", len(replacement)) + replacement
            replacements += 1
        else:
            result += binary[start:cursor]
    if cursor != len(binary) or replacements != 1:
        raise ValueError("Expected exactly one main scene and a valid settings stream")
    return result


def fork_package(source, target):
    data = bytearray(source.read_bytes())
    base, entries = package_entries(data)
    directory_entry, offset, size, digest = entries["project.binary"]
    old_binary = data[offset:offset + size]
    if hashlib.md5(old_binary, usedforsecurity=False).digest() != digest:
        raise ValueError("Exported settings integrity check failed")
    binary = replace_main_scene(old_binary)
    data += b"\0" * (-len(data) % 16)
    new_offset = len(data)
    data += binary
    struct.pack_into("<QQ16s", data, directory_entry, new_offset - base, len(binary),
                     hashlib.md5(binary, usedforsecurity=False).digest())
    # Every other resource, offset and digest must be preserved exactly.
    _, updated = package_entries(data)
    if {k: v for k, v in entries.items() if k != "project.binary"} != {
        k: v for k, v in updated.items() if k != "project.binary"
    }:
        raise ValueError("Package fork changed unrelated resource entries")
    target.write_bytes(data)
    return len(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("web_dir", type=Path)
    args = parser.parse_args()
    pack_size = fork_package(args.web_dir / "index.pck", args.web_dir / "sandbox.pck")
    html = (args.web_dir / "index.html").read_text(encoding="utf-8")
    original = "engine.startGame({"
    if html.count(original) != 1:
        raise ValueError("Expected one Godot Web startGame call")
    html = html.replace(original, original + '\n\t\t\tmainPack: "sandbox.pck",'
                        + f'\n\t\t\tfileSizes: {{...GODOT_CONFIG.fileSizes, "sandbox.pck": {pack_size}}},', 1)
    (args.web_dir / "sandbox.html").write_text(html, encoding="utf-8")
    print("Created sandbox.html and sandbox.pck; original game export preserved")


if __name__ == "__main__":
    main()
