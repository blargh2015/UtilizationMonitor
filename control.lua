-- The version of the data of this mod.
-- If this value does not match the data have to be reset.
local VERSION = "65"
--[[--
UM data definition:

storage:

-- The last/currently running UMData version.
storage.version : string

-- The unit_number of the next entity to be updated.
storage.last_id : uint

-- The main data container with all tracked entity data.  Indexed by entity.unit_number.
storage.entity_data : Table<UMData>

-- Limits the maximum number entities to be processed per tick. The other entities will be processed in the next tick.
storage.entity_rate_max : uint (configurable)

-- Whether we have warned this session about the rate exceeding limits.
storage.max_warning : boolean

-- Whether the mod should always compute performance percentage
storage.always_perf : boolean (configurable)

-- Should spooling up numbers be rendered at all?
storage.render_spoolup : boolean

-- Color for spooling up
storage.color_spoolup : table

-- Color for steady
storage.color_steady : table

UMData:

-- The entity that will by tracked by this data.
UMData.entity : Entity

-- The long term average processing time.
UMData.min_avg : UMAvg

-- The label for the entity associated with this data entry.
UMData.label : Entity or nil

-- Temporary variable for storing the last progress value to determine whether there are changes since last calculation.
UMData.last_progress : any

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

-- Useful commands for debugging (stored here):
-- See all data stored for an entity (replaced the 8613 with the entity ID number):
/c __UtilizationMonitorBlargh__ game.player.print(serpent.dump(storage.entity_data[8613]))

]]

-----------------------
-- Utility functions --
-----------------------

local table = require("__flib__.table")
local math = require("__flib__.math")

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
  if avg.next_index == 1 and not avg.is_stable then
    avg.is_stable = true
  end
  -- avg.avg = total / avg.count
end

--- Formats the given value to be used as label text.
--
-- @param value:numeric - The numeric value representing the average working state. Expects values between 0 and 1.
-- @returns string - The new text for the label.
--
local function format_label(value)
  return math.abs(math.clamp(math.round(value * 100), 0, 100)) .. "%"
end

--- Updates a UMData's label object.
--
-- @param data:UMData - The data to update.
--
local function update_label(data)
  -- Data label could be nil if we've hidden and disabled labels.
  if data.label == nil then
    return
  end
  if data.min_avg.is_stable then
    data.label.color = storage.color_steady
    data.label.text = format_label(data.min_avg.total / data.min_avg.count)
  else
    if storage.render_spoolup and data.min_avg.next_index > 1 then
      data.label.text = format_label(data.min_avg.total / (data.min_avg.next_index - 1))
      data.label.color = storage.color_spoolup
    else
      data.label.text = ""
    end
  end
end

--- Calculate where the label should be and it's orientation based on configuration
--
-- @param label:Label ID - The render.draw_text ID of the label to position
-- @param entity:LuaEntity - The entity object to set the label to.
--
local function set_label_offset(label, entity)
  local lp = settings.global["utilization-monitor-label-pos"].value
  local off = {0, 0}
  local ha = "center"
  local va = "middle"
  -- Calculate relative left_top, right_bottom, and center_middle based on entity's selection_box and position.
  local lt = { x=entity.selection_box.left_top["x"] - entity.position["x"], y=entity.selection_box.left_top["y"] - entity.position["y"]}
  local rb = { x=entity.selection_box.right_bottom["x"] - entity.position["x"], y=entity.selection_box.right_bottom["y"] - entity.position["y"] }
  local cm = { x=(entity.selection_box.left_top["x"] + entity.selection_box.right_bottom["x"])/2 - entity.position["x"], y=(entity.selection_box.left_top["y"] + entity.selection_box.right_bottom["y"])/2 - entity.position["y"] }
  local off = cm
  if lp == "Upper Left" then
    off =  lt
    ha = "left"
    va = "top"
  elseif lp == "Upper Center" then
    off = { x=cm["x"], y=lt["y"] }
    ha = "center"
    va = "top"
  elseif lp == "Upper Right" then
    off = { x=rb["x"], y=lt["y"] }
    ha = "right"
    va = "top"
  elseif lp == "Middle Left" then
    off = { x=lt["x"], y=cm["y"] }
    ha = "left"
    va = "middle"
  elseif lp == "Middle Right" then
    off = { x=rb["x"], y=cm["y"] }
    ha = "right"
    va = "middle"
  elseif lp == "Bottom Left" then
    off = { x=lt["x"], y=rb["y"] }
    ha = "left"
    va = "bottom"
  elseif lp == "Bottom Center" then
    off = { x=cm["x"], y=rb["y"] }
    ha = "center"
    va = "bottom"
  elseif lp == "Bottom Right" then
    off = rb
    ha = "right"
    va = "bottom"
  end
  label.target = {entity = entity, offset = off }
  label.alignment = ha
  label.vertical_alignment = va
