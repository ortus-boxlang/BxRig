#!/usr/bin/env python3
"""Generates the BxRig brand SVGs (icon and logo). The mark is drawn here; the Ortus icons in assets/brand/ stay for the Powered by BoxLang note.
Run: python3 assets/build.py && node assets/render.js
Palette: Ortus Brand Book 2025 (main #00FF78, second #00DBFF, accent #FFF500, dark #303446) on Catppuccin Frappe neutrals."""
import base64, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
G1, G2, YEL = "#00FF78", "#00DBFF", "#FFF500"
BASE, MANTLE, CRUST, TEXT, SUB = "#303446", "#292c3c", "#232634", "#c6d0f5", "#a5adce"

def uri(path):
	return "data:image/svg+xml;base64," + base64.b64encode(open(path, 'rb').read()).decode()
BOXLANG, BOXLANG_MONO, MATCHBOX = uri('brand/boxlang-icon-full.svg'), uri('brand/boxlang-icon-mono-dark.svg'), uri('brand/matchbox-icon-full.svg')

def img(href, x, y, size):
	return f'<image href="{href}" x="{x}" y="{y}" width="{size}" height="{size}"/>'

defs = f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{G2}"/><stop offset="1" stop-color="{G1}"/></linearGradient></defs>'
FONT = "font-family=\"Inter, 'Noto Sans', 'DejaVu Sans', sans-serif\""

LAPTOP = uri('brand/bxrig-laptop.svg')

def mark(x, y, size, mono=False):
	"""The BxRig mark: the laptop with the BoxLang emblem (assets/brand/bxrig-laptop.svg, drawn by the owner). `size` is its width; it is 4:3.
    mono is kept for callers that wanted a quiet version; the laptop has one look."""
	h = size * 0.75
	return f'<image href="{LAPTOP}" x="{x}" y="{y + (size - h) / 2:.1f}" width="{size}" height="{h:.1f}"/>'
def word(x, y, size, anchor="middle", extra=""):
	return f'<text x="{x}" y="{y}" text-anchor="{anchor}" {FONT} font-size="{size}" font-weight="700" fill="url(#g)" {extra}>Bx<tspan fill="{TEXT}">Rig</tspan></text>'
def svg(w, h, body):
	return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{defs}{body}</svg>\n'

W, H = 2560, 1440
# app icon: the BxRig laptop alone (no tile, no glow, transparent), as large as the canvas allows. Two drawings: the owner's laptop for 64 px and up,
# and a simplified one (thicker bezel, bigger emblem without the small dot, plain base) for 16 to 48 px. Rendered by render.js into icons/N.png.
LAPTOP_SVG = open('brand/bxrig-laptop.svg').read()
LAPTOP_INNER = LAPTOP_SVG[LAPTOP_SVG.index('>') + 1:LAPTOP_SVG.rindex('</svg>')]
LAPTOP_VIEW = "115 114 794 542"   # the drawn laptop (121,120 to 903,650) plus a small margin
def icon_svg(inner):
	w = 248; h = w * 542 / 794
	return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 256 256" width="256" height="256" role="img" aria-label="BxRig">'
			f'<svg x="4" y="{(256 - h) / 2:.2f}" width="{w}" height="{h:.2f}" viewBox="{LAPTOP_VIEW}">{inner}</svg></svg>\n')
