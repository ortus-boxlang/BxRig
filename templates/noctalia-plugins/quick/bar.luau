--!nonstrict
-- BxRig Quick settings bar widget: a bare Tabler glyph (palette role tertiary, no plate) that toggles the quick settings popover.

barWidget.render(ui.glyph({ name = "adjustments-horizontal", color = "tertiary" }))
barWidget.setTooltip("Quick settings")

function onClick()
	noctalia.togglePanel("bxrig/quick:panel")
end
