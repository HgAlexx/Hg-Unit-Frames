local ns = Hg_Rebirth
local GetTime = GetTime
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsPVP = UnitIsPVP
local floor = math.floor
local Player = {
    savedVariable = "Hg_Rebirth_Player_Options",
    defaults = {
        locked = true, progress = "experience", compact = true, healer = false,
        raidGroup = true, scale = 1, opacity = 1, portrait = false,
        compactPercent = true, portrait3D = false, combatText = false,
        alternateMana = true, shortBars = false, className = true,
        showLevel = true, matchLevelHeight = true, manaDeficit = false, showInRaid = true,
        pvpIcon = true, barValues = false, groupInName = false,
        fiveSecondRule = false, pvpTimer = false, classResource = true,
        resourceColor = { 0.75, 0, 0 }, resourceOnTop = false,
        x = -2, y = -20,
        sticky1ChildY = 0,
        sticky1ChildX = 0,
        sticky1ParentX = 0,
        sticky1ParentY = 0,
        sticky1Y = 0,
        stickyMove = false,
        sticky1X = 0,
        stickyScale = false,
        sticky1Placed = false,
        stickyParent = "",
    },
    ranges = { scale = { 0.01, 1.49 }, opacity = { 0, 1 },
        progress = { experience = true, reputation = true, hidden = true },
        resourceColor = ns.rgbRange },
    buttons = {}, boxes = {}, bars = {},
}
ns.RegisterModule("Player", Player)

local resourcePowers = { ROGUE = 4, DRUID = 4, WARLOCK = 7, PALADIN = 9, MONK = 12, MAGE = 16 }

function Player:Notice(key, message)
    self.notices = self.notices or {}
    if not self.notices[key] then
        self.notices[key] = true
        ns.Warn(message)
    end
end

local function overlay(owner, parent, nameArea)
    local button = ns.UnitOverlay(owner, parent, owner.frame, "player")
    button:SetAttribute("toggleForVehicle", true)
    button.nameArea = nameArea
    return button
end

