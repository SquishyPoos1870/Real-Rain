local M = {}

-- Kept from the original timing model so existing worlds keep roughly the same cadence.
local TICKS_PER_HOUR = 1050
local random = math.random
local floor = math.floor

local STAGE_DATA = {
  drizzle = { visual = 0.38, thunder = 0.02, splash = 0.35, sound = 0.55, post = 0.15 },
  rain    = { visual = 0.82, thunder = 0.18, splash = 0.70, sound = 0.78, post = 0.35 },
  heavy   = { visual = 1.28, thunder = 0.55, splash = 1.05, sound = 1.00, post = 0.55 },
  storm   = { visual = 1.72, thunder = 1.18, splash = 1.40, sound = 1.10, post = 0.75 },
  monsoon = { visual = 2.25, thunder = 1.75, splash = 1.80, sound = 1.18, post = 1.00 }
}

local VALID_STAGE = {
  drizzle = true,
  rain = true,
  heavy = true,
  storm = true,
  monsoon = true
}

local SEQUENCES = {
  light = {
    { at = 0.00, stage = "drizzle" },
    { at = 0.22, stage = "rain" },
    { at = 0.74, stage = "drizzle" }
  },
  normal = {
    { at = 0.00, stage = "drizzle" },
    { at = 0.15, stage = "rain" },
    { at = 0.48, stage = "heavy" },
    { at = 0.72, stage = "rain" },
    { at = 0.90, stage = "drizzle" }
  },
  storm = {
    { at = 0.00, stage = "drizzle" },
    { at = 0.10, stage = "rain" },
    { at = 0.30, stage = "heavy" },
    { at = 0.52, stage = "storm" },
    { at = 0.70, stage = "heavy" },
    { at = 0.86, stage = "rain" },
    { at = 0.95, stage = "drizzle" }
  },
  monsoon = {
    { at = 0.00, stage = "drizzle" },
    { at = 0.08, stage = "rain" },
    { at = 0.20, stage = "heavy" },
    { at = 0.38, stage = "storm" },
    { at = 0.56, stage = "monsoon" },
    { at = 0.68, stage = "storm" },
    { at = 0.80, stage = "heavy" },
    { at = 0.90, stage = "rain" },
    { at = 0.97, stage = "drizzle" }
  }
}

local function cfg()
  storage.cfg = storage.cfg or {}
  return storage.cfg
end

local function is_weather_surface(surface)
  if not (surface and surface.valid) then return false end
  local c = cfg()
  if c.nauvis_only ~= false then
    return surface.name == "nauvis"
  end
  return true
end

local function load_cfg()
  storage.cfg = storage.cfg or {}
  local g = settings.global
  local wet_min = g["real-rain-wet-min-hours"].value
  local wet_max = g["real-rain-wet-max-hours"].value
  if wet_max < wet_min then wet_max, wet_min = wet_min, wet_max end

  storage.cfg.wet_min = wet_min
  storage.cfg.wet_max = wet_max
  storage.cfg.wet_power = g["real-rain-wet-power"].value
  storage.cfg.dry_mean = g["real-rain-dry-mean-hours"].value
  storage.cfg.storm_stage_enabled = g["real-rain-storm-stages-enabled"].value
  storage.cfg.monsoon_chance = g["real-rain-monsoon-chance"].value
  storage.cfg.post_rain_enabled = g["real-rain-post-rain-enabled"].value
  storage.cfg.post_rain_min_seconds = g["real-rain-post-rain-min-seconds"].value
  storage.cfg.post_rain_max_seconds = g["real-rain-post-rain-max-seconds"].value
end

local function hours_to_ticks(hours)
  return floor(hours * TICKS_PER_HOUR + 0.5)
end

local function seconds_to_ticks(seconds)
  return floor(seconds * 60 + 0.5)
end

local function u01()
  local u = random()
  if u <= 0.0 then u = 1e-12 end
  if u >= 1.0 then u = 1.0 - 1e-12 end
  return u
end

local function sample_wet_hours()
  local c = cfg()
  local u = u01()
  local shaped = u ^ c.wet_power
  return c.wet_min + (c.wet_max - c.wet_min) * shaped
