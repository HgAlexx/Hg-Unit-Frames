local ns = Hg_Rebirth
local Castbars = {
    savedVariable = "Hg_Rebirth_Castbars_Options",
    defaults = {
        playerEnabled = true, targetEnabled = true, focusEnabled = true, partyEnabled = true,
        playerTimer = true, targetTimer = true, focusTimer = true, partyTimer = true,
        playerLeftTimer = true, targetLeftTimer = true, focusLeftTimer = true, partyLeftTimer = false,
        playerReplaceName = false, targetReplaceName = false, focusReplaceName = false, partyReplaceName = false,
        showOriginal = false, targetShowOriginal = false, focusShowOriginal = false, opacity = 1,
        castColor = { 1, 0.7, 0 }, channelColor = { 0, 1, 0 }, uninterruptibleColor = { 0.5, 0.5, 0.5 },
    },
    ranges = { opacity = { 0, 1 }, castColor = ns.rgbRange,
        channelColor = ns.rgbRange, uninterruptibleColor = ns.rgbRange },
    bars = {}, notices = {},
}
ns.RegisterModule("CastBar", Castbars)

local media = "Interface\\AddOns\\Hg_Rebirth_Castbars\\Media\\Castbar"
local function colorObject(rgb)
    return CreateColor(rgb[1], rgb[2], rgb[3])
end
local castEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local foreground = {
    "name", "activity", "pvp", "pvpTime", "leader", "master", "role",
    "threat", "dead", "quest", "disconnected", "key",
}

function Castbars:Notice(key, message)
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn(ns.L[message])
end

local function readable(value)
    return not ns.IsSecret(value) and value ~= nil
end

local function present(value)
    return ns.IsSecret(value) or value ~= nil
end

local function timerEnums()
    local interpolation = Enum and Enum.StatusBarInterpolation
    local direction = Enum and Enum.StatusBarTimerDirection
    return interpolation and direction and interpolation.Immediate ~= nil
        and direction.ElapsedTime ~= nil and direction.RemainingTime ~= nil
end

function Castbars:Eligible(bar)
    if ns.positioning then return false end
    if bar.retired or bar.owner.unavailable or not bar.owner.frame or ns.modules[bar.ownerId] ~= bar.owner then return false end
    local exists = UnitExists(bar.unit)
    return self.db[bar.group .. "Enabled"] and not ns.IsSecret(exists) and exists
        and bar.host.frame:IsVisible()
end

function Castbars:TimerAPI(bar)
    return bar.frame.SetTimerDuration and timerEnums()
end

function Castbars:IdleCapability(bar)
    if self:TimerAPI(bar) and UnitCastingDuration and UnitChannelDuration then return true end
    if not UnitCastingInfo or not UnitChannelInfo then return false end
    if C_Secrets and C_Secrets.ShouldUnitSpellCastingBeSecret then
        local restricted = C_Secrets.ShouldUnitSpellCastingBeSecret(bar.unit)
        return not ns.IsSecret(restricted) and not restricted
    end
    return true
end

