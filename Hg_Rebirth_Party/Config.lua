local ns = Hg_Rebirth
local Party = ns.modules.Party

function Party:BuildOptions(category)
    ns.Panel("Party",
        ns.L["Four party members and embedded pet health. Layout changes wait until combat ends."] .. "\n"
        .. ns.L["Native raid displays are preserved. Restricted indicators are hidden or neutral."], category, function(content)
        if self.unavailable then
            ns.Section(content, "Required Mainline aura API unavailable; native Party retained.")
            return
        end
        ns.Section(content, "Layout")
        ns.Select(content, "Party visibility", function()
            return { { text = "Always", value = "always" }, { text = "Hide in raid", value = "raid" },
                { text = "Hidden", value = "hidden" } }
        end, function() return self.db.visibility end, function(value) ns.Set(self, "visibility", value) end)
        ns.Check(content, self, "locked", "Lock frame position")
        ns.Check(content, self, "vertical", "Arrange party vertically")
        ns.Check(content, self, "compact", "Compact mode")
        ns.SubOptions(content, function() return self.db.compact end, function()
            ns.Check(content, self, "compactPercent", "Show percentages in compact mode")
            ns.Check(content, self, "shortBars", "Short bars in compact mode")
        end)
        ns.Check(content, self, "showLevel", "Show class and level frame")
        ns.Check(content, self, "showPets", "Show embedded party-pet health bars")
        ns.Slider(content, self, "spacing", "Party spacing (positive: down or right)", -150, 150, 1)
        ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
        ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
        ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
        ns.Button(content, "Reset Party position", function()
            ns.Confirm(ns.L["Reset Party position for this character?"], function() self:ResetPosition() end)
        end)
        ns.NudgeControls(content, self)
        ns.Section(content, "Text and portrait")
        ns.Check(content, self, "healer", "Healer mode: show health deficit")
        ns.SubOptions(content, function() return self.db.healer end, function()
            ns.Check(content, self, "manaDeficit", "Show mana deficit in healer mode")
            ns.Check(content, self, "healerValues", "Always show values in healer mode")
        end)
        for _, option in ipairs({
            { "className", "Class-colored name" },
            { "pvpIcon", "Show PvP icon" }, { "showKeys", "Show party targeting key labels" },
            { "portrait", "Show portrait" },
        }) do ns.Check(content, self, option[1], option[2]) end
        ns.SubOptions(content, function() return self.db.portrait end, function()
            ns.Check(content, self, "portrait3D", "Use 3D portrait")
        end)
        local function locations()
            local result = {}
            for index, text in ipairs({ "Above name (upper row)", "Above name (lower row)", "Right of name",
                "Right of stats (upper row)", "Right of stats (lower row)",
                "Below stats (upper row)", "Below stats (lower row)" }) do
                result[#result + 1] = { text = text, value = index }
            end
            return result
        end
        ns.Section(content, "Party buffs")
        ns.AuraGroupOptions(content, self, false, locations)
        ns.Section(content, "Party debuffs")
        ns.AuraGroupOptions(content, self, true, locations)
        ns.Section(content, "Aura spacing")
        ns.DependentOptions(content, function() return ns.HasAuraCount(self) end, function()
            ns.Slider(content, self, "auraSpacingHorizontal", "Horizontal spacing", -10, 30, 0.5)
            ns.Check(content, self, "auraTimers", "Show aura native cooldown")
            ns.DependentOptions(content, function() return self.db.portrait end, function()
                ns.Check(content, self, "portraitAuras", "Anchor above and below auras to portrait when shown")
            end)
        end)
    end)
end
