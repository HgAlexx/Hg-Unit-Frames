local ns = Hg_Rebirth
local Chain = {
    savedVariable = "Hg_Rebirth_Target_Target_Options",
    defaults = {
        showTooltip = true, tooltipAnchor = "default",
        locked = true, scale = 1, opacity = 1, showTarget = true, showTargetTarget = false,
        showPower = true, className = true, numericHealth = false,
        buffs = false, debuffs = false, targetBuffs = false, targetDebuffs = false,
        castableBuffs = false, curableDebuffs = false, ownDebuffs = false,
        warningMode = "off", warningSize = "small", warningSound = false, warningSoundKit = "9373",
        warningSolo = true, warningGroup = true, warningRaid = true,
        auraSpacingHorizontal = 1, auraSpacingVertical = 1,
        groupSpacingVertical = 1,
        x = 435.9999389648467, y = -20, targetX = 543.9999999999992, targetY = -20,
        sticky1ChildX = 0,
        stickyParent = "Target",
        sticky1ParentY = 0,
        stickyScale = false,
        targetScale = 1,
        stickyMove = true,
        targetSticky1ChildY = 0,
        targetStickyScale = false,
        sticky1Placed = true,
        targetSticky1ChildX = 0,
        targetSticky1ParentY = 0,
        targetSticky1Placed = true,
        targetSticky1ParentX = 1,
        sticky1X = -2.577856482566517,
        sticky1Y = 0,
        sticky1ChildY = 0,
        sticky1ParentX = 1,
        targetSticky1X = -2.577699147494855,
        targetStickyMove = true,
        targetStickyParent = "TargetTarget",
        targetSticky1Y = 0,
    },
    ranges = {
        tooltipAnchor = { right = true, default = true },
        scale = { 0.01, 1.49 }, opacity = { 0, 1 },
        auraSpacingHorizontal = { -10, 30 }, auraSpacingVertical = { -10, 30 },
        groupSpacingVertical = { 0, 100 },
        warningMode = { off = true, dps = true, tank = true, healer = true },
        warningSize = { small = true, large = true, hidden = true },
        warningSoundKit = { ["9372"] = true, ["9373"] = true, ["9374"] = true,
            ["9375"] = true, ["9378"] = true, ["9379"] = true },
    },
    buttons = {},
}
ns.RegisterModule("TargetTarget", Chain)

function Chain:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Target Target: " .. ns.L[message])
end

function Chain:Exists(unit)
    local exists = UnitExists(unit)
    if ns.IsSecret(exists) then
        self:Notice("existence", "Restricted chained-unit existence: secure visibility remains active; unavailable updates are paused.")
        return nil
    end
    return exists
end

local function overlay(owner, parent, entry)
    return ns.UnitOverlay(owner, parent, entry.frame, entry.unit, entry.xKey, entry.yKey)
end

