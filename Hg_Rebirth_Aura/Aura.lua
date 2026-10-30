local ns = Hg_Rebirth
local buttonElements = {}
local function createCooldown(parent)
    local cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetFrameLevel(parent:GetFrameLevel() + 1)
    return cooldown
end

local Engine = {}

function Engine:TopAnchor(host)
    if not self.topAnchor then
        self.topAnchor = CreateFrame("Frame", nil, host.frame)
        self.topAnchor:EnableMouse(false)
        self.updateTopAnchor = function() self:TopAnchor(host) end
        local function changed()
            ns.AfterCombat(self.layoutKey .. "TopAnchor", self.updateTopAnchor)
        end
        for _, box in ipairs(host.boxes) do
            box:HookScript("OnShow", changed)
            box:HookScript("OnHide", changed)
        end
    end
    local scale = host.frame:GetEffectiveScale()
    local originX, originY = host.frame:GetLeft(), host.frame:GetTop()
    local left, right, top
    for _, box in ipairs(host.boxes) do
        if box:IsShown() then
            local ratio = box:GetEffectiveScale() / scale
            local x, y, edge = box:GetLeft(), box:GetTop(), box:GetRight()
            if x and y and edge then
                x, y, edge = x * ratio, y * ratio, edge * ratio
                left = left and math.min(left, x) or x
                right = right and math.max(right, edge) or edge
                top = top and math.max(top, y) or y
            else
                self:Notice("anchor", "Aura anchor box geometry is unavailable.")
                return host.frame
            end
        end
    end
    if not left or not originX or not originY then
        self:Notice("anchor", "Aura anchor box geometry is unavailable.")
        return host.frame
    end
    self.topAnchor:ClearAllPoints()
    self.topAnchor:SetPoint("TOPLEFT", host.frame, "TOPLEFT", left - originX, top - originY)
    self.topAnchor:SetSize(math.max(1, right - left), 1)
    return self.topAnchor
end

function Engine:InitializeFormatter()
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding then
        self.formatter = C_StringUtil.CreateNumericRuleFormatter()
        self.durationOptions = { textFormatter = self.formatter }
    else self:Notice("formatter", "Numeric duration formatter unavailable; using native duration formatting.") end
end

function Engine:UpdateFilters()
    local entry = self.active
    if not entry then return end
    local friendly = UnitIsFriend("player", self.auraUnit)
    local buffFilter = self.db.castableBuffs and "HELPFUL|RAID" or "HELPFUL"
    local debuffFilter = "HARMFUL"
    if not ns.IsSecret(friendly) then
        if friendly and self.db.curableDebuffs then debuffFilter = "HARMFUL|RAID"
        elseif not friendly and self.db.ownDebuffs then debuffFilter = "HARMFUL|PLAYER" end
    end
    if entry.buffFilter ~= buffFilter then
        entry.container:SetAuraGroupFilterString("buffs", buffFilter)
        entry.buffBackground.frame:SetAuraSlotFilterString("background", buffFilter)
        entry.buffFilter = buffFilter
    end
    if entry.debuffFilter ~= debuffFilter then
        entry.debuffContainer:SetAuraGroupFilterString("debuffs", debuffFilter)
        entry.debuffBackground.frame:SetAuraSlotFilterString("background", debuffFilter)
        entry.debuffFilter = debuffFilter
    end
end

function Engine:UpdateFormatter()
    if not self.formatter then return end
    if self.formattedSecondsMode == self.db.secondsMode then return end
    local rounding = Enum.NumericRuleFormatRounding
    local minutes = { div = 60, step = 1, rounding = rounding.Down }
    local seconds = { mod = 60, step = 1, rounding = rounding.Down }
    local show = self.db.secondsMode ~= 0
    self.formatter:SetBreakpoints({
        { threshold = 0, format = "" },
        { threshold = 0.5, step = 1, rounding = rounding.Nearest, format = "%ds" },
        { threshold = 59.5, step = 1, rounding = rounding.Nearest,
            format = show and "%d:%02d" or "%dm", components = show and { minutes, seconds } or { minutes } },
        { threshold = 599.5, step = 1, rounding = rounding.Nearest,
            format = self.db.secondsMode == 1 and "%d:%02d" or "%dm",
            components = self.db.secondsMode == 1 and { minutes, seconds } or { minutes } },
        { threshold = 3599.5, step = 1, rounding = rounding.Nearest, format = "%dh %02dm",
            components = { { div = 3600, step = 1, rounding = rounding.Down },
                { div = 60, mod = 60, step = 1, rounding = rounding.Down } } },
        { threshold = 86399.5, step = 1, rounding = rounding.Nearest, format = "%dd%02dh",
            components = { { div = 86400, step = 1, rounding = rounding.Down },
                { div = 3600, mod = 24, step = 1, rounding = rounding.Down } } },
    })
    self.formattedSecondsMode = self.db.secondsMode
