#!/usr/bin/env python3
"""Ensure Runner build configs keep CODE_SIGN_ENTITLEMENTS after signing tools modify the project."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def patch_build_settings(block: str, entitlements_path: str) -> str:
    if "PRODUCT_BUNDLE_IDENTIFIER" not in block and "INFOPLIST_FILE = Runner/Info.plist;" not in block:
        return block

    line = f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = {entitlements_path};"
    if "CODE_SIGN_ENTITLEMENTS =" in block:
        return re.sub(
            r"(?m)^\s*CODE_SIGN_ENTITLEMENTS = [^;]+;$",
            line,
            block,
            count=1,
        )

    if "CODE_SIGN_STYLE =" in block:
        return block.replace(
            "CODE_SIGN_STYLE = Automatic;",
            f"CODE_SIGN_STYLE = Automatic;\n{line}",
            1,
        )

    return block.replace("\n\t\t\t};", "\n" + line + "\n\t\t\t};", 1)


def ensure_entitlements(project_path: Path, entitlements_path: str) -> bool:
    content = project_path.read_text(encoding="utf-8")
    pattern = re.compile(r"(\t\t[0-9A-F]+ /\* [^*]+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n)(.*?)(\n\t\t\t\};\n\t\t\tname = [^;]+;\n\t\t\};)", re.S)

    changed = False

    def repl(match: re.Match[str]) -> str:
        nonlocal changed
        head, body, tail = match.groups()
        updated_body = patch_build_settings(body, entitlements_path)
        if updated_body != body:
            changed = True
        return head + updated_body + tail

    updated_content = pattern.sub(repl, content)
    if changed:
        project_path.write_text(updated_content, encoding="utf-8")
    return changed


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: ensure_ios_push_entitlements.py <project.pbxproj> <Runner/Runner.entitlements>")
        return 1

    project_path = Path(sys.argv[1])
    entitlements_path = sys.argv[2]
    if not project_path.is_file():
        print(f"ERROR: project file not found: {project_path}")
        return 1

    changed = ensure_entitlements(project_path, entitlements_path)
    print(
        "CODE_SIGN_ENTITLEMENTS "
        + ("updated" if changed else "already present")
        + f" in {project_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
