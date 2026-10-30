local ns = Hg_Rebirth
local FocusTarget = ns.modules.FocusTarget

function FocusTarget:BuildOptions(category)
    ns.Panel("Focus Target",
        ns.L["Independent focus-target frame. Layout changes wait until combat ends."], category, function(content)
        ns.Section(content, "Layout")
        ns.Check(content, self, "enabled", "Show focus target")
        local function enabled() return self.db.enabled end
        ns.SubOptions(content, enabled, function()
            ns.Check(content, self, "showInRaid", "Show in raid")
        end)
        ns.DependentOptions(content, enabled, function()
            for _, option in ipairs({
                { "locked", "Lock frame position" }, { "showPower", "Show power bars" },
                { "className", "Class-colored name" },
            }) do ns.Check(content, self, option[1], option[2]) end
            ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
            ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
            ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
            ns.Button(content, "Align right of Focus", function()
                ns.AlignRight(self, "Focus", { { frame = self.frame, alignToBackground = true } })
            end)
            ns.Button(content, "Reset Focus Target position", function()
                ns.Confirm(ns.L["Reset Focus Target position for this character?"], function() self:ResetPosition() end)
            end)
            ns.NudgeControls(content, self)
            ns.Section(content, "Focus-target auras")
            ns.Check(content, self, "buffs", "Show focus-target buffs")
            ns.SubOptions(content, function() return self.db.buffs end, function()
                ns.Check(content, self, "castableBuffs", "Only show castable buffs")
            end)
            ns.Check(content, self, "debuffs", "Show focus-target debuffs")
            ns.SubOptions(content, function() return self.db.debuffs end, function()
                ns.Check(content, self, "curableDebuffs", "Only show curable debuffs")
                ns.Check(content, self, "ownDebuffs", "Only show own debuffs on hostile targets")
            end)
            ns.DependentOptions(content, function() return self.db.buffs or self.db.debuffs end, function()
                ns.Slider(content, self, "auraSpacingHorizontal", "Horizontal spacing", -10, 30, 0.5)
                ns.Slider(content, self, "auraSpacingVertical", "Vertical spacing", -10, 30, 0.5)
            end)
            ns.DependentOptions(content, function() return self.db.buffs and self.db.debuffs end, function()
                ns.Slider(content, self, "groupSpacingVertical", "Buff/debuff gap", 0, 100, 1)
            end)
        end)
        if self.borderAPI == false or (self.borderAPI == nil and not ns.HasAuraAPI()) then
            ns.Section(content, "Mainline aura API unavailable; Focus Target remains active without aura icons or debuff-border coloring.")
        end
    end)
end