SMALL_INNER = (
	'<defs><linearGradient id="rig-frame" x1="200" y1="120" x2="800" y2="640" gradientUnits="userSpaceOnUse"><stop stop-color="#00ff78"/><stop offset=".5" stop-color="#00dbff"/><stop offset="1" stop-color="#087cff"/></linearGradient>'
	'<linearGradient id="em1" x1="21.39" y1="77.59" x2="78.67" y2="29.52" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#00dbff"/><stop offset="1" stop-color="#00ff75"/></linearGradient>'
	'<linearGradient id="em3" x1="10.92" y1="105.24" x2="102.26" y2="28.6" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#00dbff"/><stop offset="1" stop-color="#00ff75"/></linearGradient></defs>'
	'<path d="M198 172 Q203 120 257 120 H767 Q821 120 826 172 L861 585 H163 Z" fill="url(#rig-frame)"/>'
	'<path d="M236 190 Q240 168 262 168 H762 Q784 168 788 190 L814 546 H210 Z" fill="#06182c"/>'
	'<g transform="translate(374 207) scale(2.52)"><path fill="url(#em1)" d="M37.96,18.29l10.66-8.95h.01s.02,0,.02,0c.38.06.75.12,1.13.19,22.89,4.56,37.72,26.84,33.15,49.7-4.52,22.67-26.4,37.42-49.02,33.27,4.88-1.11,9.57-3.35,13.67-6.78,13.73-11.52,15.53-32,4-45.74-6.61-7.87-16.15-11.81-25.68-11.58l12.06-10.12Z"/>'
	'<path fill="url(#em3)" d="M61.42,117.85c-19.21,3.86-38.12-1.94-51.7-14.04.79-.34,1.55-.79,2.25-1.38,1.42-1.19,2.38-2.74,2.85-4.4,2.97,1.71,6.12,3.16,9.43,4.3,28.27,9.72,59.04-5.34,68.73-33.6C102.7,40.46,87.64,9.69,59.38,0c24.61,4.05,44.13,22.9,48.99,47.31,6.52,32.45-14.5,64.02-46.95,70.54Z"/></g>'
	'<path d="M135 580 H889 Q906 580 902 599 Q895 642 840 650 H184 Q129 642 122 599 Q118 580 135 580 Z" fill="url(#rig-frame)"/>')
os.makedirs('icons', exist_ok=True)
open('icons/bxrig.svg', 'w').write(icon_svg(LAPTOP_INNER))
open('icons/bxrig-small.svg', 'w').write(icon_svg(SMALL_INNER))
# Bar plates (the hybrid style: plates only on the logo button and on the Launchpad grid in the dock). A dark rounded tile with a gradient outline
# and a soft halo (stacked low-opacity rounded squares, no SVG filters) so the plate stays visible on dark and Retro bars. Rendered to PNG by render.js.
def plate_svg(inner, label):
	return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" role="img" aria-label="' + label + '">'
		'<defs><linearGradient id="pg" x1="6" y1="6" x2="58" y2="58" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#00ff78"/><stop offset=".55" stop-color="#00dbff"/><stop offset="1" stop-color="#087cff"/></linearGradient></defs>'
		'<rect x="1" y="1" width="62" height="62" rx="18" fill="url(#pg)" opacity=".16"/>'
		'<rect x="3" y="3" width="58" height="58" rx="16" fill="url(#pg)" opacity=".26"/>'
		'<rect x="5.5" y="5.5" width="53" height="53" rx="14" fill="#06182c" stroke="url(#pg)" stroke-width="2.4"/>' + inner + '</svg>\n')
GRID_SQ = ''.join(
	('<rect x="%.1f" y="%.1f" width="7.2" height="7.2" rx="2" fill="none" stroke="url(#pg)" stroke-width="1.5"/>' % (x + .75, y + .75)) if (r == 0 and k == 2)
	else ('<rect x="%.1f" y="%.1f" width="9" height="9" rx="2.4" fill="url(#pg)"/>' % (x, y))
	for r, y in enumerate((5, 19.5, 34)) for k, x in enumerate((5, 19.5, 34)))
PLATE_GRID = plate_svg('<g transform="translate(14 14) scale(.75)">' + GRID_SQ + '</g>', 'Apps')
PLATE_LOGO = plate_svg('<svg x="13" y="17.5" width="38" height="%.2f" viewBox="%s">%s</svg>' % (38 * 542 / 794, LAPTOP_VIEW, SMALL_INNER), 'BxRig menu')
os.makedirs('icons/plates', exist_ok=True)
open('icons/plates/bxrig-grid.svg', 'w').write(PLATE_GRID)
open('icons/plates/bxrig-menu.svg', 'w').write(PLATE_LOGO)
# logo: icon + wordmark, for dark backgrounds
open('logo.svg', 'w').write(svg(720, 200, f'{mark(14, 20, 160)}{word(200, 124, 96, "start")}'))
# The wallpapers are photographs made per theme (assets/wallpapers/<theme>.jpg, see assets/wallpapers/README.md), not drawn here.