function Castbars:Read(bar)
    local unit = bar.unit
    if not UnitCastingInfo or not UnitChannelInfo then
        self:Notice("infoAPI", "Casting information API unavailable; embedded cast bars are inactive.")
        return nil, false
    end
    local name, text, _, startTime, endTime, _, notInterruptible, _, empowered, _, id = UnitChannelInfo(unit)
    local mode, guid, delay = "channel"
    if present(name) then
        if readable(empowered) and empowered then mode = "empower" end
    else
        name, text, _, startTime, endTime, _, guid, notInterruptible, _, id, delay = UnitCastingInfo(unit)
        mode = "cast"
        if not present(name) then return nil, self:IdleCapability(bar) end
    end
    local duration
    if self:TimerAPI(bar) then
        if mode == "cast" and UnitCastingDuration then duration = UnitCastingDuration(unit)
        elseif mode == "empower" and UnitEmpoweredChannelDuration then duration = UnitEmpoweredChannelDuration(unit, true)
        elseif mode == "channel" and UnitChannelDuration then duration = UnitChannelDuration(unit) end
    end
    local info = { mode = mode, name = name, text = text, interrupt = notInterruptible,
        id = readable(id) and id or nil, guid = readable(guid) and guid or nil,
        delay = readable(delay) and delay or nil }
    if readable(startTime) and readable(endTime) and endTime > startTime then
        info.startTime, info.endTime = startTime / 1000, endTime / 1000
    end
    if present(duration) then
        info.duration = duration
    elseif info.startTime then
        if mode == "empower" then
            local hold = GetUnitEmpowerHoldAtMaxTime and GetUnitEmpowerHoldAtMaxTime(unit)
            if not readable(hold) then
                self:Notice("empowerAPI", "Empowered duration API unavailable; embedded empowered bars are inactive.")
                return nil, false
            end
            info.endTime = info.endTime + hold / 1000
        end
    else
        self:Notice("progressAPI", "Safe cast progress unavailable; affected embedded bars are inactive.")
        return nil, false
    end
    if readable(startTime) then info.identityTime = startTime end
    if not present(text) then info.text = name end
    return info, true
end

local function sameCast(bar, info)
    if not bar.info or bar.info.mode ~= info.mode then return false end
    if bar.info.id and info.id then return bar.info.id == info.id end
    if bar.info.guid and info.guid then return bar.info.guid == info.guid end
    if bar.info.identityTime and info.identityTime then return bar.info.identityTime == info.identityTime end
    return true
end

function Castbars:Replacement(bar)
    bar.replacing = bar.active and self.db[bar.group .. "ReplaceName"] or false
    if bar.replacing then
        bar.host.name:SetText(bar.spellName)
    else
        bar.host.name:SetText(bar.host.currentName)
    end
end

function Castbars:Meter(bar, hidden)
    if bar.group ~= "target" or bar.host.castMeterHidden == hidden then return end
    bar.host.castMeterHidden = hidden
    bar.host:UpdateResources()
end

function Castbars:Clear(bar)
    bar.frame:SetScript("OnUpdate", nil)
    if bar.cleared and not bar.preview then return end
    bar.preview = nil
    bar.cleared = true
    bar.active, bar.state, bar.info, bar.duration = false, nil, nil, nil
    bar.eventGuid = nil
    bar.legacyStart, bar.legacyEnd, bar.delay = nil, nil, nil
    bar.frame:Hide(); bar.spark:Hide(); bar.flash:Hide(); bar.timer:Hide()
    self:Replacement(bar)
    self:Meter(bar, false)
end

function Castbars:Preview(bar)
    if not ns.positioning or InCombatLockdown() then return end
    self:Clear(bar)
    if bar.retired or not self.db[bar.group .. "Enabled"] then return end
    bar.preview = true
    bar.frame:SetMinMaxValues(0, 100)
    bar.frame:SetValue(60)
    local rgb = self.db.castColor
    bar.frame:SetStatusBarColor(rgb[1], rgb[2], rgb[3], self.db.opacity)
    bar.frame:SetAlpha(0.8)
    bar.frame:Show()
    bar.spark:SetShown(bar.fill ~= nil)
    bar.timer:SetText("1.5")
    bar.timer:SetShown(self.db[bar.group .. "Timer"])
    if self.db[bar.group .. "ReplaceName"] then bar.host.name:SetText(ns.L["Cast bar"]) end
    if bar.group == "target" then bar.host.nameMeter:Hide() end
end

