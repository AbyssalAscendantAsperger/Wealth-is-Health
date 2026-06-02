dofile_once("data/scripts/lib/mod_settings.lua")
local mod_id = "gold_regen"
mod_settings_version = 1
mod_settings = {
    {
        id = "interval",
        ui_name = "Regen Interval (Normal Mode)",
        ui_description = "Time between each gold spend to heal 1 HP.\nApplies when HP is near full (above 98%) or when Turbo Mode is disabled.\nRange: 0.5s to 5.0s",
        value_default = 0.8,
        value_min = 0.5,
        value_max = 5.0,
        value_display_multiplier = 1,
        value_display_formatting = " $0 s",
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        ui_fn = mod_setting_vertical_spacing,
        not_setting = true,
    },
    {
        id = "min_gold_threshold",
        ui_name = "Minimum Gold Threshold",
        ui_description = "Do not heal if current gold is less than this amount.\nEnsures you always keep at least X gold in reserve.\n(Default: 0)",
        value_default = 0,
        value_min = 0,
        value_max = 10000,
        value_integer = true,
        value_display_multiplier = 1,
        value_display_formatting = " $0 gold",
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        ui_fn = mod_setting_vertical_spacing,
        not_setting = true,
    },
    {
        id = "enable_turbo",
        ui_name = "ENABLE SPEED GOVERNOR (TURBO MODE)",
        ui_description = "AUTO FAST HEAL: Continuously spend gold to heal 1% Max HP per tick when HP is below 98%.\nHelps recover health very quickly in mid/late game.\nAutomatically stops when HP is near full to save gold.\n\nNote: 100% safe activation only. No refund logic needed.",
        value_default = false,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
}
function ModSettingsUpdate(init_scope)
    mod_settings_update(mod_id, mod_settings, init_scope)
end
function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end
function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end