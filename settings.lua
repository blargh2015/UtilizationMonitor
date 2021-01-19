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
        setting_type = "runtime-global",
        default_value = true,
        order = "utilization-monitor-d"
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
        order = "utilization-monitor-s1"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-furnace",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s2"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-mining-drill",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s3"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-lab",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s4"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-boiler",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s5"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-generator",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s6"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-secs-reactor",
        setting_type = "runtime-global",
        default_value = 1200,
        minimum_value = 0,
        maximum_value = 3600,
        order = "utilization-monitor-s7"
    },
    {
        type = "string-setting",
        name = "utilization-monitor-color-spoolup",
        setting_type = "runtime-global",
        default_value = "Orange",
        allowed_values =  { "Off (do not show)", "White", "Black", "Red", "Green", "Blue", "Yellow", "Orange" },
        order = "utilization-monitor-t1"
    },
    {
        type = "string-setting",
        name = "utilization-monitor-color-steady",
        setting_type = "runtime-global",
        default_value = "White",
        allowed_values =  { "White", "Black", "Red", "Green", "Blue", "Yellow", "Orange" },
        order = "utilization-monitor-t1"
    },      
}
