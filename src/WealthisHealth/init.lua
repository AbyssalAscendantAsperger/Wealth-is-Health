dofile_once("data/scripts/lib/utilities.lua")

local MOD_ID = "gold_regen"
local SETTING_KEY_INTERVAL = MOD_ID .. ".interval"
local SETTING_KEY_TURBO    = MOD_ID .. ".enable_turbo"
local SETTING_KEY_MIN_GOLD = MOD_ID .. ".min_gold_threshold"

local HP_PER_HEAL = 0.04
local FPS = 60

local frame_counter = 0
local player_entity = nil

local function GetPlayer()
    local players = EntityGetWithTag("player_unit")
    if players and #players > 0 then
        return players[1]
    end
    return nil
end

local function IsPlayerAlive(entity)
    return entity ~= nil and EntityGetIsAlive(entity)
end

local function GetCurrentGold(entity)
    local wallet = EntityGetFirstComponent(entity, "WalletComponent")
    if wallet then
        return ComponentGetValue2(wallet, "money")
    end
    return 0
end

local function GetCurrentHP(entity)
    local dmg = EntityGetFirstComponent(entity, "DamageModelComponent")
    if dmg then
        local hp     = ComponentGetValue2(dmg, "hp")
        local max_hp = ComponentGetValue2(dmg, "max_hp")
        return hp, max_hp, dmg
    end
    return nil, nil, nil
end

local function SetHP(dmg_comp, new_hp)
    if ComponentSetValue2 then
        ComponentSetValue2(dmg_comp, "hp", new_hp)
    else
        ComponentSetValue(dmg_comp, "hp", tostring(new_hp))
    end
end

local function SpendGold(entity, amount)
    local wallet = EntityGetFirstComponent(entity, "WalletComponent")
    if not wallet then return false end

    local current = ComponentGetValue2(wallet, "money")
    if current < amount then return false end

    if ComponentSetValue2 then
        ComponentSetValue2(wallet, "money", current - amount)
    else
        edit_component(entity, "WalletComponent", function(comp_id, vars)
            vars.money = current - amount
        end)
    end

    return true
end

local function GetIntervalFrames()
    local seconds = ModSettingGet(SETTING_KEY_INTERVAL)
    if type(seconds) ~= "number" or seconds < 0.5 then seconds = 0.5 end
    if seconds > 5.0 then seconds = 5.0 end
    return math.floor(seconds * FPS + 0.5)
end

local function GetMinGoldThreshold()
    local min_gold = ModSettingGet(SETTING_KEY_MIN_GOLD)
    if type(min_gold) ~= "number" then return 0 end
    if min_gold < 0 then return 0 end
    return math.floor(min_gold)
end

local function DoRegenTick()
    player_entity = GetPlayer()
    if not IsPlayerAlive(player_entity) then return end

    local gold              = GetCurrentGold(player_entity)
    local hp, max_hp, dmg_comp = GetCurrentHP(player_entity)

    if not hp or not max_hp or not dmg_comp then return end

    local min_gold         = GetMinGoldThreshold()
    local is_turbo_enabled = ModSettingGet(SETTING_KEY_TURBO)
    local epsilon          = 0.001

    if is_turbo_enabled then
        local missing_hp    = max_hp - hp
        local gap_threshold = max_hp * 0.02

        local turbo_heal_val = max_hp * 0.01
        local turbo_cost     = math.max(1, math.floor((turbo_heal_val / HP_PER_HEAL) + 0.5))

        if missing_hp > (gap_threshold + epsilon)
           and gold >= min_gold
           and gold >= turbo_cost then

            local spent = SpendGold(player_entity, turbo_cost)
            if spent then
                SetHP(dmg_comp, math.min(hp + turbo_heal_val, max_hp))
                return
            end
        end
    end

    if gold < min_gold then return end
    if gold < 1 then return end
    if (max_hp - hp) < epsilon then return end

    local spent = SpendGold(player_entity, 1)
    if not spent then return end

    SetHP(dmg_comp, math.min(hp + HP_PER_HEAL, max_hp))
end

function OnPlayerSpawned(entity)
    player_entity = entity
    frame_counter = 0
end

function OnWorldPostUpdate()
    if not IsPlayerAlive(player_entity) then
        player_entity = GetPlayer()
        if not IsPlayerAlive(player_entity) then return end
    end

    frame_counter = frame_counter + 1
    local interval = GetIntervalFrames()

    if frame_counter > interval then
        frame_counter = interval
    end

    if frame_counter >= interval then
        frame_counter = 0
        DoRegenTick()
    end
end