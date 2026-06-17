local M = {}

local events = require("events")
local weather_model = require("weather_model")
local random = math.random
local floor = math.floor

local CLEANUP_INTERVAL_TICKS = 60 * 60

local function ensure_cfg()
  storage.cfg = storage.cfg or {}
  local g = settings.global
  storage.cfg.pollution_cleanup_per_minute = g["real-rain-pollution-cleanup-per-minute"].value
  storage.cfg.pollution_max_chunks_per_tick = g["real-rain-pollution-max-chunks-per-tick"].value
end

local function add_chunk(st, chunk)
  local chunks = st.chunks
  local n = #chunks + 1
  chunks[n] = { x = chunk.x, y = chunk.y }

  if st.cursor > n then
    st.cursor = 1
  end

  local insert_index = random(st.cursor, n)
  chunks[n], chunks[insert_index] = chunks[insert_index], chunks[n]
end

local function build_chunks(surface)
  local st = { chunks = {}, cursor = 1, chunk_quota = 0 }
  for chunk in surface.get_chunks() do
    add_chunk(st, chunk)
  end
  return st
end

local function reset_surface(surface)
  storage.real_rain_pollution = storage.real_rain_pollution or {}
  if weather_model.is_weather_surface(surface) then
    storage.real_rain_pollution[surface.index] = build_chunks(surface)
  end
end

local function ensure_surface(surface)
  storage.real_rain_pollution = storage.real_rain_pollution or {}
  local st = storage.real_rain_pollution[surface.index]
  if not st then
    reset_surface(surface)
    st = storage.real_rain_pollution[surface.index]
  end
  return st
end

local function take_next_chunk(st)
  local chunks = st.chunks
  local count = #chunks
  if count == 0 then return nil end

  if st.cursor > count then
    st.cursor = 1
  end

  local random_index = random(st.cursor, count)
  chunks[st.cursor], chunks[random_index] = chunks[random_index], chunks[st.cursor]

  local chunk = chunks[st.cursor]
  st.cursor = st.cursor + 1
  return chunk
end

function M.on_init()
  ensure_cfg()
  storage.real_rain_pollution = {}
  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      reset_surface(surface)
    end
  end
end

function M.on_configuration_changed()
  ensure_cfg()
  storage.real_rain_pollution = storage.real_rain_pollution or {}
  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      reset_surface(surface)
    end
  end
end

function M.on_chunk_generated(event)
  local surface = event.surface
  if not weather_model.is_weather_surface(surface) then return end
  local st = ensure_surface(surface)
  if not st then return end
  add_chunk(st, event.position)
end

function M.on_surface_deleted(surface_index)
  if storage.real_rain_pollution then
    storage.real_rain_pollution[surface_index] = nil
  end
end

function M.on_tick(surface, is_raining)
  if not is_raining then return end

  local cleanup_per_minute = storage.cfg.pollution_cleanup_per_minute
  if cleanup_per_minute == 0 then return end

  local st = ensure_surface(surface)
  if not st then return end

  local chunk_count = #st.chunks
  if chunk_count == 0 then return end

  st.chunk_quota = st.chunk_quota + chunk_count / CLEANUP_INTERVAL_TICKS
  if st.chunk_quota < 1 then return end

  local desired_chunks = floor(st.chunk_quota)
  local chunks_to_process = math.min(desired_chunks, storage.cfg.pollution_max_chunks_per_tick)
  st.chunk_quota = st.chunk_quota - desired_chunks

  local cleanup_per_chunk = cleanup_per_minute * desired_chunks / chunks_to_process
  local cleaned_chunks = nil

  for _ = 1, chunks_to_process do
    local chunk = take_next_chunk(st)
    if not chunk then return end

    local pos = { x = chunk.x * 32 + 16, y = chunk.y * 32 + 16 }
    local current = surface.get_pollution(pos)
    if current > 0 then
      local removed = math.min(current, cleanup_per_chunk)
      if removed > 0 then
        surface.pollute(pos, -removed, "real-rain-pollution-cleaner")
        cleaned_chunks = cleaned_chunks or {}
        cleaned_chunks[#cleaned_chunks + 1] = {
          chunk_position = { x = chunk.x, y = chunk.y },
          pollution_before = current,
          pollution_removed = removed,
          pollution_after = current - removed
        }
      end
    end
  end

  if cleaned_chunks then
    script.raise_event(events.on_rain_pollution_cleaned, {
      surface_index = surface.index,
      chunks = cleaned_chunks
    })
  end
end

return M