function Castbars:Color(bar)
    local castColor = self.castColor
    local channelColor = self.channelColor
    local uninterruptibleColor = self.uninterruptibleColor
    local r, g, b = castColor:GetRGB()
    if bar.state == "failure" then r, g, b = 1, 0, 0
    elseif bar.state == "success" then r, g, b = 0, 1, 0
    elseif bar.state ~= "neutral" and bar.info and bar.info.mode == "channel" then
        r, g, b = channelColor:GetRGB()
    end
    if bar.active and bar.info then
        if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean and present(bar.info.interrupt) then
            local color = C_CurveUtil.EvaluateColorFromBoolean(bar.info.interrupt,
                uninterruptibleColor, bar.info.mode == "channel" and channelColor or castColor)
            r, g, b = color:GetRGB()
        elseif not ns.IsSecret(bar.info.interrupt) and bar.info.interrupt then
            r, g, b = uninterruptibleColor:GetRGB()
        end
    end
    bar.frame:SetStatusBarColor(r, g, b, self.db.opacity)
end

function Castbars:Terminal(bar, state)
    bar.frame:SetScript("OnUpdate", bar.update)
    bar.active, bar.state, bar.animationTime = false, state, 0
    bar.duration, bar.legacyStart, bar.legacyEnd = nil, nil, nil
    bar.delay = nil
    self:Replacement(bar)
    bar.spark:Hide()
    bar.timer:Hide()
    -- Clear the engine timer before assigning the public terminal fill.
    bar.frame:SetMinMaxValues(0, 1)
    bar.frame:SetValue(state == "neutral" and 0 or 1)
    self:Color(bar)
    bar.flash:SetAlpha(0)
    bar.flash:SetShown(state == "success")
    bar.frame:SetAlpha(0.8)
end

function Castbars:Progress(bar, info)
    bar.duration, bar.legacyStart, bar.legacyEnd = nil, nil, nil
    if present(info.duration) then
        local direction = info.mode == "channel" and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime
        bar.frame:SetTimerDuration(info.duration, Enum.StatusBarInterpolation.Immediate, direction)
        if not ns.IsSecret(info.duration) then bar.duration = info.duration end
    else
        bar.legacyStart, bar.legacyEnd = info.startTime, info.endTime
        bar.frame:SetMinMaxValues(0, info.endTime - info.startTime)
    end
end

function Castbars:Timer(bar)
    if not self.db[bar.group .. "Timer"] or not bar.active then
        bar.timer:Hide()
        return
    end
    local remaining
    if bar.duration and bar.duration.GetRemainingDuration then remaining = bar.duration:GetRemainingDuration()
    elseif bar.legacyEnd then remaining = math.max(0, bar.legacyEnd - GetTime()) end
    if not present(remaining) then
        bar.timer:Hide()
        self:Notice("timerAPI", "Safe remaining-time display unavailable; affected cast timers are hidden.")
        return
    end
    if bar.delay and bar.delay ~= 0 then
        bar.timer:SetFormattedText("|cffcc0000%s%.2f|r %.2f",
            bar.delay < 0 and "-" or "+", math.abs(bar.delay), remaining)
    else bar.timer:SetFormattedText("%.2f", remaining) end
    if not bar.timer:IsShown() then bar.timer:Show() end
end

function Castbars:Begin(bar, info)
    self:Clear(bar)
    bar.cleared = false
    bar.info, bar.active, bar.state = info, true, "active"
    bar.spellName = info.text
    self:Progress(bar, info)
    self:Color(bar)
    bar.delay = info.delay and info.delay / 1000 or nil
    bar.frame:SetAlpha(0.8)
    bar.frame:Show()
    bar.spark:SetShown(bar.fill ~= nil)
    self:Meter(bar, true)
    bar.frame:SetScript("OnUpdate", bar.update)
    self:Replacement(bar)
    self:TickBar(bar, 0)
end

