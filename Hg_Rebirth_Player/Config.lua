local ns = Hg_Rebirth
local Player = ns.modules.Player

function Player:BuildOptions(category)
    local db = function() return self.db end
    ns.Panel("Player",
        "Player appearance follows the original unit frame. Layout changes wait until combat ends.\n"
        .. "Restricted data may pause threat, aura borders, or combat feedback; the addon reports this.", category, function(content)
        ns.Section(content, "Layout")
        ns.Check(content, self, "locked", "Lock frame position")
        ns.Check(content, self, "compact", "Compact mode")
        ns.SubOptions(content, function() return db().compact end, function()
            ns.Check(content, self, "compactPercent", "Show percentages in compact mode")
            ns.Check(content, self, "shortBars", "Short bars in compact mode")
        end)
        ns.Check(content, self, "showLevel", "Show class and level frame")
        ns.SubOptions(content, function() return db().showLevel end, function()
            ns.Check(content, self, "matchLevelHeight", "Match class and level frame height to stats frame")
        end)
        ns.Check(content, self, "alternateMana", "Show alternate mana bar")
        ns.Check(content, self, "showInRaid", "Show Player frame in raids")
        ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
        ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
        ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
        ns.Button(content, "Reset Player position", function()
            if InCombatLockdown() then ns.Warn("Cannot reset position during combat."); return end
            self:ResetPosition()
        end)
        ns.NudgeControls(content, self)
        ns.Section(content, "Progress bar")
        ns.Select(content, "Display", function()
            return { { text = "Experience", value = "experience" },
                { text = "Reputation", value = "reputation" }, { text = "Hidden", value = "hidden" } }
        end, function() return self.db.progress end, function(value) ns.Set(self, "progress", value) end)
        ns.Section(content, "Text and portrait")
        ns.Check(content, self, "healer", "Healer mode: show health deficit")
        ns.SubOptions(content, function() return db().healer end, function()
            ns.Check(content, self, "manaDeficit", "Show mana deficit in healer mode")
            ns.Check(content, self, "barValues", "Always show values in healer mode")
        end)
        ns.Check(content, self, "className", "Class-colored name")
        ns.Check(content, self, "portrait", "Show portrait")
        ns.SubOptions(content, function() return db().portrait end, function()
            ns.Check(content, self, "portrait3D", "Use 3D portrait")
            ns.Check(content, self, "combatText", "Portrait combat text")
        end)
        ns.Section(content, "Status and class resources")
        if ns.IsForever then ns.Check(content, self, "fiveSecondRule", "Show five-second mana rule") end
        for _, option in ipairs({
            { "raidGroup", "Show raid group number" },
            { "groupInName", "Show raid group in name (in raid)" },
            { "pvpIcon", "Show PvP icon" }, { "pvpTimer", "Show PvP timer" },
            { "classResource", "Show class resource frame" },
        }) do ns.Check(content, self, option[1], option[2]) end
        ns.SubOptions(content, function() return db().classResource end, function()
            ns.ColorPicker(content, self, "resourceColor", "Class resource color")
            ns.Check(content, self, "resourceOnTop", "Show class resource bar at top of name frame")
        end)
    end)
end