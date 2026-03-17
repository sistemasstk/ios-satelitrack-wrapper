#!/usr/bin/env python3
"""Ensure generated iOS project enables Push + Background Modes capabilities."""

from __future__ import annotations

import re
import sys
from pathlib import Path


SYSTEM_CAPABILITIES_BLOCK = """\t\t\t\t\tSystemCapabilities = {
\t\t\t\t\t\tcom.apple.BackgroundModes = {
\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t};
\t\t\t\t\t\tcom.apple.Push = {
\t\t\t\t\t\t\tenabled = 1;
\t\t\t\t\t\t};
\t\t\t\t\t};
"""


def _ensure_capability(block: str, capability: str) -> str:
    pattern = re.compile(
        rf"(?ms)^(\t{{5}}{re.escape(capability)} = \{{\n)(.*?)(^\t{{5}}\}};)$"
    )
    match = pattern.search(block)
    if match:
        head, body, tail = match.groups()
        if "enabled = 1;" in body:
            return block
        body = re.sub(r"(?m)^\t{6}enabled = \d;$", "\t\t\t\t\t\tenabled = 1;", body)
        if "enabled =" not in body:
            body += "\t\t\t\t\t\tenabled = 1;\n"
        return block[: match.start()] + head + body + tail + block[match.end() :]

    insertion = (
        f"\t\t\t\t\t{capability} = {{\n"
        "\t\t\t\t\t\tenabled = 1;\n"
        "\t\t\t\t\t};\n"
    )
    return block.replace("\t\t\t\t\t};\n", insertion + "\t\t\t\t\t};\n", 1)


def _patch_target_attribute_block(block: str) -> str:
    looks_like_app_target = any(
        marker in block
        for marker in (
            "ProvisioningStyle = Automatic;",
            "ProvisioningStyle = Manual;",
            "DevelopmentTeam = ",
            "CreatedOnToolsVersion = ",
        )
    )
    if not looks_like_app_target:
        return block

    if "SystemCapabilities = {" not in block:
        return block.replace("\t\t\t\t};\n", SYSTEM_CAPABILITIES_BLOCK + "\t\t\t\t};\n", 1)

    updated = _ensure_capability(block, "com.apple.BackgroundModes")
    updated = _ensure_capability(updated, "com.apple.Push")
    return updated


def ensure_push_capabilities(project_path: Path) -> bool:
    content = project_path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(?ms)(\t\t\tTargetAttributes = \{\n)(.*?)(\t\t\t\};\n\t\t\tbuildConfigurationList = )"
    )
    match = pattern.search(content)
    if not match:
        return False

    head, body, tail = match.groups()
    block_pattern = re.compile(
        r"(?ms)(^\t\t\t\t[0-9A-F]+ = \{\n)(.*?)(^\t\t\t\t\};$)"
    )

    changed = False

    def repl(block_match: re.Match[str]) -> str:
        nonlocal changed
        block_head, block_body, block_tail = block_match.groups()
        original = block_head + block_body + block_tail
        updated = _patch_target_attribute_block(original)
        if updated != original:
            changed = True
        return updated

    updated_body = block_pattern.sub(repl, body)
    if not changed:
        return False

    project_path.write_text(content[: match.start()] + head + updated_body + tail + content[match.end() :], encoding="utf-8")
    return True


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: ensure_ios_push_capabilities.py <project.pbxproj>")
        return 1

    project_path = Path(sys.argv[1])
    if not project_path.is_file():
        print(f"ERROR: project file not found: {project_path}")
        return 1

    changed = ensure_push_capabilities(project_path)
    print(
        "Push/Background SystemCapabilities "
        + ("updated" if changed else "already present")
        + f" in {project_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
