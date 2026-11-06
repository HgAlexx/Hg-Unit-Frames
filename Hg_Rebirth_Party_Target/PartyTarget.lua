local ns = Hg_Rebirth
local PartyTarget = {
    savedVariable = "Hg_Rebirth_Party_Target_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        enabled = true, showInRaid = true, locked = true, showPower = false,
        className = true, scale = 1, opacity = 1,
        x1 = 233.0000457763672, y1 = -214, x2 = 233.0000457763672, y2 = -309,
        x3 = 233.0000457763672, y3 = -404, x4 = 233.0000457763672, y4 = -499,
        sticky1ChildY = 0,
        sticky4Y = 2.577817148798602,
        sticky1ChildX = 0,
        sticky2ChildY = 0,
        sticky1ParentX = 1,
        sticky4ParentY = 0,
        sticky3X = -5.155516296293456,
        stickyParent = "Party",
        sticky3ParentX = 1,
        sticky2Y = 2.577738481262713,
        sticky1ParentY = 0,
        sticky3Placed = true,
        sticky4Placed = true,
        sticky1Y = 2.577777815030686,
        stickyMove = true,
        sticky1X = -5.155516296293456,
        stickyScale = false,
        sticky3Y = 2.577817148798602,
        sticky1Placed = true,
        sticky4ChildX = 0,
        sticky4ChildY = 0,
        sticky2Placed = true,
        sticky3ChildX = 0,
        sticky4ParentX = 1,
        sticky2ChildX = 0,
        sticky2ParentX = 1,
        sticky3ParentY = 0,
        sticky2ParentY = 0,
        sticky4X = -5.155516296293456,
        sticky3ChildY = 0,
        sticky2X = -5.155516296293456,
    },
    ranges = { tooltipAnchor = { right = true, default = true },
        scale = { 0.01, 1.49 }, opacity = { 0, 1 } },
    members = {}, buttons = {},
}
ns.RegisterModule("PartyTarget", PartyTarget)

function PartyTarget:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Party Target: " .. ns.L[message])
end

function PartyTarget:CreateMember(index)
    local member = ns.CreateCompactTarget(self, {
        unit = "party" .. index .. "target", ownerUnit = "party" .. index,
        xKey = "x" .. index, yKey = "y" .. index,
    }, "Hg_Rebirth_PartyTargetFrame" .. index)
    self.members[index] = member
    member.events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_CONNECTION",
        "UNIT_FACTION", "UNIT_AURA" }) do
        member.events:RegisterUnitEvent(event, member.unit)
    end
    member.events:RegisterUnitEvent("UNIT_TARGET", member.ownerUnit)
    member.events:SetScript("OnEvent", function(_, event) self:UpdateMember(member, ns.VitalsEventKinds[event]) end)
end

function PartyTarget:ResetTransient(member)
    ns.ResetCompactTarget(member)
end

function PartyTarget:UpdateBorders(member, exists)
    ns.UpdateCompactTargetBorders(self, member, exists)
end

function PartyTarget:Layout()
    for _, member in ipairs(self.members) do ns.LayoutCompactTarget(self, member) end
end

function PartyTarget:UpdateMember(member, kind)
    if ns.PreviewUnit(member, ns.L["Party Target"] .. " " .. member.unit:match("%d+"), self.db) then return end
    ns.UpdateCompactTarget(self, member, kind)
end

function PartyTarget:UpdateAll()
    for _, member in ipairs(self.members) do self:UpdateMember(member) end
end

function PartyTarget:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    ns.AfterCombat("PartyTargetLayout", function() self:Layout(); self:UpdateAll() end)
end

function PartyTarget:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset Party Target during combat."]); return end
    for _, member in ipairs(self.members) do
        self.db[member.xKey], self.db[member.yKey] = self.defaults[member.xKey], self.defaults[member.yKey]
    end
    self:Refresh()
end

function PartyTarget:Start()
    if self.frame then return end
    if InCombatLockdown() then ns.AfterCombat("PartyTargetStart", function() self:Start() end); return end
    self.borderAPI = ns.HasAuraAPI() == true
    if not self.borderAPI then
        self:Notice("borderAPI", "Mainline aura API unavailable; Party Target remains active without debuff-border coloring.")
    end
    self.healthCurve = ns.CreateHealthCurve()
    for index = 1, 4 do self:CreateMember(index) end
    self.frame = self.members[1].frame
    self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "RAID_TARGET_UPDATE", "PLAYER_ALIVE" }) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent", function() self:UpdateAll() end)
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
end
