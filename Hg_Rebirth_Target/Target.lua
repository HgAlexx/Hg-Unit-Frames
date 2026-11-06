local ns = Hg_Rebirth
local Target = {
    savedVariable = "Hg_Rebirth_Target_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        locked = true, style = "new", compact = true, compactPercent = true,
        shortBars = false, healer = false, manaDeficit = false, scale = 1, opacity = 1,
        classIcon = true, classPanel = true, pvpIcon = true,
        comboPoints = true, nameMeter = false, portrait = false, portrait3D = false,
        combatText = false, classificationPanel = false, numericThreat = true,
        guild = false, eliteGraphic = false, className = true, targetSound = false,
        x = 233.0000457763672, y = -20,
        sticky1ChildY = 1,
        sticky1ChildX = 0,
        sticky1ParentX = 1,
        sticky1Y = 0,
        stickyMove = true,
        sticky1X = -5.155516296293456,
        sticky1Placed = true,
        stickyParent = "Player",
        stickyScale = false,
        sticky1ParentY = 1,
    },
    ranges = {
        tooltipAnchor = { right = true, default = true },
        style = { classic = true, new = true }, scale = { 0.01, 1.49 },
        opacity = { 0, 1 },
        exclusive = { { "numericThreat", "classificationPanel" } },
    },
    buttons = {}, boxes = {},
}
ns.RegisterModule("Target", Target)

function Target:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Target: " .. message)
end

