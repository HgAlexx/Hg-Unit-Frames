local ns = Hg_Rebirth
local Chain = ns.modules.TargetTarget

function Chain:BuildOptions(category)
    ns.Panel("Target Target", ns.L["Target-chain frames for Retail and Forever. Layout changes wait until combat ends."], category, function(content)
        if self.unavailable then
            ns.Section(content, "Required Mainline aura API unavailable; native target-of-target retained.")
            return
        end
        ns.Section(content, "Layout")
        for _, option in ipairs({
            { "showTarget", "Show target of target" }, { "showTargetTarget", "Show target of target of target" },
            { "locked", "Lock frame position" }, { "showPower", "Show power bars" },
            { "className", "Class-colored name" }, { "numericHealth", "Show numeric health when maximum is not 100" },
        }) do ns.Check(content, self, option[1], option[2]) end
        ns.Slider(content, self, "scale", "Scale (%)", 1, 149, 1, 100)
        ns.Button(content, "Set to current UI scale", function() ns.Set(self, "scale", UIParent:GetScale()) end)
        ns.Slider(content, self, "targetScale", "Target-of-target-of-target scale (%)", 1, 149, 1, 100)
        ns.Slider(content, self, "opacity", "Opacity (%)", 0, 100, 1, 100)
        ns.Button(content, "Reset target-chain positions", function()
            ns.Confirm(ns.L["Reset target-chain positions for this character?"], function() self:ResetPosition() end)
        end)
        ns.Button(content, "Align target-chain frames right of Target", function() self:Align(false) end)
        ns.Button(content, "Align target-chain frames above Target", function() self:Align(true) end)
        ns.NudgeControls(content, self)
        ns.Section(content, "Target-chain auras")
        local function tot() return self.db.showTarget end
        local function totot() return self.db.showTargetTarget end
        ns.DependentOptions(content, tot, function()
            ns.Check(content, self, "buffs", "Show target-of-target buffs")
            ns.Check(content, self, "debuffs", "Show target-of-target debuffs")
        end)
        ns.DependentOptions(content, totot, function()
            ns.Check(content, self, "targetBuffs", "Show target-of-target-of-target buffs")
            ns.Check(content, self, "targetDebuffs", "Show target-of-target-of-target debuffs")
        end)
        local function anyBuffs()
            local db = self.db
            return (db.showTarget and db.buffs) or (db.showTargetTarget and db.targetBuffs)
        end
        local function anyDebuffs()
            local db = self.db
            return (db.showTarget and db.debuffs) or (db.showTargetTarget and db.targetDebuffs)
        end
        ns.DependentOptions(content, anyBuffs, function()
            ns.Check(content, self, "castableBuffs", "Only show castable buffs")
        end)
        ns.DependentOptions(content, anyDebuffs, function()
            ns.Check(content, self, "curableDebuffs", "Only show curable debuffs")
            ns.Check(content, self, "ownDebuffs", "Only show own debuffs on hostile targets")
        end)
        ns.DependentOptions(content, function() return anyBuffs() or anyDebuffs() end, function()
            ns.Slider(content, self, "auraSpacingHorizontal", "Horizontal spacing", -10, 30, 0.5)
            ns.Slider(content, self, "auraSpacingVertical", "Vertical spacing", -10, 30, 0.5)
        end)
        ns.DependentOptions(content, function()
            local db = self.db
            return (db.showTarget and db.buffs and db.debuffs)
                or (db.showTargetTarget and db.targetBuffs and db.targetDebuffs)
        end, function()
            ns.Slider(content, self, "groupSpacingVertical", "Buff/debuff gap", 0, 100, 1)
        end)
        ns.Section(content, "Target-chain warnings")
        ns.DependentOptions(content, tot, function()
            ns.Select(content, "Warning mode", function()
                return {
                    { text = "Off", value = "off" }, { text = "DPS", value = "dps" },
                    { text = "Tank", value = "tank" }, { text = "Healer", value = "healer" },
                }
            end, function() return self.db.warningMode end, function(value) ns.Set(self, "warningMode", value) end)
            ns.SubOptions(content, function() return self.db.warningMode ~= "off" end, function()
                ns.Select(content, "Warning text", function()
                    return {
                        { text = "Small", value = "small" }, { text = "Large", value = "large" }, { text = "Hidden", value = "hidden" },
                    }
                end, function() return self.db.warningSize end, function(value) ns.Set(self, "warningSize", value) end)
            end)
            ns.DependentOptions(content, function() return self.db.warningMode ~= "off" end, function()
                ns.Check(content, self, "warningSound", "Play target-chain warning sound")
                ns.SubOptions(content, function() return self.db.warningSound end, function()
                    ns.Select(content, "Warning sound", function()
                        return {
                            { text = "PVP Flag Captured Alliance", value = "9372" },
                            { text = "PVP Flag Captured Horde", value = "9374" },
                            { text = "PVP Flag Taken Alliance", value = "9378" },
                            { text = "PVP Flag Taken Horde", value = "9379" },
                            { text = "PVP Warning Alliance", value = "9373" },
                            { text = "PVP Warning Horde", value = "9375" },
                        }
                    end, function() return self.db.warningSoundKit end,
                        function(value) ns.Set(self, "warningSoundKit", value) end)
                    ns.Button(content, "Preview target-chain warning sound", function() self:PlayWarningSound() end)
                end)
            end)
            ns.Section(content, "Active when")
            ns.DependentOptions(content, function() return self.db.warningMode ~= "off" end, function()
                ns.Check(content, self, "warningSolo", "Solo")
                ns.Check(content, self, "warningGroup", "In group")
                ns.Check(content, self, "warningRaid", "In raid")
            end)
        end)
        ns.Section(content, "Warnings are skipped when required combat data is restricted."):SetFontObject("GameFontNormalSmall")
        ns.Section(content, "Warnings will most likely not work in instances and raids."):SetFontObject("GameFontNormalSmall")
    end)
end
