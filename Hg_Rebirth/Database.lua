local _, ns = ...

local visibilityAliases = {
    hideLevel = "showLevel", hideName = "showName", hidePower = "showPower",
    hideInRaid = "showInRaid", hideOriginal = "showOriginal",
}

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = ns.Copy(item) end
    return result
end

local function validate(input, defaults, ranges, changedKey, changedValue)
    if type(input) ~= "table" then return nil, "Settings must be a table." end
    local result = ns.Copy(input)
    if changedKey then result[changedKey] = changedValue end
    if ns.modules.Core and defaults == ns.modules.Core.defaults then result.fadeBars = nil end
    for oldKey, newKey in pairs(visibilityAliases) do
        if defaults[newKey] ~= nil and result[oldKey] ~= nil then
            if type(result[oldKey]) ~= "boolean" then return nil, "Invalid setting: " .. oldKey end
            if result[newKey] == nil then result[newKey] = not result[oldKey] end
            result[oldKey] = nil
        end
    end
    for key, default in pairs(defaults) do
        local value = result[key]
        local range = ranges and ranges[key]
        if range and range.rgb and type(value) == "string" and ns.colors[value] then
            value = ns.Copy(ns.colors[value])
            result[key] = value
        end
        if value == nil then
            if key == "auraBackgroundAlpha" and type(input.hideAuraBackground) == "boolean" then
                result[key] = input.hideAuraBackground and 0 or 1
            else result[key] = ns.Copy(default) end
        elseif type(value) ~= type(default) then
            return nil, "Invalid setting: " .. key
        elseif range and range.rgb then
            for index, component in pairs(value) do
                if index ~= 1 and index ~= 2 and index ~= 3 then
                    return nil, "Invalid color setting: " .. key
                end
                if type(component) ~= "number" or ns.IsSecret(component)
                    or component ~= component or component < 0 or component > 1 then
                    return nil, "Invalid color setting: " .. key
                end
            end
            if value[1] == nil or value[2] == nil or value[3] == nil then
                return nil, "Invalid color setting: " .. key
            end
        elseif type(value) == "number" then
            local range = ranges and ranges[key]
            if value ~= value or value == math.huge or value == -math.huge
                or (range and (value < range[1] or value > range[2]))
                or (range and range.integer and value % 1 ~= 0) then
                return nil, "Out-of-range setting: " .. key
            end
        elseif type(value) == "string" and ranges and ranges[key] and not ranges[key][value] then
            return nil, "Unknown setting value: " .. key
        end
    end
    -- Mutually exclusive boolean pairs; the first entry wins unless the second was just enabled.
    local exclusive = ranges and ranges.exclusive
    if exclusive then
        for _, pair in ipairs(exclusive) do
            local first, second = pair[1], pair[2]
            if result[first] and result[second] then
                if changedKey == second then result[first] = false else result[second] = false end
            end
        end
    end
    return result
end
ns.ValidateSettings = validate

function ns.InitializeStorage()
    for _, name in ipairs({ "Hg_Rebirth_Options", "Hg_Rebirth_Player_Options", "Hg_Rebirth_Player_Pet_Options",
        "Hg_Rebirth_Target_Options", "Hg_Rebirth_Target_Target_Options", "Hg_Rebirth_Focus_Options",
        "Hg_Rebirth_Party_Options", "Hg_Rebirth_Party_Target_Options", "Hg_Rebirth_Focus_Target_Options",
        "Hg_Rebirth_Party_Pet_Options", "Hg_Rebirth_Castbars_Options", "Hg_Rebirth_Player_Aura_Options",
        "Hg_Rebirth_Target_Aura_Options", "Hg_Rebirth_Focus_Aura_Options" }) do
        if _G[name] == nil then _G[name] = { version = 1, characters = {} } end
        local db = _G[name]
        if type(db) ~= "table" or db.version ~= 1 or type(db.characters) ~= "table" then
            error("Unsupported or damaged Hg_Rebirth settings: " .. name)
        end
    end
end

