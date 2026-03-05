#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found in PATH" >&2
  exit 1
fi

# Generates ios/ project files without overriding existing Dart source.
flutter create --platforms=ios --project-name ios_satelitrack_wrapper .

echo "iOS Flutter project generated."
