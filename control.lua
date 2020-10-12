-- The version of the data of this mod.
-- If this value does not match the data have to be reset.
local VERSION = "0.3.0"
--[[--
UM data definition:



global:

-- The last/currently running UMData version.
global.version : string

-- The last id of the entity that was updated.
global.last_id : uint

-- The main data container with all tracked entity data.
global.entity_data : Table<UMData>

-- The current iteration for the data (required for iterations_per_update)
global.iteration : uint

-- Whether to show the labels or not
global.show_labels : boolean (configurable)

-- Whether the mod is disabled or not.
global.disabled : boolean (configurable)

-- Limits the total count of entities to be processed per tick. The other entities will be processed in the next tick.
global.entities_per_tick : uint (configurable)

-- After how many iterations the long term average and labels should be updated.
global.iterations_per_update : uint (configurable)


UMData:

-- The entity that will by tracked by this data.
UMData.entity : Entity

-- A function that can be used to calculate whether the entity is currently working
UMData.is_working : function(UMData):boolean

-- The short term average processing time.
UMData.sec_avg : UMAvg

-- The long term average processing time.
UMData.min_avg : UMAvg

-- The label for the entity associated with this data entry.
UMData.label : Entity or nil

-- Temporary variable for storing the last progress value to determine whether there are changes since last calculation.
UMData.last_progress : any



UMAvg:

-- The working states during the last n measurements.
UMAvg.values : Array<numeric>

-- The next index of the values array that should be overwritten.
UMAvg.next_index : uint

-- The sum of values for performance reasons.
UMAvg.total : uint

]]

-----------------------
-- Utility functions --
-----------------------

--- Adds the given value to the given average holder and returns the current average.
--
-- @param avg:UMAvg - The average holder to update.
-- @param value:numeric - The value to add to the average.
-- @returns numeric - The current average as specified by the average holder.
--
local function add2(avg, value)
  local index = avg.next_index
  local total = avg.total - avg.values[index] + value
  avg.total = total
  avg.values[index] = value
  avg.next_index = index % 60 + 1
  return total / 60
end

--- Calculates the label position for the given entity.
--
-- @param entity:Entity - The entity to calculate the label position for.
--
local function label_position_for(entity)
  local left_top = entity.prototype.selection_box.left_top
  --top left corner
  return {x = entity.position.x + left_top.x, y = entity.position.y + left_top.y}
end

--- Formats the given value to be used as label text.
--
-- @param value:numeric - The numeric value representing the average working state. Expects values between 0 and 1.
-- @returns string - The new text for the label.
--
local function format_label(value)
  return math.max(math.floor(value * 100), 0) .. "%"
end

--- Creates a label for the entity associated with the given data.
--
-- @param data:UMData - The data associated with the entity the label should be created for.
--
local function add_label(data)
  local entity = data.entity
  local percent = data.min_avg.total / 60
  data.label = entity.surface.create_entity{name = "statictext", position = label_position_for(entity), text = format_label(percent)}
end

--- Removes the label for the entity associated with the given data if it does exist.
--
-- @param data:UMData - The data associated with the entity the label should be removed from.
--
local function remove_label(data)
  if data and data.label and data.label.valid then
    data.label.destroy()
    data.label = nil
  end
end

--- Removes all labels for the entries on the given data table.
--
-- @param entity_data:Table<UMData> - The table that contains all data that should be purged.
--
local function purge_labels(entity_data)
  for _, data in pairs(global.entity_data) do
    remove_label(data)
  end
end

--- Determine if we have support for this entity type.
--
-- @param entity:Entity - The entity for which the function should be searched.
-- @return boolean - true if we can support (and thus should monitor), false otherwise.
--
local function can_determine_working(entity)
  local t = entity.type
  if t == "furnace" then
    return true
  elseif t == "assembling-machine" then
    return true
  elseif t == "mining-drill" then
    if entity.name == "factory-port-marker" then
      -- ignore factorissimo2 arrows on factory buildings
      return false
    end
    return is_working_mining_drill
  elseif t == "lab" then
    return true
  end
  return false
end

-----------------
-- Actual code --
-----------------

