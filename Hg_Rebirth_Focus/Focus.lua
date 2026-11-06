local ns = Hg_Rebirth
local Focus = {
    savedVariable = "Hg_Rebirth_Focus_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        locked = true, style = "new", compact = true, compactPercent = true,
        shortBars = false, healer = false, manaDeficit = false, scale = 1, opacity = 1,
        classIcon = true, classPanel = true, pvpIcon = true,
        portrait = false, portrait3D = false, combatText = false, classificationPanel = false,
        className = true, x = 391.6733808509937, y = -656.0859690398753,
        sticky1ChildY = 0,
        sticky1Y = 0,
        stickyMove = false,
        sticky1ChildX = 0,
        sticky1X = 0,
        sticky1Placed = false,
        sticky1ParentX = 0,
        stickyParent = "",
        sticky1ParentY = 0,
        stickyScale = false,
    },
    ranges = {
        tooltipAnchor = { right = true, default = true },
        style = { classic = true, new = true }, scale = { 0.01, 1.49 },
        opacity = { 0, 1 },
    },
    buttons = {}, boxes = {},
}
ns.RegisterModule("Focus", Focus)

function Focus:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Focus: " .. ns.L[message])
end

local function box(owner, width, height)
    local frame = ns.Box(owner.frame, width, height)
    owner.boxes[#owner.boxes + 1] = frame
    ns.UnitOverlay(owner, frame, owner.frame, "focus")
    return frame
end

local function text(parent, point, relative, relativePoint, x, y)
    local label = ns.Label(parent, "GameFontNormal")
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetNonSpaceWrap(false)
    return label
end

function Focus:Create()
    self.frame = ns.UnitRoot("Hg_Rebirth_FocusFrame", "focus", 177)
    self.nameBox = box(self, 177, 24)
    self.nameBox:SetPoint("TOPLEFT")
    self.name = text(self.nameBox, "LEFT", self.nameBox, "LEFT", 7, 0)
    self.name:SetJustifyH("LEFT")
    self.classIcon = ns.Icon(self.nameBox, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
        15, 15, "TOPLEFT", self.nameBox, "TOPLEFT", 5, -4)
    self.pvp = ns.Icon(self.nameBox, nil, 32, 32, "TOPRIGHT", self.nameBox, "TOPRIGHT", 9, -3)
    self.dead = ns.Icon(self.nameBox, "Interface\\TargetingFrame\\TargetDead",
        16, 16, "TOPRIGHT", self.nameBox, "TOPRIGHT", -5, -5)
    self.threat = ns.ThreatIcon(self.nameBox, "RIGHT", -23)
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
    self.classBox:SetPoint("TOPLEFT", self.nameBox, "TOPLEFT", 0, 22)
    self.classText = text(self.classBox, "TOP", self.classBox, "TOP", 0, -5)
    self.classificationBox = box(self, 46, 24)
    self.classificationBox:SetPoint("BOTTOMLEFT", self.levelBox, "TOPLEFT", 0, -2)
    self.classification = text(self.classificationBox, "TOP", self.classificationBox, "TOP", 0, -5)
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
    self.feedback:SetPoint("CENTER", self.portraitBox, "CENTER", 0, 0)
    self.feedback:Hide()
    self.health, self.power = ns.UnitBar(self.stats, 200), ns.UnitBar(self.stats, 200)
    for _, entry in ipairs({ self.health, self.power }) do
        entry.right = ns.Label(entry.frame)
        entry.percent = ns.Label(entry.frame)
        entry.percent:SetPoint("RIGHT", 35, 0)
        entry.right:SetTextColor(1, 1, 1)
        entry.percent:SetTextColor(1, 1, 1)
        entry.button = ns.UnitOverlay(self, entry.frame, self.frame, "focus")
        entry.button:HookScript("OnEnter", function() entry.hover = true; self:UpdateVitals() end)
        entry.button:HookScript("OnLeave", function() entry.hover = false; self:UpdateVitals() end)
    end
    self.healthCurve = ns.CreateHealthCurve()
end

function Focus:Layout()
    local db, core = self.db, ns.modules.Core.db
    local classic, compact = db.style == "classic", db.style == "new" and db.compact
    local nameWidth, width, barWidth = 177, 221, 200
    if not classic then
        nameWidth, width, barWidth = 211, 270, 150
        if compact then
            width = (db.shortBars and 135 or 170) + (db.compactPercent and 35 or 0)
            nameWidth, barWidth = width - 44, db.shortBars and 115 or 150
        end
    end
    local classWidth = compact and db.shortBars and not db.compactPercent and 91 or 95
    self.frame:SetScale(db.scale + (1 - UIParent:GetEffectiveScale()))
    self.frame:SetAlpha(db.opacity)
    self.frame:SetWidth(nameWidth)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    self.nameBox:SetWidth(nameWidth)
    self.stats:SetSize(width, 42)
    self.classBox:SetWidth(classWidth)
    self.classText:SetSize(classWidth - 10, 14)
    self.classBox:SetShown(db.classPanel)
    self.classificationBox:SetShown(db.classificationPanel)
    self.portraitBox:SetShown(db.portrait)
    if not db.combatText then self.feedbackAge = nil; self.feedback:Hide() end
    self.health.frame:ClearAllPoints()
    self.health.frame:SetPoint(classic and "TOP" or "TOPLEFT", self.stats,
        classic and "TOP" or "TOPLEFT", classic and 0 or 10, -10)
    self.power.frame:ClearAllPoints()
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
    ns.UnitVisibility(self.frame, "visibility", "[petbattle] hide; [@focus,exists] show; hide")
    ns.CastHostChanged(self)
end

function Focus:UpdateVitals(kind)
    if ns.PreviewUnit(self, "Focus") then return end
    ns.DetailedVitals(self, "focus", "FocusPowerVisibility", true, kind)
end

function Focus:UpdateIdentity()
    ns.HostName(self, UnitName("focus"))
    local isPlayer = UnitIsPlayer("focus")
    local className, token = UnitClass("focus")
    local class = not ns.IsSecret(token) and token and RAID_CLASS_COLORS[token]
    local r, g, b
    if self.db.className and not ns.IsSecret(isPlayer) and isPlayer and class then r, g, b = class.r, class.g, class.b
    else r, g, b = ns.UnitNameColor("focus") end
    if not r then
        r, g, b = 1, 1, 1
        self:Notice("identity", "Restricted focus identity: unavailable indicators are hidden; name coloring is neutral.")
    end
    self.name:SetTextColor(r, g, b)
    local iconToken = self.db.classIcon and ns.ClassIconToken("focus", isPlayer, token)
    local coords = iconToken and CLASS_ICON_TCOORDS[iconToken]
    local showIcon = coords ~= nil and coords ~= false
    self.classIcon:SetShown(showIcon)
    if showIcon then self.classIcon:SetTexCoord(unpack(coords)) end
    local pvp, ffa, faction = UnitIsPVP("focus"), UnitIsPVPFreeForAll("focus"), UnitFactionGroup("focus")
    local readablePVP = not ns.IsSecret(pvp) and not ns.IsSecret(ffa) and not ns.IsSecret(faction)
    local showPVP = self.db.pvpIcon and readablePVP and (ffa or (pvp and faction ~= nil))
    self.pvp:SetShown(showPVP)
    if showPVP then self.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. (ffa and "FFA" or faction)) end
    -- Original player names reserve PvP space even when the optional icon is not currently flagged.
    local reservePVP = self.db.pvpIcon and ((not ns.IsSecret(isPlayer) and isPlayer)
        or (not ns.IsSecret(pvp) and pvp))
    ns.LayoutUnitName(self, showIcon, reservePVP)
    local creature = UnitCreatureType("focus")
    if not ns.IsSecret(creature) and (creature == nil or creature == NOT_SPECIFIED) then creature = ns.L["Creature"] end
    if ns.IsSecret(isPlayer) then
        self.classText:SetText(ns.L["N/A"])
    elseif isPlayer then self.classText:SetText(className)
    else self.classText:SetText(creature) end
    ns.UpdateRaidMarker(self, self.marker, "focus")
    if ns.IsSecret(isPlayer) or ns.IsSecret(token)
        or (self.db.pvpIcon and not readablePVP) then
        self:Notice("status", "Restricted focus status: unavailable indicators are hidden.")
    end
    self:UpdateLevel()
