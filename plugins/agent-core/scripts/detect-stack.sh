#!/usr/bin/env bash
# Stack detection: marker files → stack info
# Usage: !`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

if [ -f pubspec.yaml ]; then
  echo "STACK=Flutter"
  echo "TEST_CMD='flutter test'"
  echo "BUILD_CMD='flutter build'"
  echo "LINT_CMD='flutter analyze'"
  echo "TEST_PATTERN='*_test.dart'"
elif [ -f package.json ]; then
  echo "STACK=Node.js"
  echo "TEST_CMD='npx jest --verbose'"
  echo "BUILD_CMD='npm run build'"
  echo "LINT_CMD='npx eslint . || npx biome check .'"
  echo "TEST_PATTERN='*.test.{js,ts,tsx}'"
elif [ -f Package.swift ]; then
  echo "STACK=Swift"
  echo "TEST_CMD='swift test'"
  echo "BUILD_CMD='swift build'"
  echo "LINT_CMD='swiftlint'"
  echo "TEST_PATTERN='*Tests.swift'"
elif [ -f Cargo.toml ]; then
  echo "STACK=Rust"
  echo "TEST_CMD='cargo test'"
  echo "BUILD_CMD='cargo build'"
  echo "LINT_CMD='cargo clippy'"
  echo "TEST_PATTERN='*.rs (#[test])'"
elif [ -f go.mod ]; then
  echo "STACK=Go"
  echo "TEST_CMD='go test ./...'"
  echo "BUILD_CMD='go build ./...'"
  echo "LINT_CMD='golangci-lint run'"
  echo "TEST_PATTERN='*_test.go'"
elif [ -f pyproject.toml ]; then
  echo "STACK=Python"
  echo "TEST_CMD='pytest -v'"
  echo "BUILD_CMD=''"
  echo "LINT_CMD='ruff check .'"
  echo "TEST_PATTERN='test_*.py'"
else
  echo "STACK=Unknown"
  echo "TEST_CMD='echo \"Detect manually\"'"
  echo "BUILD_CMD=''"
  echo "LINT_CMD=''"
  echo "TEST_PATTERN=''"
fi