--- Adds an entity to be tracked by UM.
--
-- @param entity:Entity - The entity to track
-- @return boolean - Whether the given entity was supported and tracked.
--
local function add_entity(entity)
  local can_determine = can_determine_working(entity)
  if can_determine then
    local id = entity.unit_number
    local data = {
      entity = entity,
      sec_avg = { values = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, next_index = 1, total = 0},
      min_avg = { values = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, next_index = 1, total = 0},
    }
    if global.show_labels then
      add_label(data)
    end
    global.entity_data[id] = data
    return true
  end
  return false
end

--- Post-Processes the movement of the given entity.
--
-- @param entity:Entity - The entity that was moved.
--
local function move_entity(entity)
  local data = global.entity_data[entity.unit_number]
  if data and data.label and data.label.valid then
    local position = label_position_for(entity)
    data.label.teleport(position)
  end
end

--- Remove the given entity from being tracked by UM.
--
-- @param id:uint - The id of the entity to stop tracking.
--
local function remove_entity(id)
  local data = global.entity_data[id]
  if data then
    global.entity_data[id] = nil -- Prevent memory leaks
    -- Remove label
    remove_label(data)
  end
end

--- Hard resets all data used by UM.
--
local function reset()
  game.print("UtilizationMonitor: Full reset")
  -- clean up data used in earlier mod versions to make savegames smaller
  global.entities = nil
  global.entity_types = nil
  global.entity_positions = nil
  global.sec_avg = nil
  global.min_avg = nil
  global.last_mining_progress = nil
  global.last_lab_durability = nil
  -- end cleanup

  global.version = VERSION
  global.last_id = nil
  -- Purge old labels
  if global.entity_data ~= nil then
    purge_labels(global.entity_data)
  end
  global.entity_data = {}
  global.iteration = 0
  global.show_labels = settings.global["utilization-monitor-show-labels"].value
  global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value
  global.iterations_per_update = settings.global["utilization-monitor-iterations-per-update"].value

  local count = 0
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type="assembling-machine"}) do
      if add_entity(entity) then
        count = count + 1
      end
    end
    for _, entity in pairs(surface.find_entities_filtered{type="furnace"}) do
      if add_entity(entity) then
        count = count + 1
      end
    end
    for _, entity in pairs(surface.find_entities_filtered{type="mining-drill"}) do
      if add_entity(entity) then
        count = count + 1
      end
    end
    for _, entity in pairs(surface.find_entities_filtered{type="lab"}) do
      if add_entity(entity) then
        count = count + 1
      end
    end
  end
  game.print("UtilizationMonitor: found " .. count .. " entities")
end

-----------------------------
-- Configuration functions --
-----------------------------

--- Updates the `disabled` option and executes the necessary operations (reset/remove labels).
--
-- @param enabled:boolean - `true` if the mod should be enabled
--
local function update_disabled(enabled)
  global.disabled = not enabled
  if global.disabled then
    purge_labels(global.entity_data)
    global.entity_data = {} -- Prevent memory leaks
    remove_event_handlers()
  else
    add_event_handlers()
    reset()
  end
end

--- Updates the show_labels option and executes the necessary operations (remove/add labels).
--
-- @param value:boolean - Whether to show the labels or not.
--
local function update_show_labels(value)
  global.show_labels = value
  -- Purge old labels
  purge_labels(global.entity_data)
  -- Recreate labels
  if global.show_labels then
    for _, data in pairs(global.entity_data) do
      add_label(data)
    end
  end
end

---------------------
-- Event functions --
---------------------

local function on_dolly_moved_entity(event)
  move_entity(event.moved_entity)
end

--[[Init Events]]
local function register_conditional_events()
  if remote.interfaces["picker"] and remote.interfaces["picker"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("picker", "dolly_moved_entity_id"), on_dolly_moved_entity)
  end
end

local function on_init()
  reset()
  register_conditional_events()
end

local function on_load()
  register_conditional_events()
end

