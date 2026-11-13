local ns = Hg_Rebirth
local Party = {
    savedVariable = "Hg_Rebirth_Party_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        locked = true, compact = true, visibility = "always", spacing = 95,
        scale = 1, opacity = 1, showPets = true, healer = false, vertical = true,
        compactPercent = true, portrait = false, showKeys = true, portrait3D = false,
        className = true, shortBars = false, showLevel = true, manaDeficit = false,
        pvpIcon = true, healerValues = false, portraitAuras = true, auraTimers = false,
        castableBuffs = false, curableDebuffs = false, buffCount = 16, debuffCount = 16,
        buffSize = 16, debuffSize = 16, buffLocation = 6, debuffLocation = 3,
        auraSpacingHorizontal = 1,
        x = -7, y = -187,
        sticky1ChildY = 0,
        sticky1ChildX = 0,
        sticky1ParentX = 0,
        sticky1Y = 0,
        sticky1Placed = false,
        stickyMove = false,
        stickyParent = "",
        stickyScale = false,
        sticky1X = 0,
        sticky1ParentY = 0,
    },
    ranges = {
        tooltipAnchor = { right = true, default = true },
        visibility = { always = true, raid = true, hidden = true },
        spacing = { -150, 150, integer = true }, scale = { 0.01, 1.49 }, opacity = { 0, 1 },
        auraSpacingHorizontal = { -10, 30 },
        buffCount = { 0, 16, integer = true }, debuffCount = { 0, 16, integer = true },
        buffSize = { 1, 50, integer = true }, debuffSize = { 1, 50, integer = true },
        buffLocation = { 1, 7, integer = true }, debuffLocation = { 1, 7, integer = true },
    },
    members = {}, buttons = {}, boxes = {},
}
ns.AddUnitNameSettings(Party)
ns.RegisterModule("Party", Party)

function Party:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Party: " .. ns.L[message])
end

local function clearBar(entry)
    entry.hover = false
    entry.text:SetText(""); entry.right:SetText(""); entry.percent:SetText("")
    entry.frame:SetMinMaxValues(0, 1); entry.frame:SetValue(0)
end

local function overlay(parent, unit)
    return ns.UnitOverlay(Party, parent, Party.frame, unit)
end

