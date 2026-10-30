local ns = Hg_Rebirth
local FocusTarget = ns.modules.FocusTarget

function FocusTarget:HookStockMethods(frame, methods)
    if not frame then return end
    self.stockHooks = self.stockHooks or {}
    local hooked = self.stockHooks[frame] or {}
    self.stockHooks[frame] = hooked
    for _, method in ipairs(methods) do
        if frame[method] and not hooked[method] then
            hooked[method] = true
            hooksecurefunc(frame, method, function()
                if not self.applyingStock then self:ApplyStock() end
            end)
        end
    end
end

function FocusTarget:TrackStock(frame, frames, alphaOwner)
    if not frame then return end
    if not frame.EnableMouse or not frame.IsMouseEnabled
        or (alphaOwner and (not frame.SetAlpha or not frame.GetAlpha)) then
        self:Notice("stockAPI", "Native focus-target ownership API unavailable; unsupported widgets are unchanged.")
        return
    end
    frames[frame] = true
    self.stockFrames = self.stockFrames or {}
    if self.stockFrames[frame] then return true end
    local data = { alphaOwner = alphaOwner }
    self.stockFrames[frame] = data
    if alphaOwner then
        hooksecurefunc(frame, "SetAlpha", function(_, alpha)
            if self.applyingStock or not data.owned then return end
            data.alpha = alpha
            self:ApplyStock()
        end)
    end
    hooksecurefunc(frame, "EnableMouse", function(_, enabled)
        if self.applyingStock or not data.owned then return end
        data.mouse = enabled
        self:ApplyStock()
    end)
    if frame.HookScript then
        frame:HookScript("OnShow", function()
            if data.owned and not self.applyingStock then self:ApplyStock() end
        end)
    end
    return true
end

function FocusTarget:DiscoverStock()
    self:HookStockMethods(FocusFrame, { "CreateTargetofTarget", "Update" })
    local root = FocusFrame and FocusFrame.totFrame or FocusFrameToT
    local frames = {}
    if not root then
        self:Notice("stock", "Native focus-target unavailable; waiting for Blizzard UI to load.")
        return frames
    end
    if not self:TrackStock(root, frames, true) then return frames end
    self:TrackStock(root.HealthBar, frames); self:TrackStock(root.ManaBar, frames)
    local name = root.GetName and root:GetName()
    for index = 1, 4 do
        self:TrackStock(root["Debuff" .. index] or (name and _G[name .. "Debuff" .. index]), frames)
    end
    self:HookStockMethods(root, { "Update" })
    return frames
end

function FocusTarget:ApplyStock()
    if not self.frame or self.applyingStock then return end
    if InCombatLockdown() then ns.AfterCombat("FocusTargetStock", function() self:ApplyStock() end); return end
    local frames = self:DiscoverStock()
    local active = self.db.enabled and not (not self.db.showInRaid and IsInRaid())
    self.applyingStock = true
    for frame, data in pairs(self.stockFrames or {}) do
        if data.owned and not (active and frames[frame]) then
            data.owned = false
            if data.alphaOwner then frame:SetAlpha(data.alpha) end
            frame:EnableMouse(data.mouse)
        end
    end
    for frame, data in pairs(self.stockFrames or {}) do
        if active and frames[frame] then
            if not data.owned then
                if data.alphaOwner then data.alpha = frame:GetAlpha() end
                data.mouse = frame:IsMouseEnabled()
            end
            data.owned = true
            if data.alphaOwner and frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
            if frame:IsMouseEnabled() then frame:EnableMouse(false) end
        end
    end
    self.applyingStock = false
end
