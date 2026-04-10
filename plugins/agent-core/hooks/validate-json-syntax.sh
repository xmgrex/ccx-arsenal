#!/bin/bash
# JSON syntax validator — PostToolUse hook

FILE_PATH="$TOOL_INPUT_FILE_PATH"

echo "$FILE_PATH" | grep -qE '\.json$' || exit 0

python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$FILE_PATH" 2>&1 || echo "[Hook] JSON syntax error in $FILE_PATH"
