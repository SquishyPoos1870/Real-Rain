data:extend({
  {
    type = "bool-setting",
    name = "real-rain-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "aa"
  },
  {
    type = "string-setting",
    name = "real-rain-aaa-preset",
    setting_type = "runtime-global",
    default_value = "balanced",
    allowed_values = {"subtle", "balanced", "storm", "monsoon"},
    order = "ab"
  },
  {
    type = "double-setting",
    name = "real-rain-intensity",
    setting_type = "runtime-global",
    default_value = 1.2,
    minimum_value = 0.1,
    maximum_value = 6,
    order = "ac"
  },
  {
    type = "double-setting",
    name = "real-rain-wind-strength",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0,
    maximum_value = 3,
    order = "ad"
  },
  {
    type = "bool-setting",
    name = "real-rain-ground-splashes-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "ae"
  },
  {
    type = "bool-setting",
    name = "real-rain-tile-splashes-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "af"
  },
  {
    type = "bool-setting",
    name = "real-rain-biome-ambience-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "ag"
  },
  {
    type = "bool-setting",
    name = "real-rain-wind-sound-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "ah"
  },
  {
    type = "string-setting",
    name = "real-rain-ups-mode",
    setting_type = "runtime-global",
    default_value = "balanced",
    allowed_values = {"cinematic", "balanced", "saver"},
    order = "ai"
  },
  {
    type = "bool-setting",
    name = "real-rain-nauvis-only",
    setting_type = "runtime-global",
    default_value = true,
    order = "aj"
  },
  {
    type = "bool-setting",
    name = "real-rain-storm-stages-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "b0"
  },
  {
    type = "double-setting",
    name = "real-rain-monsoon-chance",
    setting_type = "runtime-global",
    default_value = 0.08,
    minimum_value = 0,
    maximum_value = 1,
    order = "b1"
  },
  {
    type = "bool-setting",
    name = "real-rain-post-rain-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "b2"
  },
  {
    type = "int-setting",
    name = "real-rain-post-rain-min-seconds",
    setting_type = "runtime-global",
    default_value = 35,
    minimum_value = 0,
    maximum_value = 600,
    order = "b3"
  },
  {
    type = "int-setting",
    name = "real-rain-post-rain-max-seconds",
    setting_type = "runtime-global",
    default_value = 120,
    minimum_value = 0,
    maximum_value = 900,
    order = "b4"
  },
  {
    type = "double-setting",
    name = "real-rain-wet-min-hours",
    setting_type = "runtime-global",
    default_value = 2.0,
    minimum_value = 0.1,
    order = "ba"
  },
  {
    type = "double-setting",
    name = "real-rain-wet-max-hours",
    setting_type = "runtime-global",
    default_value = 10.0,
    minimum_value = 0.1,
    order = "bb"
  },
  {
    type = "double-setting",
    name = "real-rain-wet-power",
    setting_type = "runtime-global",
    default_value = 1.45,
    minimum_value = 0.01,
    order = "bc"
  },
  {
    type = "double-setting",
    name = "real-rain-dry-mean-hours",
    setting_type = "runtime-global",
    default_value = 36.0,
    minimum_value = 0.01,
    order = "bd"
  },
  {
    type = "bool-setting",
    name = "real-rain-thunder-sound-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "ca"
  },
  {
    type = "double-setting",
    name = "real-rain-volume-modifier",
    setting_type = "runtime-global",
    default_value = 0.65,
    minimum_value = 0,
    maximum_value = 1.0,
    order = "cb"
  },
  {
    type = "double-setting",
    name = "real-rain-thunder-volume-modifier",
    setting_type = "runtime-global",
    default_value = 0.9,
    minimum_value = 0,
    maximum_value = 1.0,
    order = "cc"
  },
  {
    type = "bool-setting",
    name = "real-rain-thunder-layering-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "ccd"
  },
  {
    type = "bool-setting",
    name = "real-rain-lightning-visual-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "cd"
  },
  {
    type = "double-setting",
    name = "real-rain-min-thunder-chance",
    setting_type = "runtime-global",
    default_value = 0.00018,
    minimum_value = 0,
    maximum_value = 0.02,
    order = "ce"
  },
  {
    type = "double-setting",
    name = "real-rain-max-thunder-chance",
    setting_type = "runtime-global",
    default_value = 0.0055,
    minimum_value = 0,
    maximum_value = 0.02,
    order = "cf"
  },
  {
    type = "bool-setting",
    name = "real-rain-fire-extinguish-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "da"
  },
  {
    type = "int-setting",
    name = "real-rain-solar-power-multiplier",
    setting_type = "runtime-global",
    default_value = 55,
    minimum_value = -1,
    maximum_value = 100,
    order = "db"
  },
  {
    type = "int-setting",
    name = "real-rain-pollution-cleanup-per-minute",
    setting_type = "runtime-global",
    default_value = 8,
    minimum_value = 0,
    order = "dc"
  },
  {
    type = "int-setting",
    name = "real-rain-pollution-max-chunks-per-tick",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 32,
    order = "dd"
  }
})
