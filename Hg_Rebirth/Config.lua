local _, ns = ...

function ns.TogglePositioning()
    if not ns.SetPositioning(not ns.positioning) then return end
    ns.Print(ns.positioning and "Positioning mode enabled: drag loaded frames even when locked."
        or "Positioning mode disabled.")
    if ns.positioning then ns.Print(ns.L["Middle-click a frame or aura to open its settings."]) end
end

local function commonSetting(parent, key, text)
    ns.BooleanButtons(parent, text, function(value)
        for _, id in ipairs(ns.order) do
            local module = ns.modules[id]
            if type(module.defaults[key]) == "boolean" then
                if not ns.Set(module, key, value) then return end
            end
            if id == "PlayerPet" and key == "className" then
                if not ns.Set(module, "petClassName", value) then return end
            end
            if id == "PlayerPet" and key == "compact" then
                if not ns.Set(module, "targetCompact", value) then return end
            end
        end
    end)
end

function ns.BuildOptions()
    local core = ns.modules.Core
    local _, category = ns.Panel(ns.title,
        "Unit frame rewrites for Retail and Forever. Settings are independent per character.\n"
        .. "Protected layout changes wait until combat ends. Only loaded modules participate in copies.", nil, function(content)
        ns.Section(content, "Access")
        ns.Check(content, core, "minimap", "Show minimap button")
        ns.SubOptions(content, function() return core.db.minimap end, function()
            ns.Slider(content, core, "minimapAngle", "Minimap angle", 0, 360, 1)
            ns.Slider(content, core, "minimapRadius", "Minimap radius", 40, 200, 1)
        end)
        ns.Check(content, core, "muteWarnings", "Mute warning messages")
        ns.Section(content, "Positioning")
        ns.Button(content, "Toggle positioning mode", ns.TogglePositioning)
        ns.Description(content, "Middle-click a frame or aura to open its settings.")
        ns.Button(content, "Reset frame positions", function()
            ns.Confirm("Reset loaded frame positions for this character?", function()
                if InCombatLockdown() then ns.Warn("Cannot reset positions during combat."); return end
                for _, id in ipairs(ns.order) do
                    local module = ns.modules[id]
                    if module.ResetPosition then module:ResetPosition() end
                end
            end)
        end)
        ns.Section(content, "Character settings and global snapshot")
        local selected
        ns.Select(content, "Copy from character", function()
            local choices = {}
            for _, key in ipairs(ns.Characters()) do
                if key ~= ns.characterKey then choices[#choices + 1] = { text = key, value = key, raw = true } end
            end
            return choices
        end, function() return selected end, function(value) selected = value end)
        ns.Button(content, "Copy selected character", function()
            if not selected then ns.Warn("Select another character first."); return end
            local key = selected
            ns.Confirm("Replace this character's loaded-module settings, including positions, with " .. key .. "?",
                function() ns.CopyCharacter(key) end)
        end)
        ns.Button(content, "Save Global", function()
            ns.Confirm("Replace the global snapshot with this character's loaded-module settings?", ns.SaveGlobal)
        end)
        ns.Button(content, "Load Global", function()
            ns.Confirm("Replace this character's settings and positions with the global snapshot?", ns.LoadGlobal)
        end)
        ns.Button(content, "Reset this character to defaults", function()
            ns.Confirm("Reset this character's loaded-module settings and positions?", ns.ResetDefaults)
        end)
    end)
    ns.category = category
    ns.Panel("Common settings",
        ns.L["Apply to all loaded frames that support the setting. Individual panels can override it afterward."],
        ns.category, function(common)
        ns.Section(common, "Shared appearance")
        ns.Select(common, "Bar texture", function()
            local choices = { { text = "Blizzard", value = 0 } }
            for i = 1, 6 do choices[#choices + 1] = { text = "Texture " .. i, value = i } end
            return choices
        end, function() return core.db.texture end, function(value) ns.Set(core, "texture", value) end)
        for _, option in ipairs({
            { "transparentBackground", "Transparent frame backgrounds" },
            { "texturedBackground", "Textured bar backgrounds" },
            { "colorHealth", "Color health by remaining health" },
            { "invertBars", "Show missing health and power in bars" },
            { "colorDebuffs", "Color borders for dispellable debuffs" },
            { "threat", "Show threat indicator" },
        }) do ns.Check(common, core, option[1], option[2]) end
        ns.Section(common, "Layout")
        for _, option in ipairs({
            { "locked", "Lock frame position" }, { "className", "Class-colored name" },
            { "compact", "Compact mode" }, { "compactPercent", "Show percentages in compact mode" },
            { "shortBars", "Short bars in compact mode" }, { "showPower", "Show power bars" },
            { "portrait", "Show portrait" }, { "portrait3D", "Use 3D portrait" },
            { "healer", "Healer mode: show health deficit" }, { "manaDeficit", "Show mana deficit in healer mode" },
            { "castableBuffs", "Only show castable buffs" }, { "curableDebuffs", "Only show curable debuffs" },
            { "ownDebuffs", "Only show own debuffs on hostile targets" }, { "auraTimers", "Show aura native cooldown" },
        }) do commonSetting(common, option[1], option[2]) end
    end)
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        if module.BuildOptions then module:BuildOptions(ns.category) end
    end
    ns.BuildPresetOptions(ns.category)
    ns.InitializeBroker()
    ns.RefreshOptions()
end
