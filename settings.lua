data:extend{
    {
        type = "bool-setting",
        name = "utilization-monitor-enabled",
        setting_type = "runtime-global",
        default_value = true,
        order = "utilization-monitor-aa[enabled]"
    },
    {
        type = "int-setting",
        name = "utilization-monitor-entities-per-tick",
        setting_type = "runtime-global",
        default_value = 1000,
        maximum_value = 20000,
        minimum_value = 1,
        order = "utilization-monitor-ab[enabled]"
    },
}