function Chain:CreateUnit(name, unit, enabledKey, xKey, yKey, buffsKey, debuffsKey)
    local entry = {
        unit = unit, enabledKey = enabledKey, xKey = xKey, yKey = yKey,
        buffsKey = buffsKey, debuffsKey = debuffsKey, borders = {},
    }
    entry.frame = ns.UnitRoot(name, unit, 110)
    entry.nameBox = ns.Box(entry.frame, 110, 24)
    entry.nameBox:SetPoint("TOPLEFT")
    entry.nameButton = overlay(self, entry.nameBox, entry)
    entry.name = ns.Label(entry.nameBox, "GameFontNormal")
    entry.name:SetPoint("LEFT", 8, 0)
    entry.name:SetSize(97, 14)
    entry.name:SetJustifyH("LEFT")
    entry.name:SetNonSpaceWrap(false)
    entry.stats = ns.Box(entry.frame, 110, 42)
    entry.stats:SetPoint("TOPLEFT", entry.nameBox, "BOTTOMLEFT", 0, 2)
    entry.statsButton = overlay(self, entry.stats, entry)
    local markerFrame = CreateFrame("Frame", nil, entry.frame)
    markerFrame:SetFrameStrata("MEDIUM")
    entry.marker = ns.Icon(markerFrame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        18, 18, "CENTER", entry.nameBox, "TOPRIGHT", -10, -10)
    entry.health, entry.power = ns.UnitBar(entry.stats, 90), ns.UnitBar(entry.stats, 90)
    entry.health.frame:SetPoint("TOP", entry.stats, "TOP", 0, -10)
    entry.power.frame:SetPoint("TOP", entry.health.frame, "BOTTOM", 0, -2)
    entry.power.text:ClearAllPoints()
    entry.power.text:SetPoint("TOP", 0, 0)
    for _, bar in ipairs({ entry.health, entry.power }) do
        bar.button = overlay(self, bar.frame, entry)
        bar.button:HookScript("OnEnter", function() bar.hover = true; self:UpdateUnit(entry) end)
        bar.button:HookScript("OnLeave", function() bar.hover = false; self:UpdateUnit(entry) end)
    end
    ns.CreateChainedAuras(entry)
    for _, parent in ipairs({ entry.nameBox, entry.stats }) do
        entry.borders[#entry.borders + 1] = ns.AuraBorder(parent, unit)
    end
    entry.buffWrapper, entry.debuffWrapper = entry.buffs.wrapper, entry.debuffs.wrapper
    entry.frame:SetScript("OnShow", function() self:UpdateUnit(entry) end)
    -- Chained units do not reliably receive vitals events under their exact token.
    local vitalsElapsed = 0
    entry.frame:SetScript("OnUpdate", function(_, elapsed)
        if ns.positioning or not entry.enabled then vitalsElapsed = 0; return end
        vitalsElapsed = vitalsElapsed + elapsed
        if vitalsElapsed < 0.2 then return end
        vitalsElapsed = 0
        self:UpdateUnit(entry, "vitals")
    end)
    return entry
end

function Chain:Create()
    self.tot = self:CreateUnit("Hg_Rebirth_TargetTargetFrame", "targettarget",
        "showTarget", "x", "y", "buffs", "debuffs")
    self.target = self:CreateUnit("Hg_Rebirth_TargetTargetTargetFrame", "targettargettarget",
        "showTargetTarget", "targetX", "targetY", "targetBuffs", "targetDebuffs")
    self.frame = self.tot.frame
    self.units = { self.tot, self.target }
    self.healthCurve = ns.CreateHealthCurve()
    self.smallWarning = CreateFrame("MessageFrame", nil, UIParent)
    self.smallWarning:SetSize(512, 60)
    self.smallWarning:SetPoint("TOP", 0, -142)
    self.smallWarning:SetFrameStrata("DIALOG")
    self.smallWarning:SetFontObject(ErrorFont)
    self.smallWarning:SetJustifyH("CENTER")
    self.smallWarning:SetInsertMode("TOP")
    self.smallWarning:SetTimeVisible(5)
    self.largeWarning = CreateFrame("Frame", nil, UIParent)
    self.largeWarning:SetSize(800, 128)
    self.largeWarning:SetPoint("CENTER", 0, 284)
    self.largeText = ns.Label(self.largeWarning, "ZoneTextFont")
    self.largeText:SetAllPoints()
    self.largeText:SetTextHeight(30)
    self.largeText:SetTextColor(1, 0.2, 0)
    self.largeWarning:Hide()
end

function Chain:ClearWarnings()
    self.warningActive = nil
    self.warningAge = nil
    self.largeWarning:Hide()
    self.smallWarning:Clear()
    ns.RefreshAnimation(self)
end

function Chain:Layout()
    local db, core = self.db, ns.modules.Core.db
    for _, entry in ipairs(self.units) do
        entry.enabled, entry.powerVisible = db[entry.enabledKey], db.showPower
        entry.frame:SetScale((entry == self.target and db.targetScale or db.scale) + (1 - UIParent:GetEffectiveScale()))
        entry.frame:SetAlpha(db.opacity)
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[entry.xKey], db[entry.yKey])
        ns.UnitVisibility(entry.frame, "visibility", db[entry.enabledKey]
            and ("[petbattle] hide; [@" .. entry.unit .. ",exists] show; hide") or "hide")
        entry.stats:SetHeight(not db.showPower and 30 or 42)
        entry.power.frame:SetShown(db.showPower)
        entry.power.button:SetShown(db.showPower)
        if not db.showPower then
            entry.power.hover = false
        end
        for _, parent in ipairs({ entry.nameBox, entry.stats }) do
            parent:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
        end
        for _, bar in ipairs({ entry.health, entry.power }) do
            bar.frame:SetStatusBarTexture(ns.TexturePath())
            bar.background:SetTexture(core.texturedBackground and ns.TexturePath()
                or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        end
        self:LayoutAuras(entry)
    end
    self:ApplyStock()
end

function Chain:AuraReaction(entry)
    local friendly = UnitIsFriend("player", entry.unit)
    if ns.IsSecret(friendly) then
        self:Notice("auraReaction", "Restricted chained-unit reaction: using unfiltered hostile-order auras.")
        return false, true
    end
    return friendly == true, false
end

function Chain:UpdateAuraFilters(entry)
    local friendly, restricted = self:AuraReaction(entry)
    local buffFilter = self.db.castableBuffs and "HELPFUL|RAID" or "HELPFUL"
    local debuffFilter = "HARMFUL"
    if friendly and self.db.curableDebuffs then debuffFilter = "HARMFUL|RAID"
    elseif not friendly and not restricted and self.db.ownDebuffs then debuffFilter = "HARMFUL|PLAYER" end
    for index = 1, 2 do
        local group = index == 1 and entry.buffs or entry.debuffs
        local filter = index == 1 and buffFilter or debuffFilter
        if group.filter ~= filter then
            group.container:SetAuraGroupFilterString("icons", filter)
            group.filter = filter
        end
        local enabled = self.db[entry.enabledKey] and self.db[index == 1 and entry.buffsKey or entry.debuffsKey]
        if group.enabled ~= enabled then group.container:SetEnabled(enabled); group.enabled = enabled end
    end
    local borderEnabled = self.db[entry.enabledKey] and self.db[entry.debuffsKey]
        and ns.modules.Core.db.colorDebuffs and friendly
    if entry.borderEnabled ~= borderEnabled then
        for _, container in ipairs(entry.borders) do container:SetEnabled(borderEnabled) end
        entry.borderEnabled = borderEnabled
    end
    if entry.friendly ~= friendly then
        entry.friendly = friendly
        ns.AfterCombat("TargetTargetAura" .. entry.unit, function() self:LayoutAuras(entry) end)
    end
end

function Chain:LayoutAuras(entry)
    local friendly = self:AuraReaction(entry)
    ns.LayoutChainedAuras(entry, friendly, self.db[entry.buffsKey], self.db[entry.debuffsKey],
        self.db.auraSpacingHorizontal, self.db.auraSpacingVertical, self.db.groupSpacingVertical)
end

function Chain:ResetTransient(entry)
    if entry.cleared then return end
    entry.cleared = true
    for index = 1, 2 do
        local bar = index == 1 and entry.health or entry.power
        bar.hover = false
        bar.text:SetText("")
    end
    entry.marker:Hide()
    entry.name:SetText("")
end

function Chain:UpdateUnit(entry, kind)
    if ns.PreviewUnit(entry, entry == self.tot and "Target Target" or "Target Target Target", self.db) then return end
    if not entry.enabled then
        if entry.active then self:ResetTransient(entry); entry.guid = nil end
        entry.active = false
        return
    end
    if not entry.active then self:ResetTransient(entry); entry.guid = nil; entry.active = true end
    local exists = self:Exists(entry.unit)
    if not exists then self:ResetTransient(entry); entry.guid = nil; return end
    local guid = UnitGUID(entry.unit)
    if ns.IsSecret(guid) then
        entry.guid = nil
        if not kind then
            for index = 1, 2 do
                local group = index == 1 and entry.buffs or entry.debuffs
                if group.enabled then group.container:UpdateAllAuras() end
            end
        end
    elseif entry.guid ~= guid then
        self:ResetTransient(entry)
        entry.guid = guid; kind = nil
        entry.buffs.container:UpdateAllAuras()
        entry.debuffs.container:UpdateAllAuras()
    end
    entry.cleared = false
    if not kind then
        entry.name:SetText(UnitName(entry.unit))
        local r, g, b = ns.UnitNameColor(entry.unit)
        if self.db.className then
            local player = UnitIsPlayer(entry.unit)
            local _, class = UnitClass(entry.unit)
            if ns.IsSecret(player) or (not ns.IsSecret(player) and player and ns.IsSecret(class)) then
                self:Notice("className", "Restricted chained-unit class: using readable reaction colors or neutral name coloring.")
            end
            if not ns.IsSecret(player) and player and not ns.IsSecret(class) then
                local color = class and RAID_CLASS_COLORS[class]
                if color then r, g, b = color.r, color.g, color.b end
            end
        end
        if not r then
            r, g, b = 1, 1, 1
            self:Notice("identity", "Restricted chained-unit identity: name coloring is neutral.")
        end
        entry.name:SetTextColor(r, g, b)
    end
    local powerType = UnitPowerType(entry.unit)
    local dead, ghost = UnitIsDead(entry.unit), UnitIsGhost(entry.unit)
    local isDead = not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost)
    if kind ~= "power" then
        local value, maximum, _, percent = ns.UpdateUnitBar(self, entry.health, entry.unit, powerType, true)
        if isDead then
            value, percent = 0, 0
            if ns.modules.Core.db.invertBars then entry.health.frame:SetValue(maximum)
            else entry.health.frame:SetValue(0) end
        end
        if entry.health.hover or (self.db.numericHealth and not ns.IsSecret(maximum) and maximum ~= 100) then
            entry.health.text:SetFormattedText("%.0f/%.0f", value, maximum)
        elseif ns.IsSecret(percent) or percent ~= nil then entry.health.text:SetFormattedText("%.0f%%", percent)
        else entry.health.text:SetText("") end
    end
    if entry.powerVisible and kind ~= "health" then
        local power, powerMaximum = ns.UpdateUnitBar(self, entry.power, entry.unit, powerType, false)
        if isDead then
            power = 0
            if ns.modules.Core.db.invertBars then entry.power.frame:SetValue(powerMaximum)
            else entry.power.frame:SetValue(0) end
        end
        entry.power.text:SetShown(entry.power.hover == true)
        if entry.power.hover then
            if not ns.IsSecret(powerType) and (powerType == 1 or powerType == 2 or powerType == 6) then
                entry.power.text:SetFormattedText("%.0f", power)
            else entry.power.text:SetFormattedText("%.0f/%.0f", power, powerMaximum) end
        end
        if not ns.IsSecret(powerMaximum) and powerMaximum == 0 then
            entry.power.frame:SetStatusBarColor(0, 0, 0)
            entry.power.background:SetVertexColor(0, 0, 0, 0.25)
        end
    end
    if kind then return end
    ns.UpdateRaidMarker(self, entry.marker, entry.unit)
    if ns.IsSecret(dead) or ns.IsSecret(ghost) then
        self:Notice("status", "Restricted chained-unit status: unavailable indicators are hidden.")
    end
