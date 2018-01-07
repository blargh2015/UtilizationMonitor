local VERSION = "0.1.0"

MovingAvg = {}
MovingAvg.__index = MovingAvg

setmetatable(MovingAvg, {
  __call = function(class, ...)
          local self = setmetatable({},class)
          self:_init(...)
          return self
  end
})

function MovingAvg:_init(capacity)
  self.capacity = capacity
  self.values = {}
  self.next_index = 0
  self.total = 0
  self.count = 0
end

function MovingAvg:add(value)
  if self.count >= self.capacity then
    self.total = self.total - self.values[self.next_index] + value
  else
    self.count = self.count + 1
    self.total = self.total + value
  end
  self.values[self.next_index] = value
  self.next_index = self.next_index + 1
  if self.next_index >= self.capacity then
    self.next_index = 0
  end
end

function MovingAvg:avg()
  return self.total / self.count
end

local function label_position_for(entity)
  local left_top = entity.prototype.selection_box.left_top
  --top left corner
  return {x = entity.position.x + left_top.x, y = entity.position.y + left_top.y}
end

function is_working(data, id)
  local entity = data.entity
  local t = data.type
  if t == "furnace" then
    return entity.is_crafting() and entity.crafting_progress < 1.0
  elseif t == "assembling-machine" then
    return entity.is_crafting() and entity.crafting_progress < 1.0
  elseif t == "mining-drill" then
    local lmp = entity.mining_progress
    local is_mining = (lmp ~= data.last_mining_progress)
    data.last_mining_progress = lmp
    return is_mining
  elseif t == "lab" then
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
end

function update_entity(data, id, tick, time_strech)
  local is_working = (is_working(data, id) and 1 or 0)
  if data.sec_avg.add == nil then -- after loading the save game the add method is not defined :(
    global.need_reset = true
    return
  end
  for i = 1, time_strech do
    data.sec_avg:add(is_working)
  end
  if tick % 60 < time_strech then
    data.min_avg:add(data.sec_avg:avg())
    --[[
    game.print("last sec avg: " .. (data.sec_avg:avg()*100) .. "%, last min avg: " .. (data.min_avg:avg()*100))
    --]]
    if global.show_labels then
      local percent = math.max(math.floor(data.min_avg:avg()*100), 0)
      if data.label == nil then
        data.label = data.entity.surface.create_entity{name = "statictext", position = label_position_for(data.entity), text = tostring(percent).."%"}
      else
        data.label.text = percent .. "%"
      end
    end
  end
end

function add_entity(entity)
  local id = entity.unit_number
  global.entity_data[id] = {
    entity = entity,
    type = entity.type,
    last_tick = global.tick,
    sec_avg = MovingAvg(60),
    min_avg = MovingAvg(60)
  }
end

function remove_entity(id)
  local data = global.entity_data[id]
  if data and data.label and data.label.valid then
    data.label.destroy()
  end
end

function reset()
  game.print("UtilizationMonitor: Full reset")
  global.version = VERSION
  global.last_id = nil
  global.entity_data = {}
  global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value -- probability to process entities far from players
  global.show_labels = settings.global["utilization-monitor-enabled"].value

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

function on_tick(e)
  local tick = e.tick
  global.tick = tick
  if global.need_reset or (global.version ~= VERSION) or (type(global.entity_data) ~= "table") then
    global.need_reset = nil
    reset()
  end

  local entity_data = global.entity_data
  local id = global.last_id
  local data

  if id then
    data = entity_data[id]
  else
    id, data = next(entity_data, nil)
  end

  for i = 1, global.entities_per_tick do
    if id == nil then
      break
    end
    if data.entity.valid then
      update_entity(data, id, tick, math.min(tick - data.last_tick, 10))
      data.last_tick = tick
    else
      remove_entity(id)
    end
    if i == global.entities_per_tick then
      break
    end
    id, data = next(entity_data, id)
  end
  global.last_id = id
end

function on_built(e)
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
  elseif event.setting == "utilization-monitor-entities-per-tick" then
    global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value
    game.print("UtilizationMonitor: entities-per-tick set to " .. global.entities_per_tick)
  end
end

local function on_toogle_utilization_monitor(event)
  global.show_labels = not global.show_labels -- TODO fix this
end

script.on_event({defines.events.on_tick}, on_tick)
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_built)

script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)
script.on_event("toggle-utilization-monitor", on_toogle_utilization_monitor)
