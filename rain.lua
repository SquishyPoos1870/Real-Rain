local M = {}

local weather_model = require("weather_model")
local rain_fire = require("rain_fire")
local pollution = require("pollution")
local solar = require("solar")

local random = math.random
local sin = math.sin
local cos = math.cos
local pi = math.pi
local floor = math.floor
local min = math.min
local max = math.max

local function clamp_volume(value)
  value = tonumber(value) or 0
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

local RAIN_RAMP_TICKS = 600
local RAIN_SOUND_DURATION_TICKS = 25 * 60
local MAX_SPAWN_PER_TICK = 1250
local SPAWN_COEFFICIENT = 0.0042

local PRESETS = {
  subtle = { intensity = 0.55, thunder = 0.55, splash = 0.035, sound = 0.75 },
  balanced = { intensity = 1.0, thunder = 1.0, splash = 0.065, sound = 1.0 },
  storm = { intensity = 1.75, thunder = 1.65, splash = 0.105, sound = 1.06 },
  monsoon = { intensity = 2.65, thunder = 2.15, splash = 0.145, sound = 1.12 }
}

local UPS_MODES = {
  cinematic = { density = 1.00, max_spawns = 1250, tile_splashes = true, post = 1.0 },
  balanced = { density = 0.82, max_spawns = 900, tile_splashes = true, post = 0.75 },
  saver = { density = 0.55, max_spawns = 450, tile_splashes = false, post = 0.45 }
}

local HARD_TILE_MATCHES = { "concrete", "stone-path", "foundation", "platform", "landfill" }
local SOFT_TILE_MATCHES = { "grass", "dirt", "sand", "red-desert", "dry-dirt", "nuclear-ground" }

local function preset()
  return PRESETS[storage.cfg.aaa_preset] or PRESETS.balanced
end

local function ups_mode()
  return UPS_MODES[storage.cfg.ups_mode] or UPS_MODES.balanced
end

local function ensure_cfg()
  storage.cfg = storage.cfg or {}
  local g = settings.global
  storage.cfg.enabled = g["real-rain-enabled"].value
  storage.cfg.aaa_preset = g["real-rain-aaa-preset"].value
  storage.cfg.intensity = g["real-rain-intensity"].value
  storage.cfg.wind_strength = g["real-rain-wind-strength"].value
  storage.cfg.ground_splashes_enabled = g["real-rain-ground-splashes-enabled"].value
  storage.cfg.tile_splashes_enabled = g["real-rain-tile-splashes-enabled"].value
  storage.cfg.biome_ambience_enabled = g["real-rain-biome-ambience-enabled"].value
  storage.cfg.wind_sound_enabled = g["real-rain-wind-sound-enabled"].value
  storage.cfg.ups_mode = g["real-rain-ups-mode"].value
  storage.cfg.nauvis_only = g["real-rain-nauvis-only"].value
  storage.cfg.min_thunder_chance = g["real-rain-min-thunder-chance"].value
  storage.cfg.max_thunder_chance = g["real-rain-max-thunder-chance"].value
  storage.cfg.thunder_sound_enabled = g["real-rain-thunder-sound-enabled"].value
  storage.cfg.rain_volume_modifier = g["real-rain-volume-modifier"].value
  storage.cfg.thunder_volume_modifier = g["real-rain-thunder-volume-modifier"].value
  storage.cfg.thunder_layering_enabled = g["real-rain-thunder-layering-enabled"].value
  storage.cfg.lightning_visual_enabled = g["real-rain-lightning-visual-enabled"].value
  storage.cfg.fire_extinguish_enabled = g["real-rain-fire-extinguish-enabled"].value
  storage.cfg.solar_power_multiplier = g["real-rain-solar-power-multiplier"].value
end

