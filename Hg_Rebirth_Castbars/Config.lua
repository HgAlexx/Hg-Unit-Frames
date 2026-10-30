local ns = Hg_Rebirth
local Castbars = ns.modules.CastBar

function Castbars:UpdateHostStatus()
    for group, label in pairs(self.hostLabels or {}) do
        local bar = self.bars[group == "party" and "party1" or group]
        label:SetText(ns.L[bar and not bar.retired and "Custom host available."
            or "Custom host unavailable; settings are retained."])
    end
end

-- Blizzard Party frames have no native cast bar, so Party has no native option.
local NATIVE_LABELS = {
    player = "Show native player cast bar alongside replacement",
    target = "Show native target cast bar alongside replacement",
    focus = "Show native focus cast bar alongside replacement",
}

function Castbars:BuildOptions(category)
    ns.Panel("Cast bars",
        ns.L["Embedded cast bars for optional Player, Target, Focus and Party hosts."], category, function(content)
        self.hostLabels = {}
        for _, group in ipairs({ "player", "target", "focus", "party" }) do
            ns.Section(content, group:sub(1, 1):upper() .. group:sub(2))
            self.hostLabels[group] = ns.Section(content, "")
            self.hostLabels[group]:SetFontObject("GameFontHighlightSmall")
            self.hostLabels[group]:SetTextColor(0.75, 0.75, 0.75)
            local enabledKey, timerKey = group .. "Enabled", group .. "Timer"
            ns.Check(content, self, enabledKey, "Enable embedded cast bar")
            ns.SubOptions(content, function() return self.db[enabledKey] end, function()
                ns.Check(content, self, timerKey, "Display cast timer")
                ns.SubOptions(content, function() return self.db[timerKey] end, function()
                    ns.Check(content, self, group .. "LeftTimer", "Place cast timer on the left")
                end)
                ns.Check(content, self, group .. "ReplaceName", "Replace unit name with spell name")
                if NATIVE_LABELS[group] then
                    ns.Check(content, self, group == "player" and "showOriginal" or group .. "ShowOriginal", NATIVE_LABELS[group])
                end
            end)
        end

        ns.Section(content, "Appearance")
        for _, option in ipairs({
            { "castColor", "Cast color" }, { "channelColor", "Channel color" },
            { "uninterruptibleColor", "Uninterruptible cast color" },
        }) do
            ns.ColorPicker(content, self, option[1], option[2])
        end
        ns.Slider(content, self, "opacity", "Cast fill opacity (%)", 0, 100, 1, 100)
        local notes = ns.Label(content, "GameFontHighlightSmall")
        notes:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -content.cursor)
        notes:SetJustifyH("LEFT")
        notes:SetWordWrap(true)
        notes:SetNonSpaceWrap(true)
        notes:SetText(table.concat({
            ns.L["Native Target and Focus cast bars are hidden while their embedded replacements are usable, unless their native option is checked. Blizzard Party frames have no native cast bar."],
            ns.L["Native cast bars return without a reload when their suppression is turned off; changes made in combat apply afterwards."],
            ns.L["Player follows vehicle UI. Target casting temporarily replaces its name resource meter."],
            ns.L["Empowered spells use one charging bar without stage markers."],
            ns.L["Missing hosts retain their settings. Unavailable cast details are omitted with a notice."],
        }, "\n\n"))
        local top, previousWidth = content.cursor
        local function resizeNotes()
            local width = math.max(1, content:GetWidth() - 8)
            if width == previousWidth then return end
            previousWidth = width
            notes:SetWidth(width)
            content.cursor = top + notes:GetStringHeight() + 12
            content:SetHeight(content.cursor + 16)
        end
        content:HookScript("OnSizeChanged", resizeNotes)
        resizeNotes()
        self:UpdateHostStatus()
    end)
end

if ns.loggedIn then
    Castbars:Start()
    if ns.category then Castbars:BuildOptions(ns.category); ns.RefreshOptions() end
end
