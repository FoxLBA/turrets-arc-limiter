local function find_controled_turret()
  local turret_inddex = {}
  local turret_defauld_index = {}
  local turret_odd_sized = {}
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
      local cbox = prototypes.entity[t_name].collision_box
      if (cbox.right_bottom.x - cbox.left_top.x) > 2 then
        --turret_odd_sized[t_name] = true
        turret_odd_sized[t2.name] = true
        turret_odd_sized[t3.name] = true
      end
    end
  end
  storage.turret_inddex = turret_inddex
  storage.turret_defauld_index = turret_defauld_index
  storage.turret_odd_sized = turret_odd_sized
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

local function get_entity_name(entity)
  local e_name = entity.name
  if e_name == "entity-ghost" then
    return entity.ghost_name
  end
  return e_name
end

local function replace_turret(entity, new_name, new_direction)
  local is_ghost = (entity.name == "entity-ghost")
  local dd = entity.damage_dealt
  local k = entity.kills
  local last = entity.last_user
  local energy = entity.energy
  local health = entity.health

  local params = {
    name = new_name,
    position = entity.position,
    force = entity.force,
    direction = new_direction or entity.direction,
    quality = entity.quality,
    fast_replace = true,
    raise_built = true,
    spill = false,
    create_build_effect_smoke = false,
  }
  if is_ghost then
    params.name = "entity-ghost"
    params.inner_name = new_name
    params.tags = entity.tags
  end

  local new_entity = entity.surface.create_entity(params)
  if new_entity then
    new_entity.damage_dealt = dd
    new_entity.kills = k
    new_entity.last_user = last
    if not is_ghost then
      new_entity.health = health
      if energy then new_entity.energy = energy end
    end
  end
  return new_entity
end

local function change_turret_turn_range(entity, change_type, player)
  local e_name = get_entity_name(entity)
  local new_name
  if change_type == "next" then
    new_name =  storage.turret_inddex[e_name]
  else
    new_name =  storage.turret_defauld_index[e_name]
  end
  if not new_name then return end
  local new_entity = replace_turret(entity, new_name)
  if new_entity and player then
    player.play_sound{path = "utility/wire_connect_pole"}
  end
end

script.on_init(find_controled_turret)
script.on_configuration_changed(find_controled_turret)

script.on_event("change-turret-turn-range", function(e)
---@diagnostic disable-next-line: undefined-field
  local player = game.get_player(e.player_index)
  if not player then return end
  local selected = player.selected
  if selected and selected.valid and storage.turret_inddex[get_entity_name(selected)] then
    change_turret_turn_range(selected, "next", player)
  end
end)

local function rotate_turret(event, reverse)
  local player = game.players[event.player_index]
  if not player then return end
  local selected = player.selected
  if selected and selected.valid then
    local e_name = get_entity_name(selected)
    if storage.turret_defauld_index[e_name] then
      local d = 2
      if storage.turret_odd_sized[e_name] then d = d * 2 end
      if reverse then d = 16 - d end
      d = (selected.direction + d) % 16
      replace_turret(selected, e_name, d)
    end
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