end

function Chain:WarningsEnabled()
    if IsInRaid() then return self.db.warningRaid end
    if IsInGroup() then return self.db.warningGroup end
    return self.db.warningSolo
end

function Chain:UpdateWarningOptions()
    local db, old = self.db, self.warningOptions
    local contextEnabled = self:WarningsEnabled()
    if old and old.mode == db.warningMode and old.size == db.warningSize
        and old.sound == db.warningSound and old.enabled == db.showTarget
        and old.contextEnabled == contextEnabled then return end
    if old then self:ClearWarnings() end
    self.warningOptions = { mode = db.warningMode, size = db.warningSize, sound = db.warningSound,
        enabled = db.showTarget, contextEnabled = contextEnabled }
end

function Chain:PlayWarningSound()
    local played = PlaySound(tonumber(self.db.warningSoundKit), "SFX")
    if not played then self:Notice("sound", "Target-chain warning sound is unavailable on this client.") end
end

function Chain:WarningCondition()
    if self.db.warningMode == "off" or not self.db.showTarget or not self:WarningsEnabled() then return end
    if not self:Exists("target") or not self:Exists("targettarget") then return end
    local fighting = UnitAffectingCombat("target")
    if ns.IsSecret(fighting) then return nil, "restricted" end
    if not fighting then return end
    local dead, corpse = UnitIsDead("targettarget"), UnitIsCorpse("targettarget")
    if ns.IsSecret(dead) or ns.IsSecret(corpse) then return nil, "restricted" end
    if dead or corpse then return end
    if self.db.warningMode == "healer" then
        local player, friendly = UnitIsPlayer("target"), UnitIsFriend("player", "target")
        if ns.IsSecret(player) or ns.IsSecret(friendly) then return nil, "restricted" end
        if player and friendly then
            if not self:Exists("targettargettarget") then return end
            local reciprocal = UnitIsUnit("target", "targettargettarget")
            if ns.IsSecret(reciprocal) then return nil, "restricted" end
            if reciprocal then return "tanking", false end
            return
        end
    else
        local friendly = UnitIsFriend("player", "target")
        if ns.IsSecret(friendly) then return nil, "restricted" end
        if friendly then return end
    end
    local same = UnitIsUnit("targettarget", "player")
    if ns.IsSecret(same) then return nil, "restricted" end
    if self.db.warningMode == "tank" then
        if not same then return "lost", true end
    elseif same then return "you", true end
