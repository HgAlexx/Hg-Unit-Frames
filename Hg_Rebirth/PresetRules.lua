local _, ns = ...
local events = CreateFrame("Frame")
local previousContext, previousPreset, waiting
local contexts = {
    solo = true, party = true, raid = true, dungeon = true,
    raidInstance = true, battleground = true, arena = true,
}
local instanceContexts = {
    party = "dungeon", raid = "raidInstance", pvp = "battleground", arena = "arena",
}

function ns.PresetRules()
    local storage = ns.modules.Core.storage
    storage.presetRules = storage.presetRules or {}
    local rules = storage.presetRules[ns.characterKey]
    if not rules then
        rules = { enabled = false }
        storage.presetRules[ns.characterKey] = rules
    end
    return rules
end

function ns.PresetContext()
    local inside, instanceType = IsInInstance()
    if inside and instanceContexts[instanceType] then return instanceContexts[instanceType] end
    if IsInRaid() then return "raid" end
    if IsInGroup() then return "party" end
    return "solo"
end

function ns.EvaluatePresetRules()
    local rules = ns.PresetRules()
    if not rules.enabled then
        previousContext, previousPreset, waiting = nil, nil, nil
        return
    end
    local context = ns.PresetContext()
    local name = rules[context]
    if context == previousContext and name == previousPreset then waiting = nil; return end
    if not name then
        previousContext, previousPreset, waiting = context, nil, nil
        return
    end
    if InCombatLockdown() then waiting = true; return end
    waiting = nil
    -- Record attempts, including invalid presets, so roster chatter cannot spam errors.
    previousContext, previousPreset = context, name
    ns.LoadPreset(name)
end

local function evaluateNextFrame(self)
    self:SetScript("OnUpdate", nil)
    ns.EvaluatePresetRules()
end

function ns.SchedulePresetRules(reset)
    if reset then previousContext, previousPreset = nil, nil end
    if not ns.PresetRules().enabled then
        previousContext, previousPreset, waiting = nil, nil, nil
        events:SetScript("OnUpdate", nil)
        return
    end
    events:SetScript("OnUpdate", evaluateNextFrame)
end

function ns.SetPresetRule(context, name)
    if not contexts[context] or (name ~= nil and not ns.HasPreset(name)) then
        ns.Warn(ns.L["Invalid automatic preset rule."])
        return false
    end
    ns.PresetRules()[context] = name
    ns.SchedulePresetRules()
    ns.RefreshOptions()
    return true
end

function ns.SetPresetRulesEnabled(enabled)
    if type(enabled) ~= "boolean" then
        ns.Warn(ns.L["Invalid automatic preset rule."])
        return false
    end
    ns.PresetRules().enabled = enabled
    ns.SchedulePresetRules(true)
    ns.RefreshOptions()
    return true
end

function ns.StartPresetRules()
    local storage = ns.modules.Core.storage
    if storage.userPresets ~= nil and type(storage.userPresets) ~= "table" then
        error("Unsupported or damaged Hg_Rebirth user presets.")
    end
    if storage.presetRules ~= nil and type(storage.presetRules) ~= "table" then
        error("Unsupported or damaged Hg_Rebirth preset rules.")
    end
    for _, rules in pairs(storage.presetRules or {}) do
        if type(rules) ~= "table" then error("Unsupported or damaged Hg_Rebirth preset rules.") end
        for key, value in pairs(rules) do
            if (key == "enabled" and type(value) ~= "boolean")
                or (key ~= "enabled" and (not contexts[key] or type(value) ~= "string")) then
                error("Unsupported or damaged Hg_Rebirth preset rule: " .. tostring(key))
            end
        end
    end
    for name, preset in pairs(storage.userPresets or {}) do
        if type(name) ~= "string" or type(preset) ~= "table" then
            error("Unsupported or damaged Hg_Rebirth user preset.")
        end
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_REGEN_ENABLED" or waiting then ns.SchedulePresetRules() end
    end)
    ns.SchedulePresetRules()
end