local function box(member, width, height)
    local frame = ns.Box(member.frame, width, height)
    Party.boxes[#Party.boxes + 1] = frame
    member.boxes[#member.boxes + 1] = frame
    overlay(frame, member.unit)
    return frame
end

local function label(parent, font, point, x, y)
    local text = ns.Label(parent, font)
    text:SetPoint(point, x, y)
    text:SetNonSpaceWrap(false)
    return text
end

local function auraGroup(member, harmful)
    local wrapper = CreateFrame("Frame", nil, member.frame)
    local size = harmful and Party.db.debuffSize or Party.db.buffSize
    local container = ns.AuraContainer(wrapper, member.unit, size)
    for _, timers in ipairs({ true, false }) do
        container:AddAuraGroup(timers and "icons" or "untimed", harmful and "HARMFUL" or "HELPFUL", {
            maxFrameCount = 0,
            initializeFrame = function(button) ns.InitializeAuraButton(button, harmful, timers, nil, nil, size) end,
        })
    end
    return { wrapper = wrapper, container = container, harmful = harmful }
end

local memberEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
    "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_FLAGS", "UNIT_CONNECTION",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }

function Party:UpdateMemberActivity(member)
    local active = UnitExists(member.unit) and true or false
    if member.active == active then return end
    member.active = active
    if active then
        for _, event in ipairs(memberEvents) do
            member.events:RegisterUnitEvent(event, member.unit, member.petUnit)
        end
        member.events:RegisterUnitEvent("UNIT_PET", member.unit)
    else
        member.events:UnregisterAllEvents()
    end
    self:UpdateAuraActivity(member)
end

function Party:UpdateAuraActivity(member)
    for _, group in ipairs({ member.buffs, member.debuffs }) do
        local count = group.harmful and self.db.debuffCount or self.db.buffCount
        group.container:SetEnabled(member.active == true and count > 0)
    end
    for _, container in ipairs(member.borders) do
        container:SetEnabled(member.active == true and ns.modules.Core.db.colorDebuffs)
    end
end

function Party:CreateMember(index)
    local member = { unit = "party" .. index, petUnit = "partypet" .. index, boxes = {}, index = index }
    self.members[index] = member
    member.frame = ns.UnitRoot("Hg_Rebirth_PartyMemberFrame" .. index, member.unit, 202)
    member.frame:SetParent(self.frame)
    member.nameBox = box(member, 202, 24)
    member.nameBox:SetPoint("TOPLEFT")
    member.name = label(member.nameBox, "GameFontNormal", "CENTER", 0, 0)
    member.name:SetJustifyH("CENTER")
    member.leader = ns.Icon(member.nameBox, "Interface\\GroupFrame\\UI-Group-LeaderIcon",
        16, 16, "TOP", member.nameBox, "TOP", 0, 7)
    member.master = ns.Icon(member.nameBox, "Interface\\GroupFrame\\UI-Group-MasterLooter",
        16, 16, "TOPLEFT", member.nameBox, "TOPLEFT", 65, 7)
    member.pvp = ns.Icon(member.nameBox, nil, 32, 32, "TOPLEFT", member.nameBox, "TOPLEFT", 2, -3)
    member.role = ns.Icon(member.nameBox, ns.media .. "Role.tga",
        19, 18, "TOPLEFT", member.nameBox, "TOPLEFT", 3, -4)
    member.dead = ns.Icon(member.nameBox, "Interface\\TargetingFrame\\TargetDead",
        16, 16, "TOPRIGHT", member.nameBox, "TOPRIGHT", -25, -4)
    member.disconnected = ns.Icon(member.nameBox, "Interface\\CharacterFrame\\Disconnect-Icon",
        32, 32, "TOPRIGHT", member.nameBox, "TOPRIGHT", -35, 3)
    member.key = label(member.nameBox, "GameFontNormal", "TOPRIGHT", -8, -6)
    member.threat = ns.ThreatIcon(member.nameBox, "LEFT", 24)
    local markerFrame = CreateFrame("Frame", nil, member.frame)
    markerFrame:SetSize(26, 26)
    markerFrame:SetPoint("CENTER", member.nameBox, "TOPRIGHT", -28, -5)
    markerFrame:SetFrameStrata("MEDIUM")
    member.marker = ns.Icon(markerFrame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        18, 18, "CENTER", markerFrame, "CENTER", 0, 0)
    member.levelBox = box(member, 34, 42)
    member.levelBox:SetPoint("TOPLEFT", member.nameBox, "BOTTOMLEFT", 0, 2)
    member.classIcon = ns.Icon(member.levelBox, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
        24, 24, "TOPLEFT", member.levelBox, "TOPLEFT", 5, -5)
    member.level = label(member.levelBox, "GameFontNormalSmall", "BOTTOM", 0, 4)
    member.portraitBox = box(member, 64, 64)
    member.portraitBox:SetPoint("TOPRIGHT", member.nameBox, "TOPLEFT", 2, 0)
    member.portrait = ns.Icon(member.portraitBox, nil, 52, 52, "TOP", member.portraitBox, "TOP", 0, -6)
    member.model = CreateFrame("PlayerModel", nil, member.portraitBox)
    member.model:SetSize(54, 54); member.model:SetPoint("CENTER", 1, -1); member.model:EnableMouse(false)
    member.portraitOwner = { db = self.db, model = member.model, portrait = member.portrait }
    member.stats = box(member, 270, 54)
    member.health, member.power, member.petHealth =
        ns.UnitBar(member.stats, 150), ns.UnitBar(member.stats, 150), ns.UnitBar(member.stats, 150)
    for _, entry in ipairs({ member.health, member.power, member.petHealth }) do
        entry.right, entry.percent = ns.Label(entry.frame), ns.Label(entry.frame)
        entry.percent:SetPoint("RIGHT", 35, 0)
        entry.right:SetTextColor(1, 1, 1); entry.percent:SetTextColor(1, 1, 1)
        local unit = entry == member.petHealth and member.petUnit or member.unit
        entry.button = overlay(entry.frame, unit)
        entry.button:HookScript("OnEnter", function()
            entry.hover = true; self:UpdateVitals(member)
        end)
        entry.button:HookScript("OnLeave", function()
            entry.hover = false; self:UpdateVitals(member)
        end)
    end
    member.buffs, member.debuffs = auraGroup(member, false), auraGroup(member, true)
    member.buffWrapper, member.debuffWrapper = member.buffs.wrapper, member.debuffs.wrapper
    member.borders = {}
    for _, parent in ipairs(member.boxes) do member.borders[#member.borders + 1] = ns.AuraBorder(parent, member.unit) end
    member.events = CreateFrame("Frame")
    member.events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_PET" then
            clearBar(member.petHealth); member.petGUID = nil
        end
        if ns.positioning then self:UpdateMember(member); return end
        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            ns.UpdateUnitPortrait(member.portraitOwner, member.unit)
        elseif ns.VitalsEventKinds[event] then
            self:UpdateMember(member, unit == member.petUnit and "pet" or ns.VitalsEventKinds[event])
        elseif event ~= "UNIT_AURA" then
            local skipPortrait = event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL"
                or event == "UNIT_FACTION" or event == "UNIT_THREAT_SITUATION_UPDATE"
            self:UpdateMember(member, nil, skipPortrait)
        end
    end)
    member.frame:SetScript("OnShow", function() self:UpdateMember(member) end)
end

function Party:Create()
    self.frame = CreateFrame("Frame", "Hg_Rebirth_PartyFrame", UIParent, "SecureHandlerStateTemplate")
    self.frame:SetSize(225, 42); self.frame:SetFrameStrata("LOW")
    self.frame:SetMovable(true); self.frame:SetClampedToScreen(true)
    self.frame:SetClampRectInsets(5, 0, -5, 0)
    self.healthCurve = ns.CreateHealthCurve()
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent
        and Enum.LuaCurveType and Enum.LuaCurveType.Step then
        self.petCurve = C_CurveUtil.CreateColorCurve()
        self.petCurve:SetType(Enum.LuaCurveType.Step)
        self.petCurve:AddPoint(0, CreateColor(1, 0, 0))
        self.petCurve:AddPoint(0.255, CreateColor(1, 0.5, 0))
        self.petCurve:AddPoint(0.505, CreateColor(1, 1, 0))
        self.petCurve:AddPoint(0.755, CreateColor(0, 0.8, 0))
    end
    self.petOwner = { healthCurve = self.petCurve,
        Notice = function(_, key, message) self:Notice(key, message) end }
    for index = 1, 4 do self:CreateMember(index) end
end

function Party:Layout()
    local db, core = self.db, ns.modules.Core.db
    local short = db.compact and db.shortBars
    local nameWidth, barWidth = short and 167 or 202, short and 115 or 150
    local width = db.compact and ((short and 135 or 170) + (db.compactPercent and 35 or 0)) or 270
    if not db.showLevel then width, barWidth = width + 30, barWidth + 30 end
    self.frame:SetScale(db.scale + (1 - UIParent:GetEffectiveScale()))
    self.frame:ClearAllPoints(); self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    local spacing = -db.spacing
    local horizontal = db.spacing < 0 and db.spacing - 195 or db.spacing + 195
    for index, member in ipairs(self.members) do
        member.frame:SetWidth(nameWidth); member.frame:SetAlpha(db.opacity)
        member.frame:ClearAllPoints()
        if index == 1 then member.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -5)
        else member.frame:SetPoint("TOPLEFT", self.members[index - 1].frame, "TOPLEFT",
            db.vertical and 0 or horizontal, db.vertical and spacing or 0) end
        member.nameBox:SetWidth(nameWidth)
        member.name:ClearAllPoints()
        member.name:SetPoint("CENTER", member.nameBox, "CENTER", 0, 0)
        member.name:SetSize(nameWidth - 45, 14)
        member.stats:SetSize(width, db.showPets and 54 or 42)
        member.stats:ClearAllPoints()
        member.stats:SetPoint("TOPLEFT", member.nameBox, "BOTTOMLEFT", not db.showLevel and 0 or 32, 2)
        member.levelBox:SetShown(db.showLevel); member.portraitBox:SetShown(db.portrait)
        member.petVisible = db.showPets
        member.petHealth.frame:SetShown(db.showPets); member.petHealth.button:SetShown(db.showPets)
        member.health.frame:SetPoint("TOPLEFT", member.stats, "TOPLEFT", 10, -10)
        member.power.frame:SetPoint("TOP", member.health.frame, "BOTTOM", 0, -2)
        member.petHealth.frame:SetPoint("TOP", member.power.frame, "BOTTOM", 0, -2)
        for _, entry in ipairs({ member.health, member.power, member.petHealth }) do
            entry.frame:SetWidth(barWidth)
            entry.frame:SetStatusBarTexture(ns.TexturePath())
            entry.background:SetTexture(core.texturedBackground and ns.TexturePath()
                or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
            entry.text:ClearAllPoints(); entry.right:ClearAllPoints()
            entry.text:SetPoint(db.compact and db.healer and "TOPLEFT" or "TOP",
                db.compact and db.healer and 5 or 0, 1)
            entry.right:SetPoint("RIGHT", not db.compact and 100 or (db.healer and -10 or 85),
                db.compact and not db.healer and entry == member.power and 1 or 0)
        end
        for _, frame in ipairs(member.boxes) do frame:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1) end
        local condition = "[petbattle] hide; "
        if db.visibility == "hidden" then condition = "hide"
        else
            if db.visibility == "raid" then condition = condition .. "[group:raid] hide; " end
            condition = condition .. "[@" .. member.unit .. ",exists] show; hide"
        end
        ns.UnitVisibility(member.frame, "visibility", condition)
        self:LayoutAuras(member)
        self:PreviewAuras(member)
        ns.CastHostChanged(member)
    end