local function ensure_state()
  storage.real_rain_sound = storage.real_rain_sound or {}
  storage.real_rain_wind = storage.real_rain_wind or {}
  storage.real_rain_thunder_by_tick = storage.real_rain_thunder_by_tick or {}
  storage.real_rain_wind_sound_next = storage.real_rain_wind_sound_next or {}
  storage.real_rain_weather_mode = storage.real_rain_weather_mode or {}
  storage.real_rain_index = storage.real_rain_index or 0

  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      storage.real_rain_sound[surface.index] = storage.real_rain_sound[surface.index] or { primed = false, shift_ticks = 0 }
      storage.real_rain_wind[surface.index] = storage.real_rain_wind[surface.index] or { bucket = "straight", next_tick = 0 }
    end
  end
end

local function compute_spawn_chance(is_raining, time_left)
  if is_raining then
    if time_left <= RAIN_RAMP_TICKS then
      return time_left / RAIN_RAMP_TICKS
    end
    return 1
  end

  if time_left <= RAIN_RAMP_TICKS then
    return 1 - time_left / RAIN_RAMP_TICKS
  end
  return 0
end

local render_mode_game = defines.render_mode.game
local render_mode_chart_zoomed_in = defines.render_mode.chart_zoomed_in

local function calc_player_rect(player)
  if not (player and player.valid) then return nil end

  local player_render_mode = player.render_mode
  if player_render_mode ~= render_mode_game and player_render_mode ~= render_mode_chart_zoomed_in then
    return nil
  end

  local zoom = player.zoom or 1
  if zoom < 0.08 then return nil end

  local resolution = player.display_resolution
  if not resolution then return nil end

  local density = player.display_density_scale or 1
  local display_scale = player.display_scale or 1
  local display_width = resolution.width
  local display_height = resolution.height
  if display_height <= 0 then return nil end

  local aspect = display_width / display_height
  local half_h = display_height / (2 * display_scale * 32 * zoom * density) + (12 + 3 / zoom)
  local half_w = half_h * aspect

  local pos = player.position
  local y_shift = 10
  local x_add = 3

  return {
    min_x = pos.x - half_w,
    min_y = pos.y - half_h - y_shift,
    max_x = pos.x + half_w + x_add,
    max_y = pos.y + half_h - y_shift,
    w = half_w * 2 + x_add,
    h = half_h * 2,
    s = (half_w * 2 + x_add) * (half_h * 2)
  }
end

