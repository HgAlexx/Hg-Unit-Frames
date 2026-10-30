local ns = Hg_Rebirth
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local UnitPowerType = UnitPowerType
local Pet = {
    savedVariable = "Hg_Rebirth_Player_Pet_Options",
    defaults = {
        locked = true, compact = true, showName = true, showHappiness = false, opacity = 1,
        scale = 1, targetScale = 1, targetCompact = true, portrait = false, portrait3D = false,
        combatText = false, showXP = false, showTarget = true,
        className = true, friendlyHealth = true, petClassName = true, petFriendlyHealth = true, castableBuffs = false,
        curableDebuffs = false, buffCount = 16, debuffCount = 16,
        buffSize = 12, debuffSize = 12, buffLocation = 6, debuffLocation = 7,
        auraSpacingHorizontal = 1,
        auraSpacingVertical = 3,
        x = -0.2586113569248119, y = -94.00000261200505, targetX = 132.7413905504236, targetY = -94.00004418665903,
        sticky1ChildX = 0,
        sticky1ParentX = 0,
        stickyParent = "Player",
        stickyScale = false,
        targetStickyScale = false,
        sticky1Placed = true,
        targetStickyMove = true,
        targetSticky1ChildX = 0,
        targetSticky1ParentY = 0,
        targetSticky1Placed = true,
        targetSticky1ParentX = 1,
        sticky1ChildY = 1,
        stickyMove = true,
        sticky1X = 0,
        sticky1Y = 2.577777815030686,
        targetSticky1X = -2.911111831349615,
        targetStickyParent = "PlayerPet",
        sticky1ParentY = 0,
        targetSticky1Y = -7.866753583130048e-05,
        targetSticky1ChildY = 0,
    },
    ranges = {
        scale = { 0.01, 1.49 }, targetScale = { 0.01, 1.49 }, opacity = { 0, 1 },
        auraSpacingHorizontal = { -10, 30 },
        auraSpacingVertical = { -10, 30 },
        buffCount = { 0, 16, integer = true }, debuffCount = { 0, 16, integer = true },
        buffSize = { 1, 50, integer = true }, debuffSize = { 1, 50, integer = true },
        buffLocation = { 1, 7, integer = true }, debuffLocation = { 1, 7, integer = true },
    },
    boxes = {}, buttons = {}, containers = {},
}
ns.RegisterModule("PlayerPet", Pet)

function Pet:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Player Pet: " .. message)
end

local function savePosition(frame, xKey, yKey)
    ns.SavePosition(Pet, frame, xKey, yKey)
end

local function overlay(parent, root, unit, xKey, yKey)
    return ns.UnitOverlay(Pet, parent, root, unit, xKey, yKey)
end

local function root(name, unit)
    return ns.UnitRoot(name, unit, 170)
end

