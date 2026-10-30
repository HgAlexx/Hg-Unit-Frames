local ns = Hg_Rebirth
local PartyPet = {
    savedVariable = "Hg_Rebirth_Party_Pet_Options",
    defaults = {
        enabled = false, showInRaid = true, locked = true, portrait = false, portrait3D = false,
        scale = 1, opacity = 1, buffCount = 16, debuffCount = 16, buffSize = 12, debuffSize = 12,
        buffLocation = 4, debuffLocation = 5, castableBuffs = false, curableDebuffs = false,
        auraSpacingHorizontal = 1,
        x1 = 233.0000457763672, y1 = -214, x2 = 233.0000457763672, y2 = -309, x3 = 233.0000457763672, y3 = -404, x4 = 233.0000457763672, y4 = -499,
        sticky1ChildY = 0,
        sticky4Y = -2.57773848126277,
        sticky2ChildY = 0,
        sticky1ParentX = 1,
        sticky4ParentY = 0,
        sticky4ChildY = 0,
        sticky3X = -5.155516296293456,
        stickyParent = "Party",
        sticky3ParentX = 1,
        sticky2Y = -2.577817148798545,
        sticky3Placed = true,
        sticky4Placed = true,
        sticky2Placed = true,
        sticky1Y = -2.577777815030686,
        stickyScale = false,
        sticky3Y = -2.57773848126277,
        stickyMove = true,
        sticky1Placed = true,
        sticky4X = -5.155516296293456,
        sticky1ChildX = 0,
        sticky4ChildX = 0,
        sticky4ParentX = 1,
        sticky1ParentY = 0,
        sticky2ChildX = 0,
        sticky2ParentX = 1,
        sticky3ChildX = 0,
        sticky3ParentY = 0,
        sticky2ParentY = 0,
        sticky1X = -5.155516296293456,
        sticky3ChildY = 0,
        sticky2X = -5.155516296293456,
    },
    ranges = {
        scale = { 0.01, 1.49 }, opacity = { 0, 1 }, auraSpacingHorizontal = { -10, 30 },
        buffCount = { 0, 16, integer = true }, debuffCount = { 0, 16, integer = true },
        buffSize = { 1, 50, integer = true }, debuffSize = { 1, 50, integer = true },
        buffLocation = { 1, 7, integer = true }, debuffLocation = { 1, 7, integer = true },
    },
    members = {}, buttons = {},
}
ns.RegisterModule("PartyPet", PartyPet)

function PartyPet:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Party Pet: " .. ns.L[message])
end

local function overlay(member, parent)
    local button = ns.UnitOverlay(PartyPet, parent, member.frame, member.unit, member.xKey, member.yKey)
    button:SetScript("OnEnter", function()
        if GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(member.unit); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
    end)
    return button
end

local function auraGroup(member, harmful)
    local wrapper = CreateFrame("Frame", nil, member.frame)
    wrapper:SetFrameStrata("BACKGROUND")
    local size = harmful and PartyPet.db.debuffSize or PartyPet.db.buffSize
    local container = ns.AuraContainer(wrapper, member.unit, size)
    container:AddAuraGroup("icons", harmful and "HARMFUL" or "HELPFUL", {
        maxFrameCount = 0,
        initializeFrame = function(button) ns.InitializeAuraButton(button, harmful, false, nil, nil, size) end,
    })
    return { wrapper = wrapper, container = container, harmful = harmful, count = 0 }
end

