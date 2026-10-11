#!/usr/bin/env python3
"""Print GitHub release notes:  python3 scripts/release-notes.py <previous-tag> [<ref>]

The notes list the changelog headings that <ref> (default HEAD) has and <previous-tag> doesn't,
newest entry first, then a link to the full changelog. A release with no new headings says
"Small fixes." Leave <previous-tag> empty for the first release.
"""
import html
import re
import subprocess
import sys

PAGE = "site/changelog/index.html"


def headings(ref):
    if not ref:
        return []
    page = subprocess.run(["git", "show", f"{ref}:{PAGE}"], capture_output=True, text=True, check=True).stdout
    # Only the "points" lists: the app pictures in an entry have <dt>s of their own.
    return [html.unescape(re.sub(r"<[^>]+>", "", dt)).strip()
            for points in re.findall(r'<dl class="points">(.*?)</dl>', page, re.S)
            for dt in re.findall(r"<dt>(.*?)</dt>", points, re.S)]


old = set(headings(sys.argv[1]))
new = [h for h in headings(sys.argv[2] if len(sys.argv) > 2 else "HEAD") if h not in old]
print("\n".join(f"- {h}" for h in new) if new else "Small fixes.")
print("\nFull changelog: https://codecatch.app/changelog/")
