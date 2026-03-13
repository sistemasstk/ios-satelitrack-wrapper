#!/usr/bin/env python3
"""Ensure GoogleService-Info.plist is bundled in the generated iOS project."""

from __future__ import annotations

import plistlib
import re
import secrets
import sys
from pathlib import Path


def _load_plist(path: Path) -> dict:
    with path.open("rb") as fh:
        data = plistlib.load(fh)
    if not isinstance(data, dict):
        raise SystemExit(f"ERROR: {path} does not contain a plist dictionary.")
    return data


def _insert_once(content: str, marker: str, addition: str) -> str:
    if addition in content:
        return content
    if marker not in content:
        raise SystemExit(f"ERROR: marker not found in project file: {marker}")
    return content.replace(marker, marker + addition, 1)


def _ensure_runner_group(content: str, file_ref_id: str) -> str:
    pattern = re.compile(
        r"(/\* Runner \*/ = \{\n\s*isa = PBXGroup;\n\s*children = \(\n)"
        r"(.*?)"
        r"(\n\s*\);\n\s*path = Runner;\n\s*sourceTree = \"<group>\";\n\s*\};)",
        re.S,
    )
    match = pattern.search(content)
    if not match:
        raise SystemExit("ERROR: Runner group not found in project.pbxproj")

    entry = f"\t\t\t\t{file_ref_id} /* GoogleService-Info.plist */,"
    if entry in match.group(2):
        return content

    updated = match.group(1) + match.group(2) + entry + match.group(3)
    return content[: match.start()] + updated + content[match.end() :]


def _ensure_resources_phase(content: str, build_file_id: str) -> str:
    pattern = re.compile(
        r"(/\* Resources \*/ = \{\n\s*isa = PBXResourcesBuildPhase;\n\s*buildActionMask = \d+;\n\s*files = \(\n)"
        r"(.*?)"
        r"(\n\s*\);\n\s*runOnlyForDeploymentPostprocessing = \d+;\n\s*\};)",
        re.S,
    )
    match = pattern.search(content)
    if not match:
        raise SystemExit("ERROR: Resources build phase not found in project.pbxproj")

    entry = f"\t\t\t\t{build_file_id} /* GoogleService-Info.plist in Resources */,"
    if entry in match.group(2):
        return content

    updated = match.group(1) + match.group(2) + entry + match.group(3)
    return content[: match.start()] + updated + content[match.end() :]


def ensure_google_service_in_project(project_path: Path) -> bool:
    content = project_path.read_text(encoding="utf-8")
    if "GoogleService-Info.plist in Resources" in content:
        return False

    build_file_id = secrets.token_hex(12).upper()
    file_ref_id = secrets.token_hex(12).upper()

    content = _insert_once(
        content,
        "/* Begin PBXBuildFile section */\n",
        (
            f"\t\t{build_file_id} /* GoogleService-Info.plist in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {file_ref_id} /* GoogleService-Info.plist */; }};\n"
        ),
    )
    content = _insert_once(
        content,
        "/* Begin PBXFileReference section */\n",
        (
            f"\t\t{file_ref_id} /* GoogleService-Info.plist */ = "
            "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
            'path = "GoogleService-Info.plist"; sourceTree = "<group>"; };\n'
        ),
    )
    content = _ensure_runner_group(content, file_ref_id)
    content = _ensure_resources_phase(content, build_file_id)

    project_path.write_text(content, encoding="utf-8")
    return True


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Usage: ensure_google_service_plist.py <project.pbxproj> <GoogleService-Info.plist> [expected_bundle_id]"
        )
        return 1

    project_path = Path(sys.argv[1])
    plist_path = Path(sys.argv[2])
    expected_bundle_id = sys.argv[3].strip() if len(sys.argv) > 3 else ""

    if not project_path.is_file():
        raise SystemExit(f"ERROR: project file not found: {project_path}")
    if not plist_path.is_file():
        raise SystemExit(f"ERROR: GoogleService-Info.plist not found: {plist_path}")

    data = _load_plist(plist_path)
    bundle_id = str(data.get("BUNDLE_ID", "")).strip()
    if expected_bundle_id and bundle_id and bundle_id != expected_bundle_id:
        raise SystemExit(
            "ERROR: GoogleService-Info.plist BUNDLE_ID "
            f"'{bundle_id}' does not match expected '{expected_bundle_id}'."
        )

    changed = ensure_google_service_in_project(project_path)
    action = "updated" if changed else "already configured"
    print(f"GoogleService-Info.plist {action} in {project_path}")
    print(f"Firebase plist bundle id: {bundle_id or 'unknown'}")
    print(f"Firebase Google App ID: {data.get('GOOGLE_APP_ID', 'unknown')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
