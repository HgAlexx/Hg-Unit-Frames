local _, ns = ...

local function presetChoices(allowNone)
    local choices = {}
    if allowNone then choices[1] = { text = "Keep current settings", value = false } end
    for _, name in ipairs(ns.PresetNames()) do
        if ns.presets[name] then choices[#choices + 1] = { text = name, value = name, raw = true } end
    end
    for _, name in ipairs(ns.PresetNames()) do
        if not ns.presets[name] then
            choices[#choices + 1] = { text = name, value = name, raw = true }
        end
    end
    return choices
end

function ns.BuildPresetOptions(category)
    ns.Panel("Settings presets",
        ns.L["Presets are shared by all characters. Automatic rules are per character. Only loaded modules are saved."],
        category, function(content)
        ns.Section(content, "Settings presets")
        local selectedPreset = ns.PresetNames()[1]
        local function selection()
            if not ns.HasPreset(selectedPreset) then selectedPreset = ns.PresetNames()[1] end
            return selectedPreset
        end
        ns.Select(content, "Select a preset", presetChoices, selection, function(value)
            selectedPreset = value
            ns.RefreshOptions()
        end)
        ns.Button(content, "Load selected preset", function()
            local name = selection()
            ns.Confirm("Replace this character's loaded-module settings with the selected preset?",
                function() ns.LoadPreset(name) end)
        end)
        ns.DependentOptions(content, function() return ns.IsUserPreset(selection()) end, function()
            ns.Button(content, "Save current settings to selected preset", function()
                local name = selection()
                ns.Confirm(ns.L["Replace preset '%s' with current settings?"]:format(name),
                    function() ns.SaveUserPreset(name, true) end)
            end)
            ns.Button(content, "Delete selected preset", function()
                local name = selection()
                ns.Confirm(ns.L["Delete preset '%s' for all characters and clear its automatic rules?"]:format(name),
                    function() ns.DeleteUserPreset(name) end)
            end)
        end)
        ns.Section(content, "Create a preset")
        local input = ns.TextInput(content, "Preset name")
        ns.Button(content, "Save as new preset", function()
            local success, name = ns.SaveUserPreset(input:GetText())
            if success then
                selectedPreset = name
                input:SetText("")
                input:ClearFocus()
                ns.RefreshOptions()
            end
        end)
        ns.Description(content, "Presets include frame positions. Updating preserves settings for modules that are not loaded. Loading leaves modules absent from a user preset unchanged.")
        ns.Section(content, "Automatic switching")
        ns.Toggle(content, "Enable automatic preset switching",
            function() return ns.PresetRules().enabled end, ns.SetPresetRulesEnabled)
        ns.SubOptions(content, function() return ns.PresetRules().enabled end, function()
            for _, entry in ipairs({
                { "solo", "Solo" }, { "party", "Party (outside instances)" },
                { "raid", "Raid group (outside instances)" }, { "dungeon", "Dungeon" },
                { "raidInstance", "Raid instance" }, { "battleground", "Battleground" }, { "arena", "Arena" },
            }) do
                local key = entry[1]
                ns.Select(content, entry[2], function() return presetChoices(true) end,
                    function() return ns.PresetRules()[key] or false end,
                    function(value) ns.SetPresetRule(key, value or nil) end)
            end
        end)
        ns.Description(content, "Instance rules take priority over group rules. Leaving uses the rule for your new situation. Unassigned rules keep current settings.")
        ns.Description(content, "Rules also apply on login. Combat changes wait until combat ends and use your latest situation. Manual changes remain until the situation or its rule changes.")
    end)
end
