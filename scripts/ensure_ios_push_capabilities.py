#!/usr/bin/env python3
"""Ensure generated iOS project enables Push + Background Modes capabilities."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def _find_brace_block(text: str, marker: str) -> tuple[int, int, int] | None:
    marker_index = text.find(marker)
    if marker_index == -1:
        return None

    open_brace = text.find("{", marker_index)
    if open_brace == -1:
        return None

    depth = 0
    for index in range(open_brace, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return marker_index, open_brace, index
    return None


def _build_system_capabilities(indent: str) -> str:
    child = indent + "\t"
    grandchild = child + "\t"
    return (
        f"{indent}SystemCapabilities = {{\n"
        f"{child}com.apple.BackgroundModes = {{\n"
        f"{grandchild}enabled = 1;\n"
        f"{child}}};\n"
        f"{child}com.apple.Push = {{\n"
        f"{grandchild}enabled = 1;\n"
        f"{child}}};\n"
        f"{indent}}};\n"
    )


def _ensure_system_capabilities(block: str, indent: str) -> str:
    marker = "SystemCapabilities = {"
    existing = _find_brace_block(block, marker)
    if existing is None:
        parent_indent = indent[:-1] if indent.endswith("\t") else indent
        stripped = block.rstrip("\n")
        closing_line = f"{parent_indent}}};"
        if stripped.endswith(closing_line):
            return stripped[: -len(closing_line)] + _build_system_capabilities(indent) + closing_line
        return stripped + "\n" + _build_system_capabilities(indent) + closing_line

    marker_index, open_brace, close_brace = existing
    body = block[open_brace + 1 : close_brace]
    changed = False
    child = indent + "\t"
    grandchild = child + "\t"

    def ensure_capability(capability: str, body_text: str) -> str:
        nonlocal changed
        pattern = re.compile(
            rf"(?ms)^({re.escape(child)}{re.escape(capability)} = \{{\n)(.*?)(^{re.escape(child)}\}};\n?)"
        )
        match = pattern.search(body_text)
        if match:
            head, current, tail = match.groups()
            updated_current = current
            if "enabled = 1;" not in current:
                if re.search(r"(?m)^\s*enabled = \d;\s*$", current):
                    updated_current = re.sub(
                        r"(?m)^\s*enabled = \d;\s*$",
                        f"{grandchild}enabled = 1;",
                        current,
                    )
                else:
                    updated_current += f"{grandchild}enabled = 1;\n"
            if updated_current != current:
                changed = True
            return body_text[: match.start()] + head + updated_current + tail + body_text[match.end() :]

        changed = True
        insertion = (
            f"{child}{capability} = {{\n"
            f"{grandchild}enabled = 1;\n"
            f"{child}}};\n"
        )
        return body_text + insertion

    updated_body = ensure_capability("com.apple.BackgroundModes", body)
    updated_body = ensure_capability("com.apple.Push", updated_body)
    if updated_body == body:
        return block

    return block[: open_brace + 1] + updated_body + block[close_brace:]


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

    match = re.match(r"^([ \t]*)[0-9A-F]+ = \{\n", block)
    if not match:
        return block

    block_indent = match.group(1)
    inner_indent = block_indent + "\t"
    return _ensure_system_capabilities(block, inner_indent)


def ensure_push_capabilities(project_path: Path) -> bool:
    content = project_path.read_text(encoding="utf-8")
    block_info = _find_brace_block(content, "TargetAttributes = {")
    if block_info is None:
        return False

    _, open_brace, close_brace = block_info
    body = content[open_brace + 1 : close_brace]
    line_pattern = re.compile(r"^([ \t]*)[0-9A-F]+ = \{\n", re.M)
    matches = list(line_pattern.finditer(body))
    if not matches:
        return False

    updated_parts: list[str] = []
    cursor = 0
    changed = False

    for match in matches:
        start = match.start()
        if start < cursor:
            continue
        block_text = body[start:]
        block_info = _find_brace_block(block_text, match.group(0).strip())
        if block_info is None:
            continue
        _, sub_open, sub_close = block_info
        block_end = sub_close + 2  # include trailing ';'
        original = block_text[:block_end]
        updated = _patch_target_attribute_block(original)
        if updated != original:
            changed = True
        updated_parts.append(body[cursor:start])
        updated_parts.append(updated)
        cursor = start + block_end

    updated_parts.append(body[cursor:])
    if not changed:
        return False

    updated_body = "".join(updated_parts)
    project_path.write_text(content[: open_brace + 1] + updated_body + content[close_brace:], encoding="utf-8")
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