end

function Chain:UpdateWarnings()
    local condition, sound = self:WarningCondition()
    if sound == "restricted" then
        self.warningActive = nil
        self:Notice("warnings", "Restricted warning inputs: unavailable target-chain warnings are suppressed.")
        return
    end
    if not condition then self.warningActive = nil; return end
    if self.warningActive == condition then return end
    local mode, size = self.db.warningMode, self.db.warningSize
    local message
    if mode ~= "off" and size ~= "hidden" then
        local target, victim
        if condition ~= "lost" then target = UnitName("target") end
        if condition ~= "you" then victim = UnitName("targettarget") end
        if ns.IsSecret(target) or ns.IsSecret(victim) then
            self:Notice("warnings", "Restricted warning inputs: unavailable target-chain warnings are suppressed.")
            return
        end
        if (condition ~= "lost" and not target) or (condition ~= "you" and not victim) then
            self:Notice("warningName", "Target-chain warning names are unavailable; that warning is suppressed.")
            return
        end
        if condition == "tanking" and size == "large" then
            local playerTarget, selfTarget = UnitIsUnit("player", "target"), UnitIsUnit("target", "targettarget")
            if ns.IsSecret(playerTarget) or ns.IsSecret(selfTarget) then
                self:Notice("warnings", "Restricted warning inputs: unavailable target-chain warnings are suppressed.")
                return
            end
            if playerTarget or selfTarget then self.warningActive = condition; return end
        end
        local format = condition == "lost" and "You have lost aggro to %s!"
            or (condition == "tanking" and "%s is now tanking %s" or "%s changed target to you!")
        if condition == "lost" then message = string.format(ns.L[format], victim)
        elseif condition == "tanking" then message = string.format(ns.L[format], target, victim)
        else message = string.format(ns.L[format], target) end
    end
    self.warningActive = condition
    if message then
        if size == "large" then
            self.largeText:SetText(message)
            self.warningAge = 0
            self.largeWarning:SetAlpha(0)
            self.largeWarning:Show()
            ns.RefreshAnimation(self)
        else self.smallWarning:AddMessage(message, 1, 0, 0) end
    end
    if sound and self.db.warningSound then
        self:PlayWarningSound()
    end
