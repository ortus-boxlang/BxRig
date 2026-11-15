--!nonstrict
-- BxRig World Clock bar widget: a globe that toggles the panel.

barWidget.render(ui.glyph({ name = "world" }))
barWidget.setTooltip("World Clock")

function onClick()
  noctalia.togglePanel("bxrig/world-clock:panel")
end