local function get_surface_players(surface)
  local players = {}
  for _, player in pairs(game.connected_players) do
    if player.surface_index == surface.index then
      players[#players + 1] = player
    end
  end
  return players
end

local function choose_wind_bucket(surface, is_raining)
  storage.real_rain_wind = storage.real_rain_wind or {}
  local st = storage.real_rain_wind[surface.index]
  if not st then
    st = { bucket = "straight", next_tick = 0 }
    storage.real_rain_wind[surface.index] = st
  end

  if game.tick < st.next_tick then
    return st.bucket
  end

  local strength = storage.cfg.wind_strength or 1
  st.next_tick = game.tick + random(100, 300)

  if strength <= 0.15 then
    st.bucket = "straight"
    return st.bucket
  end

  local r = random()
  local gust_chance = min(0.42, 0.08 * strength)
  if is_raining and r < gust_chance then
    st.bucket = "gust"
  elseif r < 0.34 then
    st.bucket = "left"
  elseif r < 0.70 then
    st.bucket = "straight"
  else
    st.bucket = "right"
  end

  return st.bucket
end

local function spawner_name(layer, frame, wind_bucket)
  if layer == "splash" then
    return "real-rain-spawner-splash-normal-" .. frame
  end
  if layer == "puddle" then
    return "real-rain-spawner-puddle-" .. frame
  end
  return "real-rain-spawner-" .. layer .. "-" .. frame .. "-" .. wind_bucket
end

local function splash_spawner_name(class, frame)
  if class == "hard" then return "real-rain-spawner-splash-hard-" .. frame end
  if class == "soft" then return "real-rain-spawner-splash-soft-" .. frame end
  if class == "water" then return "real-rain-spawner-splash-water-" .. frame end
  return "real-rain-spawner-splash-normal-" .. frame
end

local function spawn_fx(surface, name, pos)
  surface.create_entity{ name = name, position = pos }
end

local function choose_layer()
  local r = random()
  if r < 0.38 then
    return "front"
  elseif r < 0.82 then
    return "mid"
  end
  return "mist"
end

local function contains_any(name, patterns)
  for i = 1, #patterns do
    if string.find(name, patterns[i], 1, true) then return true end
  end
  return false
end

local function get_tile_name(surface, pos)
  local x = floor(pos.x)
  local y = floor(pos.y)
  local ok, tile = pcall(function() return surface.get_tile(x, y) end)
  if not ok or not tile then return nil end
  return tile.name or (tile.prototype and tile.prototype.name)
end

local function classify_tile(surface, pos)
  local mode = ups_mode()
  if not (storage.cfg.tile_splashes_enabled and mode.tile_splashes) then return "normal" end

  local name = get_tile_name(surface, pos)
  if not name then return "normal" end
  if string.find(name, "water", 1, true) then return "water" end
  if contains_any(name, HARD_TILE_MATCHES) then return "hard" end
  if contains_any(name, SOFT_TILE_MATCHES) then return "soft" end
  return "normal"
end

local function tile_splash_chance_multiplier(class)
  if class == "hard" then return 1.55 end
  if class == "water" then return 1.30 end
  if class == "soft" then return 0.62 end
  return 1.0
end

local function spawn_rain(base_intensity, surface, rects, total_s, wind_bucket)
  if total_s <= 0 then return end

  local rain_index = storage.real_rain_index or 0
  local mode = ups_mode()
  local demanded_spawns = base_intensity * total_s * SPAWN_COEFFICIENT * mode.density
  local reduction = 1
  if demanded_spawns > mode.max_spawns then
    reduction = mode.max_spawns / demanded_spawns
  end

  local final_k = base_intensity * SPAWN_COEFFICIENT * mode.density * reduction
  local rect_count = #rects
  local splash_chance = preset().splash * weather_model.splash_factor(surface)

  for i = 1, rect_count do
    local rect = rects[i]
    local spawn_count = rect.s * final_k
    if spawn_count < 1 then
      spawn_count = random() < spawn_count and 1 or 0
    else
      spawn_count = floor(spawn_count)
    end

    for _ = 1, spawn_count do
      local x = rect.min_x + random() * rect.w
      local y = rect.min_y + random() * rect.h
      local should_spawn = true

      if rect_count > 1 then
        local intersections = 1
        for j = 1, rect_count do
          if i ~= j then
            local other = rects[j]
            if x >= other.min_x and x < other.max_x and y >= other.min_y and y < other.max_y then
              intersections = intersections + 1
            end
          end
        end
        should_spawn = intersections == 1 or random() < 1 / intersections
      end

      if should_spawn then
        rain_index = rain_index + 1
        local frame = ((rain_index - 1) % 4) + 1
        local layer = choose_layer()
        spawn_fx(surface, spawner_name(layer, frame, wind_bucket), { x = x, y = y })

        if storage.cfg.ground_splashes_enabled then
          local splash_pos = { x = x + random() * 1.4 - 0.7, y = y + random() * 1.4 - 0.7 }
          local class = classify_tile(surface, splash_pos)
          if random() < splash_chance * tile_splash_chance_multiplier(class) then
            spawn_fx(surface, splash_spawner_name(class, frame), splash_pos)
          end
        end
      end
    end
  end

  storage.real_rain_index = rain_index
end

local function spawn_post_rain(surface, rects, total_s, factor)
  if total_s <= 0 or factor <= 0 then return end
  if not storage.cfg.ground_splashes_enabled then return end

  local mode = ups_mode()
  local rain_index = storage.real_rain_index or 0
  local final_k = 0.00036 * mode.post * factor * preset().splash
  local rect_count = #rects

  for i = 1, rect_count do
    local rect = rects[i]
    local spawn_count = rect.s * final_k
    if spawn_count < 1 then
      spawn_count = random() < spawn_count and 1 or 0
    else
      spawn_count = min(3, floor(spawn_count))
    end

    for _ = 1, spawn_count do
      rain_index = rain_index + 1
      local frame = ((rain_index - 1) % 4) + 1
      local x = rect.min_x + random() * rect.w
      local y = rect.min_y + random() * rect.h
      local pos = { x = x, y = y }
      local class = classify_tile(surface, pos)
      if class == "hard" or class == "normal" or random() < 0.38 then
        spawn_fx(surface, spawner_name("puddle", frame, "straight"), pos)
      end
    end
  end
  storage.real_rain_index = rain_index
end

local function count_type(surface, area, type_name)
  local ok, count = pcall(function()
    return surface.count_entities_filtered{ area = area, type = type_name }
  end)
  if ok then return count or 0 end
  return 0
end

local function water_near(surface, pos)
  for dx = -10, 10, 10 do
    for dy = -10, 10, 10 do
      local name = get_tile_name(surface, { x = pos.x + dx, y = pos.y + dy })
      if name and string.find(name, "water", 1, true) then return true end
    end
  end
  return false
end

local function detect_ambience_zone(player)
  if not storage.cfg.biome_ambience_enabled then return "open" end
  if not (player and player.valid) then return "open" end

  local surface = player.surface
  local pos = player.position
  if water_near(surface, pos) then return "water" end

  local area = {{pos.x - 22, pos.y - 22}, {pos.x + 22, pos.y + 22}}
  local tree_count = count_type(surface, area, "tree")
  if tree_count >= 10 then return "forest" end

  local factory_count =
    count_type(surface, area, "assembling-machine") +
    count_type(surface, area, "furnace") +
    count_type(surface, area, "mining-drill") +
    count_type(surface, area, "boiler") +
    count_type(surface, area, "generator") +
    count_type(surface, area, "lab") +
    count_type(surface, area, "reactor")
  if factory_count >= 6 then return "factory" end

  local tile_name = get_tile_name(surface, pos)
  if tile_name and contains_any(tile_name, HARD_TILE_MATCHES) then return "factory" end

  return "open"
end

local function rain_sound_path(player, surface)
  local stage = weather_model.stage(surface)
  local zone = player and detect_ambience_zone(player) or "open"
  if zone == "forest" then return "real-rain.sound.rain-forest" end
  if zone == "factory" then return "real-rain.sound.rain-factory" end
  if zone == "water" then return "real-rain.sound.rain-water" end
  if stage == "drizzle" then return "real-rain.sound.rain-light" end
  if stage == "heavy" or stage == "storm" or stage == "monsoon" then return "real-rain.sound.rain-heavy" end
  return "real-rain.sound.rain"
end

local function play_rain(surface, players)
  local p = preset()
  local volume = clamp_volume(storage.cfg.rain_volume_modifier * p.sound * weather_model.sound_factor(surface))
  if players and #players > 0 then
    for _, player in ipairs(players) do
      if player and player.valid then
        surface.play_sound{
          path = rain_sound_path(player, surface),
          position = player.position,
          volume_modifier = volume
        }
      end
    end
  else
    surface.play_sound{
      path = "real-rain.sound.rain",
      volume_modifier = volume
    }
  end
end

local function play_wind_gust(surface, players)
  if not storage.cfg.wind_sound_enabled then return end
  if not players or #players == 0 then return end
  storage.real_rain_wind_sound_next = storage.real_rain_wind_sound_next or {}

  for _, player in ipairs(players) do
    if player and player.valid then
      local key = player.index
      local next_tick = storage.real_rain_wind_sound_next[key] or 0
      if game.tick >= next_tick then
        surface.play_sound{
          path = "real-rain.sound.wind-gust",
          position = player.position,
          volume_modifier = clamp_volume(storage.cfg.rain_volume_modifier * 0.55)
        }
        storage.real_rain_wind_sound_next[key] = game.tick + random(900, 1800)
      end
    end
  end
end

local function play_post_rain(surface, players, factor)
  if not players or #players == 0 or factor <= 0 then return end
  if random() > 0.035 * factor then return end
  for _, player in ipairs(players) do
    if player and player.valid then
      surface.play_sound{
        path = "real-rain.sound.post-rain",
        position = player.position,
        volume_modifier = clamp_volume(storage.cfg.rain_volume_modifier * 0.32 * factor)
      }
    end
  end
end

local WEATHER_MODE_LABEL = {
  ["rain"] = "rain only",
  ["thunder-rain"] = "thunder + rain",
  ["thunderstorm"] = "thunderstorm"
}

local function clear_weather_mode(surface)
  if not (surface and surface.valid) then return end
  if storage.real_rain_weather_mode then
    storage.real_rain_weather_mode[surface.index] = nil
  end
end

local function set_weather_mode(surface, mode, duration_seconds)
  if not (surface and surface.valid) then return end
  storage.real_rain_weather_mode = storage.real_rain_weather_mode or {}
  storage.real_rain_weather_mode[surface.index] = {
    mode = mode,
    expires = game.tick + floor((duration_seconds or 240) * 60 + 0.5)
  }
end

local function get_weather_mode(surface)
  if not (surface and surface.valid) then return nil end
  local modes = storage.real_rain_weather_mode
  if not modes then return nil end
  local entry = modes[surface.index]
  if not entry then return nil end
  if entry.expires and game.tick > entry.expires then
    modes[surface.index] = nil
    return nil
  end
  return entry.mode
end

local THUNDER_SOUND = {
  far = { path = "real-rain.sound.thunder-far", volume = 0.92, count = 12 },
  close = { path = "real-rain.sound.thunder-close", volume = 1.00, count = 8 },
  roll = { path = "real-rain.sound.thunder-roll", volume = 0.82, count = 7 },
  monsoon = { path = "real-rain.sound.thunder-monsoon", volume = 1.00, count = 6 }
}

local THUNDER_UNIQUE_SOUND_COUNT = 25

local function thunder_kind_from_legacy(is_close)
  return is_close and "close" or "far"
end

local function play_thunder(surface, position, kind, boost)
  if not storage.cfg.thunder_sound_enabled then return end
  kind = kind or "far"
  local def = THUNDER_SOUND[kind] or THUNDER_SOUND.far
  surface.play_sound{
    path = def.path,
    position = position,
    volume_modifier = clamp_volume(storage.cfg.thunder_volume_modifier * def.volume * (boost or 1))
  }
end

local MIN_THUNDER_DELAY = 28
local MAX_THUNDER_DELAY = 190

local function schedule_thunder(surface, position, kind, delay)
  if not storage.cfg.thunder_sound_enabled then return end

  local tick = game.tick + (delay or random(MIN_THUNDER_DELAY, MAX_THUNDER_DELAY))
  storage.real_rain_thunder_by_tick = storage.real_rain_thunder_by_tick or {}
  local list = storage.real_rain_thunder_by_tick[tick]
  if not list then
    list = {}
    storage.real_rain_thunder_by_tick[tick] = list
  end

  list[#list + 1] = {
    surface_index = surface.index,
    position = position,
    kind = kind or "far"
  }
end

local function process_thunder(tick)
  local by_tick = storage.real_rain_thunder_by_tick
  if not by_tick then return end

  local list = by_tick[tick]
  if not list then return end
  by_tick[tick] = nil

  for i = 1, #list do
    local e = list[i]
    local surface = game.surfaces[e.surface_index]
    if surface and surface.valid then
      play_thunder(surface, e.position, e.kind or thunder_kind_from_legacy(e.is_close))
    end
  end
end

local function draw_lightning(surface, position, close, debug_visible)
  if not storage.cfg.lightning_visual_enabled then return end

  local scale = close and 72 or 48
  local intensity = close and 1.25 or 0.9
  local light_ttl = debug_visible and 36 or (close and 12 or 9)
  rendering.draw_light{
    sprite = "utility/light_medium",
    surface = surface,
    target = position,
    scale = scale,
    intensity = intensity,
    minimum_darkness = 0,
    color = { r = 0.58, g = 0.64, b = 1.0, a = 1 },
    render_mode = "game",
    time_to_live = light_ttl,
    blink_interval = floor(max(3, random() * 7))
  }

  if close then
    rendering.draw_light{
      sprite = "utility/light_medium",
      surface = surface,
      target = position,
      scale = 30,
      intensity = 1.6,
      minimum_darkness = 0,
      color = { r = 0.8, g = 0.9, b = 1.0, a = 1 },
      render_mode = "game",
      time_to_live = debug_visible and 18 or 5,
      blink_interval = 2
    }
  end
end

local function trigger_thunder(players, surface, darkness, thunder_amount, weather_mode)
  local count = #players
  if count == 0 or thunder_amount <= 0.01 then return end

  local sound_only = weather_mode == "thunder-rain"

  local p = preset()
  local t = 0.000034 * game.tick
  local wave = (
    sin(t * pi * 1.5123456 + 1) +
    sin(t * pi * 2.212321 + 1) +
    sin(t * pi * 4.15617 + 3)
  ) / 3

  local darkness_factor = min(1, 0.25 + darkness * 1.55)
  local chance = storage.cfg.min_thunder_chance +
    math.abs(storage.cfg.max_thunder_chance - storage.cfg.min_thunder_chance) *
    max(0, wave) * darkness_factor * thunder_amount * p.thunder / count

  for _, player in ipairs(players) do
    if random() < chance then
      local a = random() * 2 * pi
      local r = 18 + 55 * random()
      local dx = r * cos(a)
      local dy = r * sin(a)
      local strike_pos = { x = player.position.x + dx, y = player.position.y + dy }
      local light_pos = { x = strike_pos.x + dx * 2.8, y = strike_pos.y + dy * 2.8 }
      local close = r < 38 or random() < 0.18
      local roll = random()

      local stage = weather_model.stage(surface)
      local thunder_kind = close and "close" or "far"
      if close and stage == "monsoon" then thunder_kind = "monsoon" end

      -- Forced thunder-rain mode is sound-only: rain ambience plus thunder, no lightning flash.
      if sound_only then
        local thunder_delay = close and random(8, 42) or random(55, 180)
        schedule_thunder(surface, strike_pos, thunder_kind, thunder_delay)

        if storage.cfg.thunder_layering_enabled and close then
          schedule_thunder(surface, strike_pos, "roll", thunder_delay + random(90, 210))
        end
      elseif roll < 0.78 then
        -- Every visible lightning flash is linked to thunder.
        -- This keeps the original short blue-white light flash, without drawing a bolt sprite.
        local visual_close = close and roll < 0.55
        draw_lightning(surface, light_pos, visual_close)
        local thunder_delay = visual_close and random(10, 38) or random(70, 190)
        schedule_thunder(surface, strike_pos, thunder_kind, thunder_delay)

        if storage.cfg.thunder_layering_enabled and close then
          schedule_thunder(surface, strike_pos, "roll", thunder_delay + random(90, 210))
        end
        if storage.cfg.thunder_layering_enabled and stage == "monsoon" and random() < 0.35 then
          schedule_thunder(surface, strike_pos, "far", thunder_delay + random(150, 320))
        end
      else
        schedule_thunder(surface, strike_pos, thunder_kind)
        if storage.cfg.thunder_layering_enabled and close then
          schedule_thunder(surface, strike_pos, "roll", random(90, 210))
        end
        if storage.cfg.thunder_layering_enabled and stage == "monsoon" and random() < 0.35 then
          schedule_thunder(surface, strike_pos, "far", random(150, 320))
        end
      end
    end
  end
end

local function build_rects(players)
  local rects = {}
  local total_s = 0
  for _, player in ipairs(players) do
    local rect = calc_player_rect(player)
    if rect then
      rects[#rects + 1] = rect
      total_s = total_s + rect.s
    end
  end
  return rects, total_s
end

function M.on_init()
  ensure_cfg()
  weather_model.on_init()
  ensure_state()
  rain_fire.on_init()
  pollution.on_init()
  solar.on_init()
end

function M.on_configuration_changed()
  ensure_cfg()
  weather_model.on_configuration_changed()
  ensure_state()
  rain_fire.on_configuration_changed()
  pollution.on_configuration_changed()
  solar.on_configuration_changed()
end

function M.on_runtime_mod_setting_changed(event)
  M.on_configuration_changed()
end

function M.on_surface_deleted(event)
  local idx = event.surface_index
  if storage.real_rain_sound then storage.real_rain_sound[idx] = nil end
  if storage.real_rain_wind then storage.real_rain_wind[idx] = nil end
  if storage.real_rain_weather_mode then storage.real_rain_weather_mode[idx] = nil end
  if storage.weather then storage.weather[idx] = nil end
  pollution.on_surface_deleted(idx)
  rain_fire.on_surface_deleted(idx)
  solar.on_surface_deleted(idx)
end

function M.on_chunk_generated(event)
  pollution.on_chunk_generated(event)
end

function M.on_trigger_created_entity(event)
  local e = event.entity
  if not (e and e.valid) then return end
  if e.name ~= "real-rain-fire-marker" then return end

  if storage.cfg.enabled and storage.cfg.fire_extinguish_enabled then
    rain_fire.on_fire_created(event)
  end
  e.destroy()
end

function M.on_tick(event)
  ensure_state()
  process_thunder(event.tick)

  local cfg = storage.cfg
  if not cfg.enabled then return end

  weather_model.on_tick()

  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      local players = get_surface_players(surface)
      local is_raining = weather_model.is_raining(surface)
      local forced_weather_mode = get_weather_mode(surface)
      if not is_raining and forced_weather_mode then
        clear_weather_mode(surface)
        forced_weather_mode = nil
      end
      local time_left = weather_model.time_left(surface)
      local stage_factor = weather_model.storm_factor(surface)
      local thunder_factor = weather_model.thunder_factor(surface)
      local post_rain_factor = weather_model.post_rain_factor(surface)
      local st = storage.real_rain_sound[surface.index]

      solar.sync_surface(surface, is_raining)
      pollution.on_tick(surface, is_raining)

      if cfg.fire_extinguish_enabled then
        rain_fire.on_tick(surface, is_raining)
      end

      if not is_raining then
        -- Do not play the rain loop during dry weather or the pre-rain ramp.
        -- Earlier versions primed the rain ambience before visible rain started,
        -- which could make players hear rain while the world still looked clear.
        if time_left < RAIN_RAMP_TICKS then
          if not st.primed then
            st.shift_ticks = event.tick % 900
            st.primed = true
          end
        else
          st.primed = false
        end
      end

      if is_raining then
        local base_intensity = cfg.intensity * preset().intensity * stage_factor
        local rain_sound_interval = floor(max(150, min(900, 900 / max(0.3, base_intensity))))

        if time_left > RAIN_SOUND_DURATION_TICKS / 2 then
          if ((event.tick - st.shift_ticks) % rain_sound_interval == 0) then
            play_rain(surface, players)
          end
        else
          st.primed = false
        end

        if time_left > 900 then
          if forced_weather_mode ~= "rain" then
            trigger_thunder(players, surface, surface.darkness, thunder_factor, forced_weather_mode)
          end
        end
      elseif time_left < 10000 then
        if forced_weather_mode ~= "rain" then
          trigger_thunder(players, surface, surface.darkness, 0.18, forced_weather_mode)
        end
      end

      if is_raining or time_left < RAIN_RAMP_TICKS or post_rain_factor > 0 then
        local rects, total_s = build_rects(players)
        if total_s > 0 then
          if is_raining or time_left < RAIN_RAMP_TICKS then
            local spawn_factor = compute_spawn_chance(is_raining, time_left)
            local base_intensity = cfg.intensity * preset().intensity * stage_factor * spawn_factor
            local wind_bucket = choose_wind_bucket(surface, is_raining)
            spawn_rain(base_intensity, surface, rects, total_s, wind_bucket)
            if wind_bucket == "gust" and random() < 0.02 then
              play_wind_gust(surface, players)
            end
          else
            spawn_post_rain(surface, rects, total_s, post_rain_factor)
            -- Keep the subtle post-rain visuals, but do not use the rain loop as a drip sound.
            -- This prevents phantom rain audio after the storm has ended.
          end
        end
      end
    end
  end
end

function M.is_raining(surface)
  return storage.cfg and storage.cfg.enabled and weather_model.is_raining(surface) or false
end

function M.stage(surface)
  if not (storage.cfg and storage.cfg.enabled) then return "clear" end
  return weather_model.stage(surface)
end

function M.time_left(surface)
  if not (storage.cfg and storage.cfg.enabled) then return 0 end
  return weather_model.time_left(surface)
end

function M.describe(surface)
  if not (storage.cfg and storage.cfg.enabled) then return "Real Rain is disabled" end
  local description = weather_model.describe(surface)
  local mode = get_weather_mode(surface)
  if mode then
    return description .. " (forced " .. (WEATHER_MODE_LABEL[mode] or mode) .. ")"
  end
  return description
end

function M.force_stage(surface, stage, duration_seconds)
  if not (storage.cfg and storage.cfg.enabled) then return false end
  clear_weather_mode(surface)
  return weather_model.force_stage(surface, stage, duration_seconds)
end

function M.force_weather_combo(surface, mode, duration_seconds)
  if not (storage.cfg and storage.cfg.enabled and surface and surface.valid) then return false end
  local stage = "storm"
  if mode == "rain" then
    stage = "rain"
  elseif mode == "thunder-rain" then
    stage = "heavy"
  elseif mode == "thunderstorm" then
    stage = "storm"
  else
    return false
  end

  local seconds = duration_seconds or 240
  local ok = weather_model.force_stage(surface, stage, seconds)
  if ok then
    set_weather_mode(surface, mode, seconds)
  end
  return ok
end

local VALID_FORCED_THUNDER = {
  far = true,
  close = true,
  roll = true,
  monsoon = true
}

function M.force_thunder(surface, position, kind)
  if not (storage.cfg and storage.cfg.enabled and surface and surface.valid) then return false end
  position = position or { x = 0, y = 0 }
  kind = VALID_FORCED_THUNDER[kind] and kind or "close"
  play_thunder(surface, position, kind, 1.18)
  if storage.cfg.thunder_layering_enabled and (kind == "close" or kind == "monsoon") then
    schedule_thunder(surface, position, "roll", 95)
  end
  return true
end

function M.force_lightning(surface, position, close)
  if not (storage.cfg and storage.cfg.enabled and surface and surface.valid) then return false end
  position = position or { x = 0, y = 0 }
  local is_close = close ~= false
  local kind = is_close and "close" or "far"
  draw_lightning(surface, position, is_close, true)
  play_thunder(surface, position, kind, 1.12)
  if storage.cfg.thunder_layering_enabled and is_close then
    schedule_thunder(surface, position, "roll", 95)
  end
  return true
end

function M.force_strike(surface, position, kind)
  if not (storage.cfg and storage.cfg.enabled and surface and surface.valid) then return false end
  position = position or { x = 0, y = 0 }
  kind = VALID_FORCED_THUNDER[kind] and kind or "close"
  local close_visual = kind ~= "far" and kind ~= "roll"
  draw_lightning(surface, position, close_visual, true)
  play_thunder(surface, position, kind == "roll" and "close" or kind, 1.18)
  if storage.cfg.thunder_layering_enabled and kind ~= "far" then
    schedule_thunder(surface, position, "roll", 95)
  end
  return true
end

function M.force_thunder_test(surface, position)
  if not (storage.cfg and storage.cfg.enabled and surface and surface.valid) then return false end
  position = position or { x = 0, y = 0 }
  play_thunder(surface, position, "far", 1.1)
  schedule_thunder(surface, position, "close", 120)
  schedule_thunder(surface, position, "roll", 240)
  schedule_thunder(surface, position, "monsoon", 360)
  return true
end

function M.thunder_sound_summary()
  return {
    unique = THUNDER_UNIQUE_SOUND_COUNT,
    far = THUNDER_SOUND.far.count,
    close = THUNDER_SOUND.close.count,
    roll = THUNDER_SOUND.roll.count,
    monsoon = THUNDER_SOUND.monsoon.count
  }
end

function M.force_clear(surface, duration_seconds)
  if not (storage.cfg and storage.cfg.enabled) then return false end
  clear_weather_mode(surface)
  return weather_model.force_clear(surface, duration_seconds)
end

return M
