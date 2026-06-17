-- Real Rain uses a tiny trigger marker to notice newly-created fires and let rain put them out.
-- This follows Factorio's trigger_created_entity path and keeps the runtime scanner light.
local fires = data.raw.fire
if fires then
  for _, entity in pairs(fires) do
    entity.created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          type = "create-entity",
          entity_name = "real-rain-fire-marker",
          ignore_collision_condition = true,
          trigger_created_entity = true
        }
      }
    }
    entity.selectable_in_game = false
  end
end