end

function Engine:ConfigureButton(button)
    local elements = buttonElements[button]
    if not elements then return end
    local db = self.db
    if elements.configured and elements.durationText == db.durationText
        and elements.cooldownScale == db.cooldownScale and elements.auraTimers == db.auraTimers
        and elements.secondsMode == db.secondsMode then return end
    if self.db.durationText then
        button:SetDurationText(elements.duration, self.durationOptions)
    else button:ClearDurationText() end
    elements.duration:SetAlpha(self.db.durationText and 1 or 0)
    if self.db.auraTimers then
        if not elements.cooldown then elements.cooldown = createCooldown(button) end
        elements.cooldown:SetScale(self.db.cooldownScale)
        elements.cooldown:SetAlpha(1)
        button:SetDurationCooldown(elements.cooldown)
    else
        button:ClearDurationCooldown()
        if elements.cooldown then elements.cooldown:SetAlpha(0) end
    end
    elements.configured, elements.durationText = true, db.durationText
    elements.cooldownScale, elements.auraTimers = db.cooldownScale, db.auraTimers
    elements.secondsMode = db.secondsMode
end

function Engine:InitializeButton(button, harmful)
    button:SetSize(30, 30)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local count = ns.Label(button, "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    local duration = ns.Label(button, "GameFontNormalSmall")
    duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
    button:SetIcon(icon)
    button:SetApplicationCount(count)
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT")
    if harmful or self.auraUnit ~= "player" then button:SetCancelAuraButtons(nil)
    else button:SetCancelAuraButtons("RightButtonUp") end
    if harmful then
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        button:AddDispelTypeTexture(border, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            showWhenHarmful = true, showWithoutDispelType = true,
        })
        if ENABLE_COLORBLIND_MODE == "1" then
            local symbol = ns.Label(button, "TextStatusBarText")
            symbol:SetPoint("TOPLEFT", 2, -2)
            button:SetDispelTypeText(symbol, { showWhenHarmful = true })
        end
    end
    buttonElements[button] = { duration = duration }
    self:ConfigureButton(button)
end

local function setBackground(background, container, enabled, alpha)
    local padding = enabled and 5 or 0
    background.frame:ClearAllPoints()
    background.frame:SetPoint("TOPLEFT", container, "TOPLEFT", -padding, padding)
    background.frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", padding, -padding)
    ns.SetAuraBackgroundAlpha(background, alpha)
    background.frame:SetEnabled(enabled)
end

function Engine:Container(weapons)
    weapons = weapons or false
    local entry = self.containers[weapons]
    if entry then return entry end
    local container = ns.AuraContainer(self.frame, self.auraUnit, 30)
    local debuffContainer = ns.AuraContainer(self.frame, self.auraUnit, 30)
    container:SetEnabled(false)
    debuffContainer:SetEnabled(false)
    entry = { container = container, debuffContainer = debuffContainer, enchantments = {} }
    entry.buffBackground = ns.AuraBackground(self.frame, container, ns.backdrop, self.auraUnit, false)
    entry.debuffBackground = ns.AuraBackground(self.frame, debuffContainer, ns.backdrop, self.auraUnit, true)
    self.containers[weapons] = entry
    container:AddAuraGroup("buffs", "HELPFUL", {
            maxFrameCount = self.db.buffPerRow * self.db.maxNumberOfRow,
            sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
            sortDirection = AuraContainerSortDirection.Normal,
            initializeFrame = function(button) self:InitializeButton(button, false) end,
        })
    debuffContainer:AddAuraGroup("debuffs", "HARMFUL", {
        maxFrameCount = self.db.buffPerRow * self.db.maxNumberOfRow,
        sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
        sortDirection = AuraContainerSortDirection.Normal,
        initializeFrame = function(button) self:InitializeButton(button, true) end,
    })
    if weapons then
        for _, slot in ipairs({ AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand }) do
            entry.enchantments[#entry.enchantments + 1] = container:AddItemEnchantment(slot, {
                initializeFrame = function(button) self:InitializeButton(button, false) end,
            })
        end
    end
    return entry
end