function ns.InitializeModule(module)
    if ns.InitializeStickyModule then ns.InitializeStickyModule(module) end
    module.storage = _G[module.savedVariable]
    local stored = module.storage.characters[ns.characterKey]
    if stored == nil then stored = {} end
    if module == ns.modules.TargetTarget and stored.targetScale == nil and stored.scale ~= nil then
        stored = ns.Copy(stored)
        stored.targetScale = stored.scale
    end
    local settings, err = validate(stored, module.defaults, module.ranges)
    if not settings then error(module.savedVariable .. ": " .. err) end
    module.storage.characters[ns.characterKey] = settings
    module.db = settings
end

function ns.Set(module, key, value)
    if module.defaults[key] == nil then ns.Warn("Unknown setting: " .. key); return false end
    local settings, err = validate(module.db, module.defaults, module.ranges, key, value)
    if not settings then ns.Warn(err); return false end
    if ns.ValidateSticky then
        local candidates = {}
        for _, id in ipairs(ns.order) do
            candidates[id] = ns.modules[id] == module and settings or ns.modules[id].db
        end
        local valid, stickyError = ns.ValidateSticky(candidates)
        if not valid then ns.Warn(stickyError); return false end
    end
    for _, prefix in ipairs({ "sticky", "targetSticky" }) do
        if key == prefix .. "Parent" or key == prefix .. "Move" then
            for index = 1, 4 do
                if settings[prefix .. index .. "Placed"] ~= nil then
                    settings[prefix .. index .. "Placed"] = false
                end
            end
        end
    end
    module.storage.characters[ns.characterKey] = settings
    module.db = settings
    if module == ns.modules.Core then ns.Refresh()
    else
        module:Refresh(key)
        ns.RefreshAnimation(module)
        if ns.RefreshOptions then ns.RefreshOptions() end
    end
    return true
end

