"""Reject private pixels in Git and enforce Godot's local import exclusion."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT / "assets/local/darkmoon_sandbox"
allowed = {"assets/local/darkmoon_sandbox/.gitignore", "assets/local/darkmoon_sandbox/.gdignore"}
tracked = subprocess.check_output(
    ["git", "ls-files", "--", "assets/local/darkmoon_sandbox"], cwd=ROOT, text=True
).splitlines()
assert set(tracked) <= allowed, "Private source graphics must never be tracked"
assert (PRIVATE / ".gdignore").is_file(), "Godot must exclude the private directory"
assert (PRIVATE / ".gitignore").read_text().splitlines() == ["*", "!.gitignore", "!.gdignore"]
print("Private assets excluded from Git and Godot's resource export")
