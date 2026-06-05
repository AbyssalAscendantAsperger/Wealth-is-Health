dofile_once("data/scripts/lib/utilities.lua")

local MOD_ID = "gold_regen"
local SETTING_KEY_TURBO = MOD_ID .. ".enable_turbo"
local SETTING_KEY_MIN_GOLD = MOD_ID .. ".min_gold_threshold"
local SETTING_KEY_STABLE_TICKS = MOD_ID .. ".stable_ticks"

local HP_PER_HEAL = 0.04
local FPS = 60
local DAMAGE_GRACE_FRAMES = math.floor(1.0 * FPS + 0.5)
local CURSE_RETRY_COOLDOWN = math.floor(5.0 * FPS + 0.5)

local frame_counter = 0
local player_entity = nil
local healing_cooldown_frames = 0
local last_damage_frame = -9999
local stable_hp_ticks = 0
local previous_hp = nil

local function GetValue(comp, field)
	if ComponentGetValue2 then
		return ComponentGetValue2(comp, field)
	else
		local val = ComponentGetValue(comp, field)
		local num = tonumber(val)
		if num then return num end
		if val == "true" then return true end
		if val == "false" then return false end
		return val
	end
end

local function SetValue(comp, field, value)
	if ComponentSetValue2 then
		ComponentSetValue2(comp, field, value)
	else
		ComponentSetValue(comp, field, tostring(value))
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
		return GetValue(wallet, "money")
	end
	return 0
end

local function GetCurrentHP(entity)
	local dmg = EntityGetFirstComponent(entity, "DamageModelComponent")
	if dmg then
		local hp = GetValue(dmg, "hp")
		local max_hp = GetValue(dmg, "max_hp")
		return hp, max_hp, dmg
	end
	return nil, nil, nil
end

local function SetHP(dmg_comp, new_hp)
	SetValue(dmg_comp, "hp", new_hp)
end

local function TryHeal(dmg_comp, target_hp)
	local old_hp = GetValue(dmg_comp, "hp")
	SetHP(dmg_comp, target_hp)
	local new_hp = GetValue(dmg_comp, "hp")
	local expected_gain = target_hp - old_hp
	local actual_gain = new_hp - old_hp
	if actual_gain < expected_gain * 0.5 then
		healing_cooldown_frames = CURSE_RETRY_COOLDOWN
		return false
	end
	return true
end

local function SpendGold(entity, amount)
	local wallet = EntityGetFirstComponent(entity, "WalletComponent")
	if not wallet then return false end
	local current = GetValue(wallet, "money")
	if current < amount then return false end
	SetValue(wallet, "money", current - amount)
	return true
end

local function GetDynamicInterval(gold)
	if gold < 1000 then
		return 0.5
	elseif gold < 5000 then
		return 0.8
	elseif gold < 100000 then
		return 0.8 + (gold - 5000) / 95000 * 2.2
	elseif gold < 1000000 then
		return 3.0 + (gold - 100000) / 900000 * 2.0
	elseif gold < 2000000 then
		return 5.0 + (gold - 1000000) / 1000000 * 5.0
	else
		return nil
	end
end

local function GetIntervalFrames(gold)
	local seconds = GetDynamicInterval(gold)
	if seconds == nil then
		return nil
	end
	return math.floor(seconds * FPS + 0.5)
end

local function GetMinGoldThreshold()
	local min_gold = ModSettingGet(SETTING_KEY_MIN_GOLD)
	if type(min_gold) ~= "number" then return 0 end
	if min_gold < 0 then return 0 end
	return math.floor(min_gold)
end

local function GetStableTicksRequired()
	local ticks = ModSettingGet(SETTING_KEY_STABLE_TICKS)
	if type(ticks) ~= "number" then return 2 end
	ticks = math.floor(ticks)
	if ticks < 0 then return 0 end
	if ticks > 10 then return 10 end
	return ticks
end

local function IsPlayerStable(entity, current_hp)
	local current_frame = GameGetFrameNum()
	local stable_required = GetStableTicksRequired()
	if stable_required == 0 then
		previous_hp = current_hp
		return true
	end
	if previous_hp ~= nil and current_hp < previous_hp - 0.001 then
		last_damage_frame = current_frame
		stable_hp_ticks = 0
		previous_hp = current_hp
		return false
	end
	previous_hp = current_hp
	local frames_since_damage = current_frame - last_damage_frame
	if frames_since_damage < DAMAGE_GRACE_FRAMES then
		stable_hp_ticks = 0
		return false
	end
	stable_hp_ticks = stable_hp_ticks + 1
	if stable_hp_ticks < stable_required then
		return false
	end
	return true
end

local function DoRegenTick()
	if healing_cooldown_frames > 0 then
		healing_cooldown_frames = healing_cooldown_frames - 1
		return
	end
	player_entity = GetPlayer()
	if not IsPlayerAlive(player_entity) then
		previous_hp = nil
		stable_hp_ticks = 0
		return
	end
	local gold = GetCurrentGold(player_entity)
	local hp, max_hp, dmg_comp = GetCurrentHP(player_entity)
	if not hp or not max_hp or not dmg_comp then return end
	if not IsPlayerStable(player_entity, hp) then return end
	local min_gold = GetMinGoldThreshold()
	local is_turbo_enabled = ModSettingGet(SETTING_KEY_TURBO)
	local epsilon = 0.001
	if is_turbo_enabled then
		local missing_hp = max_hp - hp
		local gap_threshold = max_hp * 0.02
		local turbo_heal_val = max_hp * 0.01
		local turbo_cost = math.max(1, math.floor((turbo_heal_val / HP_PER_HEAL) + 0.5))
		if missing_hp > (gap_threshold + epsilon) and gold >= min_gold and gold >= turbo_cost then
			local spent = SpendGold(player_entity, turbo_cost)
			if spent then
				TryHeal(dmg_comp, math.min(hp + turbo_heal_val, max_hp))
			end
			return
		end
	end
	if gold < min_gold then return end
	if gold < 1 then return end
	if (max_hp - hp) < epsilon then return end
	local spent = SpendGold(player_entity, 1)
	if not spent then return end
	TryHeal(dmg_comp, math.min(hp + HP_PER_HEAL, max_hp))
end

function OnPlayerSpawned(entity)
	player_entity = entity
	frame_counter = 0
	healing_cooldown_frames = 0
	last_damage_frame = -9999
	stable_hp_ticks = 0
	previous_hp = nil
end

function OnWorldPostUpdate()
	if not IsPlayerAlive(player_entity) then
		player_entity = GetPlayer()
		if not IsPlayerAlive(player_entity) then
			previous_hp = nil
			stable_hp_ticks = 0
			return
		end
	end
	if player_entity then
		local _, _, dmg_comp = GetCurrentHP(player_entity)
		if dmg_comp then
			local current_hp = GetValue(dmg_comp, "hp")
			local frame = GameGetFrameNum()
			if previous_hp ~= nil and current_hp < previous_hp - 0.001 then
				last_damage_frame = frame
				stable_hp_ticks = 0
			end
			previous_hp = current_hp
		end
	end
	local gold = GetCurrentGold(player_entity)
	local interval_frames = GetIntervalFrames(gold)
	if interval_frames == nil then
		return
	end
	frame_counter = frame_counter + 1
	if frame_counter > interval_frames then
		frame_counter = interval_frames
	end
	if frame_counter >= interval_frames then
		frame_counter = 0
		DoRegenTick()
	end
end