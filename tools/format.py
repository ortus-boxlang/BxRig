#!/usr/bin/env python3
"""BxRig's one format: indent with tabs (shown 4 wide), LF line endings, one final newline, no trailing spaces.

    python3 tools/format.py            rewrite every file that is not formatted
    python3 tools/format.py --check    list them and exit 1 (CI)
    python3 tools/format.py FILE...    only these files
    python3 tools/format.py --stdin NAME   format stdin as the file NAME would be (for generators), to stdout

JSON gets the standard layout with tabs (json.dumps(indent="\\t")). In code, only the leading whitespace of a line
changes: each indent step becomes a tab and leftover alignment stays as spaces; text inside strings, heredocs and
long strings that span lines is never touched (whitespace there is part of the value). YAML (tabs are not allowed
in YAML), Markdown (indentation changes the meaning) and pixel-art text files keep their indentation; they still get
LF and one final newline.
"""
import io
import json
import os
import re
import sys
import tokenize

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", ".cache", "artifacts", "dist", "node_modules", "site", "target", ".bxsites"}
# src/resources and tests/resources only hold links to folders formatted on their own
SKIP_PATHS = {os.path.join("src", "resources"), os.path.join("tests", "resources")}
CODE = {".bx", ".bxs", ".bxm", ".cfc", ".cfm", ".js", ".lua", ".luau", ".py", ".sh", ".bash", ".zsh", ".fish",
		".toml", ".script", ".plymouth", ".service", ".desktop", ".conf", ".css", ".html"}
KEEP_INDENT = {".md", ".yml", ".yaml", ".txt", ".pub", ".svg"}
SHELLS = ("sh", "bash", "zsh", "dash")


def kind(path):
	ext = os.path.splitext(path)[1].lower()
	if ext == ".json":
		return "json"
	if ext in CODE:
		return ext
	if ext in KEEP_INDENT:
		return "keep"
	if not ext:
		try:
			with open(path, "rb") as f:
				first = f.readline().decode("utf-8", "replace")
		except OSError:
			return None
		if first.startswith("#!") and any(re.search(r"\b%s\b" % s, first) for s in SHELLS):
			return ".sh"
	return None


def files(args):
	if args:
		return [os.path.abspath(a) for a in args]
	out = []
	for base, dirs, names in os.walk(ROOT):
		rel = os.path.relpath(base, ROOT)
		dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and os.path.join(rel, d).lstrip("./") not in SKIP_PATHS
						 and not os.path.islink(os.path.join(base, d)))
		for n in sorted(names):
			p = os.path.join(base, n)
			if not os.path.islink(p) and kind(p):
				out.append(p)
	return out


# ---- the lines that start inside a string (their leading whitespace is part of the value) ----

def protected_c_like(text, interpolate):
	"""BoxLang and JavaScript: '...' and "..." (doubled quote or backslash escapes), `...` (JS), #expr# in BoxLang
    strings, // and /* */ comments."""
	prot, line, i, n = set(), 0, 0, len(text)
	state = []  # stack: ("str", q) | ("interp",)
	while i < n:
		c = text[i]
		if c == "\n":
			line += 1
			if state and state[-1][0] == "str":
				prot.add(line)
			elif state:
				prot.add(line)
			i += 1
			continue
		top = state[-1] if state else None
		if top and top[0] == "str":
			q = top[1]
			if c == "\\" and q == "`":
				i += 2
				continue
			if c == q:
				if q != "`" and i + 1 < n and text[i + 1] == q:
					i += 2
					continue
				state.pop()
			elif interpolate and c == "#":
				if i + 1 < n and text[i + 1] == "#":
					i += 2
					continue
				close, eol = text.find("#", i + 1), text.find("\n", i + 1)
				if close >= 0 and (eol < 0 or close < eol):
					i = close + 1  # #expr# on one line: skip it whole, quotes inside belong to it
					continue
			i += 1
			continue
		if top and top[0] == "interp" and c == "#":
			state.pop()
			i += 1
			continue
		if text.startswith("//", i):
			j = text.find("\n", i)
			i = n if j < 0 else j
			continue
		if text.startswith("/*", i):
			j = text.find("*/", i + 2)
			j = n if j < 0 else j + 2
			line += text.count("\n", i, j)
			i = j
			continue
		if c in "'\"" or (c == "`" and not interpolate):
			state.append(("str", c))
		i += 1
	return prot


