local rain = require("rain")
local events = require("events")

local VALID_COMMAND_STAGE = {
  drizzle = true,
  rain = true,
  heavy = true,
  storm = true,
  monsoon = true
}

local function resolve_surface(surface_index)
  if type(surface_index) ~= "number" then return nil end
  return game.surfaces[surface_index]
end

local function command_surface(cmd)
  if cmd.player_index then
    local player = game.get_player(cmd.player_index)
    if player and player.valid then return player.surface, player end
  end
  return game.surfaces.nauvis or game.surfaces[1], nil
end

local function split_words(text)
  local words = {}
  for word in string.gmatch(text or "", "%S+") do
    words[#words + 1] = string.lower(word)
  end
  return words
end

local function can_use_weather_command(player)
  if not player then return true end
  local ok, multiplayer = pcall(function() return game.is_multiplayer() end)
  if ok and not multiplayer then return true end
  if player.admin then return true end
  player.print("Real Rain weather commands are admin-only on multiplayer servers.")
  return false
end

local function run_command(cmd)
  local surface, player = command_surface(cmd)
  if not surface then return end
  if not can_use_weather_command(player) then return end

  local words = split_words(cmd.parameter)
  local action = words[1] or "status"
  local seconds = tonumber(words[2]) or 240
  local variant = words[2] or "close"

  local function say(message)
    if player then player.print(message) else game.print(message) end
  end

  if action == "status" then
    say("Real Rain: " .. rain.describe(surface))
    return
  end

  if action == "clear" then
    rain.force_clear(surface, seconds)
    say("Real Rain: forced clear weather on " .. surface.name .. " for " .. seconds .. " seconds.")
    return
  end

  if action == "rain" or action == "rain-only" or action == "rainonly" then
    rain.force_weather_combo(surface, "rain", seconds)
    say("Real Rain: forced rain only on " .. surface.name .. " for " .. seconds .. " seconds. No lightning or thunder.")
    return
  end

  if action == "thunder-rain" or action == "thunderrain" or action == "rain-thunder" or action == "thunderandrain" then
    rain.force_weather_combo(surface, "thunder-rain", seconds)
    say("Real Rain: forced thunder + rain on " .. surface.name .. " for " .. seconds .. " seconds. Thunder sounds only, no lightning flash.")
    return
  end

  if action == "thunderstorm" or action == "storm" or action == "storm-only" or action == "stormonly" then
    rain.force_weather_combo(surface, "thunderstorm", seconds)
    say("Real Rain: forced thunderstorm on " .. surface.name .. " for " .. seconds .. " seconds. Rain, lightning flash, and linked thunder.")
    return
  end

  if action == "thunder" then
    local kind = words[2] or "close"
    rain.force_thunder(surface, player and player.position or { x = 0, y = 0 }, kind)
    say("Real Rain: forced immediate " .. kind .. " thunder on " .. surface.name .. ".")
    return
  end

  if action == "thunder-test" or action == "sound-test" or action == "test-thunder" then
    rain.force_thunder_test(surface, player and player.position or { x = 0, y = 0 })
    local summary = rain.thunder_sound_summary()
    say("Real Rain: thunder sound test started. Soundbank: " .. summary.unique .. " unique thunder files, with variation pools far=" .. summary.far .. ", close=" .. summary.close .. ", roll=" .. summary.roll .. ", monsoon=" .. summary.monsoon .. ".")
    return
  end

  if action == "lightning" or action == "lighting" then
    local close = (variant ~= "far")
    rain.force_lightning(surface, player and player.position or { x = 0, y = 0 }, close)
    say("Real Rain: forced " .. (close and "close" or "far") .. " lightning flash + linked thunder on " .. surface.name .. ".")
    return
  end

  if action == "strike" then
    local kind = words[2] or "close"
    rain.force_strike(surface, player and player.position or { x = 0, y = 0 }, kind)
    say("Real Rain: forced " .. kind .. " lightning strike on " .. surface.name .. ".")
    return
  end

  if VALID_COMMAND_STAGE[action] then
    rain.force_stage(surface, action, seconds)
    say("Real Rain: forced " .. action .. " on " .. surface.name .. " for " .. seconds .. " seconds.")
    return
  end

  say("Real Rain commands: /real-rain status | rain [seconds] | thunder-rain [seconds] | thunderstorm [seconds] | thunder [far/close/roll/monsoon] | thunder-test | lightning/lighting [far/close] | strike [far/close/monsoon] | clear [seconds] | drizzle/heavy/monsoon [seconds]. Aliases: /rr, /rrrain, /rrthunderrain, /rrstorm, /rrthunder, /rrlightning, /rrstrike.")
end

local function prefixed_command(action)
  return function(cmd)
    local parameter = action
    if cmd.parameter and cmd.parameter ~= "" then
      parameter = parameter .. " " .. cmd.parameter
    end
    run_command({ player_index = cmd.player_index, parameter = parameter })
  end
end

script.on_init(function()
  rain.on_init()
end)

script.on_configuration_changed(function()
  rain.on_configuration_changed()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, rain.on_runtime_mod_setting_changed)
script.on_event(defines.events.on_tick, rain.on_tick)
script.on_event(defines.events.on_surface_created, rain.on_configuration_changed)
script.on_event(defines.events.on_surface_deleted, rain.on_surface_deleted)
script.on_event(defines.events.on_chunk_generated, rain.on_chunk_generated)
script.on_event(defines.events.on_trigger_created_entity, rain.on_trigger_created_entity)

commands.add_command("real-rain", "Real Rain debug: status | rain [seconds] | thunder-rain [seconds] | thunderstorm [seconds] | thunder [far/close/roll/monsoon] | thunder-test | lightning/lighting [far/close] | strike [far/close/monsoon] | clear [seconds]", run_command)
commands.add_command("real_rain", "Alias for /real-rain", run_command)
commands.add_command("rr", "Alias for /real-rain", run_command)
commands.add_command("rrain", "Alias for /real-rain", run_command)
commands.add_command("rrrain", "Real Rain: rain only. Usage: /rrrain [seconds]", prefixed_command("rain"))
commands.add_command("rrthunderrain", "Real Rain: thunder plus rain, no lightning. Usage: /rrthunderrain [seconds]", prefixed_command("thunder-rain"))
commands.add_command("rrstorm", "Real Rain: full thunderstorm. Usage: /rrstorm [seconds]", prefixed_command("thunderstorm"))
commands.add_command("rrthunderstorm", "Real Rain: full thunderstorm. Usage: /rrthunderstorm [seconds]", prefixed_command("thunderstorm"))
commands.add_command("rrthunder", "Real Rain: play thunder now. Usage: /rrthunder [far|close|roll|monsoon]", prefixed_command("thunder"))
commands.add_command("rrlightning", "Real Rain: lightning flash plus linked thunder. Usage: /rrlightning [far|close]", prefixed_command("lightning"))
commands.add_command("rrstrike", "Real Rain: lightning flash plus thunder strike now. Usage: /rrstrike [far|close|monsoon]", prefixed_command("strike"))
commands.add_command("rrtest", "Real Rain: play far, close, roll, and monsoon thunder test", prefixed_command("thunder-test"))

remote.add_interface("real-rain", {
  is_raining = function(surface_index)
    local surface = resolve_surface(surface_index)
    if not surface then return nil end
    return rain.is_raining(surface)
  end,
  stage = function(surface_index)
    local surface = resolve_surface(surface_index)
    if not surface then return nil end
    return rain.stage(surface)
  end,
  time_left = function(surface_index)
    local surface = resolve_surface(surface_index)
    if not surface then return nil end
    return rain.time_left(surface)
  end,
  describe = function(surface_index)
    local surface = resolve_surface(surface_index)
    if not surface then return nil end
    return rain.describe(surface)
  end,
  force_stage = function(surface_index, stage, seconds)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_stage(surface, stage, seconds)
  end,
  force_clear = function(surface_index, seconds)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_clear(surface, seconds)
  end,
  force_weather_combo = function(surface_index, mode, seconds)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_weather_combo(surface, mode, seconds)
  end,
  force_thunder = function(surface_index, x, y, kind)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_thunder(surface, { x = x or 0, y = y or 0 }, kind)
  end,
  force_lightning = function(surface_index, x, y, close)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_lightning(surface, { x = x or 0, y = y or 0 }, close ~= false)
  end,
  force_strike = function(surface_index, x, y, kind)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_strike(surface, { x = x or 0, y = y or 0 }, kind)
  end,
  force_thunder_test = function(surface_index, x, y)
    local surface = resolve_surface(surface_index)
    if not surface then return false end
    return rain.force_thunder_test(surface, { x = x or 0, y = y or 0 })
  end,
  thunder_sound_summary = function()
    return rain.thunder_sound_summary()
  end,
  get_events = function()
    return {
      on_rain_pollution_cleaned = events.on_rain_pollution_cleaned
    }
  end
})
