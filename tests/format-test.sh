#!/usr/bin/env bash
# The data and template files BxRig packs (src/resources) and the repo's JSON keep one format, so they stay easy to edit:
# JSON in the standard 2-space layout (as `json.dumps(indent=2)` writes it), no tabs, no trailing spaces, LF, one final newline.
# Lua/Luau/TOML/text indent with 2 spaces, fish with 4 (fish_indent). See .editorconfig. Usage: format-test.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$root" <<'PY'
import json, os, re, sys
root = sys.argv[1]
dirs = ["catalog", "templates", "themes", "skills", "assets/wizard", "keys", "docs/reference"]
files = [os.path.join(root, "box.json")]
for d in dirs:
    for base, _, names in os.walk(os.path.join(root, d)):
        files += [os.path.join(base, n) for n in names]
text_ext = (".json", ".lua", ".luau", ".toml", ".txt", ".md", ".zsh", ".bash", ".fish", ".pub", ".plymouth", ".script")
problems = []
for f in sorted(files):
    if not f.endswith(text_ext):
        continue
    rel = os.path.relpath(f, root)
    s = open(f, encoding="utf-8").read()
    if "\r" in s: problems.append(f"{rel}: CRLF line endings")
    if not s.endswith("\n") or s.endswith("\n\n"): problems.append(f"{rel}: must end with exactly one newline")
    if not f.endswith(".md") and any(l != l.rstrip() for l in s.split("\n")): problems.append(f"{rel}: trailing spaces")
    if re.search(r"^\t", s, re.M): problems.append(f"{rel}: indented with tabs")
    if f.endswith(".json"):
        try:
            if s != json.dumps(json.loads(s), indent=2, ensure_ascii=False) + "\n":
                problems.append(f"{rel}: not in the standard 2-space JSON layout (python3 -c 'import json,sys;p=sys.argv[1];open(p,\"w\").write(json.dumps(json.load(open(p)),indent=2,ensure_ascii=False)+chr(10))' {rel})")
        except ValueError as e:
            problems.append(f"{rel}: invalid JSON ({e})")
    elif f.endswith((".lua", ".luau")):
        widths = [len(m) for m in re.findall(r"^( +)\S", s, re.M)]
        if any(w % 2 for w in widths): problems.append(f"{rel}: indent is not a multiple of 2 spaces")
for p in problems: print("FAIL:", p)
sys.exit(1 if problems else 0)
PY
echo "format-test: ok"
