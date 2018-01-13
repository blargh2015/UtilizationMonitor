data:extend{
    {
        type = "bool-setting",
        name = "utilization-monitor-show-labels",
        setting_type = "runtime-global",
        default_value = true,
        order = "utilization-monitor-a"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-entities-per-tick",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 1,
        maximum_value = 20000,
        order = "utilization-monitor-b"
    },
	{
        type = "int-setting",
        name = "utilization-monitor-iterations-per-update",
        setting_type = "runtime-global",
        default_value = 60,
        minimum_value = 1,
        maximum_value = 300,
        order = "utilization-monitor-c"
    },
}
