#!/usr/bin/env python3
"""Delete all remote Git branches except the protected branch (master by default)."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=check,
        text=True,
        capture_output=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Delete every branch from a Git remote except one protected branch."
    )
    parser.add_argument("--remote", default="origin", help="Remote name (default: origin)")
    parser.add_argument(
        "--keep", default="master", help="Branch that must never be deleted (default: master)"
    )
    args = parser.parse_args()

    if not (Path.cwd() / ".git").exists():
        print("Error: run this script from the repository root.", file=sys.stderr)
        return 2

    print(f"Fetching {args.remote}...")
    run("git", "fetch", args.remote, "--prune")

    result = run(
        "git",
        "for-each-ref",
        "--format=%(refname:strip=3)",
        f"refs/remotes/{args.remote}",
    )

    branches = sorted(
        branch.strip()
        for branch in result.stdout.splitlines()
        if branch.strip()
        and branch.strip() not in {args.keep, "HEAD"}
    )

    if not branches:
        print(f"Nothing to delete. Only '{args.keep}' remains on {args.remote}.")
        return 0

    print(f"Keeping protected branch: {args.keep}")
    print("Branches to delete:")
    for branch in branches:
        print(f"  - {branch}")

    failed: list[str] = []
    for branch in branches:
        print(f"Deleting {args.remote}/{branch}...")
        deleted = run("git", "push", args.remote, "--delete", branch, check=False)
        if deleted.returncode != 0:
            failed.append(branch)
            message = deleted.stderr.strip() or deleted.stdout.strip()
            print(f"  FAILED: {message}", file=sys.stderr)

    if failed:
        print("\nCould not delete these branches:", file=sys.stderr)
        for branch in failed:
            print(f"  - {branch}", file=sys.stderr)
        return 1

    print(f"\nDone. All remote branches except '{args.keep}' were deleted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