local function box(owner, width, height)
    local frame = ns.Box(owner.frame, width, height)
    owner.boxes[#owner.boxes + 1] = frame
    ns.UnitOverlay(owner, frame, owner.frame, "target")
    return frame
end

local function text(parent, point, relative, relativePoint, x, y, font)
    local label = ns.Label(parent, font or "GameFontNormal")
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetNonSpaceWrap(false)
    return label
end

function Target:Create()
    self.frame = ns.UnitRoot("Hg_Rebirth_TargetFrame", "target", 177)
    self.nameBox = box(self, 177, 24)
    self.nameBox:SetPoint("TOPLEFT")
    self.name = text(self.nameBox, "LEFT", self.nameBox, "LEFT", 7, 0)
    self.name:SetJustifyH("LEFT")
    self.classIcon = ns.Icon(self.nameBox, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
        15, 15, "TOPLEFT", self.nameBox, "TOPLEFT", 5, -4)
    self.pvp = ns.Icon(self.nameBox, nil, 32, 32, "TOPRIGHT", self.nameBox, "TOPRIGHT", 9, -3)
    self.dead = ns.Icon(self.nameBox, "Interface\\TargetingFrame\\TargetDead",
        16, 16, "TOPRIGHT", self.nameBox, "TOPRIGHT", -5, -4)
    self.quest = ns.Icon(self.nameBox, "Interface\\TargetingFrame\\PortraitQuestBadge",
        16, 16, "TOPRIGHT", self.nameBox, "TOPRIGHT", -5, -4)
    self.leader = ns.Icon(self.nameBox, "Interface\\GroupFrame\\UI-Group-LeaderIcon",
        16, 16, "TOP", self.nameBox, "TOP", 0, 7)
    self.master = ns.Icon(self.nameBox, "Interface\\GroupFrame\\UI-Group-MasterLooter",
        16, 16, "TOP", self.nameBox, "TOP", 65, 7)
    self.threat = ns.ThreatIcon(self.nameBox, "RIGHT", -25)
    local markerFrame = CreateFrame("Frame", nil, self.frame)
    markerFrame:SetFrameStrata("MEDIUM")
    self.marker = ns.Icon(markerFrame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        18, 18, "TOP", self.nameBox, "TOP", 45, -10)
    self.levelBox = box(self, 46, 24)
    self.levelBox:SetPoint("TOPLEFT", self.nameBox, "TOPRIGHT", -2, 0)
    self.level = text(self.levelBox, "TOP", self.levelBox, "TOP", 0, -5)
    self.stats = box(self, 221, 42)
    self.stats:SetPoint("TOPLEFT", self.nameBox, "BOTTOMLEFT", 0, 2)
    self.classBox = box(self, 95, 24)
    self.classBox:SetPoint("BOTTOMLEFT", self.nameBox, "TOPLEFT", 0, -2)
    self.classText = text(self.classBox, "TOP", self.classBox, "TOP", 0, -5)
    self.guildBox = box(self, 95, 24)
    self.guildText = text(self.guildBox, "TOP", self.guildBox, "TOP", 0, -5)
    self.classificationBox = box(self, 46, 24)
    self.classificationBox:SetPoint("BOTTOMLEFT", self.levelBox, "TOPLEFT", 0, -2)
    self.classification = text(self.classificationBox, "TOP", self.classificationBox, "TOP", 0, -5)
    self.comboBox = box(self, 25, 30)
    self.combo = text(self.comboBox, "CENTER", self.comboBox, "CENTER", 0, 0, "GameFontNormalLarge")
    self.nameMeter = CreateFrame("StatusBar", nil, self.nameBox)
    self.nameMeter:SetSize(170, 12)
    self.nameMeter:SetPoint("TOPLEFT", 6, -6)
    self.nameMeter:SetFrameLevel(self.nameBox:GetFrameLevel() - 1)
    self.nameMeter:SetStatusBarTexture(ns.TexturePath())
    self.nameMeter:SetStatusBarColor(1, 0, 0)
    self.portraitBox = box(self, 64, 64)
    self.portraitBox:SetPoint("TOPLEFT", self.levelBox, "TOPRIGHT", -2, 0)
    self.portrait = ns.Icon(self.portraitBox, nil, 52, 52, "TOP", self.portraitBox, "TOP", 0, -6)
    self.model = CreateFrame("PlayerModel", nil, self.portraitBox)
    self.model:SetSize(54, 54)
    self.model:SetPoint("CENTER", 1, -1)
    self.model:EnableMouse(false)
    local feedbackFrame = CreateFrame("Frame", nil, self.frame)
    feedbackFrame:SetSize(64, 64)
    feedbackFrame:SetPoint("TOPLEFT", self.portraitBox, "TOPLEFT")
    feedbackFrame:SetFrameStrata("MEDIUM")
    self.feedback = ns.Label(feedbackFrame, "NumberFontNormalHuge")
    self.feedback:SetPoint("CENTER")
    self.feedback:Hide()
    local graphicFrame = CreateFrame("Frame", nil, self.frame)
    graphicFrame:SetFrameStrata("BACKGROUND")
    self.elite = ns.Icon(graphicFrame, nil, 250, 140, "TOPLEFT", self.levelBox, "TOPRIGHT", -210, 19)
    self.health, self.power = ns.UnitBar(self.stats, 200), ns.UnitBar(self.stats, 200)
    for _, entry in ipairs({ self.health, self.power }) do
        entry.right = ns.Label(entry.frame)
        entry.percent = ns.Label(entry.frame)
        entry.percent:SetPoint("RIGHT", 35, 0)
        entry.right:SetTextColor(1, 1, 1)
        entry.percent:SetTextColor(1, 1, 1)
        entry.button = ns.UnitOverlay(self, entry.frame, self.frame, "target")
        entry.button:HookScript("OnEnter", function()
            entry.hover = true
            self:UpdateVitals()
        end)
        entry.button:HookScript("OnLeave", function()
            entry.hover = false
            self:UpdateVitals()
        end)
    end
    self.healthCurve = ns.CreateHealthCurve()
end

function Target:Layout()
    local db, core = self.db, ns.modules.Core.db
    local classic, compact = db.style == "classic", db.style == "new" and db.compact
    local width, barWidth, meterWidth, guildWidth, classWidth
    local upper = db.classificationPanel or db.numericThreat
    if classic then width, barWidth, meterWidth = 221, 200, 170
    elseif not compact then width, barWidth, meterWidth = 270, 150, 189
    else
        width = db.shortBars and 135 or 170
        if db.compactPercent then width = width + 35 end
        barWidth = db.shortBars and 115 or 150
        meterWidth = width - 51
    end
    classWidth = compact and db.shortBars and not db.compactPercent and 91 or 95
    guildWidth = width - (db.classPanel and 93 or 0) - (upper and 3 or 0)
    local stackedGuild = compact and upper and db.classPanel and not db.compactPercent
        or (compact and db.shortBars and not db.compactPercent)
        or (compact and db.shortBars and db.compactPercent and upper and db.classPanel)
    if stackedGuild then
        guildWidth = upper and db.classPanel and (db.shortBars and not db.compactPercent and 135 or 136)
            or (db.classPanel and 91 or width - (upper and 44 or 0))
    end
    if db.guild and upper and not (compact and db.shortBars and not db.compactPercent) then
        guildWidth = guildWidth - 41
    end
    self.frame:SetScale(db.scale + (1 - UIParent:GetEffectiveScale()))
    self.frame:SetAlpha(db.opacity)
    self.frame:SetWidth(width - 44)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    self.nameBox:SetWidth(width - 44)
    self.nameMeter:SetWidth(meterWidth)
    self.stats:SetSize(width, 42)
    self.classBox:SetWidth(classWidth)
    self.classText:SetSize(classWidth - 10, 14)
    self.classBox:SetShown(db.classPanel)
    self.guildBox:SetWidth(guildWidth)
    self.guildBox:ClearAllPoints()
    if stackedGuild and db.classPanel then
        self.guildBox:SetPoint("BOTTOMLEFT", self.classBox, "TOPLEFT", 0, -2)
    elseif db.classPanel then self.guildBox:SetPoint("TOPLEFT", self.classBox, "TOPRIGHT", -2, 0)
    else self.guildBox:SetPoint("BOTTOMLEFT", self.nameBox, "TOPLEFT", 0, -2) end
    self.guildText:SetSize(guildWidth - 13, 14)
    self.guildBox:SetShown(db.guild)
    self.classificationBox:SetShown(upper)
    self.portraitBox:SetShown(db.portrait)
    self.comboBox:ClearAllPoints()
    self.comboBox:SetPoint("TOPLEFT", db.portrait and self.portraitBox or self.stats,
        "TOPRIGHT", -2, db.portrait and -34 or 0)
    self.elite:ClearAllPoints()
    self.elite:SetPoint("TOPLEFT", db.portrait and self.portraitBox or self.levelBox, "TOPRIGHT", -210, 19)
    self.feedback:ClearAllPoints()
    self.feedback:SetPoint("CENTER", self.portraitBox, "CENTER",
        not db.portrait and db.comboPoints and 25 or 0, 0)
    if not db.combatText then self.feedbackAge = nil; self.feedback:Hide() end
    self.health.frame:ClearAllPoints()
    if classic then self.health.frame:SetPoint("TOP", self.stats, "TOP", 0, -10)
    else self.health.frame:SetPoint("TOPLEFT", self.stats, "TOPLEFT", 10, -10) end
    self.power.frame:SetPoint("TOP", self.health.frame, "BOTTOM", 0, -2)
    for _, entry in ipairs({ self.health, self.power }) do
        entry.frame:SetWidth(barWidth)
        entry.frame:SetStatusBarTexture(ns.TexturePath())
        entry.background:SetTexture(core.texturedBackground and ns.TexturePath()
            or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        entry.text:ClearAllPoints(); entry.right:ClearAllPoints()
        entry.text:SetPoint(compact and db.healer and "TOPLEFT" or "TOP",
            compact and db.healer and 5 or 0, 1)
        entry.right:SetPoint("RIGHT", compact and -5 or 100, 0)
    end
    for _, frame in ipairs(self.boxes) do
        frame:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
    end
    ns.UnitVisibility(self.frame, "visibility", "[petbattle] hide; [@target,exists] show; hide")
    ns.CastHostChanged(self)
end

function Target:UpdateVitals(kind)
    if ns.PreviewUnit(self, "Target") then return end
    ns.DetailedVitals(self, "target", "TargetPowerVisibility", false, kind)
end

function Target:UpdateIdentity()
    ns.HostName(self, UnitName("target"))
    local isPlayer = UnitIsPlayer("target")
    local className, token = UnitClass("target")
    local class = not ns.IsSecret(token) and token and RAID_CLASS_COLORS[token]
    local r, g, b
    if self.db.className and not ns.IsSecret(isPlayer) and isPlayer and class then r, g, b = class.r, class.g, class.b
    else r, g, b = ns.UnitNameColor("target") end
    if not r then
        r, g, b = 1, 1, 1
        self:Notice("identity", "Restricted target identity: unavailable indicators are hidden; name coloring is neutral.")
    end
    self.name:SetTextColor(r, g, b)
    local iconToken = self.db.classIcon and ns.ClassIconToken("target", isPlayer, token)
    local coords = iconToken and CLASS_ICON_TCOORDS[iconToken]
    local showIcon = coords ~= nil and coords ~= false
    self.classIcon:SetShown(showIcon)
    if showIcon then self.classIcon:SetTexCoord(unpack(coords)) end
    local pvp, sanctuary = UnitIsPVP("target"), UnitIsPVPSanctuary("target")
    local faction = UnitFactionGroup("target")
    local ffa = UnitIsPVPFreeForAll("target")
    local showPVP = self.db.pvpIcon and not ns.IsSecret(pvp) and not ns.IsSecret(sanctuary)
        and not ns.IsSecret(ffa) and not ns.IsSecret(faction) and pvp and not sanctuary and (ffa or faction ~= nil)
    self.pvp:SetShown(showPVP)
    if showPVP then self.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. (ffa and "FFA" or faction)) end
    ns.LayoutUnitName(self, showIcon, showPVP)
    local creature = UnitCreatureType("target")
    if not ns.IsSecret(creature) and (creature == nil or creature == NOT_SPECIFIED) then creature = ns.L["Creature"] end
    if not ns.IsSecret(isPlayer) and isPlayer then self.classText:SetText(className)
    else self.classText:SetText(creature) end
    local guild
    local visible = UnitIsVisible("target")
    if not ns.IsSecret(isPlayer) and isPlayer and not ns.IsSecret(visible) and visible then
        guild = GetGuildInfo("target")
        if not ns.IsSecret(guild) and guild == nil then guild = ns.L["Unguilded"] end
    else guild = ns.L["N/A"] end
    self.guildText:SetText(guild)
    self:UpdateLevel()
    ns.UpdateRaidMarker(self, self.marker, "target")
    local leader = UnitIsGroupLeader("target")
    self.leader:SetShown(not ns.IsSecret(leader) and leader)
    local quest = UnitIsQuestBoss and UnitIsQuestBoss("target")
    self.quest:SetShown(not ns.IsSecret(quest) and quest == true)
    if ns.IsSecret(leader) or ns.IsSecret(quest)
        or (self.db.pvpIcon and (ns.IsSecret(pvp) or ns.IsSecret(sanctuary)
            or ns.IsSecret(ffa) or ns.IsSecret(faction))) then
        self:Notice("status", "Restricted target status: unavailable indicators are hidden.")
    end
    self.master:Hide()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local method, party, raid = C_PartyInfo.GetLootMethod()
        if not ns.IsSecret(method) and method == "master" and not ns.IsSecret(party) and not ns.IsSecret(raid) then
            local unit = raid and ("raid" .. raid) or (party and (party == 0 and "player" or "party" .. party))
            if unit then
                local same = UnitIsUnit(unit, "target")
                self.master:SetShown(not ns.IsSecret(same) and same)
            end
        end
    end
end

function Target:UpdateLevel()
    local level, classification = UnitLevel("target"), UnitClassification("target")
    self.elite:Hide()
    self.classification:SetText(ns.L["N/A"])
    self.classification:SetTextColor(1, 1, 1)
    if ns.IsSecret(level) then
        self.level:SetFormattedText("%.0f", level)
        self.level:SetTextColor(1, 1, 1)
    else
        local color = GetQuestDifficultyColor(level)
        self.level:SetTextColor(color.r, color.g, color.b)
        if not self.db.numericThreat then self.classification:SetTextColor(color.r, color.g, color.b) end
        local suffix = ""
        if not ns.IsSecret(classification) then
            suffix = ({ rareelite = "r+", elite = "+", rare = "r", minus = "-" })[classification] or ""
        end
        self.level:SetText((level < 0 and "??" or tostring(level)) .. suffix)
        if level < 0 then self.level:SetTextColor(1, 0, 0) end
    end
    if not ns.IsSecret(classification) then
        local label = ({ worldboss = "Boss", rareelite = "Rare Elite", elite = "Elite", rare = "Rare", minus = "Trivial" })[classification]
        self.classification:SetText(ns.L[label or "N/A"])
        if classification == "worldboss" then self.classification:SetTextColor(1, 0, 0) end
        local asset = ({ worldboss = "Elite", elite = "Elite", rareelite = "RareElite", rare = "Rare" })[classification]
        if asset and self.db.eliteGraphic then self.elite:SetTexture(ns.media .. asset .. ".tga"); self.elite:Show() end
    elseif self.db.classificationPanel or self.db.eliteGraphic then
        self:Notice("classification", "Target classification unavailable while restricted.")
    end
end

function Target:UpdateThreat()
    local status = UnitThreatSituation("player", "target")
    self.threat:SetShown(ns.modules.Core.db.threat and not ns.IsSecret(status) and status ~= nil and status > 0)
    if not self.db.numericThreat then return end
    local percent
    if UnitDetailedThreatSituation then
        local _, _, value = UnitDetailedThreatSituation("player", "target")
        percent = value
    else self:Notice("numericThreat", "Numeric threat API unavailable on this client.") end
    if ns.IsSecret(percent) or percent ~= nil then self.classification:SetFormattedText("%.0f", percent)
    else self.classification:SetText(ns.L["N/A"]) end
    if not ns.IsSecret(status) and status then self.classification:SetTextColor(GetThreatStatusColor(status))
    else
        self.classification:SetTextColor(1, 1, 1)
        if ns.IsSecret(status) then self:Notice("threat", "Restricted threat status: numeric threat retains neutral coloring.") end
    end
end

function Target:ResourceData()
    local _, class = UnitClass("player")
    local powerType = class == "EVOKER" and 19 or 4
    local vehicle = UnitHasVehicleUI("player")
    local supported = class == "ROGUE" or class == "DRUID" or class == "EVOKER"
    local value, maximum, assigned
    if not ns.IsSecret(vehicle) and vehicle then
        value, maximum = UnitPower("vehicle", 4), UnitPowerMax("vehicle", 4)
        if ns.IsSecret(maximum) or maximum > 0 then supported, assigned = true, true end
    end
    if not assigned and supported then value, maximum = UnitPower("player", powerType), UnitPowerMax("player", powerType) end
    return supported, value, maximum
end

local function applyResourceVisibility()
    local supported = Target:ResourceData()
    Target.comboBox:SetShown(Target.db.comboPoints and supported)
end

function Target:UpdateResources()
    if ns.positioning then return end
    local supported, value, maximum = self:ResourceData()
    if not InCombatLockdown() or ns.pending.TargetResourceVisibility ~= applyResourceVisibility then
        ns.AfterCombat("TargetResourceVisibility", applyResourceVisibility)
    end
    if not supported then self.combo:SetText(""); self.nameMeter:Hide(); return end
    self.combo:SetFormattedText("%.0f", value)
    local readable = not ns.IsSecret(value) and not ns.IsSecret(maximum)
    local r, g = 1, 1
    if readable then r = maximum > 0 and math.max(0, math.min(1, value / maximum)) or 0; g = 1 - r end
    self.combo:SetTextColor(r, g, readable and 0 or 1)
    self.nameMeter:SetMinMaxValues(0, readable and math.max(1, maximum) or maximum)
    self.nameMeter:SetValue(value)
    self.nameMeter:SetShown(not self.castMeterHidden and self.db.nameMeter and (not readable or value > 0))
end

function Target:UpdatePortrait()
    ns.UpdateUnitPortrait(self, "target")
end

function Target:UpdateAll()
    if ns.PreviewUnit(self, "Target") then return end
    if not self.frame or not UnitExists("target") then return end
    self:UpdateVitals(); self:UpdateIdentity(); self:UpdateThreat()
    self:UpdateResources(); self:UpdatePortrait()
end

function Target:Refresh()
    if not self.frame then return end
    ns.AfterCombat("TargetLayout", function() self:Layout(); self:UpdateAll() end)
end

function Target:ResetPosition()
    if InCombatLockdown() then ns.Warn("Cannot reset Target during combat."); return end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self:Refresh()
end

function Target:PlayTargetSound()
    if not self.db.targetSound then return end
    local sound = SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT
    if UnitExists("target") then
        local enemy, friendly = UnitIsEnemy("target", "player"), UnitIsFriend("player", "target")
        sound = SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT
        if not ns.IsSecret(enemy) and enemy then sound = SOUNDKIT.IG_CREATURE_AGGRO_SELECT
        elseif not ns.IsSecret(friendly) and friendly then sound = SOUNDKIT.IG_CHARACTER_NPC_SELECT end
        if sound == SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT and (ns.IsSecret(enemy) or ns.IsSecret(friendly)) then
            self:Notice("sound", "Restricted target reaction: using neutral target-selection sound.")
        end
    end
    PlaySound(sound, "SFX")
end

function Target:SuppressStock()
    TargetFrame:SetAlpha(0)
    TargetFrame:EnableMouse(false)
    local content = TargetFrame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    if main then
        if main.ManaBar then main.ManaBar:EnableMouse(false) end
        if main.HealthBarsContainer and main.HealthBarsContainer.HealthBar then
            main.HealthBarsContainer.HealthBar:EnableMouse(false)
        end
    end
    for _, child in pairs({ tot = TargetFrame.totFrame or TargetFrameToT,
        cast = TargetFrame.spellbar or TargetFrameSpellBar, power = TargetFrame.powerBarAlt or TargetFramePowerBarAlt }) do
        if child.SetIgnoreParentAlpha then child:SetIgnoreParentAlpha(true) end
    end
    local chain = ns.modules.TargetTarget
    if chain and chain.frame then chain:ApplyStock() end
end

function Target:Start()
    if InCombatLockdown() then ns.AfterCombat("TargetStart", function() self:Start() end); return end
    if self.frame then return end
    self:Create()
    self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "RAID_TARGET_UPDATE",
        "GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED" }) do self.events:RegisterEvent(event) end
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION",
        "UNIT_FLAGS", "UNIT_CONNECTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_PORTRAIT_UPDATE",
        "UNIT_MODEL_CHANGED", "UNIT_COMBAT", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
        self.events:RegisterUnitEvent(event, "target")
    end
    self.resources = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        self.resources:RegisterUnitEvent(event, "player", "vehicle")
    end
    for _, event in ipairs({ "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
        self.resources:RegisterUnitEvent(event, "player")
    end
    self.resources:SetScript("OnEvent", function() self:UpdateResources() end)
    self.events:SetScript("OnEvent", function(_, event, unit, action, descriptor, amount, school)
        if ns.PreviewUnit(self, "Target") then return end
        if event == "UNIT_COMBAT" then
            if self.db.combatText then ns.ShowCombatFeedback(self, action, descriptor, amount, school) end
            return
        end
        if ns.VitalsEventKinds[event] or event == "UNIT_DISPLAYPOWER" then
            self:UpdateVitals(ns.VitalsEventKinds[event])
            return
        end
        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            ns.UpdateUnitPortrait(self, "target")
            return
        end
        if event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
            self:UpdateThreat()
            return
        end
        if event == "PLAYER_TARGET_CHANGED" then
            for index = 1, 2 do
                local entry = index == 1 and self.health or self.power
                entry.hover = false
                entry.text:SetText(""); entry.right:SetText(""); entry.percent:SetText("")
            end
            self.feedbackAge = nil; self.feedback:Hide()
            self:PlayTargetSound()
        end
        self:UpdateAll()
    end)
    self.frame:SetScript("OnShow", function() self:UpdateAll() end)
    ns.SetAnimationUpdate(self, self.frame, function(elapsed)
        ns.TickCombatFeedback(self, elapsed)
    end, function() return not ns.positioning and self.feedbackAge end)
    self:SuppressStock()
    hooksecurefunc(TargetFrame, "SetAlpha", function(_, alpha)
        if ns.IsSecret(alpha) or alpha ~= 0 then ns.AfterCombat("TargetStock", function() self:SuppressStock() end) end
    end)
    TargetFrame:HookScript("OnShow", function() ns.AfterCombat("TargetStock", function() self:SuppressStock() end) end)
end
