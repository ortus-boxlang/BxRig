#!/usr/bin/env python3
"""Replaces the hand-written literal "Usage: bxrig ..." strings in src/ with new bxrig.CommandSpec().usage( "KEY" ), where KEY is the leading
lowercase words of the usage (just the command when the text lists several variants). Strings that are built with & (dynamic) or carry a
trailing explanation in parentheses are left alone and listed. Run from the repo root; prints a count."""
import re, json, glob, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cj = json.load(open(root + '/docs/reference/cli.json'))
cmds = {c['name'] for g in cj['groups'] for c in g['commands']}
done = kept = 0
for f in sorted(glob.glob(root + '/src/bxrig/*.bx')) + [root + '/src/Main.bx']:
	if os.path.basename(f) in ('CommandSpec.bx', 'HelpData.bx', 'Help.bx'): continue
	t = open(f).read(); out = []; last = 0
	for m in re.finditer(r'"(Usage: bxrig ([^"\n]*))"', t):
		pre = t[max(0, m.start() - 3):m.start()].strip(); post = t[m.end():m.end() + 3].strip()
		rest = m.group(2)
		toks = rest.split(); key = []
		for tk in toks:
			if re.fullmatch(r'[a-z][a-z0-9-]*', tk): key.append(tk)
			else: break
		if ' | ' in rest: key = key[:1]
		extra = bool(re.search(r'\)\s*$', rest)) or '   or   ' in rest or '   (' in rest
		if pre.endswith('&') or post.startswith('&') or not key or key[0] not in cmds or extra:
			kept += 1; print('kept', os.path.basename(f), rest[:90]); continue
		out.append(t[last:m.start()]); out.append('new bxrig.CommandSpec().usage( "%s" )' % ' '.join(key)); last = m.end(); done += 1
	out.append(t[last:])
	n = ''.join(out)
	if n != t: open(f, 'w').write(n)
print('replaced', done, 'kept', kept)