end

function Party:LayoutAuras(member)
    local db = self.db
    local spacing = db.auraSpacingHorizontal
    for _, group in ipairs({ member.buffs, member.debuffs }) do
        local count = group.harmful and db.debuffCount or db.buffCount
        local size = group.harmful and db.debuffSize or db.buffSize
        local location = group.harmful and db.debuffLocation or db.buffLocation
        local width = count > 0 and math.max(1, count * size + (count - 1) * spacing) or 1
        group.wrapper:SetSize(width, size); group.wrapper:SetShown(count > 0)
        group.wrapper:ClearAllPoints()
        local anchor = db.portrait and db.portraitAuras and member.portraitBox or member.nameBox
        if location <= 2 then
            group.wrapper:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 3, location == 1 and 20 or 0)
        elseif location <= 5 then
            group.wrapper:SetPoint("TOPLEFT", location == 3 and member.nameBox or member.stats,
                "TOPRIGHT", 0, location == 5 and -23 or -3)
        else
            local portrait = db.portrait and db.portraitAuras
            group.wrapper:SetPoint("TOPLEFT", portrait and member.portraitBox or member.stats,
                "BOTTOMLEFT", (portrait or not db.showLevel) and 3 or -27, location == 7 and -20 or 0)
        end
        group.container:ClearAllPoints(); group.container:SetPoint("TOPLEFT", group.wrapper, "TOPLEFT", 0, 0)
        group.container:SetFlowLayoutAnchorPoint("TOPLEFT")
        group.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        ns.LayoutAuraIcons(group.container, { "icons", "untimed" }, size, spacing, 0)
        group.container:SetAuraGroupMaxFrameCount("icons", db.auraTimers and count or 0)
        group.container:SetAuraGroupMaxFrameCount("untimed", not db.auraTimers and count or 0)
    end
    self:UpdateAuraFilters(member)
