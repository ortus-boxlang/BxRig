--!nonstrict
-- BxRig System panel: two tabs, Updates and Backups.
--
-- Updates (`bxrig system updates --json`, every 60 s while open): the number waiting and the repo / AUR split, a banner when a restart is
--   needed (a pending kernel, systemd or glibc update, or a kernel that was already replaced), a filter (All, Repo, AUR), the package list
--   (name, old -> new, repo or aur) and "Update all". That button opens a terminal that runs `bxrig system update --yes`, so the snapshot
--   that comes first and the progress are on screen. Without `checkupdates` (pacman-contrib) the tab says so and offers to install it.
-- Backups (`bxrig backup status --json`, every 60 s while open): a row per kind (config snapshots, system snapshots, files) with its last run,
--   next run, size and health; a play button on a row and "Back up now" (all rows that can) run the rows' own commands in a terminal;
--   "Open Time Machine" runs `bxrig timemachine` there.
-- The Updates count and the restart flag are published with noctalia.state for the bar widget.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local REFRESH_MS = 60000
local UPDATES_TIMEOUT_MS = 240000
local BACKUPS_TIMEOUT_MS = 60000
local LIST_CAP = 300

local tab = "updates"
local filter = "all"
local closeButton = true

local upd = nil -- data of `system updates --json`
local updErr = nil
local updLoading = false
local updFetchedMs = -REFRESH_MS

local bk = nil -- data of `backup status --json`
local bkErr = nil
local bkLoading = false
local bkFetchedMs = -REFRESH_MS

local TYPE_GLYPH = { config = "adjustments", system = "device-desktop", data = "folders" }

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function num(v)
	return tonumber(v) or 0
end

local function list(v)
	if type(v) == "table" then
		return v
	end
	return {}
end

local render

-- ---- terminal launch ----

-- One word of a shell command line, single quoted.
local function shq(s)
	return "'" .. (string.gsub(s, "'", "'\\''")) .. "'"
end

-- The shell text that runs `bxrig <args>`; the executable comes from the plugin setting and may be a path, so it is quoted too.
local function bx(args)
	local words = { shq(bxrig.command()) }
	for _, a in ipairs(args) do
		table.insert(words, shq(a))
	end
	return table.concat(words, " ")
end

-- Runs shell lines one after the other in a terminal and waits for Enter, so the output can be read.
local function inTerminal(lines)
	local script = table.concat(lines, "; ") .. "; echo; printf 'Done. Press Enter to close. '; read -r _"
	noctalia.runInTerminal(script)
end

-- ---- data ----

local function fetchUpdates()
	if updLoading then
		return
	end
	updLoading = true
	updFetchedMs = noctalia.nowMs()
	bxrig.json({ "system", "updates", "--json" }, function(data, err)
		updLoading = false
		if err ~= nil then
			updErr = err
		else
			upd = data
			updErr = nil
			noctalia.state.set("updates", num(data.total))
			noctalia.state.set("reboot", data.needs_reboot == true)
		end
		render()
	end, UPDATES_TIMEOUT_MS)
end

local function fetchBackups()
	if bkLoading then
		return
	end
	bkLoading = true
	bkFetchedMs = noctalia.nowMs()
	bxrig.json({ "backup", "status", "--json" }, function(data, err)
		bkLoading = false
		if err ~= nil then
			bkErr = err
		else
			bk = data
			bkErr = nil
		end
		render()
	end, BACKUPS_TIMEOUT_MS)
end

local function fetchCurrent()
	if tab == "updates" then
		fetchUpdates()
	else
		fetchBackups()
	end
end

local function selectTab(name)
	if tab == name then
		return
	end
	tab = name
	local fetchedMs = name == "updates" and updFetchedMs or bkFetchedMs
	if noctalia.nowMs() - fetchedMs >= REFRESH_MS then
		fetchCurrent()
	end
	render()
end

-- ---- drawing helpers ----

