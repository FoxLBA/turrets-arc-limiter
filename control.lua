local function find_controled_turret()
  local turret_inddex = {}
  local turret_defauld_index = {}
  for _, turret in pairs(prototypes.get_entity_filtered{
      {filter = "type", type = {"ammo-turret", "electric-turret"}}
    }) do
    if (turret.attack_parameters.turn_range == 1)
    or (not turret.attack_parameters.turn_range)
    then
      local t_name = turret.name
      local t2 = prototypes.entity[t_name .. "-tr1d3"]
      local t3 = prototypes.entity[t_name .. "-tr1d7"]
      if t2 and t3 then
        turret_inddex[t_name] = t2.name
        turret_inddex[t2.name] = t3.name
        turret_inddex[t3.name] = t_name
        turret_defauld_index[t2.name] = t_name
        turret_defauld_index[t3.name] = t_name
      end
    end
  end
  storage.turret_inddex = turret_inddex
  storage.turret_defauld_index = turret_defauld_index
end

local function on_configuration_changed(event)
  find_controled_turret()
  local turrets = {}
  for _, t_name in pairs(storage.turret_defauld_index) do
    if not turrets[t_name] then turrets[t_name] = true end
  end
  for _, force in pairs(game.forces) do
    for t_name, _ in pairs(turrets) do
      local bonus = force.get_turret_attack_modifier(t_name)
      if bonus > 0 then
          force.set_turret_attack_modifier(t_name .. "-tr1d3", bonus)
          force.set_turret_attack_modifier(t_name .. "-tr1d7", bonus)
      end
    end
  end
end

local function replace_turret(entity, new_name, new_direction)
  local dd = entity.damage_dealt
  local k = entity.kills
  local last = entity.last_user
  local energy = entity.energy
  local health = entity.health

  local new_entity = entity.surface.create_entity({
    name = new_name,
    position = entity.position,
    force = entity.force,
    direction = new_direction or entity.direction,
    fast_replace = true,
    raise_built = true,
    spill = false,
    create_build_effect_smoke = false,
  })
  if new_entity then
    new_entity.damage_dealt = dd
    new_entity.kills = k
    new_entity.last_user = last
    new_entity.health = health
    if energy then new_entity.energy = energy end
  end
  return new_entity
end

local function change_turret_turn_range(entity, change_type, player)
  local new_name
  if change_type == "next" then
    new_name =  storage.turret_inddex[entity.name]
  else
    new_name =  storage.turret_defauld_index[entity.name]
  end
  if not new_name then return end
  local new_entity = replace_turret(entity, new_name)
  if new_entity then
    if player then
      player.play_sound{path = "utility/wire_connect_pole"}
    end
  end
end

script.on_init(find_controled_turret)
script.on_configuration_changed(on_configuration_changed)

script.on_event("change-turret-turn-range", function(e)
---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(e.player_index)
  if not player then return end
  local selected = player.selected
  if selected and selected.valid and storage.turret_inddex[selected.name] then
    change_turret_turn_range(selected, "next", player)
  end
end)

local function rotate_turret(event, reverse)
  local player = game.players[event.player_index]
  if not player then return end
  local selected = player.selected
  if selected and selected.valid and storage.turret_defauld_index[selected.name] then
    local d = 2
    if reverse then d = 14 end
    d = (selected.direction + d) % 16
    replace_turret(selected, selected.name, d)
  end
end

script.on_event("change-turret-rotate", function(e)
  rotate_turret(e, false)
end)

script.on_event("change-turret-reverse-rotate", function(e)
  rotate_turret(e, true)
end)

commands.add_command("reset_turrets_turn_range", {"command-help.reset-turrets-turn-range"}, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  if not player.admin then
    player.print({"cant-run-command-not-admin", "reset_turrets_turn_range"})
    return
  end

  local turret_list = {}
  for name, _ in pairs(storage.turret_defauld_index) do
    table.insert(turret_list, name)
  end

  local c = 0
  for _, surface in pairs(game.surfaces) do
    for _, turret in pairs(surface.find_entities_filtered{name = turret_list}) do
      change_turret_turn_range(turret, "default")
      c = c + 1
    end
  end
  player.print({"command-message.reset-turrets-turn-range", c})
end)