function Castbars:Reconcile(bar, update, restart)
    if ns.positioning and not InCombatLockdown() then self:Preview(bar); return end
    if bar.preview then self:Clear(bar) end
    if not self:Eligible(bar) then self:Clear(bar); return end
    local info, usable = self:Read(bar)
    bar.usable = usable
    if not usable then self:Clear(bar); return end
    if not info then
        if bar.active then self:Terminal(bar, "neutral") end
        return
    end
    if not restart and bar.state and not bar.active and sameCast(bar, info) then return end
    if restart or not bar.active or not sameCast(bar, info) then
        self:Begin(bar, info)
    elseif update then
        if info.mode == "channel" and bar.info.endTime and info.endTime then
            bar.delay = (bar.delay or 0) + info.endTime - bar.info.endTime
        elseif info.mode == "channel" and not (bar.info.endTime and info.endTime) then
            self:Notice("delay", "Restricted channel timing: delay annotations are omitted.")
        elseif info.delay then bar.delay = info.delay / 1000
        elseif bar.info.endTime and info.endTime then
            bar.delay = (bar.delay or 0) + info.endTime - bar.info.endTime
        else self:Notice("delay", "Restricted cast timing: delay annotations are omitted.") end
        bar.info, bar.spellName = info, info.text
        self:Progress(bar, info)
        self:Color(bar); self:Replacement(bar); self:TickBar(bar, 0)
    end
end

function Castbars:TickBar(bar, elapsed)
    if not self:Eligible(bar) then
        if bar.state then self:Clear(bar) end
        return
    end
    if bar.active then
        if bar.legacyEnd then
            local total = bar.legacyEnd - bar.legacyStart
            local progress = math.max(0, math.min(total, GetTime() - bar.legacyStart))
            bar.frame:SetValue(bar.info.mode == "channel" and total - progress or progress)
            if progress == total and bar.info.mode ~= "empower" then self:Terminal(bar, "success"); return end
        end
        self:Timer(bar)
    elseif bar.state then
        bar.animationTime = bar.animationTime + elapsed
        local hold = bar.state == "failure" and 1 or (bar.state == "success" and 4 / 60 or 0)
        if bar.state == "success" then bar.flash:SetAlpha(math.min(0.8, bar.animationTime * 12)) end
        local alpha = math.max(0, 0.8 - math.max(0, bar.animationTime - hold) * 0.6)
        bar.frame:SetAlpha(alpha)
        if alpha == 0 then self:Clear(bar) end
    end
end

local function matchesEvent(bar, guid, id)
    if not bar.info then return false end
    if readable(id) and bar.info.id then return id == bar.info.id end
    if readable(guid) and bar.eventGuid then return guid == bar.eventGuid end
    if readable(guid) and bar.info.guid then return guid == bar.info.guid end
    return false
end

function Castbars:CastEvent(bar, event, unit, guid, spell, arg4, arg5, arg6)
    if ns.positioning and not InCombatLockdown() then self:Preview(bar); return end
    if ns.IsSecret(unit) then
        local update = event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
        if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_EMPOWER_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED"
            or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            self:Notice("event", "Restricted cast outcome: ambiguous endings use a neutral fade.")
        end
        self:Reconcile(bar, update)
        self:ApplyStock()
        return
    end
    if unit ~= bar.unit then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        self:Reconcile(bar, false, true)
        if bar.active and readable(guid) then bar.eventGuid = guid end
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        self:Reconcile(bar, true)
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if bar.active then bar.info.interrupt = event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"; self:Color(bar) end
    else
        local id = arg4
        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then id = arg5
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then id = arg6 end
        if not matchesEvent(bar, guid, id) then
            if not readable(id) and not readable(guid) and bar.active then
                self:Notice("event", "Restricted cast outcome: ambiguous endings use a neutral fade.")
            end
            self:Reconcile(bar)
            return
        end
        local current, usable = self:Read(bar)
        bar.usable = usable
        if current and not sameCast(bar, current) then self:Begin(bar, current); return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if bar.info.mode ~= "channel" and (bar.active or bar.state == "neutral") then self:Terminal(bar, "success") end
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if bar.active or bar.state then
                self:Terminal(bar, "failure")
            end
        elseif bar.active then
            if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                if ns.IsSecret(arg4) then
                    self:Notice("event", "Restricted cast outcome: ambiguous endings use a neutral fade.")
                    self:Terminal(bar, "neutral")
                else self:Terminal(bar, arg4 == nil and "success" or "failure") end
            elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                if ns.IsSecret(arg4) then
                    self:Notice("event", "Restricted cast outcome: ambiguous endings use a neutral fade.")
                    self:Terminal(bar, "neutral")
                else self:Terminal(bar, arg4 and "success" or "failure") end
            else self:Terminal(bar, "neutral") end
        end
    end
    self:ApplyStock()
