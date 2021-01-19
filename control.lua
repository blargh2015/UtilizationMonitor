-- The version of the data of this mod.
-- If this value does not match the data have to be reset.
local VERSION = "47"
--[[--
UM data definition:



global:

-- The last/currently running UMData version.
global.version : string

-- The unit_number of the next entity to be updated.
global.last_id : uint

-- The main data container with all tracked entity data.  Indexed by entity.unit_number.
global.entity_data : Table<UMData>

-- The count of entries in entity_data
global.entity_count : uint

-- Whether to show the labels or not
global.show_labels : boolean (configurable)

-- Whether the mod is disabled or not.
global.disabled : boolean (configurable)

-- Limits the maximum number entities to be processed per tick. The other entities will be processed in the next tick.
global.entity_rate_max : uint (configurable)

-- Whether we have warned this session about the rate exceeding limits.
global.max_warning : boolean

-- The current number of entities per ticket.  Calculated based on entity_count and the entities_per_tick limit
global.entity_rate : uint

-- Whether the mod should always compute performance percentage
global.always_perf : boolean (configurable)

-- Should spooling up numbers be rendered at all?
global.render_spoolup : boolean

-- Color for spooling up
global.color_spoolup : table

-- Color for steady
global.color_steady : table

UMData:

-- The entity that will by tracked by this data.
UMData.entity : Entity

-- The long term average processing time.
UMData.min_avg : UMAvg

-- The label for the entity associated with this data entry.
UMData.label : Entity or nil

-- Temporary variable for storing the last progress value to determine whether there are changes since last calculation.
UMData.last_progress : any

-- Some entity types have additional fields based on our computations from the prototypes, to avoid a recalc everytime:
-- Whether to bother looking at energy statistics for this entity to determine its working percentage.
UMData.variable_working : boolean

-- For type=="generator", we store the max_energy_production
UMData.mep : numeric

-- For type=="boiler", we store the max flow rate.
UMData.maxflow : numeric


UMAvg:

-- The working states during the last n measurements.
UMAvg.values : Array<numeric>

-- The number of values in the array
UMAvg.count : uint

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
  avg.next_index = index % avg.count + 1
  if avg.next_index == 1 then
    avg.has_rolled = true
  end
  avg.avg = total / avg.count
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

--- Updates a UMData's label object.
--
-- @param data:UMData - The data to update.
--
local function update_label(data)
  if data.min_avg.has_rolled then
    data.label.text = format_label(data.min_avg.avg)
    data.label.color = global.color_steady
  else
    if global.render_spoolup then
        data.label.text = format_label(data.min_avg.avg)
        data.label.color = global.color_spoolup
    else
        data.label.text = ""
    end
  end
end

--- Creates a label for the entity associated with the given data.
--
-- @param data:UMData - The data associated with the entity the label should be created for.
--
local function add_label(data)
  local entity = data.entity
  data.label = entity.surface.create_entity{name = "statictext", position = label_position_for(entity), text=""}
  update_label(data)
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
    return true
  elseif t == "lab" then
    return true
  elseif t == "generator" then
    return true
  elseif t == "reactor" then
    return true
  elseif t == "boiler" then
    return true
  end
  return false
end

-----------------
-- Actual code --
-----------------

-- Recompute the number of entities per tick to process.  Issues a warning (once per reset)
-- if the maximum is hit.
local function recompute_rate()
  desired_rate = math.ceil(global.entity_count / 60)
  if desired_rate > global.entity_rate_max then
    global.entity_rate = global.entity_rate_max
    if global.max_warning ~= true then
      game.print({"utilization-monitor-limit-exceeded", global.entity_rate_max})
      global.max_warning = true
    end
  else
    global.entity_rate = desired_rate
  end
end

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
      type = entity.type,
      min_avg = { values = {}, next_index = 1, total = 0, count = settings.global["utilization-monitor-secs-" .. entity.type].value, has_rolled = false, avg = 0},
    }
    if data.min_avg.count == 0 then  -- The counting of this type of object has been configured disable.
      return false
    end
    for i = 1, data.min_avg.count do
      table.insert(data.min_avg.values, 0)
    end
    -- Store some data from the prototype locally to improve performance.
    if entity.prototype.energy_usage ~= nil then
      data.variable_working = true
      data.reqenergy = entity.prototype.energy_usage * (1 + entity.consumption_bonus)
    else
      data.variable_working = false
    end
    if data.type == "generator" then
      data.mep = data.entity.prototype.max_energy_production
    elseif data.type == "boiler" then
      -- This gets complex, as while we can get the current flow rate in units per tick, the maximum (expected) of that value has to be calculated from the energy values.
      influidproto = data.entity.prototype.fluidbox_prototypes[1]
      intemp = influidproto.filter.default_temperature        -- C
      inheat = influidproto.filter.heat_capacity              -- J needed to raise 1 deg C
      outtemp = data.entity.prototype.target_temperature      -- C
      maxenergy = data.entity.prototype.max_energy_usage      -- W = J/s 
      data.maxflow = maxenergy / ((outtemp - intemp) * inheat)
    end
    global.entity_data[id] = data
    global.entity_count = global.entity_count + 1
    recompute_rate()
    if global.show_labels then
      add_label(data)
    end
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
    global.entity_count = global.entity_count -1
    recompute_rate()
    -- Remove label
    remove_label(data)
  end
end


--- Returns performance of a machine, based on type and energy available or used
---
-- @param data:UMData - The entity we need to calculator for
-- @return float - A number from 0.0 to 1.0 for the performance of the entity currently
--
local function working_value_calc(data)
  local entstatus = data.entity.status
  if data.type == "generator" then
    return data.entity.energy_generated_last_tick / data.mep
  elseif data.type == "reactor" then
    return ((entstatus == defines.entity_status.working) and 1 or 0)
  elseif data.type == "boiler" then
    local fr = data.entity.fluidbox.get_flow(2)
    local ret = fr / data.maxflow
    --  game.print("UMDebug: boiler name "..data.entity.name..", id ".. data.entity.unit_number.." , flow " .. fr .. " over max rate " .. data.maxflow.. ", ret "..ret)
    return ret
  else
    if data.variable_working == false then
      return 1.0
    end
    if entstatus == defines.entity_status.working and global.always_perf == false then
      return 1.0
    elseif (entstatus == defines.entity_status.working and global.always_perf == true) or entstatus == defines.entity_status.low_power then
--- Thanks to boskid and eradicator at https://forums.factorio.com/viewtopic.php?f=25&t=93820 for answering this    
      return math.min(data.reqenergy, data.entity.energy) / data.reqenergy
    else
      return 0.0
    end
  end
end

-- Rethink our color settings if needed.
local function recompute_colors()
  local color_map = {White={r=1,g=1,b=1,a=1}, Black={r=0,g=0,b=0,a=1}, Red={r=1,g=0,b=0,a=1}, Green={r=0,g=1,b=0,a=1}, Blue={r=0,g=0,b=1,a=1}, Yellow={r=1,g=1,b=0,a=1}, Orange={r=1,g=0.5,b=0,a=1} }
  if settings.global["utilization-monitor-color-spoolup"].value == "Off (do not show)" then
    global.render_spoolup = false
  else
    global.render_spoolup = true
    global.color_spoolup = color_map[settings.global["utilization-monitor-color-spoolup"].value]
  end
  global.color_steady = color_map[settings.global["utilization-monitor-color-steady"].value]
end  


--- Hard resets all data used by UM.
--
local function reset()
  -- clean up data used in earlier mod versions to make savegames smaller
  global.entities = nil
  global.entity_types = nil
  global.entity_positions = nil
  global.sec_avg = nil
  global.min_avg = nil
  global.last_mining_progress = nil
  global.last_lab_durability = nil
  global.iterations_per_update = nil
  -- end cleanup

  global.version = VERSION
  global.last_id = nil
  -- Purge old labels
  if global.entity_data ~= nil then
    purge_labels(global.entity_data)
  end
  global.entity_data = {}
  global.entity_count = 0
  global.entity_rate = 0
  global.iteration = 0
  global.show_labels = settings.global["utilization-monitor-show-labels"].value
  global.entity_rate_max = settings.global["utilization-monitor-entities-per-tick"].value
  global.always_perf = settings.global["utilization-monitor-always-perf"].value
  global.max_warning = false
  recompute_colors()

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type={"assembling-machine","furnace","mining-drill","lab","boiler","generator","reactor"}}) do
      add_entity(entity)
    end
  end
  game.print({"utilization-monitor-reset", global.entity_count, global.entity_rate})
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
    global.entity_count = 0
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