end

function Focus:UpdateLevel()
    local level, classification = UnitLevel("focus"), UnitClassification("focus")
    self.classification:SetText(ns.L["N/A"])
    self.classification:SetTextColor(1, 1, 1)
    if ns.IsSecret(level) then
        self.level:SetFormattedText("%.0f", level)
        self.level:SetTextColor(1, 1, 1)
    else
        local color = GetQuestDifficultyColor(level)
        self.level:SetTextColor(color.r, color.g, color.b)
        self.classification:SetTextColor(color.r, color.g, color.b)
        local suffix = ""
        if not ns.IsSecret(classification) then
            suffix = ({ rareelite = "r+", elite = "+", rare = "r" })[classification] or ""
        end
        self.level:SetText((level < 0 and "??" or tostring(level)) .. suffix)
        if level < 0 then self.level:SetTextColor(1, 0, 0) end
    end
    if not ns.IsSecret(classification) then
        local label = ({ worldboss = "Boss", rareelite = "Rare Elite", elite = "Elite", rare = "Rare" })[classification]
        self.classification:SetText(ns.L[label or "N/A"])
        if classification == "worldboss" then self.classification:SetTextColor(1, 0, 0) end
    elseif self.db.classificationPanel then
        self:Notice("classification", "Focus classification unavailable while restricted.")
    end
