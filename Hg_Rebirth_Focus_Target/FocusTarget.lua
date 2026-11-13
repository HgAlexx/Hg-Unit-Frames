local ns = Hg_Rebirth
local FocusTarget = {
    savedVariable = "Hg_Rebirth_Focus_Target_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        enabled = true, showInRaid = true, locked = true, showPower = true,
        className = true, scale = 1, opacity = 1, x = 593.6735229492173, y = -656.085956960502,
        buffs = false, debuffs = false, castableBuffs = false, curableDebuffs = false, ownDebuffs = false,
        auraSpacingHorizontal = 1, auraSpacingVertical = 1,
        groupSpacingVertical = 1,
        sticky1Y = 3.933376791565024e-05,
        stickyMove = true,
        sticky1ChildX = 0,
        sticky1Placed = true,
        stickyParent = "Focus",
        stickyScale = false,
        sticky1ChildY = 0,
        sticky1ParentY = 0,
        sticky1X = -3.866666722546029,
        sticky1ParentX = 1,
    },
    ranges = {
        tooltipAnchor = { right = true, default = true },
        scale = { 0.01, 1.49 }, opacity = { 0, 1 },
        auraSpacingHorizontal = { -10, 30 }, auraSpacingVertical = { -10, 30 },
        groupSpacingVertical = { 0, 100 },
    },
    buttons = {},
}
ns.AddUnitNameSettings(FocusTarget)
ns.RegisterModule("FocusTarget", FocusTarget)

function FocusTarget:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Focus Target: " .. ns.L[message])
end

function FocusTarget:UpdateMember(entry, kind)
    if ns.PreviewUnit(entry, "Focus Target", self.db) then return end
    local previousGUID = entry.guid
    ns.UpdateCompactTarget(self, entry, kind)
    if kind and previousGUID == entry.guid then return end
    if entry.buffs then
        self:UpdateAuraFilters()
        if ns.IsSecret(UnitGUID(entry.unit)) or previousGUID ~= entry.guid then
            self:UpdateAuraIcons()
            return true
        end
    end
end

function FocusTarget:UpdateAuraIcons()
    if not self.entry.buffs then return end
    self.entry.buffs.container:UpdateAllAuras()
    self.entry.debuffs.container:UpdateAllAuras()
end

function FocusTarget:UpdateAuraFilters()
    local entry, db = self.entry, self.db
    local friendly, restricted = ns.UnitAuraReaction(self, entry.unit)
    local buffFilter = db.castableBuffs and "HELPFUL|RAID" or "HELPFUL"
    local debuffFilter = "HARMFUL"
    if friendly and db.curableDebuffs then debuffFilter = "HARMFUL|RAID"
    elseif not friendly and not restricted and db.ownDebuffs then debuffFilter = "HARMFUL|PLAYER" end
    for index = 1, 2 do
        local group = index == 1 and entry.buffs or entry.debuffs
        local filter = index == 1 and buffFilter or debuffFilter
        local enabled = db.enabled and (index == 1 and db.buffs or index == 2 and db.debuffs)
        if group.filter ~= filter then
            group.filter = filter
            group.container:SetAuraGroupFilterString("icons", filter)
        end
        if group.enabled ~= enabled then group.enabled = enabled; group.container:SetEnabled(enabled) end
    end
    if entry.auraFriendly ~= friendly then
        entry.auraFriendly = friendly
        ns.AfterCombat("FocusTargetAuraLayout", function() self:LayoutAuras() end)
    end
end

function FocusTarget:LayoutAuras()
    if not self.entry.buffs then return end
    local friendly = ns.UnitAuraReaction(self, self.entry.unit)
    ns.LayoutChainedAuras(self.entry, friendly, self.db.buffs, self.db.debuffs,
        self.db.auraSpacingHorizontal, self.db.auraSpacingVertical, self.db.groupSpacingVertical)
end

function FocusTarget:UpdateAll()
    return self:UpdateMember(self.entry)
end

function FocusTarget:Layout()
    ns.LayoutCompactTarget(self, self.entry)
    self:LayoutAuras()
end

function FocusTarget:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    ns.AfterCombat("FocusTargetLayout", function() self:Layout(); self:UpdateAll(); self:ApplyStock() end)
end

function FocusTarget:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset Focus Target during combat."]); return end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self:Refresh()
end

function FocusTarget:Start()
    if self.frame then return end
    if InCombatLockdown() then ns.AfterCombat("FocusTargetStart", function() self:Start() end); return end
    self.borderAPI = ns.HasAuraAPI() == true
    if not self.borderAPI then
        self:Notice("borderAPI", "Mainline aura API unavailable; Focus Target remains active without aura icons or debuff-border coloring.")
    end
    self.healthCurve = ns.CreateHealthCurve()
    self.entry = ns.CreateCompactTarget(self, { unit = "focustarget", xKey = "x", yKey = "y" },
        "Hg_Rebirth_FocusTargetFrame")
    if self.borderAPI then ns.CreateChainedAuras(self.entry) end
    for _, key in ipairs({ "frame", "nameBox", "stats", "marker", "health", "power" }) do self[key] = self.entry[key] end
    self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
        "RAID_TARGET_UPDATE", "PLAYER_ALIVE", "ADDON_LOADED" }) do self.events:RegisterEvent(event) end
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_CONNECTION",
        "UNIT_FACTION", "UNIT_AURA" }) do self.events:RegisterUnitEvent(event, "focustarget") end
    self.events:RegisterUnitEvent("UNIT_TARGET", "focus")
    self.events:SetScript("OnEvent", function(_, event)
        if ns.positioning then self:UpdateAll(); return end
        if ns.VitalsEventKinds[event] then
            self:UpdateMember(self.entry, ns.VitalsEventKinds[event])
            return
        end
        if event == "PLAYER_FOCUS_CHANGED" then
            ns.ResetCompactTarget(self.entry); self.entry.guid = nil
            for _, border in ipairs(self.entry.borders) do border:UpdateAllAuras() end
        end
        local updatedAuras = self:UpdateAll()
        if not updatedAuras and (event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_TARGET" or event == "UNIT_AURA"
            or event == "PLAYER_ENTERING_WORLD") then self:UpdateAuraIcons() end
        if event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD"
            or event == "GROUP_ROSTER_UPDATE" or event == "ADDON_LOADED" then self:ApplyStock() end
    end)
    local elapsedSinceUpdate = 0
    ns.SetAnimationUpdate(self, self.events, function(elapsed)
        if ns.positioning then
            elapsedSinceUpdate = elapsedSinceUpdate + elapsed
            if elapsedSinceUpdate >= 0.2 then elapsedSinceUpdate = elapsedSinceUpdate % 0.2; self:UpdateAll() end
        else
            elapsedSinceUpdate = 0
        end
    end, function()
        if ns.positioning then return true end
        elapsedSinceUpdate = 0
        return false
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:ApplyStock() end, self)
    end
    self:ApplyStock()
end
