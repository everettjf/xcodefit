#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
output="$root/build/ui-layout.noindex"
mkdir -p "$output"
sources=("$root"/XcodeFit/XcodeFit/Core/*.swift)
for source in "$root"/XcodeFit/XcodeFit/*.swift; do
  if [[ "$(basename "$source")" != 'XcodeFitApp.swift' ]]; then sources+=("$source"); fi
done
swiftc -D DEBUG -swift-version 6 -parse-as-library "${sources[@]}" \
  "$root/Tools/UILayoutChecks.swift" -o "$output/check-ui-layout"
"$output/check-ui-layout" --ui-fixture