end

function Chain:Tick(elapsed)
    if ns.positioning then return end
    if self.warningAge then
        self.warningAge = self.warningAge + elapsed
        local age = self.warningAge
        if age < 0.2 then self.largeWarning:SetAlpha(age / 0.2)
        elseif age < 2.7 then self.largeWarning:SetAlpha(1)
        elseif age < 4.7 then self.largeWarning:SetAlpha(1 - (age - 2.7) / 2)
        else self.warningAge = nil; self.largeWarning:Hide() end
    end
end

function Chain:UpdateAll()
    if ns.positioning then
        self:ClearWarnings()
        if not self.warningPreview then
            self.warningPreview = CreateFrame("Frame", nil, UIParent)
            self.warningPreview:SetFrameStrata("DIALOG")
            self.warningPreview:EnableMouse(false)
            self.warningPreview.text = ns.Label(self.warningPreview, "ErrorFont")
            self.warningPreview.text:SetAllPoints()
            self.warningPreview.text:SetTextColor(1, 0.2, 0)
        end
        self.warningPreview:SetShown(self.db.showTarget and self.db.warningMode ~= "off"
            and self.db.warningSize ~= "hidden")
        self.warningPreview:ClearAllPoints()
        local large = self.db.warningSize == "large"
        self.warningPreview:SetSize(large and 800 or 512, large and 128 or 60)
        self.warningPreview:SetPoint(large and "CENTER" or "TOP", UIParent,
            large and "CENTER" or "TOP", 0, large and 284 or -142)
        self.warningPreview.text:SetFontObject(large and "ZoneTextFont" or "ErrorFont")
        local warningLabel = ({ dps = "DPS", tank = "Tank", healer = "Healer", off = "Off" })[self.db.warningMode]
        self.warningPreview.text:SetText(ns.L["Target Target"] .. " - " .. ns.L[warningLabel])
        for _, entry in ipairs(self.units) do self:UpdateUnit(entry) end
        return
    end
    if self.warningPreview then self.warningPreview:Hide() end
    self:UpdateWarningOptions()
    for _, entry in ipairs(self.units) do
        self:UpdateUnit(entry)
        self:UpdateAuraFilters(entry)
    end
    self:UpdateWarnings()
