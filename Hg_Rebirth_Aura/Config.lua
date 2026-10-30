local ns = Hg_Rebirth

function ns.BuildAuraOptions(module, category, title, subtitle, options, resetLabel, resetPrompt)
    local self = module
    ns.Panel(title, ns.L[subtitle], category, function(content)
        local subOptions = {
            durationText = function()
                ns.Select(content, "Duration seconds", function()
                    return { { text = "Whole minutes", value = 0 }, { text = "Always show seconds", value = 1 },
                        { text = "Show seconds below 10 minutes", value = 2 } }
                end, function() return self.db.secondsMode end, function(value) ns.Set(self, "secondsMode", value) end)
            end,
            auraTimers = function()
                ns.Slider(content, self, "cooldownScale", "Cooldown scale (%)", 10, 200, 1, 100)
            end,
            showAuraBackground = function()
                ns.Slider(content, self, "auraBackgroundAlpha", "Aura background opacity (%)", 0, 100, 1, 100)
            end,
        }
        ns.Check(content, self, options[1][1], options[1][2])
        ns.DependentOptions(content, function() return self.db.enabled end, function()
            for index = 2, #options do
                local key = options[index][1]
                ns.Check(content, self, key, options[index][2])
                if subOptions[key] then
                    ns.SubOptions(content, function() return self.db[key] end, subOptions[key])
                end
            end
            ns.Select(content, "Aura anchor", function()
                return { { text = "Bottom left", value = 1 }, { text = "Bottom right", value = 2 },
                    { text = "Top left", value = 3 }, { text = "Top right", value = 4 } }
            end, function() return self.db.anchorLocation end, function(value) ns.Set(self, "anchorLocation", value) end)
            for _, option in ipairs({
                { "offsetHorizontal", "Horizontal offset", -250, 250 },
                { "offsetVertical", "Vertical offset", -250, 250 },
                { "spacingHorizontal", "Horizontal spacing", -100, 100 },
                { "spacingVertical", "Vertical spacing", -100, 100 },
                { "groupSpacingVertical", "Buff/debuff gap", 0, 100 },
                { "buffPerRow", "Auras per row", 1, 40 }, { "maxNumberOfRow", "Maximum aura rows", 1, 40 },
            }) do ns.Slider(content, self, option[1], option[2], option[3], option[4], 1) end
            ns.Slider(content, self, "scale", "Scale (%)", 10, 200, 1, 100)
        end)
        ns.Button(content, resetLabel, function()
            ns.Confirm(ns.L[resetPrompt], function()
                self.db = ns.Copy(self.defaults)
                self.storage.characters[ns.characterKey] = self.db
                self:Refresh()
                ns.RefreshOptions()
            end)
        end)
    end)
end