end

function Castbars:Style(bar)
    local host, group = bar.host, bar.group
    bar.frame:SetSize(host.nameBox:GetWidth() - 10, 15)
    bar.frame:SetPoint("TOPLEFT", host.nameBox, "TOPLEFT", 5, -5)
    bar.flash:SetSize(host.nameBox:GetWidth(), 40)
    bar.timer:ClearAllPoints()
    if self.db[group .. "LeftTimer"] then
        local anchor = host.nameBox
        if (group == "player" or group == "party") and host.portraitBox:IsShown() then anchor = host.portraitBox end
        bar.timer:SetPoint("RIGHT", anchor, "LEFT", 0, 0)
    else
        local anchor = host.nameBox
        if group == "target" or group == "focus" then
            anchor = host.portraitBox:IsShown() and host.portraitBox or host.levelBox
        end
        bar.timer:SetPoint("LEFT", anchor, "RIGHT", 0, 0)
    end
end

local function retire(bar)
    bar.retired = true
    bar.events:UnregisterAllEvents()
    bar.events:SetScript("OnEvent", nil)
    bar.frame:SetScript("OnUpdate", nil)
end

function Castbars:Attach(key, group, host, owner, unit)
    local old = self.bars[key]
    if old and not old.retired and old.host == host and old.nameBox == host.nameBox then
        if old.unit ~= unit then self:Clear(old); old.unit = unit end
        self:Style(old); self:Reconcile(old)
        return
    end
    if old then
        self:Clear(old); old.host.castBar = nil
        retire(old)
    end
    local bar = { host = host, owner = owner, group = group, unit = unit, nameBox = host.nameBox,
        ownerId = group:sub(1, 1):upper() .. group:sub(2) }
    self.bars[key], host.castBar = bar, bar
    local content = CreateFrame("Frame", nil, host.nameBox)
    content:SetAllPoints(host.nameBox)
    content:SetFrameLevel(host.nameBox:GetFrameLevel() + 3)
    content:EnableMouse(false)
    for _, name in ipairs(foreground) do
        if host[name] then host[name]:SetParent(content) end
    end
    bar.content = content
    bar.frame = CreateFrame("StatusBar", nil, host.nameBox)
    bar.frame:SetFrameLevel(host.nameBox:GetFrameLevel() + 1)
    bar.frame:EnableMouse(false)
    bar.frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.fill = bar.frame.GetStatusBarTexture and bar.frame:GetStatusBarTexture()
    if ns.IsSecret(bar.fill) then bar.fill = nil end
    bar.spark = ns.Icon(bar.frame, media .. "Spark.tga", 44, 44, "CENTER", bar.fill or bar.frame, "RIGHT", 0, 0)
    bar.spark:SetBlendMode("ADD")
    if not bar.fill then self:Notice("spark", "Cast fill-edge API unavailable; embedded sparks are hidden.") end
    bar.flash = CreateFrame("Frame", nil, bar.frame)
    bar.flash:EnableMouse(false)
    bar.flash:SetFrameLevel(host.nameBox:GetFrameLevel() + 2)
    bar.flash:SetPoint("CENTER", host.nameBox, "CENTER", 0, 0)
    bar.flashTexture = ns.Icon(bar.flash, media .. "Flash.tga", 240, 64, "CENTER", bar.flash, "CENTER", 0, 0)
    bar.flashTexture:ClearAllPoints()
    bar.flashTexture:SetAllPoints(bar.flash)
    bar.flashTexture:SetBlendMode("ADD")
    bar.timer = ns.Label(bar.frame, "GameFontHighlight")
    bar.events = CreateFrame("Frame")
    for _, event in ipairs(castEvents) do
        if group == "player" then bar.events:RegisterUnitEvent(event, "player", "vehicle")
        else bar.events:RegisterUnitEvent(event, unit) end
    end
    bar.events:SetScript("OnEvent", function(_, event, ...) self:CastEvent(bar, event, ...) end)
    host.frame:HookScript("OnHide", function()
        if not bar.retired then self:Clear(bar); self:ApplyStock() end
    end)
    host.frame:HookScript("OnShow", function()
        if not bar.retired then self:Reconcile(bar); self:ApplyStock() end
    end)
    bar.update = function(_, elapsed) self:TickBar(bar, elapsed) end
    self:Style(bar); self:Clear(bar); self:Reconcile(bar)