end

function Chain:ApplyStock()
    if InCombatLockdown() then ns.AfterCombat("TargetTargetStock", function() self:ApplyStock() end); return end
    local stock = TargetFrame and (TargetFrame.totFrame or TargetFrameToT)
    if not stock then self:Notice("stock", "Native target-of-target frame unavailable; no stock display was changed."); return end
    if self.db.showTarget and not self.stock then
        self.stock = { root = stock, frames = {} }
        for _, frame in pairs({ root = stock, health = stock.HealthBar, power = stock.ManaBar }) do
            local data = { frame = frame, mouse = frame:IsMouseEnabled() }
            if frame == stock then data.alpha = frame:GetAlpha() end
            self.stock.frames[#self.stock.frames + 1] = data
            hooksecurefunc(frame, "EnableMouse", function(_, enabled)
                if self.applyingStock or not self.stockOwned then return end
                data.mouse = enabled
                ns.AfterCombat("TargetTargetStock", function() self:ApplyStock() end)
            end)
            if frame == stock then
                hooksecurefunc(frame, "SetAlpha", function(_, alpha)
                    if self.applyingStock or not self.stockOwned then return end
                    data.alpha = alpha
                    ns.AfterCombat("TargetTargetStock", function() self:ApplyStock() end)
                end)
                frame:HookScript("OnShow", function()
                    if self.stockOwned then ns.AfterCombat("TargetTargetStock", function() self:ApplyStock() end) end
                end)
            end
        end
    end
    if not self.stock then return end
    self.applyingStock = true
    if self.db.showTarget then
        if not self.stockOwned then
            for _, data in ipairs(self.stock.frames) do
                data.mouse = data.frame:IsMouseEnabled()
                if data.frame == stock then data.alpha = stock:GetAlpha() end
            end
        end
        self.stockOwned = true
        stock:SetAlpha(0)
        for _, data in ipairs(self.stock.frames) do data.frame:EnableMouse(false) end
    elseif self.stockOwned then
        self.stockOwned = false
        for _, data in ipairs(self.stock.frames) do
            data.frame:EnableMouse(data.mouse)
            if data.frame == self.stock.root then data.frame:SetAlpha(data.alpha) end
        end
    end
    self.applyingStock = false
end

function Chain:Refresh()
    if not self.frame then return end
    self:UpdateAll()
    ns.AfterCombat("TargetTargetLayout", function() self:Layout(); self:UpdateAll() end)
end

function Chain:ResetPosition()
    if InCombatLockdown() then ns.Warn(ns.L["Cannot reset target-chain frames during combat."]); return false end
    self.db.x, self.db.y = self.defaults.x, self.defaults.y
    self.db.targetX, self.db.targetY = self.defaults.targetX, self.defaults.targetY
    self:Refresh()
    return true
end

function Chain:Align(above)
    if InCombatLockdown() then ns.Warn(ns.L["Cannot align target-chain frames during combat."]); return false end
    local target = ns.modules.Target
    if not target or not target.frame then
        ns.Warn(ns.L["Target must be enabled and initialized to align target-chain frames."])
        return false
    end
    local own = self.frame:GetEffectiveScale()
    local relative, x, y
    if above then
        relative = target.nameBox
        local upper = target.db.classPanel or target.db.classificationPanel or target.db.numericThreat or target.db.guild
        x = relative:GetLeft()
        y = relative:GetTop() + (upper and 84 or 62)
    else
        local hasResource = target:ResourceData()
        relative = target.db.comboPoints and hasResource and target.comboBox
            or (target.db.portrait and target.portraitBox or target.levelBox)
        x, y = relative:GetRight() - 2, target.nameBox:GetTop()
    end
    local ratio = relative:GetEffectiveScale() / own
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
    ns.SavePosition(self, self.frame, "x", "y")
    local nextFrame = self.target.frame
    ratio = own / nextFrame:GetEffectiveScale()
    nextFrame:ClearAllPoints()
    nextFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        (self.frame:GetRight() + (above and 1 or -2)) * ratio, self.frame:GetTop() * ratio)
    ns.SavePosition(self, nextFrame, "targetX", "targetY")
    return true
