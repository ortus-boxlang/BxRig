--!nonstrict
-- BxRig Clock bar widget: the time as text ("Nov 5 - 04:00"). Click opens the panel; right click opens the Noctalia calendar (plugin.toml).
--
-- The text is drawn with barWidget.render (a ui tree), so the widget shows no glyph. The format is the plugin setting `format`
-- (Noctalia date format tokens, `bxrig time format` writes it). update() runs on the minute boundary, or every second when the format shows seconds.

local FALLBACK = "%b %-d - %H:%M"

local lastText = nil

local function pattern()
	local f = noctalia.getConfig("format")
	if type(f) ~= "string" or noctalia.string.trim(f) == "" then
		return FALLBACK
	end
	return f
end

-- seconds are on screen when the pattern has one of the second-resolution tokens
local function showsSeconds(p)
	return p:find("%%[STsrcX]") ~= nil
end

local function schedule(p)
	if showsSeconds(p) then
		noctalia.setUpdateInterval(1000)
	else
		-- the next whole minute, so the text changes when the minute does
		local ms = 60000 - (noctalia.nowMs() % 60000) + 40
		noctalia.setUpdateInterval(ms)
	end
end

local function draw()
	local p = pattern()
	local text = noctalia.formatTime(p)
	if text ~= lastText then
		lastText = text
		barWidget.render(ui.label({ text = text }))
		barWidget.setTooltip(noctalia.formatTime("%A, %B %-d, %Y"))
	end
	schedule(p)
end

function update()
	draw()
end

function onClick()
	noctalia.togglePanel("bxrig/clock:panel")
end

draw()