function Engine:Preview()
    local show = ns.positioning and self.db.enabled
    if not self.preview then
        if not show then return end
        self.preview = CreateFrame("Frame", nil, self.frame)
        self.preview:SetAllPoints(self.frame)
        self.preview.icons = {}
    end
    self.preview:SetShown(show)
    if not show then return end
    local db = self.db
    local count = db.buffPerRow * db.maxNumberOfRow
    local weapons = db.weaponBuff and math.min(2, count) or 0
    local right, up = db.anchorLocation % 2 == 0, db.anchorLocation >= 3
    local point = up and (right and "BOTTOMRIGHT" or "BOTTOMLEFT") or (right and "TOPRIGHT" or "TOPLEFT")
    local helpfulRows = db.maxNumberOfRow
    local height = 30 + (db.durationText and 15 or 0)
    local padding = db.showAuraBackground and 5 or 0
    local width = math.max(1, db.buffPerRow * 30 + (db.buffPerRow - 1) * db.spacingHorizontal)
    local groupHeight = math.max(1, db.maxNumberOfRow * height
        + (db.maxNumberOfRow - 1) * db.spacingVertical)
    local function positionPreviewPanel(panel, firstRow)
        panel:ClearAllPoints()
        local groupOffset = firstRow > 0 and db.groupSpacingVertical - db.spacingVertical + 2 * padding or 0
        panel:SetPoint(point, self.preview, point,
            right and padding or -padding,
            (up and 1 or -1) * (firstRow * (height + db.spacingVertical)
                + groupOffset)
                + (up and db.durationText and 15 or 0) - (up and padding or -padding))
        panel:SetSize(width + 2 * padding, groupHeight + 2 * padding)
        panel:SetAlpha(db.auraBackgroundAlpha)
        panel:SetShown(db.showAuraBackground)
    end
    if not self.preview.buffBackground then
        self.preview.buffBackground = ns.AuraPanel(self.preview, ns.backdrop)
        self.preview.debuffBackground = ns.AuraPanel(self.preview, ns.backdrop)
    end
    positionPreviewPanel(self.preview.buffBackground, 0)
    positionPreviewPanel(self.preview.debuffBackground, helpfulRows)
    local cooldownStart = db.auraTimers and GetTime() - 15
    for i = 1, count * 2 do
        local icon = self.preview.icons[i]
        if not icon then
            icon = CreateFrame("Frame", nil, self.preview)
            icon:SetSize(30, 30)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.border = icon:CreateTexture(nil, "OVERLAY")
            icon.border:SetSize(32, 32); icon.border:SetPoint("CENTER")
            icon.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
            icon.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
            icon.border:SetVertexColor(1, 0, 0)
            icon.duration = ns.Label(icon)
            icon.duration:SetPoint("TOP", icon, "BOTTOM", 0, -1)
            icon.count = ns.Label(icon, "NumberFontNormalSmall")
            icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
            self.preview.icons[i] = icon
        end
        local harmful = i > count
        local index = harmful and i - count - 1 or i - 1
        local row = math.floor(index / db.buffPerRow) + (harmful and helpfulRows or 0)
        icon:ClearAllPoints()
        icon:SetPoint(point, self.preview, point, (right and -1 or 1) * ((index % db.buffPerRow) * (30 + db.spacingHorizontal)),
            (up and 1 or -1) * (row * (height + db.spacingVertical)
                + (harmful and (db.groupSpacingVertical - db.spacingVertical + 2 * padding) or 0))
                + (up and db.durationText and 15 or 0))
        icon.texture:SetTexture(harmful and "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
            or i <= weapons and "Interface\\Icons\\INV_Sword_04" or "Interface\\Icons\\Spell_Holy_WordFortitude")
        icon.border:SetShown(harmful)
        icon.count:SetText(not harmful and i <= weapons and "" or "2")
        icon.duration:SetText(db.secondsMode == 0 and "5m" or "5:00")
        icon.duration:SetShown(db.durationText)
        if db.auraTimers then
            if not icon.cooldown then icon.cooldown = createCooldown(icon) end
            icon.cooldown:SetScale(db.cooldownScale)
            icon.cooldown:Show()
            icon.cooldown:SetCooldown(cooldownStart, 60)
        elseif icon.cooldown then icon.cooldown:Hide() end
        icon:Show()
    end
    for i = count * 2 + 1, #self.preview.icons do self.preview.icons[i]:Hide() end
end

