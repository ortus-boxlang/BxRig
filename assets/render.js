// Renders every SVG in assets/ to PNG (wallpapers at 2560x1440, icon 256, logo 720x200). Usage: node assets/render.js [icons]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch();
  const jobs = [['wallpapers/box', 2560, 1440], ['wallpapers/grid', 2560, 1440], ['wallpapers/aurora', 2560, 1440], ['wallpapers/minimal', 2560, 1440], ['logo', 720, 200]];
  const iconsOnly = process.argv[2] === 'icons';   // node assets/render.js icons: only the app icon PNGs
  for (const [name, w, h] of (iconsOnly ? [] : jobs)) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    await p.goto('file://' + path.resolve(__dirname, name + '.svg'));
    const jpg = ['wallpapers/box', 'wallpapers/grid', 'wallpapers/aurora'].includes(name);
    await p.screenshot(jpg ? { path: path.resolve(__dirname, name + '.jpg'), type: 'jpeg', quality: 92 } : { path: path.resolve(__dirname, name + '.png'), omitBackground: !name.startsWith('wallpapers') });
    await p.close();
  }
  // The app icon: transparent PNGs, the simplified drawing up to 48 px and the laptop from 64 px (the same SVG rendered at each size by the browser).
  fs.mkdirSync(path.resolve(__dirname, 'icons'), { recursive: true });
  for (const size of [16, 24, 32, 48, 64, 128, 256]) {
    const src = size <= 48 ? 'icons/bxrig-small.svg' : 'icons/bxrig.svg';
    const p = await b.newPage({ viewport: { width: size, height: size } });
    const data = fs.readFileSync(path.resolve(__dirname, src)).toString('base64');
    await p.setContent(`<body style="margin:0;background:transparent"><img id="i" src="data:image/svg+xml;base64,${data}" width="${size}" height="${size}" style="display:block"></body>`);
    await p.waitForFunction(() => document.getElementById('i').complete);
    await p.screenshot({ path: path.resolve(__dirname, `icons/${size}.png`), omitBackground: true });
    await p.close();
  }
  await b.close();
})();
