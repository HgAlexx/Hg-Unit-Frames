local ns = Hg_Rebirth
local Pet = ns.modules.PlayerPet

function Pet:BuildOptions(category)
    ns.Panel("Player Pet",
        "Pet and pet-target frames for Retail and Forever. Protected layout changes wait until combat ends.\n"
        .. "Auras use Mainline AuraContainer/AuraButton. Player is optional; alignment saves independent positions.", category, function(content)
        if self.unavailable then
            ns.Section(content, "Required AuraContainer/AuraButton API unavailable; stock pet frame retained.")
            return
        end
        ns.Section(content, "Layout")
        for _, option in ipairs({
            { "locked", "Lock frame position" }, { "compact", "Compact mode" },
            { "showName", "Show pet name and level" },
        }) do ns.Check(content, self, option[1], option[2]) end
        ns.Slider(content, self, "scale", "Pet scale (%)", 1, 149, 1, 100)
        ns.Button(content, "Set pet to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
        ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
        ns.Button(content, "Reset pet and pet-target positions", function()
            ns.Confirm("Reset pet and pet-target positions for this character?", function() self:ResetPosition() end)
        end)
        ns.Button(content, "Align pet frames below Player", function() self:Align() end)
        ns.NudgeControls(content, self)
        ns.Section(content, "Text and portrait")
        ns.DependentOptions(content, function() return self.db.showName end, function()
            ns.Check(content, self, "petClassName", "Class-colored name")
            ns.Check(content, self, "showHappiness", "Show pet happiness")
        end)
        ns.Check(content, self, "petFriendlyHealth", "Show numerical health")
        ns.Check(content, self, "portrait", "Show portrait")
        ns.SubOptions(content, function() return self.db.portrait end, function()
            ns.Check(content, self, "portrait3D", "Use 3D portrait")
            ns.Check(content, self, "combatText", "Portrait combat text")
        end)
        local _, class = UnitClass("player")
        if class == "HUNTER" and type(GetPetExperience) == "function" then
            ns.Check(content, self, "showXP", "Show pet experience")
        end
        ns.Section(content, "Pet's target")
        ns.Check(content, self, "showTarget", "Show pet's target")
        ns.SubOptions(content, function() return self.db.showTarget end, function()
            ns.Check(content, self, "targetCompact", "Compact mode")
            ns.Check(content, self, "className", "Class-colored name")
            ns.Check(content, self, "friendlyHealth", "Show numerical friendly health")
            ns.Slider(content, self, "targetScale", "Pet-target scale (%)", 1, 149, 1, 100)
            ns.Button(content, "Set pet's target to current UI scale",
                function() ns.Set(self, "targetScale", UIParent:GetScale()) end)
            ns.Button(content, "Align pet target right of Pet", function()
                ns.AlignRight(self, "PlayerPet", {
                    { frame = self.target.frame, xKey = "targetX", yKey = "targetY", alignToBackground = true },
                })
            end)
        end)
        local function locations()
            local result = {}
            for index, text in ipairs({ "Above name (upper row)", "Above name (lower row)",
                "Right of name", "Right of stats (upper row)", "Right of stats (lower row)",
                "Below stats (upper row)", "Below stats (lower row)" }) do
                result[#result + 1] = { text = text, value = index }
            end
            return result
        end
        ns.Section(content, "Pet buffs")
        ns.AuraGroupOptions(content, self, false, locations)
        ns.Section(content, "Pet debuffs")
        ns.AuraGroupOptions(content, self, true, locations)
        ns.Section(content, "Aura spacing")
        ns.DependentOptions(content, function() return ns.HasAuraCount(self) end, function()
            ns.Slider(content, self, "auraSpacingHorizontal", "Horizontal spacing", -10, 30, 0.5)
            ns.Slider(content, self, "auraSpacingVertical", "Vertical spacing", -10, 30, 0.5)
        end)
    end)
end
