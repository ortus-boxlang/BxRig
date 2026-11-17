--!nonstrict
-- BxRig Developer bar widget: a code glyph with the number of databases, containers and VMs running. Click opens the panel.
--
-- The number is refreshed every 2 minutes in the background; while the panel is open it refreshes every 15 s and shares the number
-- through noctalia.state, so the badge follows it. The glyph is colored by one palette role: primary while something runs.

local dev = require("./dev.luau")

local REFRESH_MS = 120000

local running = nil -- nil until the first answer
local engineMissing = false
local loading = false

local function draw()
	local active = running ~= nil and running > 0
	local children = { ui.glyph({ name = "code", color = active and "primary" or nil }) }
	if active then
		table.insert(children, ui.label({ text = tostring(running), fontSize = 11, fontWeight = "bold", color = "primary" }))
	end
	local container = barWidget.isVertical() and ui.column or ui.row
	barWidget.render(container({ gap = 4, align = "center" }, children))
	if engineMissing and not active then
		barWidget.setTooltip("Developer: no container engine installed")
	elseif active then
		barWidget.setTooltip("Developer: " .. tostring(running) .. " running")
	else
		barWidget.setTooltip("Developer")
	end
end

local function refresh()
	if loading then
		return
	end
	loading = true
	dev.load(function(result)
		loading = false
		running = result.running
		engineMissing = result.engineMissing
		draw()
	end, 30000)
end

function update()
	refresh()
end

function onClick()
	noctalia.togglePanel("bxrig/dev:panel")
end

noctalia.state.watch("running", function(value)
	if type(value) == "number" then
		running = value
		draw()
	end
end)

noctalia.setUpdateInterval(REFRESH_MS)
draw()
refresh()