end


--- Creates a label for the entity associated with the given data. Handles if no labels should be shown,
--- and if called with or without an existing label.
--
-- @param data:UMData - The data associated with the entity the label should be created for.
--
local function add_label(data)
  if #storage.players_with_labels== 0 then
    return
  end
  local entity = data.entity
  if data.label == nil then
   data.label = rendering.draw_text{text = "", surface = entity.surface, target = entity, force = entity.force, color = storage.color_spoolup, players = storage.players_with_labels, only_in_alt_mode=settings.global["utilization-monitor-label-alt"].value,scale=settings.global["utilization-monitor-label-size"].value}
  else
    -- Ensure label is set up correctly, as per current settings
    data.label.players = storage.players_with_labels
    data.label.only_in_alt_mode = settings.global["utilization-monitor-label-alt"].value
    data.label.scale = settings.global["utilization-monitor-label-size"].value
  end
  set_label_offset(data.label, data.entity)
  
  -- This function can get called on already-running data if Ctrl-U is tapped, but update_label only changes the color on state change from spoolup to steady.   Make sure the color is right here.
  if data.min_avg.is_stable then
    data.label.color = storage.color_steady
  end
  update_label(data)
end

--- Removes the label for the entity associated with the given data if it does exist.
--
-- @param data:UMData - The data associated with the entity the label should be removed from.
--
local function remove_label(data)
  if data and data.label then
    data.label.destroy()
    data.label = nil
  end
end

--- Removes all labels for the entries on the given data table.
--
-- @param entity_data:Table<UMData> - The table that contains all data that should be purged.
--
local function purge_labels(entity_data)
  for _, data in pairs(storage.entity_data) do
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
  elseif t == "boiler" and entity.burner ~= nil then  -- TODO: Remove the second restriction when heat exchangers get figured out.
    return true
  elseif t == "offshore-pump" then
    return true
  elseif t == "pump" then
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
    if settings.global["utilization-monitor-force-player"].value == false or entity.force.name == 'player' then
      -- Init UMData for this new entity.
      local id = entity.unit_number
      local data = {
        entity = entity,
        type = entity.type,
        min_avg = { values = {}, next_index = 1, total = 0, count = settings.global["utilization-monitor-secs-" .. entity.type].value, is_stable = false},
        sec_avg = { values = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}, is_stable = false, next_index = 1, total = 0, count = 60},      
      }
      if data.min_avg.count == 0 then  -- The counting of this type of object has been configured disable.
        return false
      end
      for i = 1, data.min_avg.count do
        table.insert(data.min_avg.values, 0)
      end
      
      -- Set special cache values for some types so we don't have to recalculate/fetch them every time.
      if data.type == "generator" then
        data.mep = data.entity.prototype.get_max_energy_production(entity.quality)
      elseif data.type == "boiler" then
        -- This gets complex, as while we can get the current flow rate in units per tick, the maximum (expected) of that value has to be calculated from the energy values.
        influidproto = data.entity.prototype.fluidbox_prototypes[1]
        -- Apparently some mods add in boilers that don't have a specific fluid they take in.  Check for it, and we'll mark this object untrackable for now.
        if influidproto.filter == nil then
          return false
        end
        intemp = influidproto.filter.default_temperature        -- C
        inheat = influidproto.filter.heat_capacity              -- J needed to raise 1 deg C
        outtemp = data.entity.prototype.target_temperature      -- C
        maxenergy = data.entity.prototype.get_max_energy_usage(entity.quality)      -- W = J/s 
        data.maxflow = maxenergy / ((outtemp - intemp) * inheat)
      end
      
      -- Add object, emit warning if we just tripped over the limit per tick.
      storage.entity_data[id] = data
      if table_size(storage.entity_data) > storage.entity_rate_max and storage.max_warning ~= true then
        game.print({"utilization-monitor-limit-exceeded", storage.entity_rate_max})
        storage.max_warning = true
      end
      add_label(data)
      return true
    end
  end
  return false