end

function Party:UpdateAuraFilters(member)
    for _, group in ipairs({ member.buffs, member.debuffs }) do
        local filtered = group.harmful and self.db.curableDebuffs or not group.harmful and self.db.castableBuffs
        local filter = (group.harmful and "HARMFUL" or "HELPFUL") .. (filtered and "|RAID" or "")
        group.container:SetAuraGroupFilterString("icons", filter)
        group.container:SetAuraGroupFilterString("untimed", filter)
    end
    self:UpdateAuraActivity(member)
end

function Party:BarText(entry, health, powerType, value, maximum, missing, percent)
    local db = self.db
    local single = not health and not ns.IsSecret(powerType) and (powerType == 1 or powerType == 6)
    local function values(label)
        if single then label:SetFormattedText("%.0f", value)
        else label:SetFormattedText("%.0f/%.0f", value, maximum) end
    end
    entry.text:SetText(""); entry.right:SetText(""); entry.percent:SetText("")
    entry.right:SetTextColor(1, 1, 1)
    if db.healer then
        if (health or db.manaDeficit) and (ns.IsSecret(missing) or missing ~= nil) then
            entry.right:SetFormattedText("-%.0f", missing)
            if not health then entry.right:SetTextColor(0.5, 0.5, 0.5) end
        end
        if db.healerValues or entry.hover then values(entry.text) end
    elseif db.compact then values(entry.text)
    else
        entry.right:SetFormattedText("%.0f/%.0f", value, maximum)
        if single then entry.text:SetFormattedText("%.0f", value)
        elseif ns.IsSecret(percent) or percent ~= nil then entry.text:SetFormattedText("%.0f%%", percent) end
    end
    if db.compact and db.compactPercent and (ns.IsSecret(percent) or percent ~= nil) then
        entry.percent:SetFormattedText("%.0f%%", percent)
    end
