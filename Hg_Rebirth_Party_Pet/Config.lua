local ns = Hg_Rebirth
local PartyPet = ns.modules.PartyPet

function PartyPet:BuildOptions(category)
    ns.Panel("Party Pet",
        ns.L["Independent party-pet frames. Native displays and Party's embedded pet bars are unchanged."], category, function(content)
        ns.Section(content, "Layout")
        ns.Check(content, self, "enabled", "Show party pets")
        local function enabled() return self.db.enabled end
        ns.SubOptions(content, enabled, function()
            ns.Check(content, self, "showInRaid", "Show in raid")
        end)
        ns.DependentOptions(content, enabled, function()
            ns.Check(content, self, "locked", "Lock frame position")
            ns.Check(content, self, "portrait", "Show portrait")
            ns.SubOptions(content, function() return self.db.portrait end, function()
                ns.Check(content, self, "portrait3D", "Use 3D portrait")
            end)
            ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
            ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
            ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
            ns.Button(content, "Reset Party Pet positions", function()
                ns.Confirm(ns.L["Reset Party Pet positions for this character?"], function() self:ResetPosition() end)
            end)
            ns.Button(content, "Align right of Party", function()
                ns.Confirm(ns.L["Align Party Pet beside Party for this character?"], function() self:Align() end)
            end)
            ns.NudgeControls(content, self)
            local function locations()
                local result = {}
                for index, text in ipairs({ "Above name (upper row)", "Above name (lower row)", "Right of name",
                    "Right of stats (upper row)", "Right of stats (lower row)",
                    "Below stats (upper row)", "Below stats (lower row)" }) do
                    result[#result + 1] = { text = text, value = index }
                end
                return result
            end
            if self.auraAPI == false or (self.auraAPI == nil and not ns.HasAuraAPI()) then
                ns.Section(content, "Mainline aura API unavailable; Party Pet remains active without aura icons or debuff-border coloring.")
            end
            ns.Section(content, "Pet buffs")
            ns.AuraGroupOptions(content, self, false, locations)
            ns.Section(content, "Pet debuffs")
            ns.AuraGroupOptions(content, self, true, locations)
            ns.Section(content, "Aura spacing")
            ns.DependentOptions(content, function() return ns.HasAuraCount(self) end, function()
                ns.Slider(content, self, "auraSpacingHorizontal", "Horizontal spacing", -10, 30, 1)
            end)
        end)
    end)
end