end

--- Remove the given entity from being tracked by UM.
--
-- @param id:uint - The id of the entity to stop tracking.
--
local function remove_entity(id)
  local data = storage.entity_data[id]
  if data then
    storage.entity_data[id] = nil -- Prevent memory leaks
    -- Remove label
    remove_label(data)
  end
end


--- Returns performance of a machine, based on type and energy available or used
---
-- @param data:UMData - The entity we need to calculator for
-- @return float - A number from 0.0 to 1.0 for the performance of the entity currently
--
local function calc_energy_ratio(entity)
  if entity.prototype.energy_usage == nil then
    return 1.0
  end
  local reqenergy = entity.prototype.energy_usage * (1 + entity.consumption_bonus)
  return math.min(reqenergy, entity.energy) / reqenergy
end  

local function working_value_calc(data)
  if data.type == "generator" then
    return data.entity.energy_generated_last_tick / data.mep
  elseif data.type == "pump" or data.type == "offshore-pump" then
    local fbc = data.entity.fluidbox.get_capacity(1)
    local fb = data.entity.fluidbox[1]
    local fa = fbc
    if fb ~= nil then
      fa = fb.amount
    end
    return math.min(1.0, (fbc - fa) / data.entity.prototype.pumping_speed) * calc_energy_ratio(data.entity)
  elseif data.type == "boiler" then
    -- If this is a burner, measure it by its heat
    if data.entity.burner ~= nil then 
      return 1 - (data.entity.burner.heat / data.entity.burner.heat_capacity)
    else
      return 1.0  -- TODO: for now - this is where heat exchanger code needs to go in the future.
    end
  end

  -- Now for common checks based on status and the value of the "Always calculate energy effect" checkbox (always_perf)
  local entstatus = data.entity.status
  
  if (entstatus == defines.entity_status.working and storage.always_perf == false) then
    return 1.0
  elseif (entstatus == defines.entity_status.working and storage.always_perf == true) or entstatus == defines.entity_status.low_power then
--- Thanks to boskid and eradicator at https://forums.factorio.com/viewtopic.php?f=25&t=93820 for answering this.  We need to recalc reqenergy each time as modules, etc. can change.
    return calc_energy_ratio(data.entity)
  else
    return 0.0
  end
end

-- Rethink our color settings if needed.
local function recompute_colors()
  local color_map = {White={r=1,g=1,b=1,a=1}, Black={r=0,g=0,b=0,a=1}, Red={r=1,g=0,b=0,a=1}, Green={r=0,g=1,b=0,a=1}, Blue={r=0,g=0,b=1,a=1}, Yellow={r=1,g=1,b=0,a=1}, Orange={r=1,g=0.5,b=0,a=1} }
  if settings.global["utilization-monitor-color-spoolup"].value == "Off (do not show)" then
    storage.render_spoolup = false
  else
    storage.render_spoolup = true
    storage.color_spoolup = color_map[settings.global["utilization-monitor-color-spoolup"].value]
  end
  storage.color_steady = color_map[settings.global["utilization-monitor-color-steady"].value]
end  