local function on_tick(event)
  -- Check state
  if global.need_reset then
    global.need_reset = nil
    reset()
    return
  end

  -- Prepare for faster access
  local next = next
  local entity_data = global.entity_data
  local entities_per_tick = global.entities_per_tick
  local update = global.iteration == 0

  -- Prepare iteration data holders
  local id = global.last_id
  local data

  if id then
    data = entity_data[id]
    -- Fix for #17: The next data to be processed has been removed between the ticks.
    if data == nil then
      id, data = next(entity_data, nil)
    end
  else
    id, data = next(entity_data, nil)
  end

  -- Actually execute the update
  for i = 1, entities_per_tick do
    if id == nil then
      break
    end
    if data.entity.valid then
      local is_working = ((data.entity.status == defines.entity_status.working) and 1 or 0)
      if update then
        local sec_percent = add2(data.sec_avg, is_working)
        local min_percent = add2(data.min_avg, sec_percent)
        if data.label then
          data.label.text = format_label(min_percent)
        end
      else
        local index = data.sec_avg.next_index
        data.sec_avg.total = data.sec_avg.total - data.sec_avg.values[index] + is_working
        data.sec_avg.values[index] = is_working
        data.sec_avg.next_index = index % 60 + 1
      end
    else
      remove_entity(id)
    end
    id, data = next(entity_data, id)
  end

  -- Update state for next run
  if id == nil then
    global.iteration = (global.iteration + 1) % global.iterations_per_update
  end
  global.last_id = id
end

--- Event handler for newly build entities.
--
-- @param event:Event - The event contain the information about the newly build entity.
--
local function on_built(event)
  add_entity(event.created_entity)
end

local function on_built_script(event)
  add_entity(event.entity)
end

--- Event handler for destroyed entities.
--
-- @param event:Event - The event contain the information about the destroyed entity.
--
local function on_destroyed(event)
  remove_entity(event.entity.unit_number)
end

--- Event handler for a changed configuration and mods.
--
-- @param event:Event - The event containing the details of the changes.
--
local function on_configuration_changed(event)
  -- Any MOD has been changed/added/removed, including base game updates.
  if event.mod_changes then
    game.print("UtilizationMonitor: Game or mod version changes detected")
    global.need_reset = true
  end
end

--- Event handler for the update settings event
--
-- @param event - The event with the information which setting has changed.
--
local function update_settings(event)
  if event.setting == "utilization-monitor-enabled" then
    update_disabled(settings.global["utilization-monitor-enabled"].value)

  elseif event.setting == "utilization-monitor-show-labels" then
    update_show_labels(settings.global["utilization-monitor-show-labels"].value)

  elseif event.setting == "utilization-monitor-entities-per-tick" then
    global.entities_per_tick = settings.global["utilization-monitor-entities-per-tick"].value
    game.print("UtilizationMonitor: entities-per-tick set to " .. global.entities_per_tick)

  elseif event.setting == "utilization-monitor-iterations-per-update" then
    global.iterations_per_update = settings.global["utilization-monitor-iterations-per-update"].value
    game.print("UtilizationMonitor: iterations-per-update set to " .. global.iterations_per_update)
  end
end

--- Event handler for the toggle UM hotkey.
--
-- @param event - The event causing the toggle.
--
local function on_toogle_utilization_monitor(event)
  update_disabled(global.disabled)
end

--- Event handler for the toggle UM labels hotkey.
--
-- @param event - The event causing the toggle.
--
local function on_toogle_utilization_monitor_labels(event)
  update_show_labels(not global.show_labels)
end

-----------------------------
-- Register event handlers --
-----------------------------

function add_event_handlers()
  script.on_event({defines.events.on_tick}, on_tick)
  script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_built)
  script.on_event({defines.events.script_raised_built, defines.events.script_raised_revive}, on_built_script)
  script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.script_raised_destroy}, on_destroyed)
  script.on_event("toggle-utilization-monitor-labels", on_toogle_utilization_monitor_labels)
end

function remove_event_handlers()
  script.on_event({defines.events.on_tick}, nil)
  script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built, defines.events.script_raised_revive}, nil)
  script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.script_raised_destroy}, nil)
  script.on_event("toggle-utilization-monitor-labels", nil)
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)
script.on_event("toggle-utilization-monitor", on_toogle_utilization_monitor)
if not global.disabled then
  commands.add_command("umreset", "Use /umreset to reset Utilization Monitor, recheck entities, and restart counting.", reset)
  add_event_handlers()
end
