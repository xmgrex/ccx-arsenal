#!/bin/bash
# SKILL.md frontmatter validator — PostToolUse hook
# Checks that name and description fields exist in YAML frontmatter

FILE_PATH="$TOOL_INPUT_FILE_PATH"

# Only check SKILL.md files
echo "$FILE_PATH" | grep -q 'SKILL\.md$' || exit 0

# Validate frontmatter
python3 -c "
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m:
    print('[Hook] SKILL.md missing YAML frontmatter (--- block)')
    sys.exit(1)

fm = m.group(1)
missing = [k for k in ('name', 'description') if not re.search(r'^' + k + r'\s*:', fm, re.MULTILINE)]
if missing:
    print('[Hook] SKILL.md frontmatter missing: ' + ', '.join(missing))
    sys.exit(1)
" "$FILE_PATH"