end

function Castbars:HostChanged(host)
    local bar = host and host.castBar
    if bar and bar.group == "player" and bar.unit ~= host.unit then
        self:Clear(bar); bar.unit = host.unit
        self:Reconcile(bar); self:ApplyStock()
    end
    ns.AfterCombat("CastBarHosts", function() self:Discover() end)
end

function Castbars:Discover()
    for _, group in ipairs({ "player", "target", "focus", "party" }) do
        local name = group:sub(1, 1):upper() .. group:sub(2)
        local owner = ns.modules[name]
        if owner and owner.frame and not owner.unavailable then
            if group == "party" then
                for index, host in ipairs(owner.members) do self:Attach("party" .. index, group, host, owner, host.unit) end
            else self:Attach(group, group, owner, owner, group == "player" and owner.unit or group) end
        end
    end
    for _, bar in pairs(self.bars) do
        if ns.modules[bar.ownerId] ~= bar.owner or bar.owner.unavailable or not bar.owner.frame then
            self:Clear(bar); bar.usable = false
            retire(bar)
        end
    end
    self:ApplyStock()
    if self.UpdateHostStatus then self:UpdateHostStatus() end
end

function Castbars:Refresh()
    self.castColor = colorObject(self.db.castColor)
    self.channelColor = colorObject(self.db.channelColor)
    self.uninterruptibleColor = colorObject(self.db.uninterruptibleColor)
    if not self.started then return end
    for _, bar in pairs(self.bars) do
        if bar.preview and not ns.positioning then
            self:Clear(bar)
            self:Reconcile(bar)
        end
        if not self.db[bar.group .. "Enabled"] then self:Clear(bar)
        else self:Replacement(bar); self:Color(bar); self:Timer(bar) end
    end
    self:ApplyStock()
    self:HostChanged()
end

function Castbars:Start()
    if self.started then return end
    self.castColor = colorObject(self.db.castColor)
    self.channelColor = colorObject(self.db.channelColor)
    self.uninterruptibleColor = colorObject(self.db.uninterruptibleColor)
    self.started = true
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE", "ADDON_LOADED", "PLAYER_REGEN_ENABLED" }) do self.events:RegisterEvent(event) end
    self.events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then
            for _, id in ipairs({ "Player", "Target", "Focus", "Party" }) do
                local host = ns.modules[id]
                if host and host.db and host.Start and not host.frame and not host.unavailable then host:Start() end
            end
        end
        for key, bar in pairs(self.bars) do
            if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_TARGET_CHANGED" and key == "target")
                or (event == "PLAYER_FOCUS_CHANGED" and key == "focus") or (event == "GROUP_ROSTER_UPDATE" and bar.group == "party") then
                self:Clear(bar)
            end
        end
        self:HostChanged()
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:HostChanged() end, self)
    end
    self:HostChanged()
end
