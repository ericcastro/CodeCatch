#!/usr/bin/env python3
"""Reject embedded developer home paths before signing release artifacts."""

import argparse
from pathlib import Path
import re
import sys

HOME_PATH = re.compile(
    rb"(?<![A-Za-z0-9/])(?:file://)?(?:/System/Volumes/Data)?"
    rb"/(?:Users|home)/[^/\x00\r\n]+(?:/|(?=[\x00\r\n]|$))"
)


def check(path):
    if path.is_symlink():
        return True
    try:
        if path.is_dir():
            return all([check(child) for child in path.iterdir()])
        if HOME_PATH.search(path.read_bytes()):
            print(f"Embedded developer path in {path.name}", file=sys.stderr)
            return False
    except OSError:
        print(f"Cannot scan {path.name}", file=sys.stderr)
        return False
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    return 0 if all([check(path) for path in args.paths]) else 1


if __name__ == "__main__":
    sys.exit(main())
