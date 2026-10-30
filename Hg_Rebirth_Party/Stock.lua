local ns = Hg_Rebirth
local Party = ns.modules.Party

function Party:StockActive()
    return self.frame ~= nil and self.db.visibility ~= "hidden" and not IsInRaid()
        and UnitExists("party1")
end

function Party:SuppressStockFrame(frame, data)
    local alpha = frame:GetAlpha()
    if ns.IsSecret(alpha) or alpha ~= 0 then frame:SetAlpha(0) end
    if data.mouseSupported and frame:IsMouseEnabled() then frame:EnableMouse(false) end
end

function Party:ReapplyStockFrame(frame, data)
    if InCombatLockdown() then
        ns.AfterCombat("PartyStock", function() self:ApplyStock() end)
        return
    end
    if not self:StockActive() then self:ApplyStock(); return end
    self.applyingStock = true
    self:SuppressStockFrame(frame, data)
    self.applyingStock = false
end

function Party:TrackStock(frame)
    if not frame then return end
    self.stockFrames = self.stockFrames or {}
    if self.stockFrames[frame] then return end
    local data = { mouseSupported = frame.EnableMouse and frame.IsMouseEnabled }
    self.stockFrames[frame] = data
    hooksecurefunc(frame, "SetAlpha", function(_, alpha)
        if self.applyingStock or not data.owned then return end
        data.alpha = alpha
        self:ReapplyStockFrame(frame, data)
    end)
    if data.mouseSupported then
        hooksecurefunc(frame, "EnableMouse", function(_, enabled)
            if self.applyingStock or not data.owned then return end
            data.mouse = enabled
            self:ReapplyStockFrame(frame, data)
        end)
    end
    if frame.HookScript then
        frame:HookScript("OnShow", function()
            if data.owned then self:ReapplyStockFrame(frame, data) end
        end)
    end
end

function Party:TrackStockMember(frame, compact)
    if not frame then return end
    self:TrackStock(frame)
    if compact then
        self:TrackStock(frame.healthBar); self:TrackStock(frame.powerBar)
        self:TrackStock(frame.selectionHighlight); self:TrackStock(frame.centerStatusIcon)
        self:TrackStock(frame.readyCheckIcon)
        self:TrackStock(frame.readyCheckIcon and frame.readyCheckIcon.Icon)
        self:TrackStock(frame.pingIconFrame)
    else
        self:TrackStock(frame.HealthBarContainer and frame.HealthBarContainer.HealthBar or frame.HealthBar)
        self:TrackStock(frame.ManaBar)
        if frame.PetFrame then
            self:TrackStock(frame.PetFrame); self:TrackStock(frame.PetFrame.HealthBar)
        end
    end
end

function Party:HookStockLayout(frame, methods)
    if not frame then return end
    self.stockHooks = self.stockHooks or {}
    local hooked = self.stockHooks[frame] or {}
    self.stockHooks[frame] = hooked
    for _, method in ipairs(methods) do
        if frame[method] and not hooked[method] then
            hooked[method] = true
            hooksecurefunc(frame, method, function()
                if not self.applyingStock and (self.stockOwned or self:StockActive()) then
                    ns.AfterCombat("PartyStock", function() self:ApplyStock() end)
                end
            end)
        end
    end
end

function Party:DiscoverStock()
    self:TrackStock(PartyFrame)
    if PartyFrame then
        local pool = PartyFrame.PartyMemberFramePool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do self:TrackStockMember(frame, false) end
        end
        for index = 1, 4 do self:TrackStockMember(PartyFrame["MemberFrame" .. index], false) end
        self:HookStockLayout(PartyFrame, { "InitializePartyMemberFrames", "UpdateMemberFrames",
            "UpdatePartyFrames", "UpdateSpacingAndLayout", "UpdatePartyMemberBackground", "Layout" })
    end
    for index = 1, 4 do
        self:TrackStockMember(_G["PartyMemberFrame" .. index], false)
        self:TrackStock(_G["PartyMemberFrame" .. index .. "HealthBar"])
        self:TrackStock(_G["PartyMemberFrame" .. index .. "ManaBar"])
        self:TrackStock(_G["PartyMemberFrame" .. index .. "PetFrame"])
    end
    if CompactPartyFrame then
        self:TrackStock(CompactPartyFrame)
        for _, frame in ipairs(CompactPartyFrame.memberUnitFrames or {}) do self:TrackStockMember(frame, true) end
        for _, frame in ipairs(CompactPartyFrame.petUnitFrames or {}) do self:TrackStockMember(frame, true) end
        self:HookStockLayout(CompactPartyFrame, { "RefreshMembers", "UpdateVisibility", "UpdateLayout" })
    end
    if not self.stockFrames or not next(self.stockFrames) then
        self:Notice("stock", "Native Party frames unavailable; waiting for Blizzard UI to load.")
    end
end

function Party:ApplyStock()
    if not self.frame then return end
    if InCombatLockdown() then ns.AfterCombat("PartyStock", function() self:ApplyStock() end); return end
    self:DiscoverStock()
    local active = self:StockActive()
    self.applyingStock = true
    for frame, data in pairs(self.stockFrames or {}) do
        if active then
            if not data.owned then
                data.alpha = frame:GetAlpha()
                if data.mouseSupported then data.mouse = frame:IsMouseEnabled() end
            end
            data.owned = true
            self:SuppressStockFrame(frame, data)
        elseif data.owned then
            data.owned = false
            frame:SetAlpha(data.alpha)
            if data.mouseSupported then frame:EnableMouse(data.mouse) end
        end
    end
    self.applyingStock = false
    self.stockOwned = active
end
