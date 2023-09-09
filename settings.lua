data:extend{
    {
        type = "bool-setting",
        name = "utilization-monitor-enabled",
        setting_type = "runtime-global",
        default_value = true,
        order = "utilization-monitor-a"
    },
    {
        type = "bool-setting",
        name = "utilization-monitor-always-perf",
        setting_type = "runtime-global",
        default_value = false,
        order = "utilization-monitor-b"
    },
    {
        type = "bool-setting",
        name = "utilization-monitor-show-labels",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "utilization-monitor-c"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-entities-per-tick",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 1,
        maximum_value = 20000,
        order = "utilization-monitor-d"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-assembling-machine",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s01"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-furnace",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s02"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-mining-drill",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s03"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-lab",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s04"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-boiler",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s05"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-generator",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s06"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-reactor",
        setting_type = "runtime-global",
        default_value = 1200,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s07"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-pump",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s08"
    },            
    {
        type = "int-setting",
        name = "utilization-monitor-secs-offshore-pump",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s09"
    },    
    {
        type = "string-setting",
        name = "utilization-monitor-color-spoolup",
        setting_type = "runtime-global",
        default_value = "Orange",
        allowed_values =  { "Off (do not show)", "White", "Black", "Red", "Green", "Blue", "Yellow", "Orange" },
        order = "utilization-monitor-t"
    },
    {
        type = "string-setting",
        name = "utilization-monitor-color-steady",
        setting_type = "runtime-global",
        default_value = "White",
        allowed_values =  { "White", "Black", "Red", "Green", "Blue", "Yellow", "Orange" },
        order = "utilization-monitor-u"
    },       
    {
        type = "string-setting",
        name = "utilization-monitor-label-pos",
        setting_type = "runtime-global",
        default_value = "Upper Left",
        allowed_values =  { "Upper Left", "Upper Center", "Upper Right", "Middle Left", "Middle Center", "Middle Right", "Bottom Left", "Bottom Center", "Bottom Right" },
        order = "utilization-monitor-v"
    },
    {
        type = "bool-setting",
        name = "utilization-monitor-label-alt",
        setting_type = "runtime-global",
        default_value = false,
        order = "utilization-monitor-w"
    },
    {
        type = "bool-setting",
        name = "utilization-monitor-force-player",
        setting_type = "runtime-global",
        default_value = true,        
        order = "utilization-monitor-x"
    },	
    {
        type = "double-setting",
        name = "utilization-monitor-label-size",
        setting_type = "runtime-global",
        default_value = 1.0,
        minimum_value = 0.1,
        maximum_value = 10.0,
        order = "utilization-monitor-y"
    },     
}
