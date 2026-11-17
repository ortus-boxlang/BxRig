--!nonstrict
-- BxRig VPN bar widget: a bare shield glyph colored by one palette role. Green (primary) with a check while a VPN is connected, muted
-- while none is; hidden until the first answer and whenever `bxrig vpn list` has nothing (no VPN app and no saved VPN profile).
-- Click opens the panel. The list is read every minute in the background; while the panel is open it reads every 10 s and shares the
-- answer through noctalia.state, so the shield follows it.

local vpn = require("./vpn.luau")

local REFRESH_MS = 60000

local result = nil -- nil until the first answer
local loading = false

local function draw()
	if result == nil or #result.providers == 0 then
		barWidget.setVisible(false)
		return
	end
	barWidget.setVisible(true)
	local on = #result.connected
	local children = { ui.glyph({ name = on > 0 and "shield-check" or "shield", color = on > 0 and "primary" or "on_surface_variant" }) }
	if on > 1 then
		table.insert(children, ui.label({ text = tostring(on), fontSize = 11, fontWeight = "bold", color = "primary" }))
	end
	local container = barWidget.isVertical() and ui.column or ui.row
	barWidget.render(container({ gap = 3, align = "center" }, children))
	barWidget.setTooltip("VPN: " .. vpn.summary(result.connected))
end

local function refresh()
	if loading then
		return
	end
	loading = true
	vpn.load(function(answer)
		loading = false
		result = answer
		draw()
	end, 30000)
end

function update()
	refresh()
end

function onClick()
	noctalia.togglePanel("bxrig/vpn:panel")
end

-- the open panel reads more often and hands its answer over
noctalia.state.watch("list", function(value)
	if type(value) == "table" and type(value.providers) == "table" then
		result = value
		draw()
	end
end)

noctalia.setUpdateInterval(REFRESH_MS)
barWidget.setVisible(false)
refresh()
