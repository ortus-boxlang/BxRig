#!/usr/bin/env python3
"""One-off helper: writes a "flags" list for every command of docs/reference/cli.json (run again after adding a command).
A command accepts: the flags named in its usage lines and examples, plus the flags of the old global whitelist (src/Main.bx history,
passed with --whitelist) that its code can read: the string "flag" in the command's classes (and the classes those create), or in its case block.
When unsure the flag is kept. Types: value (written --flag=X somewhere), bool (written bare), any (found in code only).
Usage: tools/infer-command-flags.py --whitelist FILE_WITH_FLAGS_ONE_PER_LINE [--write]"""
import json, re, sys, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = sys.argv[1:]
W = [l.strip() for l in open(args[args.index('--whitelist') + 1]) if l.strip()]
main = open(root + '/src/Main.bx').read()
cj = json.load(open(root + '/docs/reference/cli.json'))
# case blocks: consecutive labels share a block
blocks = {}
parts = re.split(r'(?m)^(\s*case "[a-z0-9-]+":\s*\n)', main)
labels, cur = [], None
i = 1
while i < len(parts):
	lab = re.findall(r'case "([a-z0-9-]+)":', parts[i]); body = parts[i + 1] if i + 1 < len(parts) else ''
	labels += lab
	if body.strip():
		for l in labels: blocks[l] = body
		labels = []
	i += 2
def classes_of(text, depth=1, seen=None):
	seen = seen if seen is not None else set()
	out = ''
	for c in re.findall(r'new bxrig\.(\w+)', text):
		if c in seen: continue
		seen.add(c)
		p = '%s/src/bxrig/%s.bx' % (root, c)
		if os.path.exists(p):
			t = open(p).read(); out += t
			if depth > 1: out += classes_of(t, depth - 1, seen)
	return out
def flags_in(text):
	return set(re.findall(r'--([a-z][a-z0-9-]*)', text))
for g in cj['groups']:
	for c in g['commands']:
		usage = ' '.join(c['usage'] + c['examples'])
		written = re.findall(r'--([a-z][a-z0-9-]*)(=?)', usage)
		typ = {}
		for n, eq in written:
			typ[n] = 'value' if eq or typ.get(n) == 'value' else 'bool'
		body = blocks.get(c['name'], '')
		code = body + classes_of(body)
		# also the classes that share the first class's name as a prefix (Backup -> BackupConfig, BackupData, ...)
		first = re.findall(r'new bxrig\.(\w+)', body)
		if first:
			for f in sorted(os.listdir(root + '/src/bxrig')):
				if f.startswith(first[0]) and f.endswith('.bx') and f != first[0] + '.bx': code += open(root + '/src/bxrig/' + f).read()
		for w in W:
			if w in typ: continue
			e = re.escape(w)
			if re.search(r'structKeyExists\(\s*[\w.]+\s*,\s*"%s"\s*\)' % e, code) or re.search(r'\[\s*"%s"\s*\]' % e, code) or re.search(r'(?:options|opts|opt|flags)\.%s\b' % e, code):
				typ[w] = 'any'
		glob = {'json', 'yes', 'dry-run', 'force', 'quiet'}
		c['flags'] = [{'name': n, 'type': t} for n, t in sorted(typ.items()) if n not in glob]
if '--write' in args:
	open(root + '/docs/reference/cli.json', 'w').write(json.dumps(cj, indent=1, ensure_ascii=False) + '\n')
	print('wrote', sum(len(c['flags']) for g in cj['groups'] for c in g['commands']), 'flags for', sum(len(g['commands']) for g in cj['groups']), 'commands')
else:
	for g in cj['groups']:
		for c in g['commands']: print(c['name'], ' '.join(f['name'] + ('=' if f['type'] == 'value' else '?' if f['type'] == 'any' else '') for f in c['flags']))