end

function Party:PetColor(member, value, maximum, zero)
    if not ns.modules.Core.db.colorHealth then return end
    local r, g, b = 0, 0.8, 0
    if zero then r, g = 1, 0
    elseif not ns.IsSecret(value) and not ns.IsSecret(maximum) then
        local percent = maximum > 0 and math.floor(value / maximum * 100 + 0.5) or 0
        if percent <= 25 then r, g = 1, 0
        elseif percent <= 50 then r, g = 1, 0.5
        elseif percent <= 75 then r, g = 1, 1 end
    elseif self.petCurve and UnitHealthPercent then
        local color = UnitHealthPercent(member.petUnit, true, self.petCurve)
        r, g, b = color:GetRGB()
    else self:Notice("petColor", "Stepped pet-health coloring unavailable for restricted health on this client.") end
    local entry = member.petHealth
    entry.frame:SetStatusBarColor(r, g, b); entry.background:SetVertexColor(r, g, b, 0.25)
end

function Party:UpdateVitals(member, kind)
    if ns.positioning and ns.PreviewUnit(member, ns.L["Party"] .. " " .. member.index, self.db) then return end
    if not UnitExists(member.unit) then return end
    local dead, ghost, connected = UnitIsDead(member.unit), UnitIsGhost(member.unit), UnitIsConnected(member.unit)
    local zero = not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost)
    local powerType = UnitPowerType(member.unit)
    for index = kind == "power" and 2 or 1, kind == "health" and 1 or (kind == "pet" and 0 or 2) do
        local health = index == 1
        local entry = health and member.health or member.power
        local value, maximum, missing, percent = ns.UpdateUnitBar(self, entry, member.unit, powerType, health, zero)
        self:BarText(entry, health, powerType, value, maximum, missing, percent)
    end
    local feign = UnitIsFeignDeath and UnitIsFeignDeath(member.unit)
    local status = zero and (DEAD or "Dead") or nil
    if not ns.IsSecret(feign) and feign then status = FEIGN_DEATH or "Feign Death" end
    if not ns.IsSecret(connected) and not connected then status = PLAYER_OFFLINE or "Offline" end
    member.dead:SetShown(zero)
    member.disconnected:SetShown(not ns.IsSecret(connected) and not connected)
    if status then (self.db.compact and member.health.text or member.health.right):SetText(status) end
    if ns.IsSecret(dead) or ns.IsSecret(ghost) or ns.IsSecret(connected) or ns.IsSecret(feign) then
        self:Notice("status", "Restricted party status: unavailable indicators are hidden.")
    end
    if member.petVisible and (not kind or kind == "pet") then
        if UnitExists(member.petUnit) and (ns.IsSecret(connected) or connected) then
            local petDead, petGhost = UnitIsDead(member.petUnit), UnitIsGhost(member.petUnit)
            local petZero = not ns.IsSecret(petDead) and not ns.IsSecret(petGhost) and (petDead or petGhost)
            local value, maximum, missing, percent =
                ns.UpdateUnitBar(self.petOwner, member.petHealth, member.petUnit, nil, true, petZero)
            self:BarText(member.petHealth, true, nil, value, maximum, missing, percent)
            self:PetColor(member, value, maximum, petZero)
            if ns.IsSecret(petDead) or ns.IsSecret(petGhost) then
                self:Notice("petStatus", "Restricted party-pet status: death state is not inferred.")
            end
        else
            clearBar(member.petHealth)
            member.petHealth.frame:SetStatusBarColor(0, 0.8, 0, 0)
            member.petHealth.background:SetVertexColor(0, 0.8, 0, 0)
        end
    end
