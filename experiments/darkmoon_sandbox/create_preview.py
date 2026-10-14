"""Create a second Web entry point sharing the existing game export."""
from pathlib import Path
import argparse

SCENE = "res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("web_dir", type=Path)
    args = parser.parse_args()
    html = (args.web_dir / "index.html").read_text(encoding="utf-8")
    original = "engine.startGame({"
    if html.count(original) != 1:
        raise ValueError("Expected one Godot Web startGame call")
    html = html.replace(original, original + f'\n\t\t\targs: ["{SCENE}"],', 1)
    (args.web_dir / "sandbox.html").write_text(html, encoding="utf-8")
    print("Created isolated sandbox.html entry point; original index.html preserved")


if __name__ == "__main__":
    main()
