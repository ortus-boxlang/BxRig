// Renders the PNGs of the BxRig icon theme (assets/icons/theme) and the contact sheet (docs/assets/bxrig-icon-theme.png).
// Run by tools/gen-icon-theme.py; needs playwright and a Chrome (CHROME=/path/to/chrome, default /usr/bin/google-chrome, else playwright's own).
//   node tools/render-icon-theme.js [--sheet-only]
// 16 and 22 px come from assets/icons/theme/src/small (bold glyph, darker tile, less glow), the others from the scalable SVG.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const theme = path.join(root, 'assets/icons/theme');
(async () => {
	const man = JSON.parse(fs.readFileSync(path.join(theme, 'manifest.json'), 'utf8'));
	const exe = process.env.CHROME || (fs.existsSync('/usr/bin/google-chrome') ? '/usr/bin/google-chrome' : undefined);
	const b = await chromium.launch(exe ? { executablePath: exe, args: ['--no-sandbox'] } : {});
	const sheetOnly = process.argv.includes('--sheet-only');
	const render = async (svgText, size, dest) => {
		const p = await b.newPage({ viewport: { width: size, height: size } });
		const data = Buffer.from(svgText).toString('base64');
		await p.setContent(`<body style="margin:0;background:transparent"><img id="i" src="data:image/svg+xml;base64,${data}" width="${size}" height="${size}" style="display:block"></body>`);
		await p.waitForFunction(() => document.getElementById('i').complete);
		fs.mkdirSync(path.dirname(dest), { recursive: true });
		await p.screenshot({ path: dest, omitBackground: true });
		await p.close();
	};
	if (!sheetOnly) {
		let n = 0;
		for (const ic of man.icons) {
			const full = fs.readFileSync(path.join(theme, 'BxRig/scalable', ic.context, ic.name + '.svg'), 'utf8');
			const small = fs.readFileSync(path.join(theme, 'src/small', ic.name + '.svg'), 'utf8');
			for (const z of man.sizes) {
				await render(man.small.includes(z) ? small : full, z, path.join(theme, 'BxRig', `${z}x${z}`, ic.context, ic.name + '.png'));
				n++;
			}
		}
		console.log(`rendered ${n} PNGs`);
	}
	// the contact sheet: every icon at 16 22 24 32 48 64 128 on the BxRig dark and a light panel
	const sizes = [16, 22, 24, 32, 48, 64, 128];
	const img = (ic, z) => 'file://' + path.join(theme, 'BxRig', `${z}x${z}`, ic.context, ic.name + '.png');
	const row = (ic) => `<tr><td class="n">${ic.name}</td>${sizes.map((z) => `<td><img src="${img(ic, z)}" width="${z}" height="${z}"></td>`).join('')}</tr>`;
	const table = (list) => `<table><tr><th></th>${sizes.map((z) => `<th>${z}</th>`).join('')}</tr>${list.map(row).join('')}</table>`;
	const half = Math.ceil(man.icons.length / 2);
	const html = `<body style="margin:0;background:#242734;font:12px sans-serif;color:#c6d0f5"><style>
		table{border-collapse:collapse;margin:12px}td,th{padding:4px 8px;text-align:center}.n{text-align:left;font-family:monospace;color:#9aa2c4}
		.row{display:flex;align-items:flex-start}.light{background:#eef0f6;color:#303446}.light .n{color:#5d6280}</style>
		<div class="row"><div>${table(man.icons.slice(0, half))}</div><div>${table(man.icons.slice(half))}</div></div>
		<div class="light" style="padding:8px 12px;display:flex;flex-wrap:wrap;gap:14px;align-items:center">${man.icons.map((ic) => `<img src="${img(ic, 64)}" width="64" height="64" title="${ic.name}">`).join('')}</div>
		<div style="padding:8px 12px;display:flex;flex-wrap:wrap;gap:6px;align-items:center">${man.icons.map((ic) => `<img src="${img(ic, 16)}" width="16" height="16"><img src="${img(ic, 22)}" width="22" height="22">`).join('')}</div></body>`;
	const tmp = path.join(theme, '.sheet.html');
	fs.writeFileSync(tmp, html);
	const p = await b.newPage({ viewport: { width: 1100, height: 900 } });
	await p.goto('file://' + tmp);
	await p.waitForLoadState('load');
	fs.mkdirSync(path.join(root, 'docs/assets'), { recursive: true });
	await p.screenshot({ path: path.join(root, 'docs/assets/bxrig-icon-theme.png'), fullPage: true });
	fs.unlinkSync(tmp);
	await b.close();
	console.log('contact sheet: docs/assets/bxrig-icon-theme.png');
})();
