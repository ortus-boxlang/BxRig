--!nonstrict
-- BxRig Themes bar widget: a palette that toggles the theme switcher.

barWidget.render(ui.glyph({ name = "palette" }))
barWidget.setTooltip("Switch theme")

function onClick()
	noctalia.togglePanel("bxrig/themes:panel")
end
