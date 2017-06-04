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
    self.total = self.total - self.values[self.next_index]
  else
    self.count = self.count + 1
  end
  self.total = self.total + value
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

function is_working(entity, id)
  if entity.type == "furnace" then
    return entity.is_crafting() and entity.crafting_progress < 1.0
  elseif entity.type == "assembling-machine" then
    return entity.is_crafting()
  elseif entity.type == "mining-drill" then
    local is_mining = (entity.mining_progress ~= global.last_mining_progress[id])
    global.last_mining_progress[id] = entity.mining_progress
    return is_mining
  elseif entity.type == "lab" then
    local sum_durability = 0.0
    local inventory = entity.get_inventory(defines.inventory.lab_input)
    for i = 1, #inventory do
      local item = inventory[i]
      if item.valid_for_read then
        sum_durability = sum_durability + item.durability
      end
    end
    local is_mining = (sum_durability ~= global.last_lab_durability[id])
    global.last_lab_durability[id] = sum_durability
    return is_mining
  end
end

function update_entity(entity, e)
  local id = entity.unit_number
  local is_working = (is_working(entity, id) and 1 or 0)
  if global.sec_avg[id].add == nil then -- after loading the save game the add method is not defined :(
    global.need_reset = true
    return
  end
  global.sec_avg[id]:add(is_working)
  if e.tick % 60 == 0 then
    global.min_avg[id]:add(global.sec_avg[id]:avg())
    --[[
    game.print("last sec avg: " .. (global.sec_avg[id]:avg()*100) .. "%, last min avg: " .. (global.min_avg[id]:avg()*100))
    --]]
    if global.show_labels then
      local percent = math.max(math.floor(global.min_avg[id]:avg()*100), 0)
      entity.surface.create_entity{name = "statictext", position = label_position_for(entity), text = tostring(percent).."%"}
    end
  end
end

function add_entity(entity)
  local id = entity.unit_number
  global.entities[id] = entity
  global.sec_avg[id] = MovingAvg(60)
  global.min_avg[id] = MovingAvg(60)
end

function reset()
  game.print("UtilizationMonitor: Full reset")
  global.version = VERSION
  global.entities = {}

  global.sec_avg = {}
  global.min_avg = {}
  global.last_mining_progress = {}
  global.last_lab_durability = {}
  global.show_labels = settings.global["utilization-monitor-enabled"].value

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type="assembling-machine"}) do
      add_entity(entity)
    end
    for _, entity in pairs(surface.find_entities_filtered{type="furnace"}) do
      add_entity(entity)
    end
    for _, entity in pairs(surface.find_entities_filtered{type="mining-drill"}) do
      add_entity(entity)
    end
    for _, entity in pairs(surface.find_entities_filtered{type="lab"}) do
      add_entity(entity)
    end
  end
end

function on_tick(e)
  if global.need_reset or (global.version ~= VERSION) or
     (type(global.entities) ~= "table") or (type(global.sec_avg) ~= "table") or (type(global.min_avg) ~= "table") or
     (type(global.last_mining_progress) ~= "table") or (type(global.last_lab_durability) ~= "table") then
    global.need_reset = nil
    reset()
  end
  for id, entity in pairs(global.entities) do
    if not entity.valid then
      global.entities[id] = nil
    else
      update_entity(entity, e)
    end
  end
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
  end
end

local function on_toogle_utilization_monitor(event)
  global.show_labels = not global.show_labels
end

script.on_event({defines.events.on_tick}, on_tick)
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_built)

script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)
script.on_event("toggle-utilization-monitor", on_toogle_utilization_monitor)