end

function Focus:UpdateThreat()
    local status = UnitThreatSituation("player", "focus")
    self.threat:SetShown(ns.modules.Core.db.threat and not ns.IsSecret(status) and status ~= nil and status > 0)
    if ns.IsSecret(status) and ns.modules.Core.db.threat then
        self:Notice("threat", "Restricted focus threat status: threat indicator is hidden.")
    end
end

function Focus:UpdateAll()
    if ns.PreviewUnit(self, "Focus") then return end
    if not self.frame or not UnitExists("focus") then return end
    self:UpdateVitals(); self:UpdateIdentity(); self:UpdateThreat()
    ns.UpdateUnitPortrait(self, "focus")
end

function Focus:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    ns.AfterCombat("FocusLayout", function() self:Layout(); self:UpdateAll() end)
end

function Focus:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset Focus during combat."]); return end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self:Refresh()
end

function Focus:ClearUnit()
    for index = 1, 2 do
        local entry = index == 1 and self.health or self.power
        entry.hover = false
        entry.text:SetText(""); entry.right:SetText(""); entry.percent:SetText("")
    end
    self.feedbackAge = nil; self.feedback:Hide()
end

function Focus:ApplyStock()
    if InCombatLockdown() then ns.AfterCombat("FocusStock", function() self:ApplyStock() end); return end
    if not self.frame then return end
    local root = FocusFrame
    if not root then
        self:Notice("stock", "Native Focus frame unavailable; waiting for Blizzard UI to load.")
        return
    end
    if not self.stock then
        self.stock = { root = root, frames = {}, children = {} }
        root:HookScript("OnShow", function()
            if self.stockOwned then ns.AfterCombat("FocusStock", function() self:ApplyStock() end) end
        end)
        hooksecurefunc(root, "SetAlpha", function(_, alpha)
            if self.applyingStock or not self.stockOwned then return end
            self.stock.alpha = alpha
            ns.AfterCombat("FocusStock", function() self:ApplyStock() end)
        end)
    end
    local stock = self.stock
    local content = root.TargetFrameContent or root.FocusFrameContent
    local main = content and (content.TargetFrameContentMain or content.FocusFrameContentMain)
    for _, frame in pairs({ root = root, power = main and main.ManaBar or FocusFrameManaBar,
        health = main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar or FocusFrameHealthBar }) do
        if not stock.frames[frame] then
            local data = { mouse = frame:IsMouseEnabled() }
            stock.frames[frame] = data
            hooksecurefunc(frame, "EnableMouse", function(_, enabled)
                if self.applyingStock or not self.stockOwned then return end
                data.mouse = enabled
                ns.AfterCombat("FocusStock", function() self:ApplyStock() end)
            end)
        end
    end
    for _, child in pairs({ tot = root.totFrame or FocusFrameToT, cast = root.spellbar or FocusFrameSpellBar,
        power = root.powerBarAlt or FocusFramePowerBarAlt }) do
        if stock.children[child] == nil then stock.children[child] = child:IsIgnoringParentAlpha() end
    end
    if not self.stockOwned then
        stock.alpha = root:GetAlpha()
        for frame, data in pairs(stock.frames) do data.mouse = frame:IsMouseEnabled() end
        for child in pairs(stock.children) do stock.children[child] = child:IsIgnoringParentAlpha() end
    end
    self.stockOwned, self.applyingStock = true, true
    root:SetAlpha(0)
    for frame in pairs(stock.frames) do frame:EnableMouse(false) end
    for child in pairs(stock.children) do child:SetIgnoreParentAlpha(true) end
    self.applyingStock = false
