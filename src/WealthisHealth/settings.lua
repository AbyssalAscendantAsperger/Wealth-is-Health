dofile_once("data/scripts/lib/mod_settings.lua")

local mod_id = "gold_regen"
mod_settings_version = 2

mod_settings = {
    {
        id = "interval",
        ui_name = "Regen Interval (Normal Mode)",
        ui_description = "Time between each heal tick. Range: 0.5s to 5.0s",
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
        ui_description = "Do not heal if gold is below this amount.",
        value_default = 0,
        value_min = 0,
        value_max = 100000,
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
        id = "stable_ticks",
        ui_name = "Stable HP Ticks Required",
        ui_description = "How many consecutive ticks without taking damage before healing is allowed. 0 = heal anytime. 2 = must be safe for 2 ticks first. Max 10.",
        value_default = 2,
        value_min = 0,
        value_max = 10,
        value_integer = true,
        value_display_multiplier = 1,
        value_display_formatting = " $0 tick(s)",
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        ui_fn = mod_setting_vertical_spacing,
        not_setting = true,
    },
    {
        id = "enable_turbo",
        ui_name = "ENABLE SPEED GOVERNOR (TURBO MODE)",
        ui_description = "Fast heal: spend gold to restore 1% Max HP per tick when below 98% HP.",
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