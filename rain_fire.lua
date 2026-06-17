local M = {}

local weather_model = require("weather_model")
local random = math.random
local min = math.min

local TTL_MIN, TTL_MAX = 45, 145
local MIN_SMOKE_GAP, MAX_SMOKE_GAP = 1, 70
local PRE_EXTINGUISH_TICKS = 2

local HISS_SMOKE_NAME = "smoke"
local HISS_SOUND_PATH = "real-rain.sound.hiss"
local HISS_VOLUME = 0.42
local SOUND_WINDOW_TICKS = 5
local SOUND_WINDOW_LIMIT = 1
local SMOKE_BURST_COUNT = 16
local SMOKE_BURST_OFFSET = 0.85

local function ensure_state()
  storage.real_rain_fire_by_tick = storage.real_rain_fire_by_tick or {}
  storage.real_rain_fire_sound_quota = storage.real_rain_fire_sound_quota or {}
  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      storage.real_rain_fire_sound_quota[surface.index] = storage.real_rain_fire_sound_quota[surface.index] or { window_start = game.tick, used = 0 }
    end
  end
end

local function rain_or_near(surface)
  return weather_model.is_raining(surface) or weather_model.time_left(surface) < 3600
end

local function hiss_fx(surface, position)
  for _ = 1, SMOKE_BURST_COUNT do
    local dx = (random() * 2 - 1) * SMOKE_BURST_OFFSET
    local dy = (random() * 2 - 1) * SMOKE_BURST_OFFSET
    surface.create_trivial_smoke{
      name = HISS_SMOKE_NAME,
      position = { x = position.x + dx, y = position.y + dy }
    }
  end
end

local function maybe_play_hiss(surface, position, quota)
  local tick = game.tick
  if tick - quota.window_start >= SOUND_WINDOW_TICKS then
    quota.window_start = tick
    quota.used = 0
  end

  if quota.used >= SOUND_WINDOW_LIMIT then return end
  surface.play_sound{ path = HISS_SOUND_PATH, position = position, volume_modifier = HISS_VOLUME }
  quota.used = quota.used + 1
end

local function schedule_fire(fire, ttl, next_smoke_tick)
  local by_tick = storage.real_rain_fire_by_tick
  if not by_tick then return end

  local schedule_tick = min(ttl, next_smoke_tick)
  local list = by_tick[schedule_tick]
  if not list then
    list = {}
    by_tick[schedule_tick] = list
  end
  list[#list + 1] = fire
end

local function process_tick(tick, surface, quota, is_raining)
  local by_tick = storage.real_rain_fire_by_tick
  if not by_tick then return end

  local list = by_tick[tick]
  if not list then return end
  by_tick[tick] = nil

  local near = rain_or_near(surface)
  for i = 1, #list do
    local fire = list[i]
    local ent = fire.ent
    local delta_ttl = fire.ttl - tick

    if ent and ent.valid then
      if is_raining then
        if delta_ttl <= 0 then
          ent.destroy{ raise_destroy = true }
        elseif delta_ttl == PRE_EXTINGUISH_TICKS then
          local pos = ent.position
          hiss_fx(surface, pos)
          maybe_play_hiss(surface, pos, quota)
          schedule_fire(fire, fire.ttl, math.huge)
        elseif fire.next_smoke_tick - tick <= 0 then
          local pos = ent.position
          surface.create_trivial_smoke{ name = HISS_SMOKE_NAME, position = pos }
          maybe_play_hiss(surface, pos, quota)
          fire.next_smoke_tick = tick + random(MIN_SMOKE_GAP, MAX_SMOKE_GAP)
          schedule_fire(fire, fire.ttl - PRE_EXTINGUISH_TICKS, fire.next_smoke_tick)
        end
      elseif near then
        fire.ttl = tick + random(TTL_MIN, TTL_MAX)
        fire.next_smoke_tick = tick + random(MIN_SMOKE_GAP, MAX_SMOKE_GAP)
        schedule_fire(fire, fire.ttl - PRE_EXTINGUISH_TICKS, fire.next_smoke_tick)
      end
    end
  end
end

function M.on_init()
  ensure_state()
end

function M.on_configuration_changed()
  ensure_state()
end

function M.on_surface_deleted(surface_index)
  if storage.real_rain_fire_sound_quota then
    storage.real_rain_fire_sound_quota[surface_index] = nil
  end
end

function M.on_fire_created(event)
  local e = event.source or event.entity
  if not (e and e.valid) then return end
  if not weather_model.is_weather_surface(e.surface) then return end
  if not rain_or_near(e.surface) then return end

  storage.real_rain_fire_by_tick = storage.real_rain_fire_by_tick or {}

  local tick = game.tick
  local fire = {
    ent = e,
    ttl = tick + random(TTL_MIN, TTL_MAX),
    next_smoke_tick = tick + random(MIN_SMOKE_GAP, MAX_SMOKE_GAP)
  }
  schedule_fire(fire, fire.ttl - PRE_EXTINGUISH_TICKS, fire.next_smoke_tick)
end

function M.on_tick(surface, is_raining)
  ensure_state()
  local quota = storage.real_rain_fire_sound_quota[surface.index]
  if not quota then
    quota = { window_start = game.tick, used = 0 }
    storage.real_rain_fire_sound_quota[surface.index] = quota
  end
  process_tick(game.tick, surface, quota, is_raining)
end

return M
