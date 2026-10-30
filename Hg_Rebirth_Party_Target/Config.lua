local ns = Hg_Rebirth
local PartyTarget = ns.modules.PartyTarget

function PartyTarget:BuildOptions(category)
    ns.Panel("Party Target",
        ns.L["Four independent party-target frames. Layout changes wait until combat ends."], category, function(content)
        ns.Section(content, "Layout")
        ns.Check(content, self, "enabled", "Show party targets")
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
            ns.Button(content, "Align right of Party", function()
                local entries = {}
                for index, member in ipairs(self.members) do
                    entries[index] = {
                        frame = member.frame, index = index, xKey = member.xKey, yKey = member.yKey,
                        alignToBackground = true,
                    }
                end
                ns.AlignRight(self, "Party", entries)
            end)
            ns.Button(content, "Reset Party Target positions", function()
                ns.Confirm(ns.L["Reset Party Target positions for this character?"], function() self:ResetPosition() end)
            end)
            ns.NudgeControls(content, self)
        end)
        if self.borderAPI == false then
            ns.Section(content, "Mainline aura API unavailable; Party Target remains active without debuff-border coloring.")
        end
    end)
end
