local MOD = "__real-rain__"

local empty_animation = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
  frame_count = 1,
  line_length = 1,
  animation_speed = 1
}

local function quad_sprite(name, filename, frame)
  return {
    type = "sprite",
    name = name,
    filename = filename,
    width = 256,
    height = 256,
    x = (frame % 2) * 256,
    y = math.floor(frame / 2) * 256,
    flags = {"gui-icon"}
  }
end

data:extend({
  {
    type = "sprite",
    name = "real-rain-overlay",
    filename = MOD .. "/graphics/entity/rain/rain-streaks.png",
    width = 512,
    height = 512,
    flags = {"gui-icon"}
  },
  {
    type = "sprite",
    name = "real-rain-black-pixel",
    filename = MOD .. "/graphics/black_pixel.png",
    width = 1,
    height = 1,
    flags = {"gui-icon"}
  },
  quad_sprite("real-rain-overlay-1", MOD .. "/graphics/entity/rain/rain-streaks.png", 0),
  quad_sprite("real-rain-overlay-2", MOD .. "/graphics/entity/rain/rain-streaks.png", 1),
  quad_sprite("real-rain-overlay-3", MOD .. "/graphics/entity/rain/rain-streaks.png", 2),
  quad_sprite("real-rain-overlay-4", MOD .. "/graphics/entity/rain/rain-streaks.png", 3)
})

local rain_sound = MOD .. "/sound/heavy-rain.ogg"