local function notice(glyph, color, title, sub, key)
	local texts = { ui.label({ text = title, fontSize = 13, fontWeight = "semibold", maxLines = 1 }) }
	if sub ~= nil and sub ~= "" then
		table.insert(texts, ui.label({ text = sub, fontSize = 11, color = "on_surface_variant", maxLines = 4 }))
	end
	return ui.row({ key = key, align = "center", gap = 10, paddingH = 12, paddingV = 10, radius = 12, fill = color .. "/0.14" }, {
		ui.glyph({ name = glyph, size = 20, color = color }),
		ui.column({ flexGrow = 1, gap = 2 }, texts),
	})
end

local function centered(glyph, color, text, key)
	return ui.column({ key = key, paddingV = 16, align = "center", gap = 6 }, {
		ui.glyph({ name = glyph, size = 20, color = color }),
		ui.label({ text = text, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 5 }),
	})
end

local function chipButton(key, text, on, onClick)
	return ui.button({
		key = key,
		text = text,
		variant = on and "primary" or "outline",
		selected = on,
		controlSize = "sm",
		flexGrow = 1,
		onClick = onClick,
	})
end

-- ---- the Updates tab ----

local function packageRow(p, index)
	local isAur = str(p.repo) == "aur"
	return ui.column({ key = "pkg-" .. index .. "-" .. str(p.name), gap = 1, paddingH = 10, paddingV = 6, radius = 8, fill = "surface_container" }, {
		ui.row({ align = "center", gap = 6 }, {
			ui.label({ text = str(p.name), fontSize = 12, fontWeight = "semibold", maxLines = 1, flexGrow = 1 }),
			ui.label({ text = isAur and "AUR" or "repo", fontSize = 10, fontWeight = "bold", color = isAur and "tertiary" or "on_surface_variant" }),
		}),
		ui.label({ text = str(p.old) .. " -> " .. str(p.new), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
	})
end

local function rebootBanner()
	if upd.needs_reboot ~= true then
		return nil
	end
	local stale = upd.reboot_stale == true
	local reasons = {}
	for _, r in ipairs(list(upd.reboot_reasons)) do
		table.insert(reasons, str(r))
	end
	local sub = table.concat(reasons, "; ")
	if stale and sub == "" then
		sub = "The running kernel was replaced by an update."
	end
	return notice("refresh-alert", "tertiary", stale and "Restart needed" or "Restart after updating", sub, "reboot")
end

local function updatesBody(items)
	if upd == nil then
		if updErr ~= nil then
			table.insert(items, centered("alert-triangle", "error", updErr, "upd-error"))
			if string.find(updErr, "pacman-contrib", 1, true) ~= nil then
				table.insert(items, ui.button({
					text = "Install pacman-contrib",
					glyph = "package",
					variant = "outline",
					onClick = function()
						inTerminal({ "sudo pacman -S pacman-contrib" })
						panel.close()
					end,
				}))
			end
		else
			table.insert(items, centered("loader", "on_surface_variant", "Checking for updates... this can take a few seconds", "upd-loading"))
		end
		return
	end

	local total = num(upd.total)
	local repoCount = num(upd.repo_count)
	local aurCount = num(upd.aur_count)

	-- summary
	local sub = total == 0 and "Nothing is waiting." or (repoCount .. " repo - " .. aurCount .. " AUR")
	local last = str(upd.last_update_ago) ~= "" and ("Last upgrade " .. str(upd.last_update_ago)) or "No upgrade found in the pacman log"
	table.insert(items, ui.row({ key = "summary", align = "center", gap = 10 }, {
		ui.glyph({ name = total == 0 and "circle-check" or "package", size = 28, color = total == 0 and "primary" or "secondary" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = total == 0 and "Up to date" or (total == 1 and "1 update" or (total .. " updates")), fontSize = 16, fontWeight = "bold" }),
			ui.label({ text = sub .. "  ·  " .. last, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
		}),
	}))

	local banner = rebootBanner()
	if banner ~= nil then
		table.insert(items, banner)
	end
	if str(upd.aur_error) ~= "" then
		table.insert(items, notice("alert-triangle", "error", "The AUR check failed", str(upd.aur_error), "aur-error"))
	end
	if updErr ~= nil then
		table.insert(items, ui.label({ key = "stale-error", text = "Could not refresh: " .. updErr, fontSize = 10, color = "error", maxLines = 2 }))
	end

	if total == 0 then
		return
	end

	-- filter and list
	table.insert(items, ui.row({ key = "filter", gap = 4 }, {
		chipButton("f-all", "All " .. total, filter == "all", function()
			filter = "all"
			render()
		end),
		chipButton("f-repo", "Repo " .. repoCount, filter == "repo", function()
			filter = "repo"
			render()
		end),
		chipButton("f-aur", "AUR " .. aurCount, filter == "aur", function()
			filter = "aur"
			render()
		end),
	}))
	local rows = {}
	local shown = 0
	local hidden = 0
	for i, p in ipairs(list(upd.packages)) do
		if type(p) == "table" and (filter == "all" or str(p.repo) == filter) then
			if shown < LIST_CAP then
				shown = shown + 1
				table.insert(rows, packageRow(p, i))
			else
				hidden = hidden + 1
			end
		end
	end
	if hidden > 0 then
		table.insert(rows, ui.label({ key = "more", text = "and " .. hidden .. " more", fontSize = 11, color = "on_surface_variant" }))
	end
	if #rows == 0 then
		table.insert(rows, ui.label({ key = "none", text = "Nothing in this list.", fontSize = 11, color = "on_surface_variant" }))
	end
	table.insert(items, ui.scroll({ key = "packages", flexGrow = 1, gap = 4 }, rows))
end

local function updatesFooter(items)
	if upd == nil then
		return
	end
	local total = num(upd.total)
	if total == 0 then
		return
	end
	local snapshot = str(upd.snapshot_tool)
	local note = snapshot ~= "" and ("A " .. snapshot .. " snapshot is taken first, then pacman, then the AUR. A terminal shows the progress.")
		or "No snapshot tool found (snapper or timeshift): the update runs without one. A terminal shows the progress."
	table.insert(items, ui.button({
		key = "update-all",
		text = "Update all",
		glyph = "circle-arrow-up",
		variant = "primary",
		onClick = function()
			inTerminal({ bx({ "system", "update", "--yes" }) })
			panel.close()
		end,
	}))
	table.insert(items, ui.label({ key = "update-note", text = note, fontSize = 10, color = "on_surface_variant", maxLines = 3 }))
end

-- ---- the Backups tab ----

local HEALTH = {
	ok = { glyph = "circle-check", color = "primary" },
	warn = { glyph = "alert-triangle", color = "error" },
	none = { glyph = "circle-dashed", color = "on_surface_variant" },
}

local function backupRow(r, index)
	local kind = str(r.kind)
	local health = HEALTH[str(r.health)] or HEALTH.none
	local action = list(r.action)
	local when = str(r.last_ago) ~= "" and str(r.last_ago) or "never"
	local detail = "Last " .. when .. "  ·  next " .. str(r.next)
	if str(r.size_text) ~= "" then
		detail = detail .. "  ·  " .. str(r.size_text)
	end
	local texts = {
		ui.label({ text = str(r.label), fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
		ui.label({ text = detail, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
	}
	if str(r.note) ~= "" then
		table.insert(texts, ui.label({ text = str(r.note), fontSize = 10, color = str(r.health) == "warn" and "error" or "on_surface_variant", maxLines = 3 }))
	end
	return ui.row({ key = "bk-" .. index .. "-" .. str(r.id), align = "center", gap = 10, paddingH = 12, paddingV = 10, radius = 12, fill = "surface_container" }, {
		ui.glyph({ name = TYPE_GLYPH[kind] or "folders", size = 20, color = "secondary" }),
		ui.column({ flexGrow = 1, gap = 2 }, texts),
		ui.glyph({ name = health.glyph, size = 18, color = health.color }),
		ui.button({
			glyph = "player-play",
			variant = "ghost",
			controlSize = "sm",
			enabled = #action > 0,
			tooltip = #action > 0 and "Back up now" or "Not set up yet",
			onClick = function()
				inTerminal({ bx(action) })
			end,
		}),
	})
end

local function backupsBody(items)
	if bk == nil then
		if bkErr ~= nil then
			table.insert(items, centered("alert-triangle", "error", bkErr, "bk-error"))
		else
			table.insert(items, centered("loader", "on_surface_variant", "Reading your backups...", "bk-loading"))
		end
		return
	end
	local rows = {}
	for i, r in ipairs(list(bk.rows)) do
		if type(r) == "table" then
			table.insert(rows, backupRow(r, i))
		end
	end
	if #rows == 0 then
		table.insert(items, centered("folders", "on_surface_variant", "No backup information", "bk-empty"))
	else
		table.insert(items, ui.column({ key = "bk-rows", gap = 8 }, rows))
	end
	if bkErr ~= nil then
		table.insert(items, ui.label({ key = "bk-stale", text = "Could not refresh: " .. bkErr, fontSize = 10, color = "error", maxLines = 2 }))
	end
end

local function backupsFooter(items)
	local lines = {}
	if bk ~= nil then
		for _, r in ipairs(list(bk.rows)) do
			local action = type(r) == "table" and list(r.action) or {}
			if #action > 0 then
				table.insert(lines, bx(action))
			end
		end
	end
	table.insert(items, ui.row({ key = "bk-actions", gap = 6 }, {
		ui.button({
			text = "Back up now",
			glyph = "device-floppy",
			variant = "primary",
			flexGrow = 1,
			enabled = #lines > 0,
			onClick = function()
				inTerminal(lines)
			end,
		}),
		ui.button({
			text = "Open Time Machine",
			glyph = "history",
			variant = "outline",
			flexGrow = 1,
			onClick = function()
				inTerminal({ bx({ "timemachine" }) })
				panel.close()
			end,
		}),
	}))
end

-- ---- the panel ----

render = function()
	local badge = nil
	if bk ~= nil and num(bk.warn_count) > 0 then
		badge = "alert-triangle"
	end
	local header = {
		ui.glyph({ name = "device-desktop-cog", size = 24, color = "secondary" }),
		ui.label({ text = "System", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Check again", onClick = "onRefresh" }),
	}
	if closeButton then
		table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end

	local updatesLabel = "Updates"
	if upd ~= nil and num(upd.total) > 0 then
		updatesLabel = "Updates " .. num(upd.total)
	end
	local sections = {
		ui.row({ align = "center", gap = 10 }, header),
		ui.row({ gap = 4 }, {
			ui.button({
				key = "tab-updates",
				text = updatesLabel,
				glyph = "package",
				variant = tab == "updates" and "primary" or "outline",
				selected = tab == "updates",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("updates")
				end,
			}),
			ui.button({
				key = "tab-backups",
				text = "Backups",
				glyph = badge or "device-floppy",
				variant = tab == "backups" and "primary" or "outline",
				selected = tab == "backups",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("backups")
				end,
			}),
		}),
		ui.separator({}),
	}
	if tab == "updates" then
		updatesBody(sections)
		updatesFooter(sections)
	else
		backupsBody(sections)
		backupsFooter(sections)
	end
	panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 12 }, sections))
end

function onRefresh()
	fetchCurrent()
end

function onCloseClicked()
	panel.close()
end

function onOpen(_context)
	closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
	panel.setWantsSecondTicks(true)
	render()
	fetchCurrent()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	local fetchedMs = tab == "updates" and updFetchedMs or bkFetchedMs
	if noctalia.nowMs() - fetchedMs >= REFRESH_MS then
		fetchCurrent()
	end
end