def protected_lua(text):
	"""Lua and Luau: [[ ]] / [==[ ]==] long strings (not long comments), '...' and "..." with backslash escapes."""
	prot, line, i, n = set(), 0, 0, len(text)
	while i < n:
		c = text[i]
		if c == "\n":
			line += 1
			i += 1
			continue
		if text.startswith("--", i):
			m = re.match(r"--\[(=*)\[", text[i:])
			if m:
				end = text.find("]" + m.group(1) + "]", i)
				end = n if end < 0 else end + len(m.group(1)) + 2
				line += text.count("\n", i, end)
				i = end
			else:
				j = text.find("\n", i)
				i = n if j < 0 else j
			continue
		m = re.match(r"\[(=*)\[", text[i:])
		if m:
			end = text.find("]" + m.group(1) + "]", i)
			end = n if end < 0 else end + len(m.group(1)) + 2
			for k in range(text.count("\n", i, end)):
				prot.add(line + k + 1)
			line += text.count("\n", i, end)
			i = end
			continue
		if c in "'\"`":
			j = i + 1
			while j < n and text[j] != c and text[j] != "\n":
				j += 2 if text[j] == "\\" else 1
			i = j + 1
			continue
		i += 1
	return prot


def protected_python(text):
	prot = set()
	try:
		for tok in tokenize.generate_tokens(io.StringIO(text).readline):
			if tok.type == tokenize.STRING or getattr(tokenize, "FSTRING_MIDDLE", None) == tok.type:
				for ln in range(tok.start[0] + 1, tok.end[0] + 1):
					prot.add(ln - 1)
	except (tokenize.TokenError, IndentationError, SyntaxError):
		return set(range(text.count("\n") + 1))  # cannot tokenize: touch nothing
	return prot


HEREDOC = re.compile(r"(?<!<)<<(-?)[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")


def protected_shell(text):
	"""sh/bash/zsh/fish: heredoc bodies, and lines that start inside '...' or "..." (or $'...')."""
	prot, pending = set(), []
	lines = text.split("\n")
	quote = None
	for idx, raw in enumerate(lines):
		if pending:
			prot.add(idx)
			strip_tabs, word = pending[0]
			if (raw.lstrip("\t") if strip_tabs else raw) == word:
				pending.pop(0)
			continue
		if quote:
			prot.add(idx)
		i, n = 0, len(raw)
		while i < n:
			c = raw[i]
			if quote == "'":
				if c == "'":
					quote = None
				i += 1
				continue
			if quote == '"':
				if c == "\\":
					i += 2
					continue
				if c == '"':
					quote = None
				i += 1
				continue
			if c == "\\":
				i += 2
				continue
			if c == "#" and (i == 0 or raw[i - 1] in " \t;|&(") :
				break
			if c in "'\"":
				quote = c
				i += 1
				continue
			m = HEREDOC.match(raw, i)
			if m:
				pending.append((m.group(1) == "-", m.group(3)))
				i = m.end()
				continue
			i += 1
	return prot


def protected_toml(text):
	prot, inside, line = set(), None, 0
	for idx, raw in enumerate(text.split("\n")):
		if inside:
			prot.add(idx)
		for q in ('"""', "'''"):
			if inside == q:
				if raw.count(q) % 2 == 1:
					inside = None
			elif not inside and raw.count(q) % 2 == 1:
				inside = q
	return prot


def protected(k, text):
	if k in (".bx", ".bxs", ".bxm", ".cfc", ".cfm"):
		return protected_c_like(text, interpolate=True)
	if k in (".js", ".css", ".script", ".plymouth"):
		return protected_c_like(text, interpolate=False)
	if k in (".lua", ".luau"):
		return protected_lua(text)
	if k == ".py":
		return protected_python(text)
	if k in (".sh", ".bash", ".zsh", ".fish"):
		return protected_shell(text)
	if k == ".toml":
		return protected_toml(text)
	return set()