function PartyPet:CreateMember(index)
    local member = { unit = "partypet" .. index, ownerUnit = "party" .. index,
        xKey = "x" .. index, yKey = "y" .. index, borders = {} }
    self.members[index] = member
    member.frame = ns.UnitRoot("Hg_Rebirth_PartyPetFrame" .. index, member.unit, 135)
    member.nameBox = ns.Box(member.frame, 135, 24); member.nameBox:SetPoint("TOPLEFT")
    member.name = ns.Label(member.nameBox)
    member.name:SetPoint("CENTER", 0, 0); member.name:SetSize(122, 14)
    member.name:SetJustifyH("CENTER"); member.name:SetNonSpaceWrap(false)
    member.stats = ns.Box(member.frame, 135, 34)
    member.stats:SetPoint("TOPLEFT", member.nameBox, "BOTTOMLEFT", 0, 2)
    member.portraitBox = ns.Box(member.frame, 56, 56)
    member.portraitBox:SetPoint("TOPRIGHT", member.nameBox, "TOPLEFT", 2, 0)
    member.portrait = ns.Icon(member.portraitBox, nil, 43, 43, "TOP", member.portraitBox, "TOP", 0, -6)
    member.model = CreateFrame("PlayerModel", nil, member.portraitBox)
    member.model:SetSize(45, 45); member.model:SetPoint("CENTER", 1, -1); member.model:EnableMouse(false)
    member.nameButton, member.statsButton, member.portraitButton =
        overlay(member, member.nameBox), overlay(member, member.stats), overlay(member, member.portraitBox)
    member.threat = ns.ThreatIcon(member.nameBox, "RIGHT", -5)
    member.health, member.power = ns.UnitBar(member.stats, 123), ns.UnitBar(member.stats, 123)
    member.health.frame:SetPoint("TOP", member.stats, "TOP", 0, -6)
    member.power.frame:SetPoint("TOP", member.health.frame, "BOTTOM", 0, -2)
    for _, bar in ipairs({ member.health, member.power }) do
        bar.text:ClearAllPoints(); bar.text:SetPoint("CENTER", 0, 0); bar.text:SetTextHeight(11)
    end
    if self.auraAPI then
        member.buffs, member.debuffs = auraGroup(member, false), auraGroup(member, true)
        member.buffWrapper, member.debuffWrapper = member.buffs.wrapper, member.debuffs.wrapper
        for _, parent in ipairs({ member.nameBox, member.stats, member.portraitBox }) do
            member.borders[#member.borders + 1] = ns.AuraBorder(parent, member.unit)
        end
    end
    member.events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FLAGS",
        "UNIT_CONNECTION", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_AURA" }) do member.events:RegisterUnitEvent(event, member.unit) end
    member.events:RegisterUnitEvent("UNIT_CONNECTION", member.unit, member.ownerUnit)
    member.events:RegisterUnitEvent("UNIT_NAME_UPDATE", member.unit, member.ownerUnit)
    member.events:RegisterUnitEvent("UNIT_PET", member.ownerUnit)
    member.events:SetScript("OnEvent", function(_, event, unit)
        if ns.positioning then self:UpdateMember(member); return end
        if event == "UNIT_AURA" then return end
        if event == "UNIT_PET" then self:ResetTransient(member); member.guid = nil end
        self:UpdateMember(member, ns.VitalsEventKinds[event])
    end)
    member.frame:SetScript("OnShow", function() self:UpdateMember(member) end)
end

function PartyPet:ResetTransient(member)
    if member.cleared then return end
    member.cleared = true
    member.name:SetText(""); member.threat:Hide()
    member.model:Hide(); member.model:ClearModel(); member.portrait:Hide(); member.portrait:SetTexture(nil)
    for index = 1, 2 do
        local bar = index == 1 and member.health or member.power
        bar.text:SetText("")
        bar.frame:SetMinMaxValues(0, 1); bar.frame:SetValue(0)
    end
    self:UpdateAuraState(member, false)
end

function PartyPet:UpdateAuraState(member, active)
    if not self.auraAPI then return end
    for index = 1, 2 do
        local group = index == 1 and member.buffs or member.debuffs
        local filter = group.harmful and "HARMFUL" or "HELPFUL"
        local filtered = group.harmful and self.db.curableDebuffs or not group.harmful and self.db.castableBuffs
        filter = filter .. (filtered and "|RAID" or "")
        if group.filter ~= filter then
            group.filter = filter
            group.container:SetAuraGroupFilterString("icons", filter)
        end
        local enabled = active and group.count > 0
        if group.enabled ~= enabled then group.enabled = enabled; group.container:SetEnabled(enabled) end
    end
    local enabled = active and ns.modules.Core.db.colorDebuffs
    if member.borderEnabled ~= enabled then
        member.borderEnabled = enabled
        for _, border in ipairs(member.borders) do border:SetEnabled(enabled) end
    end
end

function PartyPet:LayoutAuras(member)
    if not self.auraAPI then return end
    local db = self.db
    local spacing = db.auraSpacingHorizontal
    for _, group in ipairs({ member.buffs, member.debuffs }) do
        local count = group.harmful and db.debuffCount or db.buffCount
        local size = group.harmful and db.debuffSize or db.buffSize
        local location = group.harmful and db.debuffLocation or db.buffLocation
        local width = count > 0 and math.max(1, count * size + (count - 1) * spacing) or 1
        group.count = count
        group.wrapper:SetSize(width, size); group.wrapper:SetShown(count > 0)
        group.wrapper:ClearAllPoints()
        if location <= 2 then
            group.wrapper:SetPoint("BOTTOMLEFT", member.nameBox, "TOPLEFT", 5, location == 1 and 15 or 0)
        elseif location <= 5 then
            group.wrapper:SetPoint("TOPLEFT", location == 3 and member.nameBox or member.stats,
                "TOPRIGHT", 0, location == 3 and -3 or (location == 4 and -5 or -20))
        else
            group.wrapper:SetPoint("TOPLEFT", member.stats, "BOTTOMLEFT", 5, location == 7 and -15 or 0)
        end
        group.container:ClearAllPoints(); group.container:SetPoint("TOPLEFT", group.wrapper, "TOPLEFT", 0, 0)
        group.container:SetFlowLayoutAnchorPoint("TOPLEFT")
        group.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        ns.LayoutAuraIcons(group.container, { "icons" }, size, spacing, 0)
        group.container:SetAuraGroupMaxFrameCount("icons", count)
        ns.LayoutAuraPreview(member, group.wrapper, count, size, math.max(1, count), spacing, 0,
            "TOPLEFT", 0, 0, 1, group.harmful, false)
    end
end

function PartyPet:Layout()
    local db, core = self.db, ns.modules.Core.db
    for _, member in ipairs(self.members) do
        member.enabled = db.enabled
        member.portraitOwner = { db = { portrait = db.portrait, portrait3D = db.portrait3D },
            model = member.model, portrait = member.portrait }
        member.frame:SetScale(db.scale + 1 - UIParent:GetEffectiveScale()); member.frame:SetAlpha(db.opacity)
        member.frame:ClearAllPoints()
        member.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[member.xKey], db[member.yKey])
        local condition = db.enabled and ("[petbattle] hide; " .. (not db.showInRaid and "[group:raid] hide; " or "")
            .. "[@" .. member.unit .. ",exists] show; hide") or "hide"
        ns.UnitVisibility(member.frame, "visibility", condition)
        member.portraitBox:SetShown(db.portrait); member.portraitButton:SetShown(db.portrait)
        for _, parent in ipairs({ member.nameBox, member.stats, member.portraitBox }) do
            parent:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
        end
        for _, bar in ipairs({ member.health, member.power }) do
            bar.frame:SetStatusBarTexture(ns.TexturePath())
            bar.background:SetTexture(core.texturedBackground and ns.TexturePath()
                or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        end
        self:LayoutAuras(member)
    end
end

function PartyPet:UpdateMember(member, kind)
    if ns.PreviewUnit(member, ns.L["Party Pet"] .. " " .. member.unit:match("%d+"), self.db) then
        member.health.text:SetText("75/100")
        return
    end
    local exists, connected = UnitExists(member.unit), UnitIsConnected(member.ownerUnit)
    if ns.IsSecret(exists) or ns.IsSecret(connected) then
        self:Notice("presence", "Restricted party-pet presence or owner connection: unsupported updates are paused.")
        exists = false
    end
    if not member.enabled or not exists or not connected then
        self:ResetTransient(member); member.guid = nil; return
    end
    local guid = UnitGUID(member.unit)
    if ns.IsSecret(guid) then
        member.guid = nil
    elseif member.guid ~= guid then
        self:ResetTransient(member); member.guid = guid; kind = nil
        if self.auraAPI then
            member.buffs.container:UpdateAllAuras(); member.debuffs.container:UpdateAllAuras()
            for _, border in ipairs(member.borders) do border:UpdateAllAuras() end
        end
    end
    member.cleared = false
    if not kind then member.name:SetText(UnitName(member.unit)) end
    local dead, ghost = UnitIsDead(member.unit), UnitIsGhost(member.unit)
    local zero = not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost)
    if ns.IsSecret(dead) or ns.IsSecret(ghost) then
        self:Notice("status", "Restricted party-pet status: death state is not inferred.")
    end
    local powerType = UnitPowerType(member.unit)
    if kind ~= "power" then
        local health, healthMax = ns.UpdateUnitBar(self, member.health, member.unit, powerType, true, zero)
        member.health.text:SetFormattedText("%.0f/%.0f", health, healthMax)
    end
    if kind ~= "health" then
        local power, powerMax = ns.UpdateUnitBar(self, member.power, member.unit, powerType, false, zero)
        local _, class = UnitClass(member.ownerUnit)
        if ns.IsSecret(class) or not class then
            member.power.text:SetFormattedText("%.0f/%.0f", power, powerMax)
            self:Notice("ownerClass", "Party-pet owner class unavailable: displaying current/maximum power.")
        elseif class == "WARLOCK" then member.power.text:SetFormattedText("%.0f/%.0f", power, powerMax)
        else member.power.text:SetFormattedText("%.0f", power) end
    end
    if kind then return end
    local threat = UnitThreatSituation(member.unit)
    if ns.IsSecret(threat) then
        member.threat:Hide()
        self:Notice("threat", "Restricted party-pet threat: threat icon is hidden.")
    else
        member.threat:SetShown(ns.modules.Core.db.threat and threat ~= nil and threat > 0)
    end
    if member.portraitOwner.db.portrait and member.portraitOwner.db.portrait3D
        and ns.IsSecret(UnitIsVisible(member.unit)) then
        self:Notice("portrait", "Restricted party-pet visibility: using a 2D portrait.")
    end
    ns.UpdateUnitPortrait(member.portraitOwner, member.unit)
    self:UpdateAuraState(member, true)