-- Recalculates all labels and updates text appropriately.
local function update_show_labels()
  -- Determine new player show array
  new_pwl = {}

  for id, data in pairs(game.players) do
    if data.mod_settings["utilization-monitor-show-labels"].value then
      table.insert(new_pwl, id)
    end
  end

  storage.players_with_labels = new_pwl
  -- If no players are left having labels visible, delete them all together and disable.
  if #new_pwl == 0 then
    for _, data in pairs(storage.entity_data) do 
      remove_label(data)
    end
  else  
	  -- Reset the label entirely. add_label will recreate if needed, and apply all settings.
	  for _, data in pairs(storage.entity_data) do  
      add_label(data)
	  end
  end
end

--- Hard resets all data used by UM.
--
local function reset()
  -- clean up storage
  keyset = {}
  for k, _ in pairs(storage) do
    keyset[#keyset+1] = k
  end
  for _,k in pairs(keyset) do
    storage[k] = nil
  end
  storage = {}
  -- end cleanup

  -- Purge new-style labels.
  rendering.clear("UtilizationMonitorBlargh")

  storage.version = VERSION
  storage.last_id = nil
  storage.entity_data = {}
  storage.entity_rate_max = settings.global["utilization-monitor-entities-per-tick"].value
  storage.always_perf = settings.global["utilization-monitor-always-perf"].value
  storage.max_warning = false
  storage.update_marker = 0
  recompute_colors()
  update_show_labels()

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type={"assembling-machine","furnace","mining-drill","lab","boiler","generator","reactor","offshore-pump","pump"}}) do
      add_entity(entity)
    end
  end
  game.print({"utilization-monitor-reset", table_size(storage.entity_data)})
end


--- Shows internal information about an entity. Handy for debugging modded entities.
---
local function debugprinted(field, val)
  game.print({"utilization-monitor-debuginfo-ed", field, (val ~= nil and val or "nil")})
end
  
