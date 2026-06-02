dofile_once("data/scripts/lib/utilities.lua")
local MOD_ID = "gold_regen"
local SETTING_KEY_INTERVAL = MOD_ID .. ".interval"
local SETTING_KEY_TURBO = MOD_ID .. ".enable_turbo"
local SETTING_KEY_MIN_GOLD = MOD_ID .. ".min_gold_threshold"
local HP_PER_HEAL = 0.04
local FPS = 60
local frame_counter = 0
local player_entity = nil
local HAS_VALUE2 = ComponentGetValue2 ~= nil and ComponentSetValue2 ~= nil
local function safe_get(comp, field)
    if HAS_VALUE2 then
        return ComponentGetValue2(comp, field)
    else
        local v = ComponentGetValue(comp, field)
        return tonumber(v) or v
    end
end
local function safe_set(comp, field, value)
    if HAS_VALUE2 then
        ComponentSetValue2(comp, field, value)
    else
        ComponentSetValue(comp, field, tostring(value))
    end
end
local function safe_get_int(comp, field)
    if ComponentGetValueInt then
        return ComponentGetValueInt(comp, field)
    else
        return math.floor(safe_get(comp, field) or 0)
    end
end
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
        return safe_get_int(wallet, "money")
    end
    return 0
end
local function GetCurrentHP(entity)
    local dmg = EntityGetFirstComponent(entity, "DamageModelComponent")
    if dmg then
        local hp = safe_get(dmg, "hp")
        local max_hp = safe_get(dmg, "max_hp")
        return hp, max_hp, dmg
    end
    return nil, nil, nil
end
local function SpendGold(entity, amount)
    local wallet = EntityGetFirstComponent(entity, "WalletComponent")
    if not wallet then return false end
    local current = safe_get_int(wallet, "money")
    if current < amount then return false end
    safe_set(wallet, "money", current - amount)
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
    local gold = GetCurrentGold(player_entity)
    local hp, max_hp, dmg_comp = GetCurrentHP(player_entity)
    if not hp or not max_hp or not dmg_comp then return end
    local min_gold = GetMinGoldThreshold()
    local is_turbo_enabled = ModSettingGet(SETTING_KEY_TURBO)
    if is_turbo_enabled then
        local fresh_hp, fresh_max_hp, fresh_dmg = GetCurrentHP(player_entity)
        local fresh_gold = GetCurrentGold(player_entity)
        if fresh_hp and fresh_max_hp and fresh_dmg then
            local missing_hp = fresh_max_hp - fresh_hp
            local gap_threshold = fresh_max_hp * 0.02
            local epsilon = 0.001
            local turbo_heal_val = fresh_max_hp * 0.01
            local turbo_cost = math.floor((turbo_heal_val / HP_PER_HEAL) + 0.5)
            if missing_hp > (gap_threshold + epsilon) and fresh_gold >= min_gold and fresh_gold >= turbo_cost then
                local spent = SpendGold(player_entity, turbo_cost)
                if spent then
                    local new_hp = fresh_hp + turbo_heal_val
                    if new_hp > fresh_max_hp then new_hp = fresh_max_hp end
                    safe_set(fresh_dmg, "hp", new_hp)
                    local x,y = EntityGetTransform(player_entity)
                    GameCreateParticle("gold", x, y-5, 5, 0, 0, true, false)
                    EntityLoad("data/entities/particles/gold_pickup.xml", x, y-5)
                    return
                end
            end
        end
    end
    if gold < min_gold then return end
    if gold < 1 then return end
    if hp >= max_hp then return end
    local spent = SpendGold(player_entity, 1)
    if not spent then return end
    local new_hp = hp + HP_PER_HEAL
    if new_hp > max_hp then new_hp = max_hp end
    safe_set(dmg_comp, "hp", new_hp)
    local x,y = EntityGetTransform(player_entity)
    GameCreateParticle("gold", x, y-5, 5, 0, 0, true, false)
    EntityLoad("data/entities/particles/gold_pickup.xml", x, y-5)
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
    if frame_counter >= interval then
        frame_counter = 0
        DoRegenTick()
    end
end