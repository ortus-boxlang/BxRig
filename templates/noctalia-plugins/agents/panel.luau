--!nonstrict
-- BxRig Agents panel: header "Agents" with today's token count, then per agent
-- a name row with a launch button (">_") and per account its plan, an ACTIVE
-- badge and one meter row per limit (label, used bar, reset countdown).
--
-- Data: `bxrig ai panel --json`, fetched on open and every 60 s while open.
-- Launch: `bxrig ai launch <id>` (detached; the panel closes).
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local REFRESH_MS = 60000

local data = nil
local errorText = nil
local loading = false
local lastFetchMs = -REFRESH_MS
local closeButton = true

-- Leading glyph per agent id; anything else gets the robot.
local AGENT_GLYPHS = {
  ["claude-code"] = "asterisk",
  ["codex"] = "brand-openai",
  ["opencode"] = "code",
  ["cursor"] = "cube",
  ["gemini"] = "sparkles",
  ["copilot"] = "brand-github-copilot",
  ["github-copilot"] = "brand-github-copilot",
}

local function str(v)
  if v == nil then
    return ""
  end
  return tostring(v)
end

local function clamp01(x)
  x = tonumber(x) or 0
  if x < 0 then
    return 0
  elseif x > 1 then
    return 1
  end
  return x
end

-- 23800000 -> "23.8M", 950 -> "950".
local function compact(n)
  n = tonumber(n)
  if n == nil then
    return nil
  end
  local units = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
  for _, u in ipairs(units) do
    if n >= u[1] then
      local v = n / u[1]
      local text = v >= 100 and string.format("%.0f", v) or string.format("%.1f", v)
      text = text:gsub("%.0$", "")
      return text .. u[2]
    end
  end
  return string.format("%d", math.floor(n))
end

local function meterRow(meter, key)
  local used = clamp01(meter.used_fraction)
  local fill = "primary"
  if used >= 0.9 then
    fill = "error"
  elseif used >= 0.75 then
    fill = "tertiary"
  end
  return ui.row({ key = key, align = "center", gap = 10 }, {
    ui.label({ text = str(meter.label), fontSize = 12, color = "on_surface_variant", width = 72, maxLines = 1 }),
    ui.progress({ progress = used, flexGrow = 1, height = 6, radius = 3, fill = fill, track = "on_surface/0.12" }),
    ui.label({ text = str(meter.resets_in), fontSize = 12, color = "on_surface_variant", width = 56, textAlign = "end", maxLines = 1 }),
  })
end

local function noUsage(key)
  return ui.label({ key = key, text = "no usage data", fontSize = 11, color = "on_surface_variant" })
end

local function accountBlock(account, key)
  local children = {}
  local title = { ui.label({ text = str(account.name), fontSize = 13, fontWeight = "semibold", maxLines = 1 }) }
  if str(account.plan) ~= "" then
    table.insert(title, ui.label({ text = "· " .. str(account.plan), fontSize = 11, color = "on_surface_variant", maxLines = 1 }))
  end
  table.insert(title, ui.spacer({ flexGrow = 1 }))
  if account.active == true then
    table.insert(title, ui.label({ text = "ACTIVE", fontSize = 10, fontWeight = "bold", color = "primary" }))
  end
  table.insert(children, ui.row({ align = "center", gap = 6 }, title))

  local meters = type(account.meters) == "table" and account.meters or {}
  if #meters == 0 then
    table.insert(children, noUsage(key .. "-none"))
  else
    for i, meter in ipairs(meters) do
      if type(meter) == "table" then
        table.insert(children, meterRow(meter, key .. "-m" .. i))
      end
    end
  end
  return ui.column({ key = key, gap = 6 }, children)
end

local function agentBlock(agent, index)
  local id = str(agent.id)
  local key = "agent-" .. index .. "-" .. id
  local installed = agent.installed ~= false
  local header = {
    ui.glyph({ name = AGENT_GLYPHS[id] or "robot", size = 16, color = installed and "primary" or "on_surface_variant" }),
    ui.label({ text = str(agent.name ~= nil and agent.name or id), fontSize = 14, fontWeight = "bold", maxLines = 1 }),
  }
  if not installed then
    table.insert(header, ui.label({ text = "not installed", fontSize = 11, color = "on_surface_variant" }))
  end
  table.insert(header, ui.spacer({ flexGrow = 1 }))
  table.insert(header, ui.button({
    glyph = "terminal",
    variant = "ghost",
    controlSize = "sm",
    enabled = installed and id ~= "",
    tooltip = "Launch " .. str(agent.name ~= nil and agent.name or id),
    onClick = function()
      bxrig.run({ "ai", "launch", id })
      panel.close()
    end,
  }))

  local children = { ui.row({ align = "center", gap = 8 }, header) }
  local accounts = type(agent.accounts) == "table" and agent.accounts or {}
  if #accounts == 0 then
    table.insert(children, noUsage(key .. "-none"))
  else
    for i, account in ipairs(accounts) do
      if type(account) == "table" then
        table.insert(children, accountBlock(account, key .. "-a" .. i))
      end
    end
  end
  return ui.column({
    key = key,
    gap = 8,
    paddingH = 12,
    paddingV = 10,
    radius = 12,
    fill = "surface_container",
    opacity = installed and 1 or 0.6,
  }, children)
end

local function render()
  local titleColumn = { ui.label({ text = "Agents", fontSize = 16, fontWeight = "bold" }) }
  local tokens = data and compact(data.tokens_today) or nil
  if tokens ~= nil then
    table.insert(titleColumn, ui.label({ text = string.upper(tokens .. " tokens today"), fontSize = 10, fontWeight = "semibold", color = "on_surface_variant" }))
  end
  local header = {
    ui.glyph({ name = "robot", size = 24, color = "primary" }),
    ui.column({ flexGrow = 1, gap = 1 }, titleColumn),
    ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = "onRefresh" }),
  }
  if closeButton then
    table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
  end

  local sections = {
    ui.row({ align = "center", gap = 10 }, header),
    ui.separator({}),
  }

  local agents = data and data.agents or nil
  if data == nil then
    table.insert(sections, ui.column({ paddingV = 16, align = "center", gap = 6 }, {
      ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
      ui.label({ text = errorText or "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
    }))
  elseif type(agents) ~= "table" or #agents == 0 then
    table.insert(sections, ui.label({ text = "No agents found.", fontSize = 12, color = "on_surface_variant" }))
  else
    local blocks = {}
    for i, agent in ipairs(agents) do
      if type(agent) == "table" then
        table.insert(blocks, agentBlock(agent, i))
      end
    end
    table.insert(sections, ui.scroll({ flexGrow = 1, gap = 8 }, blocks))
    if errorText ~= nil then
      table.insert(sections, ui.label({ text = errorText, fontSize = 10, color = "error", maxLines = 2 }))
    end
  end

  panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 12 }, sections))
end

local function fetch()
  if loading then
    return
  end
  loading = true
  lastFetchMs = noctalia.nowMs()
  bxrig.json({ "ai", "panel", "--json" }, function(result, err)
    loading = false
    if err ~= nil then
      errorText = err
    else
      data = result
      errorText = nil
    end
    render()
  end, 30000)
end

function onRefresh()
  fetch()
end

function onCloseClicked()
  panel.close()
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  panel.setWantsSecondTicks(true)
  render()
  fetch()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

function update()
  if noctalia.nowMs() - lastFetchMs >= REFRESH_MS then
    fetch()
  end
end