local function debugprint(entity)
  local un = entity.unit_number
  game.print({"utilization-monitor-debuginfo-line1", un, entity.type, entity.name, entity.status})
  game.print({"utilization-monitor-debuginfo-return", "can_determine_working", can_determine_working(entity)})
  if storage.entity_data[un] == nil then
    game.print({"utilization-monitor-debuginfo-nottracked"})
  else
    game.print(serpent.line(storage.entity_data[un]))
    game.print({"utilization-monitor-debuginfo-return", "working_value_calc", working_value_calc(storage.entity_data[un])})
  end
  if entity.type == "generator" then
    debugprinted("energy_generated_last_tick", entity.energy_generated_last_tick)
  end
  if entity.fluidbox.valid and #entity.fluidbox > 0 then  
    game.print({"utilization-monitor-debuginfo-ed", "#fluidbox", #entity.fluidbox})
    if entity.type == "pump" or entity.type == "offshore-pump" then
      game.print({"utilization-monitor-debuginfo-ed", "prototype.pumping_speed", entity.prototype.pumping_speed})
    end
    for i = 1, #entity.fluidbox do
      -- game.print({"utilization-monitor-debuginfo-edsub", "fluidbox.get_flow", i, entity.fluidbox.get_flow(i)})
      -- game.print({"utilization-monitor-debuginfo-edsub", "fluidbox.get_connections", i, entity.fluidbox.get_connections(i)})
      game.print({"utilization-monitor-debuginfo-edsub", "fluidbox.get_capacity", i, entity.fluidbox.get_capacity(i)})
      if entity.fluidbox[i] == nil then
        game.print({"utilization-monitor-debuginfo-edsub", "fluidbox.amount", i, "nil"})
      else
        game.print({"utilization-monitor-debuginfo-edsub", "fluidbox.amount", i, entity.fluidbox[i].amount})
      end
    end
  end
  debugprinted("prototype.energy_usage", entity.prototype.energy_usage)
  debugprinted("consumption_bonus", entity.consumption_bonus)
  debugprinted("energy", entity.energy)
end

local function debuginfo()
  if game.player.selected == nil then
    game.print({"utilization-monitor-debuginfo-noentity"})
    return
  end
  debugprint(game.player.selected)
end

-----------------------------
-- Configuration functions --
-----------------------------

--- Re-evaluates enabled state and executes the necessary operations (reset/remove labels).
--
local function update_enabled()
  if not settings.global["utilization-monitor-enabled"].value then
    purge_labels(storage.entity_data)
    storage.entity_data = {} -- Prevent memory leaks
    remove_event_handlers()
  else
    add_event_handlers()
    reset()
  end
end

local function update_always_perf(value)
  storage.always_perf = value
end

---------------------
-- Event functions --
---------------------

local function on_init()
  reset()
end

local function on_load()
end

local function on_tick(event)
  -- Check state
  if storage.need_reset or storage.version ~= VERSION then
    storage.need_reset = nil
    reset()
    return
  end

  -- Prepare for faster access
  local next = next
  local entity_data = storage.entity_data
  local entity_rate = storage.entity_rate_max

  -- Prepare iteration data holders
  local id = storage.last_id
  local data = nil
  local cur_tick = event.tick

  if id then
    data = entity_data[id]
    -- Fix for #17: The next data to be processed has been removed between the ticks.
    if data == nil then
      id, data = next(entity_data, nil)
    end
  else
    id, data = next(entity_data, nil)
  end

  -- We update labels once a second. 
  if cur_tick % 60 == 0 then
    storage.update_marker = table_size(storage.entity_data)
  end  
  local gum = storage.update_marker

  -- Actually execute the update
  for i = 1, entity_rate do
    if id == nil then    -- This stops the loop if we get to the end of our entities list.
      break
    end
    if data.entity.valid then
      local status = data.entity.status
      local working_value = working_value_calc(data)
      add2(data.sec_avg, working_value)    
      if gum > 0 then     
        if data.sec_avg.is_stable then
          add2(data.min_avg, data.sec_avg.total / 60)
        else
          add2(data.min_avg, data.sec_avg.total / (data.sec_avg.next_index - 1))
        end 
        update_label(data)
        gum = gum - 1
      end
    else
      remove_entity(id)
    end
    id, data = next(entity_data, id)
  end

  -- Update state for next run
  storage.update_marker = gum
  storage.last_id = id
end

--- Event handler for newly build entities.
--
-- @param event:Event - The event contain the information about the newly build entity.
--
local function on_built(event)
  add_entity(event.entity)
end

--- Event handler for script created entities.
--
-- @param event:Event - The event contain the information about the newly build entity.
--
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

-- Event handler for an entity being cloned.  Not used in normal games, but /editor and some mods do (notably Warptorio2
-- and Space Exploration). 
--
-- @param event:Event - The event contain the information about the cloned entity
--
local function on_cloned(event)  
  -- Test to see if this is an entity we're tracking before bothering with the clone.
  if storage.entity_data[event.source.unit_number] ~= nil then
    -- Since this is a clone, we'll copy copy over the statistics, then recreate our label.
    -- game.print("Cloning from " .. event.source.unit_number .. " to " .. event.destination.unit_number)
    add_entity(event.destination)
    storage.entity_data[event.destination.unit_number].min_avg = table.deep_copy(storage.entity_data[event.source.unit_number].min_avg)
    storage.entity_data[event.destination.unit_number].sec_avg = table.deep_copy(storage.entity_data[event.source.unit_number].sec_avg)
    update_label(storage.entity_data[event.destination.unit_number])
  end
end

--- Event handler for a changed configuration and mods.
--
-- @param event:Event - The event containing the details of the changes.
--
local function on_configuration_changed(event)
  -- Any MOD has been changed/added/removed, including base game updates.
  if event.mod_changes then
    storage.need_reset = true
  end
end

-- Print out some basic stats.
local function stats()
  game.print({"utilization-monitor-stats", table_size(storage.entity_data)})
end

local function recompute_secs(recomp_type)
  -- Rebuild just for this type.
  to_remove = { }
  for _, data in pairs(storage.entity_data) do
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
    update_enabled(settings.global["utilization-monitor-enabled"].value)

  elseif event.setting == "utilization-monitor-show-labels" or event.setting == "utilization-monitor-label-alt" or event.setting == "utilization-monitor-label-pos" or event.setting == "utilization-monitor-label-size" then
    update_show_labels()

  elseif event.setting == "utilization-monitor-always-perf" then
    update_always_perf(settings.global["utilization-monitor-always-perf"].value)        

  elseif event.setting == "utilization-monitor-entities-per-tick" then
    storage.entity_rate_max = settings.global["utilization-monitor-entities-per-tick"].value
    storage.max_warning = false
    if table_size(storage.entity_data) > storage.entity_rate_max and storage.max_warning ~= true then
      game.print({"utilization-monitor-limit-exceeded", storage.entity_rate_max})
      storage.max_warning = true
    end    

  elseif string.sub(event.setting,1,25) == "utilization-monitor-color" then
    recompute_colors()
    update_show_labels()

  elseif string.sub(event.setting,1,24) == "utilization-monitor-secs" then
    recompute_secs(string.sub(event.setting,26))

  elseif event.setting == "utilization-monitor-force-player" then
    reset()
    
  end
end

--- Event handler for the toggle UM hotkey.
--
-- @param event - The event causing the toggle.
--
local function on_toggle_utilization_monitor(event)
  settings.global["utilization-monitor-enabled"] = {value=not settings.global["utilization-monitor-enabled"].value}
end

--- Event handler for the toggle UM labels hotkey.
--
-- @param event - The event causing the toggle.
--
local function on_toggle_utilization_monitor_labels(event)
  game.players[event.player_index].mod_settings["utilization-monitor-show-labels"] = {value=not game.players[event.player_index].mod_settings["utilization-monitor-show-labels"].value}
end

-----------------------------
-- Register event handlers --
-----------------------------

function add_event_handlers()
  event_filters = { {filter="type", type="assembling-machine"}, {filter="type", type="furnace"}, {filter="type", type="mining-drill"}, {filter="type", type="lab"}, {filter="type", type="boiler"},
    {filter="type", type="generator"}, {filter="type", type="reactor"}, {filter="type", type="offshore-pump"}, {filter="type", type="pump"}, {filter="name", name="utilization-monitor-statictext"} }
  script.on_event({defines.events.on_tick}, on_tick)
  script.on_event(defines.events.on_built_entity, on_built, event_filters)
  script.on_event(defines.events.on_robot_built_entity, on_built, event_filters)
  script.on_event(defines.events.script_raised_built, on_built_script, event_filters)
  script.on_event(defines.events.script_raised_revive, on_built_script, event_filters)
  script.on_event(defines.events.on_entity_died, on_destroyed, event_filters)
  script.on_event(defines.events.on_player_mined_entity, on_destroyed, event_filters)
  script.on_event(defines.events.on_robot_mined_entity, on_destroyed, event_filters)
  script.on_event(defines.events.script_raised_destroy, on_destroyed, event_filters)
  script.on_event(defines.events.on_entity_cloned, on_cloned, event_filters)
  script.on_event("toggle-utilization-monitor-labels", on_toggle_utilization_monitor_labels)
  commands.add_command("umreset", {"utilization-monitor-help-reset"}, reset)
  commands.add_command("umstats", {"utilization-monitor-help-stats"}, stats)
  commands.add_command("umdebug", {"utilization-monitor-debuginfo"}, debuginfo)
end

function remove_event_handlers()
  script.on_event({defines.events.on_tick}, nil)
  script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built, defines.events.script_raised_revive}, nil)
  script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.script_raised_destroy}, nil)
  script.on_event({defines.events.on_entity_cloned}, nil)
  script.on_event("toggle-utilization-monitor-labels", nil)
  commands.remove_command("umreset")
  commands.remove_command("umstats")
  commands.remove_command("umdebug")
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, update_settings)
script.on_event(defines.events.on_player_created, update_show_labels)
script.on_event("toggle-utilization-monitor", on_toggle_utilization_monitor)
if settings.global["utilization-monitor-enabled"].value then
  add_event_handlers()
end