def bracket_levels(text):
	"""BoxLang: the indent level of every line from its bracket depth ({ ( [ outside strings and comments).
	A line that starts with closers is one level out per closer; the statements under `case x:` / `default:` are one
	level in. Returns { line: (level, in_block_comment) } for the lines that do not start inside a string."""
	levels, line, i, n = {}, 0, 0, len(text)
	depth, state, comment = 0, [], False
	line_start = True
	case_depth = []  # depths at which a case label opened
	def record(idx):
		nonlocal depth
		rest = text[idx:text.find("\n", idx) if text.find("\n", idx) >= 0 else n].lstrip(" \t")
		closers = 0
		for ch in rest:
			if ch in "})]":
				closers += 1
			else:
				break
		lvl = depth - closers
		while case_depth and case_depth[-1] > depth:
			case_depth.pop()
		label = re.match(r"(case\b.*|default\s*):\s*($|//)", rest) is not None
		if case_depth and case_depth[-1] == depth and not label and not rest.startswith("}"):
			lvl += 1
		if label:
			if not case_depth or case_depth[-1] != depth:
				case_depth.append(depth)
		levels[line] = (max(lvl, 0), comment)
	record(0)
	while i < n:
		c = text[i]
		if c == "\n":
			line += 1
			i += 1
			if not state:
				record(i)
			continue
		top = state[-1] if state else None
		if comment:
			if text.startswith("*/", i):
				comment = False
				i += 2
			else:
				i += 1
			continue
		if top and top[0] == "str":
			q = top[1]
			if c == q:
				if i + 1 < n and text[i + 1] == q:
					i += 2
					continue
				state.pop()
			elif c == "#":
				if i + 1 < n and text[i + 1] == "#":
					i += 2
					continue
				close, eol = text.find("#", i + 1), text.find("\n", i + 1)
				if close >= 0 and (eol < 0 or close < eol):
					i = close + 1
					continue
			i += 1
			continue
		if top and top[0] == "interp" and c == "#":
			state.pop()
			i += 1
			continue
		if text.startswith("//", i):
			j = text.find("\n", i)
			i = n if j < 0 else j
			continue
		if text.startswith("/*", i):
			comment = True
			i += 2
			continue
		if c in "'\"":
			state.append(("str", c))
		elif c in "{([":
			depth += 1
		elif c in "})]":
			depth -= 1
		i += 1
	return levels


def unit_for(widths):
	"""The indent step of a file indented with spaces: 4 when the indents are multiples of 4, else 2."""
	widths = [w for w in widths if w]
	if not widths:
		return 4
	fours = sum(1 for w in widths if w % 4 == 0)
	twos = sum(1 for w in widths if w % 2 == 0)
	if fours >= 0.9 * len(widths):
		return 4
	if twos >= 0.9 * len(widths):
		return 2
	return 1


def format_text(path, text):
	k = kind(path)
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	if k == "json":
		try:
			return json.dumps(json.loads(text), indent="\t", ensure_ascii=False) + "\n"
		except ValueError:
			return text
	lines = text.split("\n")
	prot = protected(k, text) if k not in ("keep",) else set()
	out = []
	if k == "keep":
		out = [l if path.endswith(".md") else l.rstrip(" \t") for l in lines]
	else:
		widths = []
		for idx, l in enumerate(lines):
			if idx in prot or not l.strip():
				continue
			lead = l[: len(l) - len(l.lstrip(" \t"))]
			if "\t" not in lead:
				widths.append(len(lead))
		unit = unit_for(widths)
		levels = bracket_levels(text) if k in (".bx", ".bxs", ".cfc") else None
		for idx, l in enumerate(lines):
			if levels is not None and idx not in prot and idx in levels and l.strip():
				lvl, in_comment = levels[idx]
				body = l.lstrip(" \t").rstrip(" \t")
				# a block comment's own lines keep their " * " one space in
				out.append("\t" * lvl + (" " if in_comment and body.startswith("*") else "") + body)
				continue
			if idx in prot:
				out.append(l)
				continue
			body = l.lstrip(" \t")
			if not body:
				out.append("")
				continue
			lead = l[: len(l) - len(body)]
			width = sum(unit if ch == "\t" else 1 for ch in lead)
			out.append("\t" * (width // unit) + " " * (width % unit) + body.rstrip(" \t"))
	result = "\n".join(out).rstrip("\n")
	return result + "\n" if result else ""


def main(argv):
	if argv[:1] == ["--stdin"]:
		sys.stdout.write(format_text(argv[1], sys.stdin.read()))
		return 0
	check = "--check" in argv
	targets = files([a for a in argv if not a.startswith("--")])
	bad = []
	for p in targets:
		try:
			with open(p, encoding="utf-8", newline="") as f:
				text = f.read()
		except (UnicodeDecodeError, OSError):
			continue
		new = format_text(p, text)
		if new != text:
			bad.append(os.path.relpath(p, ROOT))
			if not check:
				with open(p, "w", encoding="utf-8", newline="") as f:
					f.write(new)
	if check:
		for b in bad:
			print("not formatted:", b)
		if bad:
			print("Run: scripts/format.sh  (tabs for indentation, LF, one final newline, no trailing spaces)")
		return 1 if bad else 0
	print("formatted %d of %d files" % (len(bad), len(targets)))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