function Engine:LayoutContainers(entry, point, right, up, weapons)
    local db = self.db
    local container = entry.container
    container:ClearAllPoints()
    container:SetPoint(point, self.frame, point, 0, up and db.durationText and 15 or 0)
    local debuffContainer = entry.debuffContainer
    debuffContainer:ClearAllPoints()
    local containerEdge = (up and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
    debuffContainer:SetPoint(point, container, containerEdge, 0,
        (up and 1 or -1) * (db.groupSpacingVertical + (db.showAuraBackground and 10 or 0)))
    container:SetFlowLayoutPadding(0, 0, 0, 0)
    debuffContainer:SetFlowLayoutPadding(0, 0, 0, 0)
    local showBackgrounds = db.showAuraBackground and db.enabled and not ns.positioning
    setBackground(entry.buffBackground, container, showBackgrounds, db.auraBackgroundAlpha)
    setBackground(entry.debuffBackground, debuffContainer, showBackgrounds, db.auraBackgroundAlpha)
    self.appliedBackgrounds = db.showAuraBackground and db.enabled
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint(point)
    container:SetFlowLayoutGrowthDirection(right and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
        up and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(math.max(1, db.buffPerRow * 30 + (db.buffPerRow - 1) * db.spacingHorizontal))
    debuffContainer:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    debuffContainer:SetFlowLayoutAnchorPoint(point)
    debuffContainer:SetFlowLayoutGrowthDirection(right and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
        up and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    debuffContainer:SetFlowLayoutMaximumLineSize(math.max(1, db.buffPerRow * 30 + (db.buffPerRow - 1) * db.spacingHorizontal))
    self:UpdateFilters()
    container:SetAuraGroupMaxFrameCount("buffs", db.buffPerRow * db.maxNumberOfRow)
    debuffContainer:SetAuraGroupMaxFrameCount("debuffs", db.buffPerRow * db.maxNumberOfRow)
    for _, item in ipairs({ { container, "buffs", 1 }, { debuffContainer, "debuffs", 0 } }) do
        local auraContainer, key, index = item[1], item[2], item[3]
        auraContainer:SetAuraGroupLayout(key, {
            elementWidth = 30, elementHeight = 30 + (db.durationText and 15 or 0),
            elementSpacing = db.spacingHorizontal, lineSpacing = db.spacingVertical,
            layoutIndex = index,
        })
        for i = 1, auraContainer:GetAuraGroupFrameCount(key) do
            self:ConfigureButton(auraContainer:GetAuraGroupFrame(key, i))
        end
    end
    if weapons then
        container:SetItemEnchantmentLayout({
            elementWidth = 30, elementHeight = 30 + (db.durationText and 15 or 0),
            elementSpacing = db.spacingHorizontal, lineSpacing = db.spacingVertical, layoutIndex = 0,
        })
        for _, button in ipairs(entry.enchantments) do self:ConfigureButton(button) end
    end
    container:SetEnabled(db.enabled and not ns.positioning)
    container:SetShown(db.enabled and not ns.positioning)
    debuffContainer:SetEnabled(db.enabled and not ns.positioning)
    debuffContainer:SetShown(db.enabled and not ns.positioning)
    self.appliedEnabled = db.enabled
end

function Engine:UpdateBackgroundAlpha()
    for _, entry in pairs(self.containers) do
        ns.SetAuraBackgroundAlpha(entry.buffBackground, self.db.auraBackgroundAlpha)
        ns.SetAuraBackgroundAlpha(entry.debuffBackground, self.db.auraBackgroundAlpha)
    end
    if self.preview and self.preview.buffBackground then
        self.preview.buffBackground:SetAlpha(self.db.auraBackgroundAlpha)
        self.preview.debuffBackground:SetAlpha(self.db.auraBackgroundAlpha)
    end
end

function Engine:UpdateAppearance()
    self:UpdateFormatter()
    for _, entry in pairs(self.containers) do
        for _, group in ipairs({ { entry.container, "buffs" }, { entry.debuffContainer, "debuffs" } }) do
            for i = 1, group[1]:GetAuraGroupFrameCount(group[2]) do
                self:ConfigureButton(group[1]:GetAuraGroupFrame(group[2], i))
            end
        end
        for _, button in ipairs(entry.enchantments) do self:ConfigureButton(button) end
    end
    self:Preview()
end

function Engine:Refresh(key)
    if not self.frame then return end
    if key == "auraBackgroundAlpha" then
        self:UpdateBackgroundAlpha()
        return
    end
    if key == "auraTimers" or key == "cooldownScale" or key == "secondsMode" then
        if not InCombatLockdown() or ns.pending[self.appearanceKey] ~= self.applyAppearance then
            ns.AfterCombat(self.appearanceKey, self.applyAppearance)
        end
        return
    end
    if InCombatLockdown() and not ns.positioning and self.preview and self.preview:IsShown() then
        self.preview:Hide()
        for _, container in ipairs({ self.active.container, self.active.debuffContainer }) do
            container:SetEnabled(self.appliedEnabled)
            container:SetShown(self.appliedEnabled)
        end
        self.active.buffBackground.frame:SetEnabled(self.appliedBackgrounds)
        self.active.debuffBackground.frame:SetEnabled(self.appliedBackgrounds)
    end
    if not InCombatLockdown() or ns.pending[self.layoutKey] ~= self.applyLayout then
        ns.AfterCombat(self.layoutKey, self.applyLayout)
    end
end

function ns.InstallAuraEngine(module, unit, id)
    module.auraUnit = unit
    module.containers = {}
    module.layoutKey = id .. "Layout"
    module.appearanceKey = id .. "Appearance"
    module.applyLayout = function() module:Layout() end
    module.applyAppearance = function() module:UpdateAppearance() end
    for name, callback in pairs(Engine) do module[name] = callback end
end