end

local function sample_dry_hours()
  local c = cfg()
  local u = u01()
  return -c.dry_mean * math.log(1.0 - u)
end

local function sample_post_rain_ticks()
  local c = cfg()
  if not c.post_rain_enabled then return 0 end

  local min_seconds = c.post_rain_min_seconds or 35
  local max_seconds = c.post_rain_max_seconds or 120
  if max_seconds < min_seconds then max_seconds, min_seconds = min_seconds, max_seconds end
  return seconds_to_ticks(min_seconds + (max_seconds - min_seconds) * random())
end

local function choose_sequence_key()
  local c = cfg()
  if not c.storm_stage_enabled then return "normal", 0.55 end

  local r = random()
  local monsoon_chance = math.max(0, math.min(1, c.monsoon_chance or 0.08))
  if r < monsoon_chance then
    return "monsoon", 1.0
  elseif r < monsoon_chance + 0.32 then
    return "storm", 0.75 + random() * 0.25
  elseif r < monsoon_chance + 0.74 then
    return "normal", 0.45 + random() * 0.35
  end
  return "light", 0.20 + random() * 0.35
end

local function stage_from_progress(sequence_key, progress)
  local seq = SEQUENCES[sequence_key] or SEQUENCES.normal
  local stage = seq[1].stage
  for i = 1, #seq do
    if progress >= seq[i].at then
      stage = seq[i].stage
    else
      break
    end
  end
  return stage
end

local function new_dry_state()
  return {
    phase = "dry",
    tLeft = hours_to_ticks(math.max(0.5, sample_dry_hours())),
    total = 0,
    stage = "clear",
    sequence = "normal",
    severity = 0,
    storm = 0.85,
    post_left = 0,
    post_total = 0,
    wind = 0,
    next_wind_tick = 0
  }
end

local function start_wet(st)
  local sequence, severity = choose_sequence_key()
  local total = hours_to_ticks(sample_wet_hours())
  st.phase = "wet"
  st.tLeft = total
  st.total = total
  st.sequence = sequence
  st.severity = severity
  st.storm = 0.75 + severity * 0.75
  st.stage = "drizzle"
  st.forced_stage = nil
  st.post_left = 0
  st.post_total = 0
  st.next_wind_tick = 0
end

local function start_dry(st)
  st.phase = "dry"
  st.tLeft = hours_to_ticks(math.max(0.5, sample_dry_hours()))
  st.total = st.tLeft
  st.stage = "clear"
  st.forced_stage = nil
  st.sequence = "normal"
  st.severity = 0
  st.storm = 0.75 + random() * 0.4
  st.post_total = sample_post_rain_ticks()
  st.post_left = st.post_total
  st.next_wind_tick = 0
end

local function update_stage(st)
  if st.phase ~= "wet" then return end
  if st.forced_stage then
    st.stage = st.forced_stage
    return
  end
  local total = math.max(1, st.total or st.tLeft or 1)
  local progress = 1 - math.max(0, st.tLeft or 0) / total
  st.stage = stage_from_progress(st.sequence or "normal", progress)
end

local function ensure_state()
  storage.weather = storage.weather or {}
  for _, surface in pairs(game.surfaces) do
    if is_weather_surface(surface) then
      local st = storage.weather[surface.index]
      if not st then
        storage.weather[surface.index] = new_dry_state()
      else
        st.stage = st.stage or (st.phase == "wet" and "rain" or "clear")
        st.sequence = st.sequence or "normal"
        st.total = st.total or st.tLeft or 0
        st.severity = st.severity or 0.5
        st.post_left = st.post_left or 0
        st.post_total = st.post_total or 0
        if st.phase ~= "wet" then st.forced_stage = nil end
      end
    end
  end
end

function M.on_init()
  load_cfg()
  ensure_state()
end

function M.on_configuration_changed()
  load_cfg()
  ensure_state()
end