local function box(parent, width, height)
    local frame = ns.Box(parent, width, height)
    Pet.boxes[#Pet.boxes + 1] = frame
    return frame
end

local function bar(parent, preceding)
    local entry = ns.UnitBar(parent, 133)
    if preceding then entry.frame:SetPoint("TOP", preceding, "BOTTOM", 0, -1)
    else entry.frame:SetPoint("TOP", parent, "TOP", 0, -6) end
    return entry
end

local function auraContainer(parent, size)
    local container = ns.AuraContainer(parent, "pet", size)
    Pet.containers[#Pet.containers + 1] = container
    return container
end

local function borderContainer(parent)
    local container = ns.AuraBorder(parent, "pet")
    Pet.containers[#Pet.containers + 1] = container
    return container
end

function Pet:Create()
    self.frame = root("Hg_Rebirth_PlayerPetFrame", "pet")
    self.nameBox = box(self.frame, 170, 24)
    self.nameBox:SetPoint("TOPLEFT")
    self.nameButton = overlay(self.nameBox, self.frame, "pet", "x", "y")
    self.name = ns.Label(self.nameBox)
    self.name:SetPoint("CENTER", 8, 0)
    self.name:SetNonSpaceWrap(false)
    self.level = ns.Label(self.nameBox)
    self.level:SetPoint("LEFT", 6, 0)
    self.threat = ns.ThreatIcon(self.nameBox, "RIGHT", -5)
    self.levelBox = box(self.frame, 30, 34)
    overlay(self.levelBox, self.frame, "pet", "x", "y")
    self.happiness = ns.Icon(self.nameBox, "Interface\\PetPaperDollFrame\\UI-PetHappiness",
        18, 18, "RIGHT", self.nameBox, "RIGHT", -5, 0)
    self.stats = box(self.frame, 170, 34)
    overlay(self.stats, self.frame, "pet", "x", "y")
    self.health = bar(self.stats)
    self.power = bar(self.stats, self.health.frame)
    self.xp = bar(self.stats, self.power.frame)
    self.portraitBox = box(self.frame, 56, 56)
    self.portraitBox:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 2, 0)
    overlay(self.portraitBox, self.frame, "pet", "x", "y")
    self.portrait = ns.Icon(self.portraitBox, nil, 43, 43, "TOP", self.portraitBox, "TOP", 0, -6)
    self.model = CreateFrame("PlayerModel", nil, self.portraitBox)
    self.model:SetSize(45, 45)
    self.model:SetPoint("CENTER", 1, -1)
    self.model:EnableMouse(false)
    local feedback = CreateFrame("Frame", nil, self.portraitBox)
    feedback:SetAllPoints()
    feedback:SetFrameLevel(self.model:GetFrameLevel() + 2)
    self.feedback = ns.Label(feedback, "NumberFontNormalHuge")
    self.feedback:SetPoint("CENTER")
    self.feedback:Hide()

    self.target = { frame = root("Hg_Rebirth_PlayerPetTargetFrame", "pettarget") }
    local target = self.target
    target.nameBox = box(target.frame, 145, 24)
    target.nameBox:SetPoint("TOPLEFT")
    overlay(target.nameBox, target.frame, "pettarget", "targetX", "targetY")
    target.name = ns.Label(target.nameBox)
    target.name:SetPoint("CENTER")
    target.name:SetSize(135, 14)
    target.name:SetNonSpaceWrap(false)
    target.marker = ns.Icon(target.nameBox, "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        11, 11, "CENTER", target.nameBox, "TOPRIGHT", -4, -3)
    target.stats = box(target.frame, 145, 34)
    target.stats:SetPoint("TOPLEFT", target.nameBox, "BOTTOMLEFT", 0, 2)
    overlay(target.stats, target.frame, "pettarget", "targetX", "targetY")
    target.health = bar(target.stats)
    target.power = bar(target.stats, target.health.frame)
    for _, entry in ipairs({ target.health, target.power }) do
        local button = overlay(entry.frame, target.frame, "pettarget", "targetX", "targetY")
        button:SetScript("OnEnter", function() entry.hover = true; self:UpdateTarget() end)
        button:SetScript("OnLeave", function() entry.hover = false; self:UpdateTarget() end)
    end
    self.healthCurve = ns.CreateHealthCurve()
    local buffSize, debuffSize = self.db.buffSize, self.db.debuffSize
    self.buffContainer = auraContainer(self.frame, buffSize)
    self.debuffContainer = auraContainer(self.frame, debuffSize)
    self.buffContainer:AddAuraGroup("icons", "HELPFUL", {
        maxFrameCount = self.db.buffCount,
        initializeFrame = function(button) ns.InitializeAuraButton(button, false, false, nil, nil, buffSize) end,
    })
    self.debuffContainer:AddAuraGroup("icons", "HARMFUL", {
        maxFrameCount = self.db.debuffCount,
        initializeFrame = function(button) ns.InitializeAuraButton(button, true, false, nil, nil, debuffSize) end,
    })
    self.borderContainers = {}
    for _, parent in ipairs({ self.nameBox, self.levelBox, self.stats, self.portraitBox }) do
        self.borderContainers[#self.borderContainers + 1] = borderContainer(parent)
    end
end

function Pet:HasXP()
    if not self.xpSupported or not self.db.showXP or self.class ~= "HUNTER" then return false end
    if ns.positioning then return true end
    local level, playerLevel = UnitLevel("pet"), UnitLevel("player")
    if ns.IsSecret(level) or ns.IsSecret(playerLevel) then
        self:Notice("xpLevel", "Pet experience layout is unavailable while levels are restricted.")
        return false
    end
    if level >= playerLevel then return false end
    local value, maximum = GetPetExperience()
    if ns.IsSecret(maximum) then return ns.IsSecret(value) or type(value) == "number" end
    return type(value) == "number" and type(maximum) == "number" and maximum > 0
end

function Pet:PositionAuras(container, location, size, count, filter)
    container:Show()
    ns.LayoutAuraIcons(container, { "icons" }, size, self.db.auraSpacingHorizontal)
    local scale = container:GetScale()
    local top = self.db.showName and self.nameBox or self.stats
    local bottom = self.stats
    local point = location <= 2 and "BOTTOMLEFT" or "TOPLEFT"
    local rowDistance = math.max(self.db.buffSize, self.db.debuffSize) + self.db.auraSpacingVertical
    local relative, relativePoint, x, y
    if location <= 2 then
        relative, relativePoint, x, y = top, "TOPLEFT", 5, location == 1 and rowDistance or 0
    elseif location == 3 then
        relative, relativePoint, x, y = self.nameBox, "TOPRIGHT", 0, -3
    elseif location <= 5 then
        relative, relativePoint, x, y = self.stats, "TOPRIGHT", 0, location == 4 and -5 or -5 - rowDistance
    else
        relative, relativePoint, x, y = bottom, "BOTTOMLEFT", 5, location == 6 and 0 or -rowDistance
    end
    container:ClearAllPoints()
    container:SetPoint(point, relative, relativePoint, x / scale, y / scale)
    container:SetFlowLayoutAnchorPoint(point)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,
        location <= 2 and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    container:SetAuraGroupFilterString("icons", filter)
    container:SetAuraGroupMaxFrameCount("icons", count)
    container:SetEnabled(count > 0)
    ns.LayoutAuraPreview(self, container, count, size, math.max(1, count), self.db.auraSpacingHorizontal, 0,
        point, x, y, 1, container == self.debuffContainer, false, relative, relativePoint)
end

function Pet:Layout()
    local db, core = self.db, ns.modules.Core.db
    self.hasHappiness = db.showHappiness and db.showName and self.class == "HUNTER"
        and self.happinessSupported
    if db.showHappiness and db.showName and self.class == "HUNTER" and not self.happinessSupported then
        self:Notice("happinessAPI", ns.L["Pet happiness API unavailable on this client; happiness icon is hidden."])
    end
    self.hasXP = self:HasXP()
    local width = db.compact and 135 or 170
    local statsWidth = width
    local barWidth = statsWidth - 12
    self.frame:SetScale(db.scale + (1 - UIParent:GetEffectiveScale()))
    self.frame:SetAlpha(db.opacity)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    self.frame:SetWidth(width)
    self.nameBox:SetWidth(width)
    self.nameBox:SetShown(db.showName)
    self.name:SetSize(width - 30 - (self.hasHappiness and 22 or 0), 14)
    self.name:ClearAllPoints()
    self.name:SetPoint("CENTER", self.nameBox, "CENTER", self.hasHappiness and -3 or 8, 0)
    self.happiness:SetShown(self.hasHappiness)
    self.threat:ClearAllPoints()
    self.threat:SetPoint("RIGHT", self.nameBox, "RIGHT", self.hasHappiness and -27 or -5, 0)
    local top = not db.showName and self.frame or self.nameBox
    local point = not db.showName and "TOPLEFT" or "BOTTOMLEFT"
    local y = not db.showName and 0 or 2
    self.levelBox:ClearAllPoints()
    self.levelBox:SetPoint("TOPLEFT", top, point, 0, y)
    self.levelBox:Hide()
    self.stats:ClearAllPoints()
    self.stats:SetPoint("TOPLEFT", top, point, 0, y)
    self.stats:SetSize(statsWidth, self.hasXP and 45 or 34)
    for _, entry in ipairs({ self.health, self.power, self.xp }) do entry.frame:SetWidth(barWidth) end
    self.xp.frame:SetShown(self.hasXP)
    self.portraitBox:SetShown(db.portrait)
    if not db.combatText then self.feedbackAge = nil; self.feedback:Hide() end
    local target = self.target
    local targetWidth = db.targetCompact and 105 or 145
    target.frame:SetSize(targetWidth, 24)
    target.nameBox:SetWidth(targetWidth)
    target.stats:SetWidth(targetWidth)
    target.name:SetWidth(targetWidth - 10)
    target.health.frame:SetWidth(targetWidth - 12)
    target.power.frame:SetWidth(targetWidth - 12)
    target.frame:SetScale(db.targetScale + (1 - UIParent:GetEffectiveScale()))
    target.frame:SetAlpha(db.opacity)
    target.frame:ClearAllPoints()
    target.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.targetX, db.targetY)
    for _, entry in ipairs({ self.health, self.power, self.xp, target.health, target.power }) do
        entry.frame:SetStatusBarTexture(ns.TexturePath())
        entry.background:SetTexture(core.texturedBackground and ns.TexturePath()
            or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    end
    for _, frame in ipairs(self.boxes) do
        frame:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
    end
    ns.UnitVisibility(self.frame, "visibility", "[petbattle] hide; [@pet,exists] show; hide")
    ns.UnitVisibility(target.frame, "visibility", db.showTarget
        and "[petbattle] hide; [@pettarget,exists] show; hide"
        or "hide")
    self:PositionAuras(self.buffContainer, db.buffLocation, db.buffSize, db.buffCount,
        db.castableBuffs and "HELPFUL|RAID" or "HELPFUL")
    self:PositionAuras(self.debuffContainer, db.debuffLocation, db.debuffSize, db.debuffCount,
        db.curableDebuffs and "HARMFUL|RAID" or "HARMFUL")
    for _, container in ipairs(self.borderContainers) do container:SetEnabled(core.colorDebuffs) end
end

function Pet:UpdatePet(kind)
    if ns.PreviewUnit(self, "Player Pet") then
        self.happiness:SetShown(self.hasHappiness)
        self.health.text:SetText(self.db.petFriendlyHealth and "75/100" or "75%")
        self.name:SetTextColor(1, 1, 0)
        if self.db.petClassName then
            local _, class = UnitClass("player")
            local color = not ns.IsSecret(class) and RAID_CLASS_COLORS[class]
            if color then self.name:SetTextColor(color.r, color.g, color.b) end
        end
        return
    end
    if not UnitExists("pet") then return end
    if not kind then
        self.name:SetText(UnitName("pet"))
        self.name:SetTextColor(1, 1, 0)
        if self.db.petClassName then
            local _, token = UnitClass("pet")
            if not ns.IsSecret(token) then
                local color = token and RAID_CLASS_COLORS[token]
                if color then self.name:SetTextColor(color.r, color.g, color.b) end
            else
                self:Notice("petClass", "Restricted pet class: class-colored pet name is unavailable.")
            end
        end
        self.level:SetText(UnitLevel("pet"))
    end
    if kind ~= "power" then
        local value, maximum, _, percent = ns.UpdateUnitBar(self, self.health, "pet", nil, true)
        local friendly = UnitIsFriend("player", "pet")
        local detailed = self.db.petFriendlyHealth and not ns.IsSecret(friendly) and friendly
        if (not detailed or (not ns.IsSecret(maximum) and maximum == 100))
            and (ns.IsSecret(percent) or percent ~= nil) then
            self.health.text:SetFormattedText("%.0f%%", percent)
        else self.health.text:SetFormattedText("%.0f/%.0f", value, maximum) end
    end
    if kind ~= "health" then
        local powerType = UnitPowerType("pet")
        local value, maximum = ns.UpdateUnitBar(self, self.power, "pet", powerType, false)
        if self.class == "HUNTER" then self.power.text:SetFormattedText("%.0f", value)
        else self.power.text:SetFormattedText("%.0f/%.0f", value, maximum) end
    end
    if kind then return end
    if self.hasXP then
        local value, maximum = GetPetExperience()
        local valid = (ns.IsSecret(value) or type(value) == "number")
            and (ns.IsSecret(maximum) or (type(maximum) == "number" and maximum > 0))
        self.xp.frame:SetMinMaxValues(0, valid and maximum or 1)
        self.xp.frame:SetValue(valid and value or 0)
        self.xp.frame:SetStatusBarColor(0, 0.6, 0.6)
        self.xp.background:SetVertexColor(0, 0.6, 0.6, 0.25)
        if valid then self.xp.text:SetFormattedText("%.0f/%.0f", value, maximum)
        else self.xp.text:SetText(""); self:Refresh() end
    end
    if self.hasHappiness then
        local happiness = C_PetInfo.GetPetHappiness()
        if ns.IsSecret(happiness) then
            self.happiness:Hide()
            self:Notice("happiness", "Pet happiness icon unavailable while its value is restricted.")
        elseif happiness == 1 or happiness == 2 or happiness == 3 then
            local offset = (3 - happiness) * 0.1875
            self.happiness:SetTexCoord(offset, offset + 0.1875, 0, 0.359375)
            self.happiness:Show()
        else self.happiness:Hide() end
    else self.happiness:Hide() end
    local threat = UnitThreatSituation("pet")
    if ns.IsSecret(threat) then
        self.threat:Hide()
        if ns.modules.Core.db.threat then self:Notice("threat", "Pet threat indicator unavailable for restricted threat.") end
    else
        self.threat:SetShown(ns.modules.Core.db.threat and threat ~= nil and threat > 0)
    end
end

function Pet:UpdatePortrait()
    if not self.db.portrait or not UnitExists("pet") then return end
    local visible = UnitIsVisible("pet")
    local model = self.db.portrait3D and not ns.IsSecret(visible) and visible
    self.model:SetShown(model)
    self.portrait:SetShown(not model)
    if model then self.model:SetUnit("pet"); self.model:SetPortraitZoom(1)
    else SetPortraitTexture(self.portrait, "pet") end
end

function Pet:UpdateTarget(kind)
    if ns.PreviewUnit(self.target, "Pet's target", self.db) then return end
    if not self.db.showTarget or not UnitExists("pettarget") then return end
    local target = self.target
    if not kind then
        target.name:SetText(UnitName("pettarget"))
        local class, r, g, b
        if self.db.className then
            local isPlayer = UnitIsPlayer("pettarget")
            if not ns.IsSecret(isPlayer) and isPlayer then
                local _, token = UnitClass("pettarget")
                if not ns.IsSecret(token) then class = RAID_CLASS_COLORS[token] end
            end
        end
        if class then r, g, b = class.r, class.g, class.b
        else r, g, b = self:TargetNameColor() end
        if not r then
            r, g, b = 1, 1, 1
            self:Notice("reaction", "Pet-target reaction coloring unavailable while identity data is restricted.")
        end
        target.name:SetTextColor(r, g, b)
    end
    local friendly = UnitIsFriend("player", "pettarget")
    local powerType = UnitPowerType("pettarget")
    for index = kind == "power" and 2 or 1, kind == "health" and 1 or 2 do
        local health = index == 1
        local entry = health and target.health or target.power
        local value, maximum, _, percent = ns.UpdateUnitBar(self, entry, "pettarget", powerType, health)
        if health then
            local detailed = entry.hover or (self.db.friendlyHealth and not ns.IsSecret(friendly) and friendly)
            if detailed and (ns.IsSecret(maximum) or maximum ~= 100) then
                entry.text:SetFormattedText("%.0f/%.0f", value, maximum)
            elseif ns.IsSecret(percent) or percent ~= nil then entry.text:SetFormattedText("%.0f%%", percent)
            else entry.text:SetText("") end
        elseif not entry.hover then entry.text:SetText("")
        elseif not ns.IsSecret(powerType) and (powerType == 1 or powerType == 2 or powerType == 6) then
            entry.text:SetFormattedText("%.0f", value)
        else entry.text:SetFormattedText("%.0f/%.0f", value, maximum) end
    end
    if kind then return end
    ns.UpdateRaidMarker(self, target.marker, "pettarget")
end

function Pet:TargetNameColor()
    return ns.UnitNameColor("pettarget")
end

function Pet:UpdateAll()
    if ns.positioning then self:UpdatePet(); self:UpdateTarget(); return end
    self:UpdatePet()
    self:UpdateTarget()
    self:UpdatePortrait()
end

function Pet:Refresh()
    if not self.frame then return end
    ns.AfterCombat("PlayerPetLayout", function() self:Layout(); self:UpdateAll() end)
end

function Pet:ResetPosition()
    if InCombatLockdown() then ns.Warn("Cannot reset pet positions during combat."); return end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self.db.targetX, self.db.targetY = self.defaults.targetX, self.defaults.targetY
    self:Refresh()
end

function Pet:Align()
    if InCombatLockdown() then ns.Warn("Cannot align pet frames during combat."); return false end
    local player = ns.modules.Player
    if not self.frame or not player or not player.stats then
        ns.Warn("Player must be enabled and initialized to align pet frames.")
        return false
    end
    local relative = player.stats
    local ownScale, otherScale = self.frame:GetEffectiveScale(), relative:GetEffectiveScale()
    local x = relative:GetLeft() * otherScale / ownScale
    local y = relative:GetBottom() * otherScale / ownScale
    if self.db.portrait and not player.db.portrait then x = x + 54 end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y + 2)
    savePosition(self.frame, "x", "y")
    local target = self.target.frame
    local ratio = ownScale / target:GetEffectiveScale()
    target:ClearAllPoints()
    target:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        (self.frame:GetRight() - 2) * ratio, self.frame:GetTop() * ratio)
    savePosition(target, "targetX", "targetY")
    return true
end

function Pet:Tick(elapsed)
    if ns.positioning then return end
    ns.TickCombatFeedback(self, elapsed)
    self.targetElapsed = (self.targetElapsed or 0) + elapsed
    if self.targetElapsed >= 0.2 then
        self.targetElapsed = 0
        self:UpdateTarget()
    end
end

function Pet:SuppressStock()
    PetFrame:SetAlpha(0)
    PetFrame:EnableMouse(false)
    if PetFrameHealthBar then PetFrameHealthBar:EnableMouse(false) end
    if PetFrameManaBar then PetFrameManaBar:EnableMouse(false) end
end

function Pet:Start()
    if InCombatLockdown() then ns.AfterCombat("PlayerPetStart", function() self:Start() end); return end
    if self.frame then return end
    if not ns.HasAuraAPI() then
        self.unavailable = true
        self:Notice("auraAPI", "Required Mainline AuraContainer/AuraButton API unavailable; stock pet frame retained.")
        return
    end
    local _, class = UnitClass("player")
    self.class = class
    self.xpSupported = type(GetPetExperience) == "function"
    self.happinessSupported = C_PetInfo and type(C_PetInfo.GetPetHappiness) == "function"
    self:Create()
    self:Layout()
    self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PET_UI_UPDATE", "RAID_TARGET_UPDATE" }) do
        self.events:RegisterEvent(event)
    end
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_TARGET",
        "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_COMBAT", "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_FACTION", "UNIT_FLAGS" }) do
        self.events:RegisterUnitEvent(event, "pet", "pettarget")
    end
    self.events:RegisterUnitEvent("UNIT_PET", "player")
    self.events:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self.events:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    self.events:RegisterUnitEvent("UNIT_LEVEL", "pet", "player")
    if self.xpSupported then self.events:RegisterUnitEvent("UNIT_PET_EXPERIENCE", "pet") end
    if self.happinessSupported then self.events:RegisterUnitEvent("UNIT_HAPPINESS", "pet") end
    self.events:SetScript("OnEvent", function(_, event, unit, action, descriptor, amount, school)
        if ns.positioning then self:UpdateAll(); return end
        if event == "UNIT_COMBAT" then
            if unit == "pet" and self.db.combatText then
                ns.ShowCombatFeedback(self, action, descriptor, amount, school)
            end
        elseif event == "UNIT_PET" then
            if unit ~= "player" then return end
            self.feedbackAge = nil
            self.feedback:Hide()
            for _, container in ipairs(self.containers) do container:UpdateAllAuras() end
            self:Refresh()
        elseif event == "UNIT_LEVEL" or event == "UNIT_PET_EXPERIENCE" or event == "PLAYER_ENTERING_WORLD" then
            self:Refresh()
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            if unit == "pet" then self:UpdatePortrait() end
        elseif unit == "pettarget" or event == "UNIT_TARGET" or event == "PLAYER_TARGET_CHANGED" then
            self:UpdateTarget(ns.VitalsEventKinds[event])
        elseif ns.VitalsEventKinds[event] or event == "UNIT_THREAT_SITUATION_UPDATE"
            or event == "UNIT_HAPPINESS" or event == "UNIT_FLAGS" or event == "UNIT_NAME_UPDATE"
            or event == "UNIT_FACTION" or event == "UNIT_DISPLAYPOWER" then
            self:UpdatePet(ns.VitalsEventKinds[event])
        else self:UpdateAll() end
    end)
    self.frame:SetScript("OnUpdate", function(_, elapsed) self:Tick(elapsed) end)
    self.target.frame:SetScript("OnShow", function() self:UpdateTarget() end)
    self.frame:SetScript("OnShow", function() self:UpdateAll() end)
    self:SuppressStock()
    ns.stockPetReplaced = true
    hooksecurefunc(PetFrame, "SetAlpha", function(_, alpha)
        if ns.IsSecret(alpha) or alpha ~= 0 then
            ns.AfterCombat("PlayerPetStock", function() self:SuppressStock() end)
        end
    end)
    PetFrame:HookScript("OnShow", function()
        ns.AfterCombat("PlayerPetStock", function() self:SuppressStock() end)
    end)
end