end

function Party:UpdateBinding(member)
    member.key:SetText(self.db.showKeys and (GetBindingKey("TARGETPARTYMEMBER" .. member.index) or "") or "")
end

function Party:UpdateIndicators(event)
    if ns.positioning then return end
    for _, member in ipairs(self.members) do
        if not member.cleared and UnitExists(member.unit) then
            if event == "UPDATE_BINDINGS" then self:UpdateBinding(member)
            else ns.UpdateRaidMarker(self, member.marker, member.unit) end
        end
    end
end

function Party:UpdateIdentity(member, skipPortrait)
    local unit = member.unit
    ns.UpdateRaidMarker(self, member.marker, unit)
    ns.HostName(member, ns.UnitFullName(self, unit))
    local _, token = UnitClass(unit)
    local isPlayer = UnitIsPlayer(unit)
    local coords = not ns.IsSecret(token) and token and CLASS_ICON_TCOORDS[token]
    member.classIcon:SetShown(coords ~= nil and coords ~= false)
    if coords then member.classIcon:SetTexCoord(unpack(coords)) end
    member.level:SetFormattedText("%.0f", UnitLevel(unit))
    local color = not ns.IsSecret(token) and token and RAID_CLASS_COLORS[token]
    local r, g, b
    if self.db.className and color then r, g, b = color.r, color.g, color.b
    else
        local controlled, visible = UnitPlayerControlled(unit), UnitIsVisible(unit)
        local pvp, ffa, sanctuary = UnitIsPVP(unit), UnitIsPVPFreeForAll(unit), UnitIsPVPSanctuary(unit)
        if not ns.IsSecret(controlled) and not ns.IsSecret(visible) then
            if not controlled and visible then
                local reaction = UnitReaction(unit, "player")
                local reactionColor = not ns.IsSecret(reaction) and reaction and FACTION_BAR_COLORS[reaction]
                if reactionColor then r, g, b = reactionColor.r, reactionColor.g, reactionColor.b end
            elseif not ns.IsSecret(pvp) and not ns.IsSecret(ffa) and not ns.IsSecret(sanctuary) then
                if ffa or (pvp and not sanctuary) then r, g, b = 0, 1, 0
                else r, g, b = 0.5, 0.5, 1 end
            end
        end
    end
    if not r then
        r, g, b = 1, 1, 1
        self:Notice("identity", "Restricted party identity: unavailable indicators are hidden; name coloring is neutral.")
    end
    member.name:SetTextColor(r, g, b)
    local pvp, ffa, sanctuary = UnitIsPVP(unit), UnitIsPVPFreeForAll(unit), UnitIsPVPSanctuary(unit)
    local faction = UnitFactionGroup(unit)
    if not ns.IsSecret(faction) and faction == nil then faction = UnitFactionGroup("player") end
    local readable = not ns.IsSecret(pvp) and not ns.IsSecret(ffa) and not ns.IsSecret(sanctuary) and not ns.IsSecret(faction)
    local showPVP = self.db.pvpIcon and readable and (ffa or (pvp and not sanctuary and faction ~= nil))
    member.pvp:SetShown(showPVP)
    if showPVP then member.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. (ffa and "FFA" or faction)) end
    local leader = UnitIsGroupLeader(unit)
    member.leader:SetShown(not ns.IsSecret(leader) and leader)
    member.master:Hide()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local method, party = C_PartyInfo.GetLootMethod()
        if not ns.IsSecret(method) and not ns.IsSecret(party) then
            member.master:SetShown(method == "master" and party == member.index)
        else self:Notice("loot", "Restricted party loot method: master-looter indicator is hidden.") end
    end
    local role = UnitGroupRolesAssigned(unit)
    local roleCoords = not ns.IsSecret(role) and ns.RoleCoordinates[role]
    member.role:SetShown(roleCoords ~= nil and roleCoords ~= false)
    if roleCoords then member.role:SetTexCoord(unpack(roleCoords)) end
    local threat = UnitThreatSituation(unit)
    member.threat:SetShown(ns.modules.Core.db.threat and not ns.IsSecret(threat) and threat ~= nil and threat > 0)
    if ns.IsSecret(isPlayer) or ns.IsSecret(token) or ns.IsSecret(leader) or ns.IsSecret(role)
        or (self.db.pvpIcon and not readable) or (ns.modules.Core.db.threat and ns.IsSecret(threat)) then
        self:Notice("status", "Restricted party status: unavailable indicators are hidden.")
    end
    self:UpdateBinding(member)
    if not skipPortrait then
        member.portraitOwner.db = self.db
        ns.UpdateUnitPortrait(member.portraitOwner, unit)
    end