local function box(owner, width, height)
    local frame = ns.Box(owner.frame, width, height)
    owner.boxes[#owner.boxes + 1] = frame
    return frame
end

local function bar(owner, id)
    local frame = CreateFrame("StatusBar", nil, owner.stats)
    frame:SetSize(150, 10)
    frame:SetStatusBarTexture(ns.TexturePath())
    frame:SetMinMaxValues(0, 1)
    frame:SetValue(0)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local percent = ns.Label(frame)
    percent:SetPoint("TOP", 0, 1)
    local value = ns.Label(frame)
    value:SetPoint("RIGHT", 100, 0)
    local compact = ns.Label(frame)
    compact:SetPoint("RIGHT", 35, 0)
    for _, text in ipairs({ percent, value, compact }) do text:SetTextColor(1, 1, 1) end
    local button = overlay(owner, frame)
    button:SetFrameLevel(frame:GetFrameLevel() + 3)
    local result = { frame = frame, background = background,
        percent = percent, value = value, compact = compact, button = button }
    button:SetScript("OnEnter", function() result.hover = true; owner:UpdateVitals() end)
    button:SetScript("OnLeave", function() result.hover = false; owner:UpdateVitals() end)
    owner.bars[id] = result
    return result
end

function Player:Create()
    local root = CreateFrame("Frame", "Hg_Rebirth_PlayerFrame", UIParent, "SecureHandlerStateTemplate")
    root:SetSize(202, 24)
    root:SetFrameStrata("LOW")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    self.frame = root
    self.nameBox = box(self, 202, 24)
    self.nameBox:SetPoint("TOPLEFT")
    self.nameMeter = CreateFrame("StatusBar", nil, self.nameBox)
    self.nameMeter:SetPoint("BOTTOMLEFT", self.nameBox, "BOTTOMLEFT", 5, 2)
    self.nameMeter:SetHeight(3)
    self.nameMeter:SetFrameLevel(self.nameBox:GetFrameLevel() + 4)
    self.nameMeter:SetStatusBarColor(1, 0, 0)
    self.nameMeter:EnableMouse(false)
    self.nameMeter:Hide()
    self.resourceMarks = {}
    for i = 1, 4 do
        local mark = self.nameMeter:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        mark:SetVertexColor(0, 0, 0, 0.8)
        mark:SetSize(1, 3)
        self.resourceMarks[i] = mark
    end
    self.nameButton = overlay(self, self.nameBox, true)
    self.name = ns.Label(self.nameBox, "GameFontNormal")
    self.name:SetPoint("CENTER")
    self.name:SetNonSpaceWrap(false)
    self.name:SetJustifyH("CENTER")
    self.activity = ns.Icon(self.nameBox, "Interface\\CharacterFrame\\UI-StateIcon",
        32, 31, "RIGHT", self.nameBox, "RIGHT", 0, 0)
    self.pvp = ns.Icon(self.nameBox, "Interface\\TargetingFrame\\UI-PVP-FFA",
        32, 32, "TOPLEFT", self.nameBox, "TOPLEFT", 2, -3)
    self.leader = ns.Icon(self.nameBox, "Interface\\GroupFrame\\UI-Group-LeaderIcon",
        16, 16, "TOP", self.nameBox, "TOP", 0, 7)
    self.master = ns.Icon(self.nameBox, "Interface\\GroupFrame\\UI-Group-MasterLooter",
        16, 16, "TOPLEFT", self.nameBox, "TOPLEFT", 65, 7)
    self.role = ns.Icon(self.nameBox, ns.media .. "Role.tga",
        19, 18, "TOPLEFT", self.nameBox, "TOPLEFT", 3, -4)
    self.threat = ns.ThreatIcon(self.nameBox, "RIGHT", -34)
    self.pvpTime = ns.Label(self.nameBox, "GameFontNormal")
    self.pvpTime:SetPoint("TOPLEFT", self.pvp, "TOPRIGHT", -13, -3)

    self.groupBox = box(self, 65, 24)
    self.groupBox:SetPoint("TOPLEFT", self.nameBox, "TOPLEFT", 0, 22)
    overlay(self, self.groupBox)
    self.groupText = ns.Label(self.groupBox)
    self.groupText:SetPoint("TOP", 0, -5)
    self.levelBox = box(self, 34, 42)
    self.levelBox:SetPoint("TOPLEFT", self.nameBox, "BOTTOMLEFT", 0, 2)
    overlay(self, self.levelBox)
    self.classIcon = ns.Icon(self.levelBox, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
        24, 24, "TOPLEFT", self.levelBox, "TOPLEFT", 5, -5)
    self.level = ns.Label(self.levelBox)
    self.level:SetPoint("BOTTOM", 0, 4)

    self.portraitBox = box(self, 64, 64)
    self.portraitBox:SetPoint("TOPRIGHT", self.nameBox, "TOPLEFT", 2, 0)
    overlay(self, self.portraitBox)
    self.portrait = ns.Icon(self.portraitBox, nil, 52, 52,
        "TOP", self.portraitBox, "TOP", 0, -6)
    self.model = CreateFrame("PlayerModel", nil, self.portraitBox)
    self.model:EnableMouse(false)
    self.model:SetSize(54, 54)
    self.model:SetPoint("CENTER", 1, -1)
    local feedbackFrame = CreateFrame("Frame", nil, self.portraitBox)
    feedbackFrame:SetAllPoints()
    feedbackFrame:SetFrameLevel(self.model:GetFrameLevel() + 2)
    self.feedback = ns.Label(feedbackFrame, "NumberFontNormalHuge")
    self.feedback:SetPoint("CENTER")
    self.feedback:Hide()

    self.stats = box(self, 270, 54)
    self.statsButton = overlay(self, self.stats)
    local health = bar(self, "health")
    health.frame:SetPoint("TOPLEFT", self.stats, "TOPLEFT", 10, -10)
    local power = bar(self, "power")
    power.frame:SetPoint("TOPLEFT", health.frame, "BOTTOMLEFT", 0, -2)
    local mana = bar(self, "mana")
    mana.frame:SetPoint("TOPLEFT", power.frame, "BOTTOMLEFT", 0, -2)
    local progress = bar(self, "progress")
    progress.value:Hide()
    progress.compact:Hide()
    progress.rest = CreateFrame("StatusBar", nil, self.stats)
    progress.rest:SetAllPoints(progress.frame)
    progress.rest:SetFrameLevel(progress.frame:GetFrameLevel() - 1)
    progress.rest:SetStatusBarTexture(ns.TexturePath())
    progress.button:SetScript("OnEnter", function() self:ProgressTooltip(progress.button) end)
    progress.button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.ticker = CreateFrame("Frame", nil, power.frame)
    self.ticker:SetSize(150, 2)
    self.ticker:SetPoint("TOPLEFT", power.frame, "BOTTOMLEFT")
    self.ticker.spark = ns.Icon(self.ticker, "Interface\\CastingBar\\UI-CastingBar-Spark",
        12, 12, "LEFT", self.ticker, "LEFT", 0, 0)
    self.ticker.spark:SetBlendMode("ADD")
    self.ticker:SetScript("OnUpdate", function(_, elapsed) self:TickManaRule(elapsed) end)
    self.ticker:Hide()
    self.essence = CreateFrame("Frame", nil, root)
    self.essence:SetSize(160, 16)
    self.essencePips = {}
    for i = 1, 10 do
        local pip = CreateFrame("Frame", nil, self.essence)
        pip:SetSize(16, 16)
        pip:SetPoint("LEFT", (i - 1) * 18, 0)
        local icon = pip:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetAtlas("UF-Essence-Icon")
        self.essencePips[i] = pip
    end
    self.healthCurve = ns.CreateHealthCurve()
    self.borderContainers = {}
    if ns.HasAuraAPI() then
        for _, parent in ipairs(self.boxes) do
            self.borderContainers[#self.borderContainers + 1] = ns.AuraBorder(parent, self.unit)
        end
    else
        self:Notice("auraAPI", "Required Mainline AuraContainer/AuraButton API unavailable; Player debuff border coloring is disabled.")
    end
end

function Player:Layout()
    local db, core = self.db, ns.modules.Core.db
    local small = db.compact and db.shortBars
    local nameWidth = small and 167 or 202
    local barWidth = small and 115 or 150
    local extra = not db.showLevel and 30 or 0
    local statsWidth = db.compact and (barWidth + 20 + (db.compactPercent and 35 or 0)) or 270
    local hasMana = db.alternateMana and (self.class == "DRUID" or self.class == "MONK"
        or self.class == "PRIEST" or self.class == "SHAMAN")
    self.hasMana = hasMana
    local height = 42 + (db.progress ~= "hidden" and 12 or 0) + (hasMana and 12 or 0)
    self.frame:SetScale(db.scale + (1 - UIParent:GetEffectiveScale()))
    self.frame:SetAlpha(db.opacity)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    self.frame:SetWidth(nameWidth)
    self.nameBox:SetWidth(nameWidth)
    self.nameMeter:SetWidth(nameWidth - 10)
    self.nameMeter:ClearAllPoints()
    local resourceAnchor = db.resourceOnTop and "TOPLEFT" or "BOTTOMLEFT"
    self.nameMeter:SetPoint(resourceAnchor, self.nameBox, resourceAnchor, 5, db.resourceOnTop and -2 or 2)
    self.nameMeter:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local resourceColor = db.resourceColor
    self.nameMeter:SetStatusBarColor(resourceColor[1], resourceColor[2], resourceColor[3], 1)
    for i, mark in ipairs(self.resourceMarks) do
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", self.nameMeter, "LEFT", (nameWidth - 10) * i / 5, 0)
    end
    self.name:SetSize(nameWidth - 40, 14)
    self.levelBox:SetShown(db.showLevel)
    self.levelBox:SetHeight(db.matchLevelHeight and height or 42)
    self.stats:SetSize(statsWidth + (not db.showLevel and 32 or 0), height)
    self.stats:ClearAllPoints()
    self.stats:SetPoint("TOPLEFT", self.nameBox, "BOTTOMLEFT", not db.showLevel and 0 or 32, 2)
    self.portraitBox:SetShown(db.portrait)
    self.portrait:SetShown(not db.portrait3D)
    self.model:SetShown(db.portrait3D)
    for id, entry in pairs(self.bars) do
        local width = id == "progress" and statsWidth - 20 or barWidth
        entry.frame:SetWidth(width + extra)
        entry.frame:SetStatusBarTexture(ns.TexturePath())
        entry.background:SetTexture(core.texturedBackground and ns.TexturePath()
            or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        entry.percent:ClearAllPoints()
        entry.value:ClearAllPoints()
        if db.compact and db.healer and id ~= "progress" then
            entry.percent:SetPoint("TOPLEFT", 5, 1)
            entry.value:SetPoint("RIGHT", -10, 0)
        else
            entry.percent:SetPoint("TOP", 0, 1)
            entry.value:SetPoint("RIGHT", db.compact and 85 or 100, 0)
        end
    end
    self.bars.mana.frame:SetShown(hasMana)
    self.ticker:SetWidth(self.bars.power.frame:GetWidth())
    if not ns.IsForever or not db.fiveSecondRule then
        self.lastMana, self.manaSpent, self.manaElapsed = nil, nil, nil
        self.ticker:Hide()
    end
    local progress = self.bars.progress
    progress.frame:ClearAllPoints()
    progress.frame:SetPoint("TOPLEFT", hasMana and self.bars.mana.frame or self.bars.power.frame, "BOTTOMLEFT", 0, -2)
    progress.frame:SetShown(db.progress ~= "hidden")
    progress.rest:SetShown(db.progress ~= "hidden")
    progress.rest:SetStatusBarTexture(ns.TexturePath())
    for _, frame in ipairs(self.boxes) do
        frame:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
    end
    local visibility = "[petbattle] hide; "
    if not db.showInRaid then visibility = visibility .. "[group:raid] hide; " end
    ns.UnitVisibility(self.frame, "visibility", visibility .. "show")
    self.groupBox:SetShown(db.raidGroup and IsInRaid())
    self:LayoutResource()
    ns.CastHostChanged(self)
    local buffs = ns.modules.PlayerAura
    if buffs then buffs:Refresh() end
end

local resourceOffsets = {
    DEATHKNIGHT = { 20, -2, 5 },
}

function Player:ApplyResource()
    local native = self.resource
    if not native then return end
    if native:GetParent() ~= self.frame then native:SetParent(self.frame) end
    native:ClearAllPoints()
    local offset = resourceOffsets[self.class] or resourceOffsets.DEATHKNIGHT
    local x = self.db.compact and self.db.shortBars and offset[3] or offset[1]
    native:SetPoint("TOPLEFT", self.stats, "BOTTOMLEFT", x, offset[2])
    native:SetAlpha(self.db.classResource and 1 or 0)
end

-- Retail class bars are PlayerBottomManagedFrameContainer children: each show or UI re-show
-- reparents them under the suppressed PlayerFrame. Re-apply ownership after Blizzard's layout.
function Player:HookResourceContainer()
    local container = PlayerBottomManagedFrameContainer
    if self.resourceHooked or not container or not hooksecurefunc then return end
    self.resourceHooked = true
    local function reapply(_, frame)
        local native = self.resource
        if native and (frame == nil or frame == native) then self:ApplyResource() end
    end
    if container.UpdateFrame then hooksecurefunc(container, "UpdateFrame", reapply) end
    if container.UpdateManagedFrames then
        hooksecurefunc(container, "UpdateManagedFrames", function() reapply() end)
    end
end

function Player:EnsureResourceVisible()
    local native = self.resource
    if not self.db.classResource or not native or not native.hiddenByPersonalResourceDisplay
        or not native.OnHideClassInfoOnPlayerFrameChanged then return end
    ns.AfterCombat("PlayerResourceVisibility", function()
        native = self.resource
        if self.db.classResource and native and native.hiddenByPersonalResourceDisplay
            and native.OnHideClassInfoOnPlayerFrameChanged then
            native:OnHideClassInfoOnPlayerFrameChanged(false)
        end
    end)
end

function Player:LayoutResource()
    if resourcePowers[self.class] then
        self.nameMeter:Hide()
        -- These classes use an addon-owned meter, not Blizzard's managed widget.
        local native = PlayerFrame and PlayerFrame.classPowerBar
        if native then native:SetAlpha(0) end
        self.essence:Hide()
        return
    end
    local native
    if self.class == "DEATHKNIGHT" then native = RuneFrame
    end
    if not native and PlayerFrame then native = PlayerFrame.classPowerBar end
    if native and self.class ~= "EVOKER" then
        if self.resource and self.resource ~= native then self.resource:SetAlpha(0) end
        self.resource = native
        self:HookResourceContainer()
        if self.resourceVisibilityHooked ~= native and native.Setup and hooksecurefunc then
            self.resourceVisibilityHooked = native
            -- Blizzard callbacks retain their original function, so hook Setup instead.
            hooksecurefunc(native, "Setup", function() self:EnsureResourceVisible() end)
        end
        self:EnsureResourceVisible()
        self:ApplyResource()
    elseif self.class == "DEATHKNIGHT" and self.db.classResource then
        self:Notice("resource", "Native class resource frame unavailable on this client.")
    elseif self.resource then
        self.resource:SetAlpha(0)
    end
    self.essence:SetShown(self.class == "EVOKER" and self.db.classResource)
    self.essence:ClearAllPoints()
    self.essence:SetPoint("TOPLEFT", self.stats, "BOTTOMLEFT",
        self.db.compact and self.db.shortBars and 16 or 34, 4)
end

function Player:UpdateResources()
    local powerType = resourcePowers[self.class]
    if not powerType then return end
    if not self.db.classResource or self.unit ~= "player" then self.nameMeter:Hide(); return end
    if self.class == "DRUID" then
        local primary = UnitPowerType("player")
        if ns.IsSecret(primary) or primary ~= 3 then self.nameMeter:Hide(); return end
    elseif self.class == "MAGE" or self.class == "MONK" then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        if not getSpec then
            self.nameMeter:Hide()
            self:Notice("resourceSpec", "Class resource specialization API unavailable on this client.")
            return
        end
        local spec = getSpec()
        if ns.IsSecret(spec) or spec ~= (self.class == "MAGE" and 1 or 3) then
            self.nameMeter:Hide()
            return
        end
    end
    local unmodified = self.class == "WARLOCK"
    local maximum = UnitPowerMax("player", powerType, unmodified)
    local value = UnitPower("player", powerType, unmodified)
    if not ns.IsSecret(maximum) and maximum <= 0 then self.nameMeter:Hide(); return end
    self.nameMeter:SetMinMaxValues(0, maximum)
    self.nameMeter:SetValue(value)
    self.nameMeter:Show()
end

function Player:Preview()
    local db = self.db
    self.nameMeter:SetShown(db.classResource and resourcePowers[self.class] ~= nil)
    if self.nameMeter:IsShown() then
        self.nameMeter:SetMinMaxValues(0, 5)
        self.nameMeter:SetValue(3)
    end
    self.groupBox:SetShown(db.raidGroup)
    self.groupText:SetText(ns.L["Group"] .. " 1")
    if db.groupInName then
        self.currentName = ns.L["Player"] .. ":1"
        self.name:SetText(self.currentName)
    end
    self.essence:SetShown(db.classResource and self.class == "EVOKER")
    for i, pip in ipairs(self.essencePips) do
        pip:SetShown(i <= 6); pip:SetAlpha(i <= 3 and 1 or 0.35)
    end
    if self.resource then self.resource:SetAlpha(0) end
    if self.class == "DEATHKNIGHT" and db.classResource then
        if not self.previewResource then
            self.previewResource = CreateFrame("Frame", nil, self.frame)
            self.previewResource:SetSize(120, 16)
            self.previewResource:EnableMouse(false)
            for i = 1, 6 do
                local pip = ns.Icon(self.previewResource, "Interface\\Buttons\\WHITE8X8",
                    14, 14, "LEFT", self.previewResource, "LEFT", (i - 1) * 18, 0)
                pip:SetVertexColor(0.3, 0.6, 0.9, i <= 3 and 1 or 0.35)
            end
        end
        self.previewResource:ClearAllPoints()
        self.previewResource:SetPoint("TOPLEFT", self.stats, "BOTTOMLEFT",
            db.compact and db.shortBars and 5 or 20, -2)
        self.previewResource:Show()
    elseif self.previewResource then self.previewResource:Hide() end
    local progress = self.bars.progress
    progress.percent:SetText(db.progress == "reputation" and ns.L["Reputation"] .. " 60%" or "60%")
    progress.rest:SetMinMaxValues(0, 100); progress.rest:SetValue(85)
    progress.rest:SetStatusBarColor(0.3, 0.5, 1)
    progress.rest:SetShown(db.progress == "experience")
    -- Five-second mana-rule preview, suspended until restricted mana spending can be detected.
    -- self.ticker:SetShown(ns.IsForever and db.fiveSecondRule)
    self.ticker:Hide()
end

function Player:Refresh()
    if not self.frame then return end
    ns.AfterCombat("PlayerLayout", function()
        self:Layout()
        self:UpdateAll()
        if self.suppressBlizzard then
            PlayerFrame:SetAlpha(0)
            PlayerFrame:EnableMouse(false)
        end
    end)
end

function Player:ResetPosition()
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self:Refresh()
end

function Player:UpdateBar(entry, powerType, health)
    if ns.PreviewUnit(self, "Player") then return end
    local unit = self.unit or "player"
    local db = self.db
    local value, maximum, missing, percent = ns.UpdateUnitBar(self, entry, unit, powerType, health)
    entry.value:SetText("")
    entry.percent:SetText("")
    entry.compact:SetText("")
    if db.healer then
        if (health or db.manaDeficit) and (ns.IsSecret(missing) or missing ~= nil) then
            entry.value:SetFormattedText("-%.0f", missing)
        elseif health or db.manaDeficit then
            self:Notice("deficit", "Deficit display API unavailable for restricted health or power.")
        end
        entry.value:SetTextColor(health and 1 or 0.5, health and 1 or 0.5, health and 1 or 0.5)
        if db.barValues or entry.hover then entry.percent:SetFormattedText("%.0f/%.0f", value, maximum) end
    else
        entry.value:SetTextColor(1, 1, 1)
        if db.compact then entry.percent:SetFormattedText("%.0f/%.0f", value, maximum)
        else
            entry.value:SetFormattedText("%.0f/%.0f", value, maximum)
            if not health and (powerType == 1 or powerType == 6) then entry.percent:SetFormattedText("%.0f", value)
            elseif ns.IsSecret(percent) or percent ~= nil then entry.percent:SetFormattedText("%.0f%%", percent) end
        end
    end
    if db.compact and db.compactPercent and (ns.IsSecret(percent) or percent ~= nil) then
        entry.compact:SetFormattedText("%.0f%%", percent)
    end
    if powerType == 0 and entry == self.bars.power and ns.IsForever and db.fiveSecondRule then
        if not ns.IsSecret(value) then
            if self.lastMana and value < self.lastMana then
                self.manaSpent = GetTime()
                self.manaElapsed = 0
                self.ticker.spark:ClearAllPoints()
                self.ticker.spark:SetPoint("CENTER", self.ticker, "LEFT", 0, 0)
                self.ticker:Show()
            end
            self.lastMana = value
        else
            self.lastMana, self.manaSpent = nil, nil
            self.ticker:Hide()
            self:Notice("manaRule", "Five-second mana rule unavailable while mana values are restricted.")
        end
    end
end

function Player:UpdateVitals(kind)
    if ns.PreviewUnit(self, "Player") then return end
    if kind ~= "power" then self:UpdateBar(self.bars.health, nil, true) end
    if kind == "health" then return end
    local powerType = UnitPowerType(self.unit or "player")
    if powerType ~= 0 then
        self.lastMana, self.manaSpent, self.manaElapsed = nil, nil, nil
        self.ticker:Hide()
    end
    self:UpdateBar(self.bars.power, powerType, false)
    if self.hasMana then
        if powerType ~= 0 then self:UpdateBar(self.bars.mana, 0, false)
        else
            local mana = self.bars.mana
            mana.frame:SetMinMaxValues(0, 1)
            mana.frame:SetValue(0)
            mana.value:SetText(""); mana.percent:SetText(""); mana.compact:SetText("")
            mana.background:SetVertexColor(0, 0, 1, 0.25)
        end
    end
    self:UpdateResources()
    if self.class == "EVOKER" then
        local maximum = UnitPowerMax("player", Enum.PowerType.Essence)
        local value = UnitPower("player", Enum.PowerType.Essence)
        if not ns.IsSecret(maximum) then
            for i, pip in ipairs(self.essencePips) do
                if ns.IsSecret(value) then
                    pip:SetShown(i <= maximum)
                    pip:SetAlpha(0.25)
                    self:Notice("essenceValue", "Essence availability is restricted; icons show capacity only.")
                else
                    pip:SetShown(i <= maximum and i <= value)
                    pip:SetAlpha(1)
                end
            end
        else self:Notice("essence", "Essence count is restricted on this client.") end
    end
end

local function experienceData(owner)
    local capped = owner:AtMaxLevel()
    if capped == nil then return end
    if capped then return 1, 1, nil, true end
    local value, maximum = UnitXP("player"), UnitXPMax("player")
    if ns.IsSecret(value) or ns.IsSecret(maximum) then
        owner:Notice("experience", "Restricted player experience: progress and tooltip calculations are paused.")
        return
    end
    if maximum <= 0 then return 1, 1, nil, true end
    local rested = GetXPExhaustion()
    if ns.IsSecret(rested) then
        owner:Notice("restedExperience", "Restricted rested experience: bonus progress and tooltip details are omitted.")
        rested = nil
    end
    return value, maximum, rested, false
end

function Player:ProgressData()
    if self.db.progress == "reputation" then
        local faction = C_Reputation.GetWatchedFactionData()
        if not faction then return 1, 1, 1, ns.L["Select a reputation"], 0.9, 0.7, 0 end
        local value = faction.currentStanding - faction.currentReactionThreshold
        local maximum = faction.nextReactionThreshold - faction.currentReactionThreshold
        local color = FACTION_BAR_COLORS[faction.reaction]
        local r, g, b = color.r, color.g, color.b
        if maximum <= 0 then return 1, 1, 1, faction.name, r, g, b end
        return value, maximum, value, string.format("%d/%d", value, maximum), r, g, b
    end
    local value, maximum, rested, capped = experienceData(self)
    if value == nil then return end
    if capped then return 1, 1, 1, ns.L["Maximum level"], 0, 0.6, 0.6 end
    rested = rested or 0
    local text = string.format("%d%%", floor(value / maximum * 100 + 0.5))
    if rested > 0 then text = text .. string.format(" (+%d%%)", floor(rested / maximum * 100 + 0.5)) end
    return value, maximum, math.min(maximum, value + rested), text, 0, 0.6, 0.6
end

function Player:AtMaxLevel()
    if GameRulesUtil and GameRulesUtil.IsPlayerAtEffectiveMaxLevel then
        local capped = GameRulesUtil.IsPlayerAtEffectiveMaxLevel()
        if not ns.IsSecret(capped) then return capped end
    elseif GetMaxLevelForPlayerExpansion then
        local level, maximum = UnitLevel("player"), GetMaxLevelForPlayerExpansion()
        if not ns.IsSecret(level) and not ns.IsSecret(maximum) then return level >= maximum end
    else
        local maximum = UnitXPMax("player")
        if not ns.IsSecret(maximum) then return maximum <= 0 end
    end
    self:Notice("experienceLevel", "Restricted player level: maximum-level status is unavailable.")
end

function Player:UpdateProgress()
    if self.db.progress == "hidden" then return end
    local value, maximum, rested, text, r, g, b = self:ProgressData()
    local entry = self.bars.progress
    if value == nil then
        entry.frame:SetMinMaxValues(0, 1); entry.frame:SetValue(0)
        entry.rest:SetMinMaxValues(0, 1); entry.rest:SetValue(0)
        entry.percent:SetText(ns.L["N/A"])
        return
    end
    entry.frame:SetMinMaxValues(0, maximum)
    entry.frame:SetValue(value)
    entry.rest:SetMinMaxValues(0, maximum)
    entry.rest:SetValue(rested)
    entry.frame:SetStatusBarColor(r, g, b)
    entry.rest:SetStatusBarColor(r, g, b, 0.5)
    entry.background:SetVertexColor(r, g, b, 0.25)
    entry.percent:SetText(text)
end

function Player:ProgressTooltip(button)
    if GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if self.db.progress == "experience" then
        local value, maximum, rested, capped = experienceData(self)
        if value == nil then GameTooltip:SetText(ns.L["N/A"])
        elseif not capped then
            GameTooltip:SetText(string.format("%d/%d", value, maximum))
            local level = UnitLevel("player")
            if ns.IsSecret(level) then
                self:Notice("experienceTooltipLevel", "Restricted player level: next-level tooltip details are omitted.")
            else
                GameTooltip:AddLine(string.format("%d (%.0f%%) until level %d",
                    maximum - value, (maximum - value) / maximum * 100, level + 1))
            end
            if rested then GameTooltip:AddLine(string.format("Rested experience: %d", rested)) end
        else GameTooltip:SetText(ns.L["Maximum level"]) end
    else
        local faction = C_Reputation.GetWatchedFactionData()
        GameTooltip:SetText(faction and faction.name or ns.L["Select a reputation"])
        local _, _, _, text = self:ProgressData()
        GameTooltip:AddLine(text)
    end
    GameTooltip:Show()
end

function Player:UpdateStatus()
    local name = UnitName("player")
    local group
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local same = UnitIsUnit("raid" .. index, "player")
            if not ns.IsSecret(same) and same then
                local _, _, subgroup = GetRaidRosterInfo(index)
                group = subgroup
                break
            end
        end
    end
    if group and self.db.groupInName and not ns.IsSecret(name) then name = name .. ":" .. group end
    ns.HostName(self, name)
    self.groupText:SetText(group and ns.L["Group"] .. " " .. group or "")
    ns.AfterCombat("PlayerGroup", function() self.groupBox:SetShown(self.db.raidGroup and group ~= nil) end)
    self.level:SetText(UnitLevel("player"))
    local coordinates = CLASS_ICON_TCOORDS[self.class]
    if coordinates then self.classIcon:SetTexCoord(unpack(coordinates)) end
    local combat = UnitAffectingCombat("player")
    local resting = IsResting()
    self.activity:SetShown(combat or resting)
    if combat then self.activity:SetTexCoord(0.5, 1, 0, 0.5)
    else self.activity:SetTexCoord(0, 0.5, 0, 0.5) end
    self.leader:SetShown(UnitIsGroupLeader("player"))
    local _, master = C_PartyInfo.GetLootMethod()
    self.master:SetShown(not ns.IsSecret(master) and master == 0)
    local role = UnitGroupRolesAssigned("player")
    local roleCoordinates
    if not ns.IsSecret(role) then roleCoordinates = ns.RoleCoordinates[role]
    else self:Notice("role", "Role indicator unavailable while role data is restricted.") end
    self.role:SetShown(roleCoordinates ~= nil)
    if roleCoordinates then self.role:SetTexCoord(unpack(roleCoordinates)) end
    local flagged, sanctuary = UnitIsPVP("player"), UnitIsPVPSanctuary("player")
    if ns.IsSecret(flagged) or ns.IsSecret(sanctuary) then
        self:Notice("pvp", "PvP status unavailable while identity data is restricted.")
        flagged = false
    else flagged = flagged and not sanctuary end
    self.pvp:SetShown(self.db.pvpIcon and flagged)
    local faction = UnitFactionGroup("player")
    if flagged then self.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" ..
        (UnitIsPVPFreeForAll("player") and "FFA" or faction or "FFA")) end
    if self.db.className then
        local color = RAID_CLASS_COLORS[self.class]
        if color then self.name:SetTextColor(color.r, color.g, color.b) end
    elseif flagged then self.name:SetTextColor(0, 1, 0)
    else self.name:SetTextColor(0.5, 0.5, 1) end
    self:UpdateThreat()
end

function Player:UpdateThreat()
    local threat = UnitThreatSituation(self.unit or "player")
    if ns.IsSecret(threat) then
        self.threat:Hide()
        if ns.modules.Core.db.threat then self:Notice("threat", "Threat indicator unavailable while threat data is restricted.") end
    else
        self.threat:SetShown(ns.modules.Core.db.threat and threat ~= nil and threat > 0)
    end
end

function Player:UpdatePortrait()
    if not self.db.portrait then return end
    local unit = self.unit or "player"
    if self.db.portrait3D then
        self.model:SetUnit(unit)
        self.model:SetPortraitZoom(1)
    else SetPortraitTexture(self.portrait, unit) end
end

function Player:UpdateAuras()
    local unit, enabled = self.unit or "player", ns.modules.Core.db.colorDebuffs
    if self.borderUnit == unit and self.borderEnabled == enabled then return end
    for _, container in ipairs(self.borderContainers) do
        if self.borderUnit ~= unit then container:SetUnit(unit) end
        container:SetEnabled(enabled)
    end
    self.borderUnit, self.borderEnabled = unit, enabled
end

function Player:UpdateAll()
    if ns.PreviewUnit(self, "Player") then return end
    self:UpdateVitals()
    self:UpdateProgress()
    self:UpdateStatus()
    self:UpdatePortrait()
    self:UpdateAuras()
end

function Player:Feedback(action, descriptor, amount, school)
    if not self.db.combatText then return end
    ns.ShowCombatFeedback(self, action, descriptor, amount, school)
end

function Player:TickManaRule(elapsed)
    if ns.positioning then return end
    self.manaElapsed = (self.manaElapsed or 0) + elapsed
    local remaining = ns.IsForever and self.db.fiveSecondRule and self.manaSpent
        and 5 - math.max(GetTime() - self.manaSpent, self.manaElapsed) or 0
    local ticking = remaining > 0
    if self.ticker:IsShown() ~= ticking then self.ticker:SetShown(ticking) end
    if ticking then
        self.ticker.spark:ClearAllPoints()
        self.ticker.spark:SetPoint("CENTER", self.ticker, "LEFT",
            self.ticker:GetWidth() * (1 - remaining / 5), 0)
    end
end

function Player:Tick(elapsed)
    if ns.positioning then return end
    ns.TickCombatFeedback(self, elapsed)
    if not self.db.pvpTimer then
        if not self.pvpTimerInitialized or self.pvpSeconds then
            self.pvpTimerInitialized, self.pvpSeconds = true, nil
            self.pvpTime:SetText("")
        end
        self.timerElapsed = 0
        return
    end
    self.timerElapsed = (self.timerElapsed or 0) + elapsed
    if self.timerElapsed >= 0.1 then
        self.timerElapsed = 0
        local seconds
        if self.db.pvpTimer and GetPVPTimer then
            local flagged = UnitIsPVP("player")
            if not ns.IsSecret(flagged) and flagged then
                local time = GetPVPTimer()
                if not ns.IsSecret(time) and time > 0 and time < 301000 then
                    seconds = floor(time / 1000)
                end
            end
        elseif self.db.pvpTimer then
            self:Notice("pvpTimer", "PvP timer API unavailable on this client.")
        end
        if not self.pvpTimerInitialized or self.pvpSeconds ~= seconds then
            self.pvpTimerInitialized, self.pvpSeconds = true, seconds
            if seconds then self.pvpTime:SetFormattedText("%d:%02d", floor(seconds / 60), seconds % 60)
            else self.pvpTime:SetText("") end
        end
    end
end

function Player:Start()
    if InCombatLockdown() then ns.AfterCombat("PlayerStart", function() self:Start() end); return end
    if self.frame then return end
    local _, class = UnitClass("player")
    self.class = class
    self.unit = UnitHasVehicleUI("player") and "vehicle" or "player"
    self:Create()
    self:Layout()
    self:UpdateAll()
    local events = CreateFrame("Frame")
    self.events = events
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_UPDATE_RESTING", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION",
        "UPDATE_FACTION", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
        "PARTY_LOOT_METHOD_CHANGED", "PLAYER_FLAGS_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEVEL_UP",
    }) do events:RegisterEvent(event) end
    for _, event in ipairs({
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
        "UNIT_DISPLAYPOWER", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_COMBAT", "UNIT_PORTRAIT_UPDATE",
        "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
    }) do events:RegisterUnitEvent(event, "player", "vehicle") end
    events:SetScript("OnEvent", function(_, event, unit, action, descriptor, amount, school)
        if ns.positioning and (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") then
            self.unit = UnitHasVehicleUI("player") and "vehicle" or "player"
        end
        if ns.PreviewUnit(self, "Player") then return end
        if event == "UNIT_COMBAT" then self:Feedback(action, descriptor, amount, school)
        elseif ns.VitalsEventKinds[event] then self:UpdateVitals(ns.VitalsEventKinds[event])
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then self:UpdatePortrait()
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then self:UpdateThreat()
        elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            ns.ClearCastHost(self)
            self.unit = UnitHasVehicleUI("player") and "vehicle" or "player"
            self:UpdateAll()
            ns.CastHostChanged(self)
        elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" then self:UpdateProgress()
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
            or event == "PLAYER_UPDATE_RESTING" or event == "PARTY_LEADER_CHANGED"
            or event == "PARTY_LOOT_METHOD_CHANGED" or event == "PLAYER_FLAGS_CHANGED"
            or event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" then self:UpdateStatus()
        else
            if InCombatLockdown() then self:UpdateAll() end
            self:Refresh()
        end
    end)
    ns.SetAnimationUpdate(self, self.frame, function(elapsed) self:Tick(elapsed) end, function()
        return not ns.positioning and (self.feedbackAge or self.db.pvpTimer
            or self.pvpSeconds)
    end)
    -- Preserve Blizzard event processing for vehicles and native class-resource widgets.
    self.suppressBlizzard = true
    if PetFrame and not ns.stockPetReplaced then PetFrame:SetIgnoreParentAlpha(true) end
    PlayerFrame:SetAlpha(0)
    PlayerFrame:EnableMouse(false)
end
