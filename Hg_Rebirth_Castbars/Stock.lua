local ns = Hg_Rebirth
local Castbars = ns.modules.CastBar

local SPELLBAR_EVENTS = { "CVAR_UPDATE", "VARIABLES_LOADED" }

local function Protected(frame)
    return InCombatLockdown() and frame.IsProtected and frame:IsProtected()
end

-- Blizzard spellbars (TargetFrameMixin:CreateSpellbar) always register these and read self.unit in them,
-- so they must stay off while the unit is cleared. IsEventRegistered can return secrets, so it is not queried.
function Castbars:StockExtraEvents(frame)
    local events = {}
    if type(frame.updateEvent) ~= "string" then return events end
    for _, event in ipairs(SPELLBAR_EVENTS) do events[#events + 1] = event end
    events[#events + 1] = frame.updateEvent
    return events
end

function Castbars:SuppressStockUnit(frame, data)
    if not data.unitMode or Protected(frame) then return end
    self.applyingStock = true
    data.extraEvents = data.extraEvents or {}
    for _, event in ipairs(self:StockExtraEvents(frame)) do
        data.extraEvents[event] = true
        frame:UnregisterEvent(event)
    end
    if frame.unit ~= nil then
        data.unit, data.showTradeSkills, data.showShield = frame.unit, frame.showTradeSkills, frame.showShield
        frame:SetUnit(nil)
    end
    self.applyingStock = false
end

function Castbars:EnforceStock(frame, data)
    if self.applyingStock or not data.owned then return end
    self.applyingStock = true
    for _, name in ipairs({ "HoldFadeOutAnim", "FadeOutAnim" }) do
        local animation = frame[name]
        if animation and animation.IsPlaying and animation.Stop and animation:IsPlaying() then animation:Stop() end
    end
    local alpha = frame:GetAlpha()
    if ns.IsSecret(alpha) or alpha ~= 0 then frame:SetAlpha(0) end
    local mouse = frame:IsMouseEnabled()
    if ns.IsSecret(mouse) or mouse then frame:EnableMouse(false) end
    if not Protected(frame) then
        if not data.unitMode and not data.eventsDisabled then
            frame:UnregisterAllEvents()
            data.eventsDisabled = true
        end
        if frame:IsShown() then frame:Hide() end
    end
    self.applyingStock = false
end

function Castbars:ReleaseStock(frame, data)
    data.owned = false
    self.applyingStock = true
    frame:SetAlpha(data.alpha or 1)
    frame:EnableMouse(data.mouse and true or false)
    if data.unitMode then
        for event in pairs(data.extraEvents or {}) do frame:RegisterEvent(event) end
        data.extraEvents = nil
        if data.unit ~= nil and frame.unit == nil then
            frame:SetUnit(data.unit, data.showTradeSkills, data.showShield)
        end
    elseif data.eventsDisabled then
        self:Notice("stockRestore", "Native cast bar events need a UI reload to return.")
    end
    self.applyingStock = false
end

function Castbars:HookStockAnimations(frame, data)
    data.animations = data.animations or {}
    for _, name in ipairs({ "HoldFadeOutAnim", "FadeOutAnim" }) do
        local animation = frame[name]
        if animation and animation.Play and animation.IsPlaying and animation.Stop and not data.animations[animation] then
            data.animations[animation] = true
            hooksecurefunc(animation, "Play", function() self:EnforceStock(frame, data) end)
        end
    end
end

function Castbars:TrackStock(frame, group)
    if not frame then return end
    if not frame.SetAlpha or not frame.GetAlpha or not frame.EnableMouse or not frame.IsMouseEnabled
        or not frame.HookScript or not frame.UnregisterAllEvents
        or (frame.IsForbidden and frame:IsForbidden()) then
        if group == "focus" then
            self:Notice("focusStockAPI", "Native focus cast-bar ownership API unavailable; native casting is unchanged.")
        elseif group == "target" then
            self:Notice("targetStockAPI", "Native target cast-bar ownership API unavailable; native casting is unchanged.")
        else self:Notice("stockAPI", "Native player cast-bar ownership API unavailable; native casting is unchanged.") end
        return
    end
    self.stockFrames = self.stockFrames or {}
    if self.stockFrames[frame] then
        self:HookStockAnimations(frame, self.stockFrames[frame])
        return true
    end
    local alpha, mouse = frame:GetAlpha(), frame:IsMouseEnabled()
    local data = {
        group = group,
        alpha = (not ns.IsSecret(alpha) and alpha > 0) and alpha or 1,
        mouse = not ns.IsSecret(mouse) and mouse or false,
        unitMode = type(frame.SetUnit) == "function" and type(frame.unit) == "string"
            and type(frame.UnregisterEvent) == "function",
    }
    self.stockFrames[frame] = data
    hooksecurefunc(frame, "SetAlpha", function()
        if self.applyingStock or not data.owned then return end
        self:EnforceStock(frame, data)
    end)
    hooksecurefunc(frame, "EnableMouse", function()
        if self.applyingStock or not data.owned then return end
        self:EnforceStock(frame, data)
    end)
    if data.unitMode then
        hooksecurefunc(frame, "SetUnit", function(_, unit)
            if self.applyingStock or not data.owned or unit == nil then return end
            if Protected(frame) then
                ns.AfterCombat("CastBarStock", function() self:ApplyStock() end)
            else
                self:SuppressStockUnit(frame, data)
                self:EnforceStock(frame, data)
            end
        end)
    else
        for _, method in ipairs({ "RegisterEvent", "RegisterUnitEvent" }) do
            if frame[method] then
                hooksecurefunc(frame, method, function()
                    if self.applyingStock or not data.owned then return end
                    data.eventsDisabled = false
                    self:EnforceStock(frame, data)
                end)
            end
        end
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if frame[method] then
            hooksecurefunc(frame, method, function()
                if self.applyingStock or not data.owned then return end
                self:EnforceStock(frame, data)
            end)
        end
    end
    frame:HookScript("OnShow", function()
        self:EnforceStock(frame, data)
    end)
    self:HookStockAnimations(frame, data)
    return true
end

function Castbars:StockEligible(bar)
    local active = bar and bar.usable and self.db.opacity > 0 and self:Eligible(bar)
    if active then
        local alpha = bar.host.frame:GetAlpha()
        active = not ns.IsSecret(alpha) and alpha > 0
    end
    return active
end

function Castbars:ShowsNative(group)
    if group == "player" then return self.db.showOriginal end
    return self.db[group .. "ShowOriginal"]
end

-- Configuration-level intent; transient host visibility never releases a native bar.
function Castbars:StockWanted(bar, group)
    if not bar or bar.retired or bar.owner.unavailable or not bar.owner.frame
        or ns.modules[bar.ownerId] ~= bar.owner then return false end
    if not self.db[group .. "Enabled"] or self.db.opacity <= 0 then return false end
    return not self:ShowsNative(group)
end

function Castbars:ApplyStock()
    if not self.started or self.applyingStock then return end
    if InCombatLockdown() then
        for frame, data in pairs(self.stockFrames or {}) do self:EnforceStock(frame, data) end
        ns.AfterCombat("CastBarStock", function() self:ApplyStock() end)
        return
    end
    local desired, wanted, currentFrames = {}, {}, {}
    for _, group in ipairs({ "player", "focus", "target" }) do
        local active = self:StockEligible(self.bars[group])
        active = active and not self:ShowsNative(group)
        local current
        if group == "player" then current = PlayerCastingBarFrame or CastingBarFrame
        elseif group == "focus" then current = FocusFrame and FocusFrame.spellbar or FocusFrameSpellBar
        else current = TargetFrame and TargetFrame.spellbar or TargetFrameSpellBar end
        if active and not current then
            if group == "focus" then
                self:Notice("focusStock", "Native focus cast bar unavailable; waiting for Blizzard UI to load.")
            elseif group == "target" then
                self:Notice("targetStock", "Native target cast bar unavailable; waiting for Blizzard UI to load.")
            else self:Notice("stock", "Native player cast bar unavailable; waiting for Blizzard UI to load.") end
        end
        if current then
            currentFrames[current] = true
            wanted[current] = self:StockWanted(self.bars[group], group)
        end
        if active and self:TrackStock(current, group) then desired[current] = true end
    end
    for frame, data in pairs(self.stockFrames or {}) do
        if desired[frame] then
            data.owned = true
            self:SuppressStockUnit(frame, data)
        elseif data.owned and currentFrames[frame] and not wanted[frame] then
            self:ReleaseStock(frame, data)
        end
    end
    for frame, data in pairs(self.stockFrames or {}) do self:EnforceStock(frame, data) end
end