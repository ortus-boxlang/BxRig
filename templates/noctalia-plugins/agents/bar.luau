--!nonstrict
-- BxRig Agents bar widget: a robot that toggles the agents panel.

barWidget.render(ui.glyph({ name = "robot" }))
barWidget.setTooltip("Agents")

function onClick()
	noctalia.togglePanel("bxrig/agents:panel")
end