end

function Party:ClearMember(member)
    if member.cleared then return end
    member.cleared = true
    ns.ClearCastHost(member)
    for _, entry in ipairs({ member.health, member.power, member.petHealth }) do clearBar(entry) end
    ns.HostName(member, ""); member.level:SetText(""); member.key:SetText("")
    for _, icon in ipairs({ member.classIcon, member.pvp, member.role, member.dead,
        member.disconnected, member.leader, member.master, member.threat, member.marker }) do icon:Hide() end
    for _, group in ipairs({ member.buffs, member.debuffs }) do group.container:UpdateAllAuras() end
    for _, container in ipairs(member.borders) do container:UpdateAllAuras() end
end

function Party:PreviewAuras(member)
    for _, group in ipairs({ member.buffs, member.debuffs }) do
        local count = group.harmful and self.db.debuffCount or self.db.buffCount
        local size = group.harmful and self.db.debuffSize or self.db.buffSize
        if ns.positioning and not InCombatLockdown() then
            if not group.preview then
                group.preview = CreateFrame("Frame", nil, member.frame)
                group.preview:SetAllPoints(group.wrapper)
                group.preview.icons = {}
            end
            if #group.preview.icons < count then
                local textures = group.harmful and {
                    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
                    "Interface\\Icons\\Spell_Frost_FrostNova",
                    "Interface\\Icons\\Spell_Nature_Poison",
                } or {
                    "Interface\\Icons\\Spell_Holy_WordFortitude",
                    "Interface\\Icons\\Spell_Holy_MagicalSentry",
                    "Interface\\Icons\\Spell_Nature_Regeneration",
                }
                for index = #group.preview.icons + 1, count do
                    local texture = textures[(index - 1) % #textures + 1]
                    local icon = CreateFrame("Frame", nil, group.preview)
                    icon.texture = ns.Icon(icon, texture, size, size, "TOPLEFT", icon, "TOPLEFT", 0, 0)
                    icon.count = ns.Label(icon, "NumberFontNormalSmall")
                    icon.count:SetPoint("BOTTOMRIGHT", -1, 0)
                    icon.count:SetText("2")
                    if group.harmful then
                        icon.border = ns.Icon(icon, "Interface\\Buttons\\UI-Debuff-Overlays",
                            size, size, "TOPLEFT", icon, "TOPLEFT", 0, 0)
                        icon.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
                        icon.border:SetVertexColor(1, 0, 0)
                    end
                    group.preview.icons[index] = icon
                end
            end
            group.preview:SetShown(count > 0)
            for index, icon in ipairs(group.preview.icons) do
                icon:SetSize(size, size)
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", group.preview, "TOPLEFT", (index - 1) * (size + self.db.auraSpacingHorizontal), 0)
                icon.texture:SetSize(size, size)
                if icon.border then icon.border:SetSize(size, size) end
                icon:SetShown(index <= count)
            end
        elseif group.preview then group.preview:Hide() end
    end
end

function Party:UpdateMember(member, kind, skipPortrait)
    self:UpdateMemberActivity(member)
    if ns.positioning then
        self:PreviewAuras(member)
        if ns.PreviewUnit(member, ns.L["Party"] .. " " .. member.index, self.db) then return end
    else
        if member.buffs.preview and member.buffs.preview:IsShown() then member.buffs.preview:Hide() end
        if member.debuffs.preview and member.debuffs.preview:IsShown() then member.debuffs.preview:Hide() end
    end
    if not UnitExists(member.unit) then
        self:ClearMember(member); member.guid, member.petGUID = nil, nil
        return
    end
    local guid, petGUID = UnitGUID(member.unit), UnitGUID(member.petUnit)
    if ns.IsSecret(guid) then
        member.guid = nil
    elseif guid ~= member.guid then
        self:ClearMember(member); member.guid = guid; kind, skipPortrait = nil, nil
    end
    member.cleared = false
    if ns.IsSecret(petGUID) then
        member.petGUID = nil
    elseif petGUID ~= member.petGUID then clearBar(member.petHealth); member.petGUID = petGUID end
    self:UpdateVitals(member, kind)
    if not kind then self:UpdateIdentity(member, skipPortrait) end
end

local groupEvents = { "PLAYER_ALIVE", "PARTY_LEADER_CHANGED", "PARTY_LOOT_METHOD_CHANGED",
    "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM", "UPDATE_BINDINGS", "RAID_TARGET_UPDATE" }

function Party:UpdateEventActivity()
    if not self.events then return end
    local active = ns.positioning or false
    for _, member in ipairs(self.members) do active = active or member.active end
    if self.eventsActive == active then return end
    self.eventsActive = active
    for _, event in ipairs(groupEvents) do
        if active then self.events:RegisterEvent(event)
        else self.events:UnregisterEvent(event) end
    end
end

function Party:UpdateAll()
    if not self.frame then return end
    for _, member in ipairs(self.members) do self:UpdateMember(member) end
    self:UpdateEventActivity()
end

function Party:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    for _, member in ipairs(self.members) do self:UpdateAuraFilters(member) end
    ns.AfterCombat("PartyLayout", function() self:Layout(); self:UpdateAll(); self:ApplyStock() end)
end

function Party:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset Party during combat."]); return end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self:Refresh()
end

function Party:Start()
    if InCombatLockdown() then ns.AfterCombat("PartyStart", function() self:Start() end); return end
    if self.frame then return end
    if not ns.HasAuraAPI() then
        self.unavailable = true
        self:Notice("auraAPI", "Required Mainline aura API unavailable; native Party retained.")
        return
    end
    self:Create(); self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
        self.events:RegisterEvent(event)
    end
    self:UpdateEventActivity()
    self.events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then self:ApplyStock(); return end
        if event ~= "GROUP_ROSTER_UPDATE" and event ~= "PLAYER_ENTERING_WORLD"
            and not ns.positioning and not UnitExists("party1") then return end
        if event == "UPDATE_BINDINGS" or event == "RAID_TARGET_UPDATE" then
            self:UpdateIndicators(event)
            return
        end
        self:UpdateAll()
        self:ApplyStock()
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:ApplyStock() end, self)
    end
    self:ApplyStock()
end
