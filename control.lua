local sound_p = "utility/wire_connect_pole"

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
    player.play_sound{path = sound_p}
  end
end

local function on_pre_build(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local cursor_stack = player.cursor_stack
  if cursor_stack and cursor_stack.valid_for_read and storage.turret_inddex[cursor_stack.name] then
    local selected = player.selected
    if selected and selected.valid and (selected.name == "entity-ghost") and storage.turret_inddex[selected.ghost_name] then
      storage.pre_build[event.player_index] = {
        name = selected.ghost_name,
        direction = selected.direction,
        position = selected.position,
      }
    end
  end
end

local function on_built(event)
  if storage.pre_build[event.player_index] then
    local e_pos = event.entity.position
    local pos = storage.pre_build[event.player_index].position
    if pos.x == e_pos.x and pos.y == e_pos.y then
      replace_turret(event.entity, storage.pre_build[event.player_index].name, storage.pre_build[event.player_index].direction)
    end
    storage.pre_build[event.player_index] = nil
  end
end

local function on_load()
  local filter = {}
  for name, _ in pairs(storage.turret_inddex or {}) do
    table.insert(filter, {filter = "name", name = name})
  end
  if #filter > 0 then
    script.on_event(defines.events.on_built_entity, on_built, filter)
  end
end

local function on_init()
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
        local cbox = prototypes.entity[t_name].collision_box
        if (cbox.right_bottom.x - cbox.left_top.x) > 2 then
          turret_odd_sized[t_name] = true
          turret_odd_sized[t2.name] = true
          turret_odd_sized[t3.name] = true
        end
      end
    end
  end
  storage.turret_inddex = turret_inddex
  storage.turret_defauld_index = turret_defauld_index
  storage.turret_odd_sized = turret_odd_sized
  storage.pre_build = storage.pre_build or {}
  on_load()
end

local function on_configuration_changed(event)
  on_init()
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

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_pre_build, on_pre_build)

script.on_event("change-turret-turn-range", function(e)
---@diagnostic disable-next-line: undefined-field
  local index = e.player_index
  local player = game.get_player(index)
  if not player then return end
  local cursor_ghost = player.cursor_ghost
  if cursor_ghost and storage.turret_inddex[cursor_ghost.name.name] then
    cursor_ghost.name = storage.turret_inddex[player.cursor_ghost.name.name]
    player.cursor_ghost = cursor_ghost
    player.play_sound{path = sound_p}
    return
  end
  local cursor_stack = player.cursor_stack
  if cursor_stack and cursor_stack.valid_for_read and storage.turret_inddex[cursor_stack.name] then
    local new_name = storage.turret_inddex[cursor_stack.name]
    if settings.get_player_settings(index)["tal-prefer-ghost"].value then
      if player.clear_cursor() then
        player.cursor_ghost = new_name
        player.play_sound{path = sound_p}
      end
    else
      player.cursor_stack.set_stack({
        name = new_name,
        count = cursor_stack.count,
        quality = cursor_stack.quality.name,
        health = cursor_stack.health,
        --tags = cursor_stack.tags, --is_item_with_tags ?
        --custom_description = cursor_stack.cm_description,
      })
      player.play_sound{path = sound_p}
    end
    return
  end
  local selected = player.selected
  if selected and selected.valid and storage.turret_inddex[get_entity_name(selected)] then
    change_turret_turn_range(selected, "next", player)
    return
  end
end)

local function rotate_turret(event, reverse)
  local player = game.players[event.player_index]
  if not player or not player.is_cursor_empty() then return end
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
