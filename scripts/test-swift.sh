#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d /private/tmp/topdown-swift-tests.XXXXXX)"
trap 'rm -r "$test_dir"' EXIT

swiftc \
  "$project_root/Sources/TopDown/OpaqueProtector.swift" \
  "$project_root/swift-tests/OpaqueProtectorSelfTest.swift" \
  -o "$test_dir/OpaqueProtectorSelfTest"
"$test_dir/OpaqueProtectorSelfTest"