local function variations(paths, volume)
  local result = {}
  for _, p in ipairs(paths) do
    result[#result + 1] = { filename = MOD .. p, volume = volume }
  end
  return result
end

data:extend({
  {
    type = "sound",
    name = "real-rain.sound.rain",
    variations = {
      { filename = rain_sound, volume = 0.55 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.rain-light",
    variations = {
      { filename = rain_sound, volume = 0.34 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.rain-heavy",
    variations = {
      { filename = rain_sound, volume = 0.68 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.rain-forest",
    variations = {
      { filename = rain_sound, volume = 0.48 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.rain-factory",
    variations = {
      { filename = rain_sound, volume = 0.60 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.rain-water",
    variations = {
      { filename = rain_sound, volume = 0.58 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.post-rain",
    variations = {
      { filename = rain_sound, volume = 0.20 }
    },
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.wind-gust",
    filename = MOD .. "/sound/wind/wind-gust.ogg",
    volume = 0.55,
    category = "world-ambient"
  },
  {
    type = "sound",
    name = "real-rain.sound.thunder-far",
    category = "world-ambient",
    variations = variations({
      "/sound/mixkit-thunder/far/mixkit-far-rumble-1.ogg",
      "/sound/mixkit-thunder/far/mixkit-far-rumble-2.ogg",
      "/sound/mixkit-thunder/far/mixkit-far-rumble-3.ogg",
      "/sound/mixkit-thunder/far/mixkit-far-rumble-4.ogg",
      "/sound/mixkit-thunder/far/mixkit-far-rumble-5.ogg",
      "/sound/mixkit-thunder/far/mixkit-far-rumble-6.ogg",
      "/sound/thunder/thunder-1.ogg",
      "/sound/thunder/thunder-2.ogg",
      "/sound/thunder/thunder-3.ogg",
      "/sound/thunder/thunder-4.ogg",
      "/sound/thunder/thunder-5.ogg",
      "/sound/thunder/thunder-6.ogg"
    }, 0.88)
  },
  {
    type = "sound",
    name = "real-rain.sound.thunder-close",
    category = "world-ambient",
    variations = variations({
      "/sound/mixkit-thunder/close/mixkit-close-crack-1.ogg",
      "/sound/mixkit-thunder/close/mixkit-close-crack-2.ogg",
      "/sound/mixkit-thunder/close/mixkit-close-crack-3.ogg",
      "/sound/mixkit-thunder/close/mixkit-close-crack-4.ogg",
      "/sound/thunder-close/thunder-1.ogg",
      "/sound/thunder-close/thunder-2.ogg",
      "/sound/thunder-close/thunder-3.ogg",
      "/sound/thunder-close/thunder-4.ogg"
    }, 1.0)
  },
  {
    type = "sound",
    name = "real-rain.sound.thunder-roll",
    category = "world-ambient",
    variations = variations({
      "/sound/mixkit-thunder/roll/mixkit-rolling-tail-1.ogg",
      "/sound/mixkit-thunder/roll/mixkit-rolling-tail-2.ogg",
      "/sound/mixkit-thunder/roll/mixkit-rolling-tail-3.ogg",
      "/sound/thunder/thunder-2.ogg",
      "/sound/thunder/thunder-3.ogg",
      "/sound/thunder/thunder-4.ogg",
      "/sound/thunder/thunder-6.ogg"
    }, 0.72)
  },
  {
    type = "sound",
    name = "real-rain.sound.thunder-monsoon",
    category = "world-ambient",
    variations = variations({
      "/sound/mixkit-thunder/impact/mixkit-monsoon-impact-1.ogg",
      "/sound/mixkit-thunder/impact/mixkit-monsoon-impact-2.ogg",
      "/sound/mixkit-thunder/close/mixkit-close-crack-1.ogg",
      "/sound/mixkit-thunder/close/mixkit-close-crack-3.ogg",
      "/sound/thunder-close/thunder-1.ogg",
      "/sound/thunder-close/thunder-3.ogg"
    }, 1.0)
  },
  {
    type = "sound",
    name = "real-rain.sound.hiss",
    volume = 0.75,
    variations = {
      { filename = MOD .. "/sound/hiss/hiss-1.ogg" },
      { filename = MOD .. "/sound/hiss/hiss-2.ogg" }
    }
  }
})

local function smoke_layout(name, filename, frame, duration, fade, start_scale, end_scale)
  return {
    type = "trivial-smoke",
    name = name,
    animation = {
      filename = filename,
      width = 256,
      height = 256,
      frame_count = 1,
      x = (frame % 2) * 256,
      y = math.floor(frame / 2) * 256,
      animation_speed = 1
    },
    duration = duration,
    spread_duration = 8,
    fade_in_duration = fade,
    fade_away_duration = fade,
    start_scale = start_scale,
    end_scale = end_scale,
    affected_by_wind = false,
    movement_slow_down_factor = 1,
    show_when_smoke_off = true,
    cyclic = true
  }
end

local rain_file = MOD .. "/graphics/entity/rain/rain-streaks.png"
local mist_file = MOD .. "/graphics/entity/rain/rain-mist.png"
local splash_file = MOD .. "/graphics/entity/rain/rain-splash.png"
local ripple_file = MOD .. "/graphics/entity/rain/rain-ripple.png"

local smoke_prototypes = {}
for frame = 0, 3 do
  local n = frame + 1
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-front-" .. n, rain_file, frame, 26, 4, 0.62, 0.62)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-mid-" .. n, rain_file, frame, 36, 6, 0.42, 0.42)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-mist-" .. n, mist_file, frame, 48, 8, 0.54, 0.54)

  -- Legacy v1.0 splash name retained so saved effects never lose a prototype on update.
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-splash-" .. n, splash_file, frame, 28, 5, 0.35, 0.55)

  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-splash-normal-" .. n, splash_file, frame, 28, 5, 0.35, 0.55)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-splash-hard-" .. n, splash_file, frame, 24, 4, 0.48, 0.75)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-splash-soft-" .. n, splash_file, frame, 22, 4, 0.25, 0.40)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-splash-water-" .. n, ripple_file, frame, 34, 6, 0.42, 0.90)
  smoke_prototypes[#smoke_prototypes + 1] = smoke_layout("real-rain-puddle-" .. n, ripple_file, frame, 54, 9, 0.34, 0.75)
end
data:extend(smoke_prototypes)

local wind_defs = {
  left = -0.18,
  straight = -0.06,
  right = 0.08,
  gust = -0.32
}

local function make_spawner(name, smoke_name, speed_x, speed_y, height, speed_mult, center_dev)
  return {
    type = "explosion",
    name = name,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    flags = {"not-on-map", "placeable-off-grid"},
    collision_box = {{0, 0}, {0, 0}},
    collision_mask = { layers = {} },
    selectable_in_game = false,
    hidden = true,
    animations = { empty_animation },
    light = { intensity = 0, size = 0 },
    created_smoke = {
      type = "create-trivial-smoke",
      smoke_name = smoke_name,
      speed = {x = speed_x, y = speed_y},
      initial_height = height,
      speed_multiplier = speed_mult,
      speed_multiplier_deviation = 0.1,
      speed_from_center = 0.01,
      speed_from_center_deviation = center_dev,
      only_when_visible = true
    }
  }
end

local spawner_prototypes = {}
for frame = 1, 4 do
  for wind_name, x_speed in pairs(wind_defs) do
    spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-front-" .. frame .. "-" .. wind_name, "real-rain-front-" .. frame, x_speed, 0.62, 1.2, 2.3, 0.02)
    spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-mid-" .. frame .. "-" .. wind_name, "real-rain-mid-" .. frame, x_speed * 0.7, 0.42, 1.1, 1.55, 0.025)
    spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-mist-" .. frame .. "-" .. wind_name, "real-rain-mist-" .. frame, x_speed * 0.45, 0.26, 1.0, 1.05, 0.035)
  end

  -- Legacy v1.0 spawner retained.
  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-splash-" .. frame, "real-rain-splash-normal-" .. frame, 0, 0.02, 0.05, 0.15, 0.08)

  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-splash-normal-" .. frame, "real-rain-splash-normal-" .. frame, 0, 0.02, 0.05, 0.15, 0.08)
  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-splash-hard-" .. frame, "real-rain-splash-hard-" .. frame, 0, 0.02, 0.05, 0.18, 0.12)
  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-splash-soft-" .. frame, "real-rain-splash-soft-" .. frame, 0, 0.02, 0.05, 0.10, 0.06)
  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-splash-water-" .. frame, "real-rain-splash-water-" .. frame, 0, 0.0, 0.03, 0.08, 0.04)
  spawner_prototypes[#spawner_prototypes + 1] = make_spawner("real-rain-spawner-puddle-" .. frame, "real-rain-puddle-" .. frame, 0, 0.0, 0.03, 0.05, 0.03)
end
data:extend(spawner_prototypes)

local blank_picture = {
  north = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  east = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  south = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  west = { filename = "__core__/graphics/empty.png", width = 1, height = 1 }
}

data:extend({
  {
    type = "simple-entity",
    name = "real-rain-pollution-cleaner",
    icon = MOD .. "/graphics/entity/rain/rain-streaks.png",
    icon_size = 512,
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"},
    collision_box = {{0, 0}, {0, 0}},
    collision_mask = { layers = {} },
    selection_box = {{0, 0}, {0, 0}},
    selectable_in_game = false,
    picture = blank_picture
  },
  {
    type = "explosion",
    name = "real-rain-fire-marker",
    flags = {"not-on-map", "placeable-off-grid", "not-selectable-in-game"},
    hidden = true,
    collision_box = nil,
    selection_box = nil,
    selectable_in_game = false,
    render_layer = "ground-patch",
    picture = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    animations = { empty_animation }
  }
})
