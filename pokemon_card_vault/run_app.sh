#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter non trovato nel PATH.' >&2
  exit 1
fi
flutter pub get
exec flutter run --target lib/rebuild/main_mobile_prototype.dart "$@"