function ns.Characters()
    local found = {}
    for _, id in ipairs(ns.order) do
        for key in pairs(ns.modules[id].storage.characters) do found[key] = true end
    end
    local result = {}
    for key in pairs(found) do result[#result + 1] = key end
    table.sort(result)
    return result
end

local function load(source)
    if InCombatLockdown() then ns.Warn("Cannot load settings during combat."); return false end
    local staged = {}
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        local input, sourceError = source(module, id)
        if not input then
            ns.Warn(sourceError or ("No settings for " .. id .. " in the selected source."))
            return false
        end
        if module == ns.modules.TargetTarget and input.targetScale == nil then
            input = ns.Copy(input)
            input.targetScale = input.scale or module.defaults.scale
        end
        local settings, err = validate(input, module.defaults, module.ranges)
        if not settings then ns.Warn(id .. ": " .. err); return false end
        staged[id] = settings
    end
    if ns.ValidateSticky then
        local valid, err = ns.ValidateSticky(staged)
        if not valid then ns.Warn(err); return false end
    end
    if ns.ResetStickyCache then ns.ResetStickyCache() end
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        module.db = staged[id]
        module.storage.characters[ns.characterKey] = module.db
    end
    ns.Refresh()
    return true
end

function ns.CopyCharacter(key)
    if not key or key == ns.characterKey then ns.Warn("Select another character to copy."); return false end
    if load(function(module) return module.storage.characters[key] end) then
        ns.Print("Copied settings from " .. key .. ".")
        return true
    end
    return false
end

function ns.SaveGlobal()
    if InCombatLockdown() then ns.Warn("Cannot save global settings during combat."); return false end
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        module.storage.global = ns.Copy(module.db)
    end
    ns.Print("Saved global snapshot for loaded modules.")
    return true
end

function ns.LoadGlobal()
    if load(function(module) return module.storage.global end) then
        ns.Print("Loaded global snapshot into this character.")
        return true
    end
    return false
end

function ns.ResetDefaults()
    if InCombatLockdown() then ns.Warn("Cannot reset during combat."); return false end
    return load(function(module) return module.defaults end)
end

function ns.PresetNames()
    local names = {}
    for name in pairs(ns.presets) do names[#names + 1] = name end
    for name in pairs(ns.modules.Core.storage.userPresets or {}) do
        if not ns.presets[name] then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function ns.IsUserPreset(name)
    local presets = ns.modules.Core.storage.userPresets
    return type(name) == "string" and ns.presets[name] == nil
        and presets ~= nil and type(presets[name]) == "table"
end

function ns.HasPreset(name)
    return type(name) == "string" and (type(ns.presets[name]) == "table" or ns.IsUserPreset(name))
end

function ns.SaveUserPreset(name, update)
    if type(name) ~= "string" then ns.Warn(ns.L["Enter a preset name."]); return false end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 80 or name:find("[%c|]") then
        ns.Warn(ns.L["Please enter a short preset name without line breaks or the | symbol."])
        return false
    end
    if ns.presets[name] ~= nil then
        ns.Warn(ns.L["Built-in presets cannot be changed or deleted."])
        return false
    end
    local storage = ns.modules.Core.storage
    local presets = storage.userPresets or {}
    if update and not ns.IsUserPreset(name) then
        ns.Warn(ns.L["Select a user preset first."])
        return false
    elseif not update and presets[name] ~= nil then
        ns.Warn(ns.L["A preset with that name already exists."])
        return false
    end
    local snapshot = update and ns.Copy(presets[name]) or {}
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        local settings, err = validate(module.db, module.defaults, module.ranges)
        if not settings then ns.Warn(id .. ": " .. err); return false end
        snapshot[id] = {}
        for key in pairs(module.defaults) do snapshot[id][key] = ns.Copy(settings[key]) end
    end
    storage.userPresets = presets
    presets[name] = snapshot
    ns.Print(ns.L["Saved preset: %s"]:format(name))
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true, name
end

function ns.DeleteUserPreset(name)
    if not ns.IsUserPreset(name) then
        ns.Warn(ns.L["Select a user preset first."])
        return false
    end
    local storage = ns.modules.Core.storage
    storage.userPresets[name] = nil
    for _, rules in pairs(storage.presetRules or {}) do
        for context, assigned in pairs(rules) do
            if assigned == name then rules[context] = nil end
        end
    end
    ns.Print(ns.L["Deleted preset: %s"]:format(name))
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end

function ns.LoadPreset(name)
    local user = ns.IsUserPreset(name)
    local preset = type(name) == "string" and (ns.presets[name]
        or (user and ns.modules.Core.storage.userPresets[name]))
    if type(preset) ~= "table" then
        ns.Warn("Unknown settings preset: " .. tostring(name))
        return false
    end
    if load(function(module, id)
        local overrides = preset[id]
        if overrides ~= nil and type(overrides) ~= "table" then
            return nil, "Invalid settings preset: " .. name .. " (" .. id .. ")"
        end
        if user and overrides == nil then return module.db end
        local settings = ns.Copy(module.defaults)
        for key, value in pairs(overrides or {}) do
            if id ~= "Core" or key ~= "fadeBars" then
                if module.defaults[key] == nil then
                    return nil, "Unknown setting in preset " .. name .. ": " .. id .. "." .. key
                end
                settings[key] = ns.Copy(value)
            end
        end
        if module == ns.modules.TargetTarget and not (overrides and overrides.targetScale) then
            settings.targetScale = settings.scale
        end
        return settings
    end) then
        ns.Print("Loaded the " .. name .. " preset for this character.")
        return true
    end
    return false
end

ns.RegisterModule("Core", {
    savedVariable = "Hg_Rebirth_Options",
    defaults = {
        texture = 0, minimap = true, minimapAngle = 290, minimapRadius = 100,
        muteWarnings = false,
        transparentBackground = false, texturedBackground = false,
        colorHealth = false, invertBars = false,
        colorDebuffs = true, threat = false,
    },
    ranges = { texture = { 0, 6, integer = true }, minimapAngle = { 0, 360 }, minimapRadius = { 40, 200 } },
    Refresh = function()
        if ns.UpdateMinimap then ns.UpdateMinimap() end
    end,
})
