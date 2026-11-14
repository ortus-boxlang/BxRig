#!/usr/bin/env python3
"""Replaces numeric exit codes at the say( ) and fail( ) call sites of the command classes with the names in src/bxrig/Exit.bx.
Only the code argument is touched: out.say( 4, ... ), cli.say( cmd, 4, ... ), the same for fail, and a ternary there (dryRun ? 0 : 2).
The number on the wire does not change. 2 becomes "usage" (a Usage line or no mention of a plan) or "plan" (the line talks about a plan, --yes or --dry-run)."""
import re, glob, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {0: 'ok', 1: 'negative', 3: 'timeout', 4: 'precondition', 5: 'official', 6: 'failed', 7: 'partial', 8: 'conflict', 9: 'internal', 10: 'update'}
def nm(n, ctx):
    n = int(n)
    if n == 2:
        low = ctx.lower()
        return 'plan' if ('usage' not in low and ('plan' in low or '--yes' in low or 'dryrun' in low or 'dry-run' in low or 'nothing was changed' in low)) else 'usage'
    return NAMES[n]
def conv(arg, ctx):
    a = arg.strip()
    if re.fullmatch(r'\d+', a): return '"%s"' % nm(a, ctx)
    m = re.fullmatch(r'(.+?)\?\s*(\d+)\s*:\s*(\d+)', a)
    if m: return '%s? "%s" : "%s"' % (m.group(1), nm(m.group(2), ctx) if m.group(2) != '2' else 'plan', nm(m.group(3), ctx) if m.group(3) != '2' else 'plan')
    return None
total = 0
OUT = re.compile(r'((?:variables\.)?out)\.(say|fail)\(\s*([^,]+?)\s*,')
CLI = re.compile(r'((?:variables\.)?cli)\.(say|fail)\(\s*([^,()]+?)\s*,\s*([^,]+?)\s*,')
for f in sorted(glob.glob(root + '/src/bxrig/*.bx')) + [root + '/src/Main.bx']:
    if os.path.basename(f) in ('Exit.bx', 'Cli.bx', 'Out.bx'): continue
    t = open(f).read(); o = t
    def line_of(s, pos):
        a = s.rfind('\n', 0, pos) + 1; b = s.find('\n', pos); return s[a:b if b > 0 else len(s)]
    def sub_out(m):
        global total
        c = conv(m.group(3), line_of(t, m.start()))
        if c is None: return m.group(0)
        total += 1; return '%s.%s( %s,' % (m.group(1), m.group(2), c)
    t = OUT.sub(sub_out, t)
    def sub_cli(m):
        global total
        c = conv(m.group(4), line_of(t, m.start()))
        if c is None: return m.group(0)
        total += 1; return '%s.%s( %s, %s,' % (m.group(1), m.group(2), m.group(3), c)
    t = CLI.sub(sub_cli, t)
    if t != o: open(f, 'w').write(t)
print('named', total, 'call sites')

# second pass: `return N;` inside a function that returns exit codes (its body has say( / fail( calls) and CLIExit( N ) in Main.bx
NM = {0: 'ok', 1: 'negative', 2: 'usage', 3: 'timeout', 4: 'precondition', 5: 'official', 6: 'failed', 7: 'partial', 8: 'conflict', 9: 'internal'}
ret = 0
for f in sorted(glob.glob(root + '/src/bxrig/*.bx')):
    if os.path.basename(f) in ('Exit.bx', 'Cli.bx', 'Out.bx'): continue
    t = open(f).read(); o = t
    starts = [m.start() for m in re.finditer(r'(?m)^    function \w+\(', t)] + [len(t)]
    out = []; last = 0
    for a, b in zip(starts, starts[1:]):
        body = t[a:b]
        rets = re.findall(r'return ([^;]+);', body)
        exitish = [x for x in rets if re.fullmatch(r'\d+', x.strip()) and int(x.strip()) in range(10) or re.search(r'\.(say|fail)\(|bxrig\.Exit\(\)|variables\.out\.(usage|precondition|failed)\(', x)]
        if rets and len(exitish) == len(rets) and any(re.fullmatch(r'\d+', x.strip()) for x in rets):
            def r(m):
                global ret
                n = int(m.group(1))
                if n not in NM: return m.group(0)
                ret += 1
                low = body.lower()
                name = NM[n]
                if n == 2 and ('plan' in low or 'nothing was changed' in low) and 'usage' not in low: name = 'plan'
                return 'return new bxrig.Exit().%s();' % name
            nb = re.sub(r'return (\d+);', r, body)
            out.append(t[last:a]); out.append(nb); last = b
    out.append(t[last:])
    t = ''.join(out)
    if t != o: open(f, 'w').write(t)
print('named', ret, 'return statements')
m = open(root + '/src/Main.bx').read(); mo = m
if 'var xit = new bxrig.Exit();' not in m:
    m = m.replace('        var cli = new bxrig.Cli( appVersion );', '        var cli = new bxrig.Cli( appVersion );\n        var xit = new bxrig.Exit();', 1)
cnt = 0
def ce(mm):
    global cnt
    n = int(mm.group(1))
    if n not in NM: return mm.group(0)
    cnt += 1; return 'CLIExit( xit.%s() )' % NM[n]
m = re.sub(r'CLIExit\( *(\d+) *\)', ce, m)
if m != mo: open(root + '/src/Main.bx', 'w').write(m)
print('named', cnt, 'CLIExit calls in Main.bx')