function M.on_tick()
  ensure_state()
  local weather = storage.weather
  if not weather then return end

  for _, surface in pairs(game.surfaces) do
    if is_weather_surface(surface) then
      local st = weather[surface.index]
      if st then
        if st.phase == "dry" and (st.post_left or 0) > 0 then
          st.post_left = st.post_left - 1
        end

        st.tLeft = st.tLeft - 1
        if st.tLeft <= 0 then
          if st.phase == "dry" then
            start_wet(st)
          else
            start_dry(st)
          end
        end

        update_stage(st)
      end
    end
  end
end

function M.is_weather_surface(surface)
  return is_weather_surface(surface)
end

function M.is_raining(surface)
  local st = storage.weather and storage.weather[surface.index]
  return st and st.phase == "wet"
end

function M.time_left(surface)
  local st = storage.weather and storage.weather[surface.index]
  return st and st.tLeft or 0
end

function M.stage(surface)
  local st = storage.weather and storage.weather[surface.index]
  if not st then return "clear" end
  if st.phase ~= "wet" then return "clear" end
  return st.stage or "rain"
end

function M.stage_data(surface)
  local stage = M.stage(surface)
  return STAGE_DATA[stage] or STAGE_DATA.rain
end

function M.storm_factor(surface)
  local st = storage.weather and storage.weather[surface.index]
  local data = M.stage_data(surface)
  if not st then return 1 end
  return (st.storm or 1) * data.visual
end

function M.thunder_factor(surface)
  local st = storage.weather and storage.weather[surface.index]
  local data = M.stage_data(surface)
  local severity = st and st.severity or 0.5
  return data.thunder * (0.75 + severity * 0.5)
end

function M.splash_factor(surface)
  local data = M.stage_data(surface)
  return data.splash
end

function M.sound_factor(surface)
  local data = M.stage_data(surface)
  return data.sound
end

function M.post_rain_factor(surface)
  local st = storage.weather and storage.weather[surface.index]
  if not st or st.phase ~= "dry" then return 0 end
  local left = st.post_left or 0
  local total = st.post_total or 0
  if left <= 0 or total <= 0 then return 0 end
  return math.max(0, math.min(1, left / total))
end

function M.force_stage(surface, stage, duration_seconds)
  if not (surface and surface.valid and is_weather_surface(surface)) then return false end
  if not VALID_STAGE[stage] then return false end
  storage.weather = storage.weather or {}
  local st = storage.weather[surface.index] or new_dry_state()
  local total = seconds_to_ticks(duration_seconds or 240)
  st.phase = "wet"
  st.tLeft = total
  st.total = total
  st.stage = stage
  st.forced_stage = stage
  st.sequence = stage == "monsoon" and "monsoon" or (stage == "storm" and "storm" or "normal")
  st.severity = stage == "monsoon" and 1 or (stage == "storm" and 0.85 or 0.55)
  st.storm = 1.0 + st.severity * 0.5
  st.post_left = 0
  st.post_total = 0
  storage.weather[surface.index] = st
  return true
end

function M.force_clear(surface, duration_seconds)
  if not (surface and surface.valid and is_weather_surface(surface)) then return false end
  storage.weather = storage.weather or {}
  local st = storage.weather[surface.index] or new_dry_state()
  local total = seconds_to_ticks(duration_seconds or 300)
  st.phase = "dry"
  st.tLeft = total
  st.total = total
  st.stage = "clear"
  st.forced_stage = nil
  st.sequence = "normal"
  st.severity = 0
  st.storm = 0.85
  st.post_left = 0
  st.post_total = 0
  storage.weather[surface.index] = st
  return true
end

function M.describe(surface)
  local st = storage.weather and storage.weather[surface.index]
  if not st then return "no weather state" end
  if st.phase == "wet" then
    return string.format("%s, %d seconds left", st.stage or "rain", math.floor((st.tLeft or 0) / 60))
  end
  local post = M.post_rain_factor(surface)
  if post > 0 then
    return string.format("clear, post-rain %.0f%%, next rain in %d seconds", post * 100, math.floor((st.tLeft or 0) / 60))
  end
  return string.format("clear, next rain in %d seconds", math.floor((st.tLeft or 0) / 60))
end

return M
