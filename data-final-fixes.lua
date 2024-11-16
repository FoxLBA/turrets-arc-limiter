local new_turrets = {}
local affected_turrest = {}

local function is_have_8_way_flag(flags)
  for _, value in pairs(flags) do
    if value == "building-direction-8-way" then return true end
  end
  return false
end

-- Create copies of turrets with a limited arc (turn_range).
for _, type in pairs({"ammo-turret", "electric-turret"}) do
  for _, turret in pairs(data.raw[type]) do
    if (data.raw.item[turret.name]) and (
        (not turret.attack_parameters.turn_range)
        or (turret.attack_parameters.turn_range == 1)
      )
      then
      local t_name = turret.name
      affected_turrest[t_name] = true
      local fr_group = turret.fast_replaceable_group or t_name
      turret.fast_replaceable_group = fr_group
      if not is_have_8_way_flag(turret.flags) then
        table.insert(turret.flags, "building-direction-8-way")
        if turret.circuit_connector and #turret.circuit_connector == 1 then
          local connector = turret.circuit_connector[1]
          for i = 1, 7 do table.insert(turret.circuit_connector, connector) end
        end
      end
      turret.turret_base_has_direction = true
      --turret.allow_turning_when_starting_attack = true
      turret.localised_description = {"", {"?", turret.localised_description or {"entity-description." .. t_name}, ""}, {"other.additional-turret-description"}}
      local new_turret = table.deepcopy(turret)
      new_turret.placeable_by = {item = t_name, count = 1}
      new_turret.localised_name = {"", {"entity-name." .. t_name}, " (1/3)"}
      new_turret.name = t_name .. "-tr1d3"
      new_turret.attack_parameters.turn_range = 1/3
      table.insert(new_turrets, table.deepcopy(new_turret))
      new_turret.localised_name = {"", {"entity-name." .. t_name}, " (1/7)"}
      new_turret.name = t_name .. "-tr1d7"
      new_turret.attack_parameters.turn_range = 1/7
      table.insert(new_turrets, new_turret)
    end
  end
end

-- Copy the turret bonus for new turrets.
for _, tech in pairs(data.raw.technology) do
  if tech.effects then
    local t_bonus = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "turret-attack" and affected_turrest[effect.turret_id] then
        table.insert(t_bonus, effect)
      end
    end
    for _, bonus in pairs(t_bonus) do
      local b = table.deepcopy(bonus)
      b.turret_id = bonus.turret_id .. "-tr1d3"
      table.insert(tech.effects, b)
      b = table.deepcopy(bonus)
      b.turret_id = bonus.turret_id .. "-tr1d7"
      table.insert(tech.effects, b)
    end
  end
end

data:extend(new_turrets)