end

function PartyPet:UpdateAll()
    for _, member in ipairs(self.members) do self:UpdateMember(member) end
end

function PartyPet:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    ns.AfterCombat("PartyPetLayout", function() self:Layout(); self:UpdateAll() end)
end

function PartyPet:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset Party Pet during combat."]); return false end
    for index = 1, 4 do
        self.db["x" .. index], self.db["y" .. index] = self.defaults["x" .. index], self.defaults["y" .. index]
    end
    self:Refresh()
    return true
end

local function finite(value)
    return not ns.IsSecret(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function PartyPet:Align()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot align Party Pet during combat."]); return false end
    local party = ns.modules.Party
    if not self.frame or not party or not party.frame or party.unavailable
        or party.db.visibility == "hidden" or (party.db.visibility == "raid" and IsInRaid()) then
        ns.Warn(ns.L["Party must be initialized and enabled to align Party Pet."]); return false
    end
    local positions, uiScale, height = {}, UIParent:GetEffectiveScale(), UIParent:GetHeight()
    if not finite(uiScale) or uiScale <= 0 or not finite(height) then
        ns.Warn(ns.L["Party Pet alignment geometry unavailable."]); return false
    end
    for index, member in ipairs(self.members) do
        local relative = party.members[index] and party.members[index].stats
        local right, top, scale
        if relative then right, top, scale = relative:GetRight(), relative:GetTop(), relative:GetEffectiveScale() end
        local own = member.frame:GetEffectiveScale()
        if not finite(right) or not finite(top) or not finite(scale) or scale <= 0
            or not finite(own) or own <= 0 then
            ns.Warn(ns.L["Party Pet alignment geometry unavailable."]); return false
        end
        positions[index] = { x = (right - 2) * scale / own + (self.db.portrait and 54 or 0),
            y = (top * scale + 30 * uiScale - height * uiScale) / own }
        if not finite(positions[index].x) or not finite(positions[index].y) then
            ns.Warn(ns.L["Party Pet alignment geometry unavailable."]); return false
        end
    end
    for index, member in ipairs(self.members) do
        self.db[member.xKey], self.db[member.yKey] = positions[index].x, positions[index].y
    end
    self:Refresh()
    return true
end

function PartyPet:Start()
    if self.frame then return end
    if InCombatLockdown() then ns.AfterCombat("PartyPetStart", function() self:Start() end); return end
    self.auraAPI = ns.HasAuraAPI() == true
    if not self.auraAPI then
        self:Notice("auraAPI", "Mainline aura API unavailable; Party Pet remains active without aura icons or debuff-border coloring.")
    end
    self.healthCurve = ns.CreateHealthCurve()
    for index = 1, 4 do self:CreateMember(index) end
    self.frame = self.members[1].frame
    self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ALIVE" }) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent", function()
        if ns.positioning then self:UpdateAll(); return end
        for _, member in ipairs(self.members) do self:ResetTransient(member); member.guid = nil end
        self:UpdateAll()
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
end
