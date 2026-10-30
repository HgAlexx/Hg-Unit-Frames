local ns = Hg_Rebirth
local Target = ns.modules.Target

function Target:BuildOptions(category)
    ns.Panel("Target",
        "Target frame for Retail and Forever. Protected layout changes wait until combat ends.", category, function(content)
        ns.Section(content, "Layout")
        ns.Select(content, "Frame style", function()
            return { { text = "Classic", value = "classic" }, { text = "New", value = "new" } }
        end, function() return self.db.style end, function(value) ns.Set(self, "style", value) end)
        local function newStyle() return self.db.style == "new" end
        ns.SubOptions(content, newStyle, function()
            ns.Check(content, self, "compact", "Compact mode")
            ns.SubOptions(content, function() return self.db.compact end, function()
                ns.Check(content, self, "compactPercent", "Show percentages in compact mode")
                ns.Check(content, self, "shortBars", "Short bars in compact mode")
            end)
        end)
        ns.Check(content, self, "locked", "Lock frame position")
        ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
        ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
        ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
        ns.Button(content, "Align right of Player", function()
            ns.AlignRight(self, "Player", { { frame = self.frame, alignToBackground = true } })
        end)
        ns.Button(content, "Reset Target position", function()
            ns.Confirm("Reset Target position for this character?", function() self:ResetPosition() end)
        end)
        ns.NudgeControls(content, self)
        ns.Section(content, "Text and portrait")
        ns.DependentOptions(content, newStyle, function()
            ns.Check(content, self, "healer", "Healer mode: show health deficit")
            ns.SubOptions(content, function() return self.db.healer end, function()
                ns.Check(content, self, "manaDeficit", "Show mana deficit in healer mode")
            end)
        end)
        for _, option in ipairs({
            { "className", "Class-colored name" }, { "classIcon", "Show class icon" },
            { "classPanel", "Show class or creature type" }, { "guild", "Show guild name" },
            { "portrait", "Show portrait" },
        }) do ns.Check(content, self, option[1], option[2]) end
        ns.SubOptions(content, function() return self.db.portrait end, function()
            ns.Check(content, self, "portrait3D", "Use 3D portrait")
        end)
        ns.Check(content, self, "combatText", "Portrait combat text")
        ns.Section(content, "Status and class resources")
        for _, option in ipairs({
            { "pvpIcon", "Show PvP icon" }, { "classificationPanel", "Show classification panel" },
            { "numericThreat", "Show numeric threat" }, { "eliteGraphic", "Show elite or rare graphic" },
            { "comboPoints", "Show combo points or essence" }, { "nameMeter", "Show resource meter in name" },
            { "targetSound", "Play sound when changing target" },
        }) do ns.Check(content, self, option[1], option[2]) end
    end)
end