end

function Focus:RestoreStock()
    if InCombatLockdown() then ns.AfterCombat("FocusStock", function() self:RestoreStock() end); return end
    if not self.stockOwned then return end
    self.stockOwned, self.applyingStock = false, true
    local stock = self.stock
    stock.root:SetAlpha(stock.alpha)
    for frame, data in pairs(stock.frames) do frame:EnableMouse(data.mouse) end
    for child, ignore in pairs(stock.children) do child:SetIgnoreParentAlpha(ignore) end
    self.applyingStock = false
end

function Focus:Start()
    if InCombatLockdown() then ns.AfterCombat("FocusStart", function() self:Start() end); return end
    if self.frame then return end
    self:Create(); self:Layout(); self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "RAID_TARGET_UPDATE",
        "GROUP_ROSTER_UPDATE", "ADDON_LOADED" }) do self.events:RegisterEvent(event) end
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION",
        "UNIT_FLAGS", "UNIT_CONNECTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_PORTRAIT_UPDATE",
        "UNIT_MODEL_CHANGED", "UNIT_COMBAT", "UNIT_AURA", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
        self.events:RegisterUnitEvent(event, "focus")
    end
    self.events:SetScript("OnEvent", function(_, event, unit, action, descriptor, amount, school)
        if ns.PreviewUnit(self, "Focus") then return end
        if event == "ADDON_LOADED" then self:ApplyStock(); return end
        if event == "UNIT_COMBAT" then
            if self.db.combatText then ns.ShowCombatFeedback(self, action, descriptor, amount, school) end
            return
        end
        if ns.VitalsEventKinds[event] or event == "UNIT_DISPLAYPOWER" or event == "UNIT_AURA" then
            self:UpdateVitals(ns.VitalsEventKinds[event])
            return
        end
        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            ns.UpdateUnitPortrait(self, "focus")
            return
        end
        if event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
            self:UpdateThreat()
            return
        end
        if event == "PLAYER_FOCUS_CHANGED" then self:ClearUnit() end
        if event == "PLAYER_ENTERING_WORLD" then self:ApplyStock() end
        self:UpdateAll()
    end)
    self.frame:SetScript("OnShow", function() self:UpdateAll() end)
    ns.SetAnimationUpdate(self, self.frame, function(elapsed)
        ns.TickCombatFeedback(self, elapsed)
    end, function() return not ns.positioning and self.feedbackAge end)
    self:ApplyStock()
end