local function update_always_perf(value)
  global.always_perf = value
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
  if global.need_reset or global.version ~= VERSION then
    global.need_reset = nil
    reset()
    return
  end

  -- Prepare for faster access
  local next = next
  local entity_data = global.entity_data
  local entity_rate = global.entity_rate

  -- Prepare iteration data holders
  local id = global.last_id
  local data = nil

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
  for i = 1, entity_rate do
    if id == nil then    -- This stops the loop if we get to the end of our entities list.
      break
    end
    if data.entity.valid then
      local status = data.entity.status
      local working_value = working_value_calc(data)
      add2(data.min_avg, working_value)
      if data.label then
        update_label(data)
      end
    else
      remove_entity(id)
    end
    id, data = next(entity_data, id)
  end

  -- Update state for next run
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
    global.need_reset = true
  end
end

-- Print out some basic stats.
local function stats()
  game.print({"utilization-monitor-stats", global.entity_count, global.entity_rate})
end

local function recompute_secs(recomp_type)
  -- Rebuild just for this type.
  to_remove = { }
  for _, data in pairs(global.entity_data) do
    if data.entity.type == recomp_type then
      table.insert(to_remove, data.entity.unit_number)
    end
  end
  for _, num in pairs(to_remove) do
    remove_entity(num)
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type=recomp_type}) do
      add_entity(entity)
    end
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
    
  elseif event.setting == "utilization-monitor-always-perf" then
    update_always_perf(settings.global["utilization-monitor-always-perf"].value)    

  elseif event.setting == "utilization-monitor-entities-per-tick" then
    global.entity_rate_max = settings.global["utilization-monitor-entities-per-tick"].value
    global.max_warning = false
    recompute_rate()
    stats()
  
  elseif string.sub(event.setting,1,25) == "utilization-monitor-color" then
    recompute_colors()
    update_show_labels(settings.global["utilization-monitor-show-labels"].value)
  
  elseif string.sub(event.setting,1,24) == "utilization-monitor-secs" then
    recompute_secs(string.sub(event.setting,26))
    
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
  commands.add_command("umreset", {"utilization-monitor-help-reset"}, reset)
  commands.add_command("umstats", {"utilization-monitor-help-stats"}, stats)
  add_event_handlers()
end
