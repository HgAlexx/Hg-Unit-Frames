local ns = Hg_Rebirth
local Buff = {
    savedVariable = "Hg_Rebirth_Target_Aura_Options",
    defaults = {
        enabled = true, scale = 0.7,
        offsetVertical = 0, offsetHorizontal = 5, spacingVertical = 1, spacingHorizontal = 1,
        groupSpacingVertical = 3,
        buffPerRow = 20, maxNumberOfRow = 2, anchorLocation = 1,
        auraTimers = true, cooldownScale = 0.7, durationText = false, secondsMode = 2,
        castableBuffs = false, curableDebuffs = false, ownDebuffs = false,
        showAuraBackground = false, auraBackgroundAlpha = 1,
    },
    ranges = {
        scale = { 0.1, 2 }, cooldownScale = { 0.1, 2 },
        offsetVertical = { -250, 250 }, offsetHorizontal = { -250, 250 },
        spacingVertical = { -100, 100 }, spacingHorizontal = { -100, 100 },
        groupSpacingVertical = { 0, 100 },
        auraBackgroundAlpha = { 0, 1 },
        buffPerRow = { 1, 40, integer = true }, maxNumberOfRow = { 1, 40, integer = true },
        anchorLocation = { 1, 4, integer = true }, secondsMode = { 0, 2, integer = true },
    },
}
ns.InstallAuraEngine(Buff, "target", "TargetAura")
ns.RegisterModule("TargetAura", Buff)

function Buff:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn(ns.L["Target Aura"] .. ": " .. ns.L[message])
end

function Buff:SuppressStock()
    if TargetFrame and TargetFrame.GetAuraContainer then
        local container = TargetFrame:GetAuraContainer()
        if container then container:SetEnabled(false) end
    end
end

function Buff:Layout()
    local db = self.db
    local host = ns.modules.Target
    if not host or not host.frame or host.unavailable then self.frame:Hide(); return end
    self.frame:SetParent(host.frame)
    self.frame:SetScale(db.scale)
    local right, up = db.anchorLocation % 2 == 0, db.anchorLocation >= 3
    local point = up and (right and "BOTTOMRIGHT" or "BOTTOMLEFT") or (right and "TOPRIGHT" or "TOPLEFT")
    local target = up and self:TopAnchor(host) or host.stats
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, target, up and (right and "TOPRIGHT" or "TOPLEFT") or (right and "BOTTOMRIGHT" or "BOTTOMLEFT"),
        db.offsetHorizontal / db.scale, db.offsetVertical / db.scale)
    self:UpdateFormatter()
    local entry = self:Container()
    self.active = entry
    self:LayoutContainers(entry, point, right, up)
    self.frame:SetShown(db.enabled)
    self:Preview()
    self:SuppressStock()
end

function Buff:Start()
    if InCombatLockdown() then ns.AfterCombat("TargetAuraStart", function() self:Start() end); return end
    if self.frame or self.unavailable then return end
    if not ns.HasAuraAPI() then
        self.unavailable = true
        self:Notice("auraAPI", "Mainline aura API unavailable; native Target auras retained.")
        return
    end
    local host = ns.modules.Target
    if not host or host.unavailable then return end
    if not host.frame then
        if not self.hostHooked then
            self.hostHooked = true
            hooksecurefunc(host, "Start", function() self:Start() end)
        end
        return
    end
    self:InitializeFormatter()
    self.frame = CreateFrame("Frame", "Hg_Rebirth_TargetAuraFrame", host.frame)
    self.frame:SetSize(1, 1)
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }) do
        self.events:RegisterEvent(event)
    end
    self.events:RegisterUnitEvent("UNIT_FACTION", "target")
    self.events:SetScript("OnEvent", function()
        if not self.active then return end
        self:UpdateFilters()
        for _, container in ipairs({ self.active.container, self.active.debuffContainer,
            self.active.buffBackground.frame, self.active.debuffBackground.frame }) do
            container:UpdateAllAuras()
        end
    end)
    hooksecurefunc(host, "Layout", function() self:Refresh() end)
    if TargetFrame and TargetFrame.ConfigureAuraContainer then
        hooksecurefunc(TargetFrame, "ConfigureAuraContainer", function()
            ns.AfterCombat("TargetAuraStock", function() self:SuppressStock() end)
        end)
    end
    if TargetFrame then
        TargetFrame:HookScript("OnShow", function()
            ns.AfterCombat("TargetAuraStock", function() self:SuppressStock() end)
        end)
    end
    self:Layout()
end