end

function Chain:Start()
    if InCombatLockdown() then ns.AfterCombat("TargetTargetStart", function() self:Start() end); return end
    if self.frame then return end
    if not ns.HasAuraAPI() then
        self.unavailable = true
        self:Notice("auraAPI", "Required Mainline aura API unavailable; native target-of-target retained.")
        return
    end
    self:Create()
    self:Layout()
    self:UpdateAll()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
        "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE" }) do self.events:RegisterEvent(event) end
    self.events:RegisterUnitEvent("UNIT_TARGET", "target", "targettarget")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
        "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_CONNECTION" }) do
        self.events:RegisterUnitEvent(event, "targettarget", "targettargettarget")
    end
    self.events:SetScript("OnEvent", function(_, event, unit)
        if ns.positioning then self:UpdateAll(); return end
        local kind = ns.VitalsEventKinds[event]
        if kind then
            for _, entry in ipairs(self.units) do
                if entry.unit == unit then self:UpdateUnit(entry, kind) end
            end
            if kind == "health" then self:UpdateWarnings() end
            return
        end
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
            self:ClearWarnings()
            for _, entry in ipairs(self.units) do self:ResetTransient(entry); entry.guid = nil end
        end
        if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_TARGET" or event == "PLAYER_ENTERING_WORLD" then
            for _, entry in ipairs(self.units) do
                for _, group in ipairs({ entry.buffs, entry.debuffs }) do group.container:UpdateAllAuras() end
                for _, container in ipairs(entry.borders) do container:UpdateAllAuras() end
            end
        end
        self:UpdateAll()
    end)
    ns.SetAnimationUpdate(self, self.events, function(elapsed) self:Tick(elapsed) end,
        function() return not ns.positioning and self.warningAge end)
end
