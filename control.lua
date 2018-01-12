local VERSION = "0.3.0"

-- util functions

local function add(avg, value)
  local index = avg.next_index
  local total = avg.total - avg.values[index] + value
  local capacity = avg.capacity
  avg.total = total
  avg.values[index] = value
  avg.next_index = index % capacity + 1
end

local function add2(avg, value)
  local index = avg.next_index
  local total = avg.total - avg.values[index] + value
  local capacity = avg.capacity
  avg.total = total
  avg.values[index] = value
  avg.next_index = index % capacity + 1
  return total / capacity
end

local function label_position_for(entity)
  local left_top = entity.prototype.selection_box.left_top
  --top left corner
  return {x = entity.position.x + left_top.x, y = entity.position.y + left_top.y}
end

local function format_label(value)
  return math.floor(value * 100) .. "%"
end

local function add_label(data)
  local entity = data.entity
  local percent = data.min_avg.total / data.min_avg.capacity
  data.label = entity.surface.create_entity{name = "statictext", position = label_position_for(entity), text = format_label(percent)}
end

local function remove_label(data)
  if data and data.label and data.label.valid then
    data.label.destroy()
  end
end

-- is working functions

local function is_working_furnance(data)
  local entity = data.entity
  return entity.is_crafting() and entity.crafting_progress < 1.0
end

local function is_working_assembly_maschine(data)
  local entity = data.entity
  return entity.is_crafting() and entity.crafting_progress < 1.0
end

local function is_working_mining_drill(data)
  local entity = data.entity
  local lmp = entity.mining_progress
  local is_mining = (lmp ~= data.last_mining_progress)
  data.last_mining_progress = lmp
  return is_mining
end

local function is_working_lab(data)
  local entity = data.entity
  local sum_durability = 0.0
  local inventory = entity.get_inventory(defines.inventory.lab_input)
  for i = 1, #inventory do
    local item = inventory[i]
    if item.valid_for_read then
      sum_durability = sum_durability + item.durability
    end
  end
  local is_mining = (sum_durability ~= data.last_lab_durability)
  data.last_lab_durability = sum_durability
  return is_mining
end

local function get_is_working_function(t)
  if t == "furnace" then
    return is_working_furnance
  elseif t == "assembling-machine" then
    return is_working_assembly_maschine
  elseif t == "mining-drill" then
    return is_working_mining_drill
  elseif t == "lab" then
    return is_working_lab
  end
end

-- actual codee

function update_entity(data, update)
  local is_working = (data.is_working(data) and 1 or 0)
  if update then
    local sec_percent = add2(data.sec_avg, is_working)
    local min_percent = add2(data.min_avg, sec_percent)
    if data.label then
      data.label.text = format_label(min_percent)
    end
  else
    add(data.sec_avg, is_working)
  end
end

local function add_entity(entity)
  local id = entity.unit_number
  local data = {
    entity = entity,
    type = entity.type,
    is_working = get_is_working_function(entity.type),
    sec_avg = { capacity = 60, values = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, next_index = 1, total = 0, count = 0 },
    min_avg = { capacity = 60, values = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, next_index = 1, total = 0, count = 0 },
  }
  if global.show_labels then
    add_label(data)
  end
  global.entity_data[id] = data
end

local function remove_entity(id)
  local data = global.entity_data[id]
  global.entity_data[id] = nil -- Prevent memory leaks
  -- Remove label
  remove_label(data)
end

local function reset()
  game.print("UtilizationMonitor: Full reset")
  global.version = VERSION
  global.last_id = nil
  -- Purge old labels
  if global.entity_data ~= nil then
    for _, data in pairs(global.entity_data) do
      remove_label(data)
    end
  end
  global.entity_data = {}
  global.iteration = 0
  global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value -- probability to process entities far from players
  global.show_labels = settings.global["utilization-monitor-enabled"].value
  global.iterations_per_update = 60 -- TODO Move to config

  local count = 0
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type="assembling-machine"}) do
      add_entity(entity)
      count = count + 1
    end
    for _, entity in pairs(surface.find_entities_filtered{type="furnace"}) do
      add_entity(entity)
      count = count + 1
    end
    for _, entity in pairs(surface.find_entities_filtered{type="mining-drill"}) do
      if entity.name ~= "factory-port-marker" then -- ignore factorissimo2 arrows on factory buildings
        add_entity(entity)
        count = count + 1
      end
    end
    for _, entity in pairs(surface.find_entities_filtered{type="lab"}) do
      add_entity(entity)
      count = count + 1
    end
  end
  game.print("UtilizationMonitor: found " .. count .. " entities")
end

-- event functions

local function on_init()
  global.need_reset = true
end

local function on_tick(e)
  if global.need_reset then
    global.need_reset = nil
    reset()
    return
  end
  local next = next

  local entity_data = global.entity_data
  local id = global.last_id
  local data

  if id then
    data = entity_data[id]
  else
    id, data = next(entity_data, nil)
  end
  local update = global.iteration == 0
  local entities_per_tick = global.entities_per_tick

  for i = 1, entities_per_tick do
    if id == nil then
      global.iteration = (global.iteration + 1) % global.iterations_per_update
      break
    end
    if data.entity.valid then
      update_entity(data, update)
    else
      remove_entity(id)
    end
    id, data = next(entity_data, id)
  end
  global.last_id = id
end

local function on_built(e)
  local entity = e.created_entity
  if (entity.type == "assembling-machine") or (entity.type == "furnace") or
      (entity.type == "mining-drill") or (entity.type == "lab") then
    add_entity(entity)
  end
end

local function on_configuration_changed(event)
  --Any MOD has been changed/added/removed, including base game updates.
  if event.mod_changes then
    game.print("UtilizationMonitor: Game or mod version changes detected")
    global.need_reset = true
  end
end

local function update_settings(event)
  if event.setting == "utilization-monitor-enabled" then
    global.show_labels = settings.global["utilization-monitor-enabled"].value
    -- Purge old labels
    for _, data in pairs(global.entity_data) do
      remove_label(data)
    end
    -- Recreate labels
    if global.show_labels then
      for _, data in pairs(global.entity_data) do
        add_label(data)
      end
    end
  elseif event.setting == "utilization-monitor-entities-per-tick" then
    global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value
    game.print("UtilizationMonitor: entities-per-tick set to " .. global.entities_per_tick)
  end
end

local function on_toogle_utilization_monitor(event)
  global.show_labels = not global.show_labels -- TODO fix this
end

script.on_init(on_init)
script.on_event({defines.events.on_tick}, on_tick)
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_built)

script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)
script.on_event("toggle-utilization-monitor", on_toogle_utilization_monitor)
