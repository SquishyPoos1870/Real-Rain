local M = {}

local weather_model = require("weather_model")
local SOLAR_PROPERTY = "solar-power"
local DEFAULT_SOLAR_POWER = 100

local function ensure_state()
  storage.real_rain_solar = storage.real_rain_solar or {}
  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      storage.real_rain_solar[surface.index] = storage.real_rain_solar[surface.index] or { active = false }
    end
  end
end

local function reset_surface(surface)
  if not (surface and surface.valid) then return end
  local st = storage.real_rain_solar and storage.real_rain_solar[surface.index]
  if st and st.active then
    surface.set_property(SOLAR_PROPERTY, DEFAULT_SOLAR_POWER)
    st.active = false
  end
end

function M.on_init()
  ensure_state()
end

function M.on_configuration_changed()
  ensure_state()
  for _, surface in pairs(game.surfaces) do
    if weather_model.is_weather_surface(surface) then
      reset_surface(surface)
    end
  end
end

function M.on_surface_deleted(surface_index)
  if storage.real_rain_solar then
    storage.real_rain_solar[surface_index] = nil
  end
end

function M.sync_surface(surface, is_raining)
  if not weather_model.is_weather_surface(surface) then return end

  storage.real_rain_solar = storage.real_rain_solar or {}
  storage.real_rain_solar[surface.index] = storage.real_rain_solar[surface.index] or { active = false }

  local st = storage.real_rain_solar[surface.index]
  local multiplier = storage.cfg.solar_power_multiplier
  if multiplier < 0 then
    if st.active then reset_surface(surface) end
    return
  end

  local should_apply = is_raining
  if st.active == should_apply then return end

  if should_apply then
    surface.set_property(SOLAR_PROPERTY, multiplier)
    st.active = true
  else
    surface.set_property(SOLAR_PROPERTY, DEFAULT_SOLAR_POWER)
    st.active = false
  end
end

return M
