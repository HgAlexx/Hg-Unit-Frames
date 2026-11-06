local _, ns = ...
local panels = {}
local framePanels = {}
local floating
local layoutFrameOptions
local categoriesByKey = {}
local categoryOrder = {
    ["Common settings"] = 0,
    ["Player"] = 1, ["Player Aura"] = 1.5, ["Player Pet"] = 2,
    ["Target"] = 3, ["Target Aura"] = 3.5, ["Target Target"] = 4,
    ["Focus"] = 5, ["Focus Aura"] = 5.5, ["Focus Target"] = 6, ["Party"] = 7,
    ["Party Target"] = 8, ["Party Pet"] = 9, ["Cast bars"] = 10,
    ["Settings presets"] = -1,
}
local categoryRanks = {}
local stickyPanels = {
    ["Player"] = "Player", ["Player Pet"] = "PlayerPet", ["Target"] = "Target",
    ["Target Target"] = "TargetTarget", ["Focus"] = "Focus", ["Focus Target"] = "FocusTarget",
    ["Party"] = "Party", ["Party Target"] = "PartyTarget", ["Party Pet"] = "PartyPet",
}
local auraPanels = { ["Player Aura"] = "PlayerAura", ["Target Aura"] = "TargetAura", ["Focus Aura"] = "FocusAura" }

function ns.HideFrameOptions()
    if floating then floating:Hide() end
end

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Warn(ns.L["Cannot open settings during combat."])
        return
    end
    local storage = ns.modules.Core.storage
    local key = storage.lastCategories and storage.lastCategories[ns.characterKey]
    local category = (type(key) == "string" and categoriesByKey[key]) or ns.category
    if category then Settings.OpenToCategory(category:GetID()) end
end

local function tooltip(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

StaticPopupDialogs.HG_REBIRTH_CONFIRM = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(_, action) action() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
    preferredIndex = 3,
}

function ns.Confirm(message, callback)
    StaticPopup_Show("HG_REBIRTH_CONFIRM", message, nil, callback)
end

local function addControl(parent, refresh)
    local controls = parent.optionsPanel.optionRefreshes
    controls[#controls + 1] = refresh
end

function ns.Panel(title, subtitle, parentCategory, build)
    local key = title
    local moduleId = stickyPanels[key] or auraPanels[key]
    local rank = categoryOrder[title] or 100
    title = ns.L[title]
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel.optionRefreshes = {}
    local heading = ns.Label(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetTextHeight(22)
    heading:SetText(title)
    local description = ns.Label(panel, "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
    description:SetJustifyH("LEFT")
    description:SetTextColor(0.75, 0.75, 0.75)
    description:SetWordWrap(true)
    description:SetNonSpaceWrap(true)
    description:SetText(subtitle)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll.ScrollBar.scrollStep = 28
    scroll:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1)
    scroll:SetScrollChild(content)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if content:GetParent() ~= scroll then return end
        content:SetWidth(math.max(1, width))
        if moduleId and content.baseHeight then layoutFrameOptions(content, math.max(1, width)) end
    end)
    content.cursor = 0
    content.layoutWidgets = {}
    content.optionsPanel = panel
    function panel:BuildOptions()
        if not build then return end
        local initialize = build
        build = nil
        initialize(content)
        local module = ns.modules[stickyPanels[key]]
        if module and module.defaults.showTooltip ~= nil then ns.TooltipOptions(content, module) end
        if module and ns.StickyOptions then ns.StickyOptions(content, module) end
        content.baseHeight = content:GetHeight()
        for _, item in ipairs(content.layoutWidgets) do
            item.points = {}
            for index = 1, item.widget:GetNumPoints() do
                item.points[index] = { item.widget:GetPoint(index) }
            end
        end
    end
    local category
    if parentCategory then
        category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, title)
        categoryRanks[category] = rank
        parentCategory:SetShouldSortAlphabetically(false)
        table.sort(parentCategory:GetSubcategories(), function(left, right)
            local leftRank, rightRank = categoryRanks[left] or 100, categoryRanks[right] or 100
            if leftRank == rightRank then return left:GetID() < right:GetID() end
            return leftRank < rightRank
        end)
    else
        category = Settings.RegisterCanvasLayoutCategory(panel, title)
        Settings.RegisterAddOnCategory(category)
    end
    categoriesByKey[key] = category
    local restoringScroll = false
    local restoringLayout = false
    local function restoreScroll()
        local storage = ns.modules.Core.storage
        local positions = storage.scrollPositions and storage.scrollPositions[ns.characterKey]
        local position = positions and positions[key] or 0
        local maximum = scroll:GetVerticalScrollRange()
        restoringScroll = true
        position = math.min(position, maximum)
        scroll.ScrollBar:SetValue(position)
        scroll:SetVerticalScroll(position)
        restoringScroll = false
    end
    scroll:HookScript("OnVerticalScroll", function(_, position)
        if restoringScroll or restoringLayout or not panel:IsShown() then return end
        local storage = ns.modules.Core.storage
        storage.scrollPositions = storage.scrollPositions or {}
        local positions = storage.scrollPositions[ns.characterKey] or {}
        storage.scrollPositions[ns.characterKey] = positions
        positions[key] = position
    end)
    scroll:HookScript("OnScrollRangeChanged", function()
        if panel:IsShown() then restoreScroll() end
    end)
    panel:SetScript("OnShow", function()
        ns.HideFrameOptions()
        restoringLayout = true
        panel:BuildOptions()
        local storage = ns.modules.Core.storage
        storage.lastCategories = storage.lastCategories or {}
        storage.lastCategories[ns.characterKey] = key
        ns.RefreshOptions(panel)
        panel:SetScript("OnUpdate", function()
            restoreScroll()
            restoringLayout = false
            panel:SetScript("OnUpdate", nil)
        end)
        restoreScroll()
    end)
    panels[#panels + 1] = panel
    if moduleId then
        framePanels[moduleId] = { panel = panel, content = content, scroll = scroll, title = title }
    end
    return content, category
end

function ns.TooltipOptions(content, module)
    ns.Section(content, "Tooltip")
    ns.Check(content, module, "showTooltip", "Show unit tooltip")
    ns.SubOptions(content, function() return module.db.showTooltip end, function()
        ns.Select(content, "Tooltip anchor", function()
            return {
                { text = "Right of frame", value = "right" },
                { text = "WoW default", value = "default" },
            }
        end, function() return module.db.tooltipAnchor end,
            function(value) ns.Set(module, "tooltipAnchor", value) end)
    end)
end

local INDENT = 20
local DISABLED_COLOR = { 0.5, 0.5, 0.5 }

local function rememberTextColor(text)
    if not text or not text.SetTextColor then return end
    if not text.enabledColor then text.enabledColor = { text:GetTextColor() } end
end

local function setTextEnabled(text, enabled)
    if not text or not text.SetTextColor then return end
    rememberTextColor(text)
    local color = enabled and text.enabledColor or DISABLED_COLOR
    text:SetTextColor(color[1], color[2], color[3])
end

local function setWidgetEnabled(widget, enabled)
    if widget:GetObjectType() == "FontString" then setTextEnabled(widget, enabled); return end
    if widget.OnButtonStateChanged then
        if enabled then widget:Enable() else widget:Disable() end
        widget:OnButtonStateChanged()
        return
    end
    local label = widget.GetFontString and widget:GetFontString()
    rememberTextColor(label)
    rememberTextColor(widget.Text)
    rememberTextColor(widget.Low)
    rememberTextColor(widget.High)
    if enabled then widget:Enable() else widget:Disable() end
    setTextEnabled(label, enabled)
    setTextEnabled(widget.Text, enabled)
    setTextEnabled(widget.Low, enabled)
    setTextEnabled(widget.High, enabled)
end

local function conditionsMet(conditions)
    for _, condition in ipairs(conditions) do
        if not condition() then return false end
    end
    return true
end

local function place(parent, widget, height, structural)
    parent.layoutWidgets[#parent.layoutWidgets + 1] = {
        widget = widget, top = parent.cursor, height = height,
    }
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.indent or 0) * INDENT, -parent.cursor)
    parent.cursor = parent.cursor + height
    parent:SetHeight(parent.cursor + 16)
    local conditions = parent.conditions
    if not structural and conditions and #conditions > 0 then
        addControl(parent, function() setWidgetEnabled(widget, conditionsMet(conditions)) end)
    end
end

-- Controls built inside `build` are greyed out while `condition` returns false.
-- Nested calls combine conditions; `indented` places them under their parent setting.
local function dependent(parent, condition, build, indented)
    local previous = parent.conditions or {}
    local conditions = {}
    for index, value in ipairs(previous) do conditions[index] = value end
    conditions[#conditions + 1] = condition
    parent.conditions = conditions
    if indented then parent.indent = (parent.indent or 0) + 1 end
    build()
    if indented then parent.indent = parent.indent - 1 end
    parent.conditions = previous
end

function ns.SubOptions(parent, condition, build) dependent(parent, condition, build, true) end
function ns.DependentOptions(parent, condition, build) dependent(parent, condition, build, false) end

function ns.Section(parent, text)
    local label = ns.Label(parent, "GameFontNormalLarge")
    label:SetHeight(24)
    label:SetJustifyV("TOP")
    parent.cursor = parent.cursor + 10
    place(parent, label, 32, true)
    label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -(parent.cursor - 32))
    label:SetJustifyH("LEFT")
    label:SetText(ns.L[text])
    return label
end

function ns.Check(parent, module, key, text, tip)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    return ns.Toggle(parent, text, function() return module.db[key] end,
        function(value) ns.Set(module, key, value) end, tip)
end

function ns.Toggle(parent, text, getValue, setValue, tip)
    local check = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    check:SetSize(24, 24)
    place(parent, check, 28)
    check.Text:SetText(ns.L[text])
    check.layoutText = check.Text
    check.layoutKind = "check"
    check.tip = tip
    check:SetScript("OnEnter", tooltip)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
    end)
    addControl(parent, function() check:SetChecked(getValue()) end)
    return check
end

function ns.TextInput(parent, text)
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(280, 24)
    input:SetAutoFocus(false)
    input:SetMaxBytes(80)
    place(parent, input, 36)
    -- InputBoxTemplate's left border extends outside the edit box.
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.indent or 0) * INDENT + 8, -(parent.cursor - 36))
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return input
end

function ns.Slider(parent, module, key, text, minimum, maximum, step, multiplier)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    text = ns.L[text]
    multiplier = multiplier or 1
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider.Text:ClearAllPoints()
    slider.Low:ClearAllPoints()
    slider.High:ClearAllPoints()
    slider.Text:SetPoint("BOTTOM", slider, "TOP", 0, 4)
    slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    slider:SetSize(260, 16)
    slider.layoutText = slider.Text
    slider.layoutKind = "slider"
    parent.cursor = parent.cursor + 18
    place(parent, slider, 44)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(_, delta)
        if not slider:IsEnabled() then return end
        local value = slider:GetValue()
        if (delta > 0) then
            value = math.max(minimum, math.min(maximum, value + step))
        elseif (delta < 0) then
            value = math.max(minimum, math.min(maximum, value - step))
        else
            return
        end
        slider:SetValue(value)
    end)
    slider.Low:SetText(minimum)
    slider.High:SetText(maximum)
    local updating
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        slider.Text:SetText(text .. ": " .. value)
        if not updating then ns.Set(module, key, value / multiplier) end
    end)
    addControl(parent, function()
        updating = true
        slider:SetValue(module.db[key] * multiplier)
        slider.Text:SetText(text .. ": " .. math.floor(module.db[key] * multiplier / step + 0.5) * step)
        updating = false
    end)
    if key == "scale" or key == "targetScale" then
        local conditions = parent.conditions or {}
        addControl(parent, function()
            setWidgetEnabled(slider, conditionsMet(conditions)
                and not (ns.StickyScaleControlled and ns.StickyScaleControlled(module, key)))
        end)
    end
end

function ns.Button(parent, text, callback, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 260, 24)
    place(parent, button, 32)
    button:SetText(ns.L[text])
    local label = button:GetFontString()
    label:SetWordWrap(false)
    button:SetWidth(math.max(width or 260, math.ceil(label:GetStringWidth()) + 32))
    button.layoutText = label
    button.layoutKind = "button"
    button.layoutWidth = button:GetWidth()
    button:SetScript("OnClick", callback)
    return button
end

function ns.ColorPicker(parent, module, key, text)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetBackdrop(ns.backdrop)
    swatch:SetBackdropBorderColor(1, 1, 1, 1)
    swatch:SetSize(64, 24)
    place(parent, swatch, 32)
    swatch.color = swatch:CreateTexture(nil, "OVERLAY")
    swatch.color:SetPoint("TOPLEFT", 4, -4)
    swatch.color:SetPoint("BOTTOMRIGHT", -4, 4)
    swatch:SetScript("OnClick", function()
        local previous = ns.Copy(module.db[key])
        local function apply()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ns.Set(module, key, { r, g, b })
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1], g = previous[2], b = previous[3], hasOpacity = false,
            extraInfo = swatch,
            swatchFunc = apply,
            cancelFunc = function() ns.Set(module, key, previous) end,
        })
    end)
    local reset = ns.Button(parent, "Reset color", function()
        if ColorPickerFrame:IsShown() and ColorPickerFrame:GetExtraInfo() == swatch then
            ColorPickerFrame:Hide()
        end
        ns.Set(module, key, ns.Copy(module.defaults[key]))
    end, 130)
    reset:ClearAllPoints()
    reset:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    parent.cursor = parent.cursor - 32
    parent:SetHeight(parent.cursor + 16)
    addControl(parent, function()
        local rgb = module.db[key]
        swatch.color:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    end)
    return swatch, reset
end

function ns.BooleanButtons(parent, text, apply)
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local on = ns.Button(parent, "Set on", function() apply(true) end, 110)
    local off = ns.Button(parent, "Set off", function() apply(false) end, 110)
    off:ClearAllPoints()
    off:SetPoint("LEFT", on, "RIGHT", 8, 0)
    parent.cursor = parent.cursor - 32
    parent:SetHeight(parent.cursor + 16)
end

function ns.Description(parent, text)
    local note = ns.Label(parent, "GameFontHighlightSmall")
    note:SetWidth(560)
    note:SetHeight(36)
    note:SetWordWrap(true)
    note:SetJustifyH("LEFT")
    note:SetText(ns.L[text])
    note.layoutKind = "description"
    place(parent, note, 44)
    return note
end

function ns.Select(parent, label, choices, getValue, setValue)
    local title = ns.Label(parent)
    place(parent, title, 20)
    title:SetText(ns.L[label])
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(280)
    place(parent, dropdown, 36)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(choices()) do
            root:CreateRadio(choice.raw and choice.text or ns.L[choice.text], function() return getValue() == choice.value end,
                function() setValue(choice.value) end)
        end
    end)
    addControl(parent, function()
        dropdown:GenerateMenu()
        if dropdown.OnButtonStateChanged then dropdown:OnButtonStateChanged() end
    end)
    return dropdown
end

-- Count slider with the filter, size and location settings it controls indented beneath it.
function ns.AuraGroupOptions(parent, module, harmful, locations)
    local db = function() return module.db end
    if harmful then
        ns.Slider(parent, module, "debuffCount", "Debuff count", 0, 16, 1)
        ns.SubOptions(parent, function() return db().debuffCount > 0 end, function()
            ns.Check(parent, module, "curableDebuffs", "Only show curable debuffs")
            ns.Slider(parent, module, "debuffSize", "Debuff size", 1, 50, 1)
            ns.Select(parent, "Debuff location", locations, function() return db().debuffLocation end,
                function(value) ns.Set(module, "debuffLocation", value) end)
        end)
    else
        ns.Slider(parent, module, "buffCount", "Buff count", 0, 16, 1)
        ns.SubOptions(parent, function() return db().buffCount > 0 end, function()
            ns.Check(parent, module, "castableBuffs", "Only show castable buffs")
            ns.Slider(parent, module, "buffSize", "Buff size", 1, 50, 1)
            ns.Select(parent, "Buff location", locations, function() return db().buffLocation end,
                function(value) ns.Set(module, "buffLocation", value) end)
        end)
    end
end

function ns.HasAuraCount(module)
    return module.db.buffCount > 0 or module.db.debuffCount > 0
end

function ns.NudgeFrames(owner, dx, dy)
    if InCombatLockdown() then ns.Warn(ns.L["Cannot nudge frames during combat."]); return false end
    if not owner.frame or owner.unavailable then
        ns.Warn(ns.L["Frame positioning requires initialized custom frames."]); return false
    end
    local entries = { { frame = owner.frame, xKey = "x", yKey = "y" } }
    if owner.members and owner.members[1] and owner.members[1].xKey then
        entries = owner.members
    elseif owner.target then
        entries[2] = { frame = owner.target.frame, xKey = "targetX", yKey = "targetY" }
    end
    local function finite(value)
        return not ns.IsSecret(value) and type(value) == "number"
            and value == value and value ~= math.huge and value ~= -math.huge
    end
    local uiScale = UIParent:GetEffectiveScale()
    local positions = {}
    for index, entry in ipairs(entries) do
        local scale = entry.frame and entry.frame:GetEffectiveScale()
        local x, y = owner.db[entry.xKey], owner.db[entry.yKey]
        if not finite(uiScale) or uiScale <= 0 or not finite(scale) or scale <= 0
            or not finite(x) or not finite(y) then
            ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
        end
        positions[index] = { x = x + dx * uiScale / scale, y = y + dy * uiScale / scale }
        if not finite(positions[index].x) or not finite(positions[index].y) then
            ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
        end
    end
    for index, entry in ipairs(entries) do
        owner.db[entry.xKey], owner.db[entry.yKey] = positions[index].x, positions[index].y
    end
    owner:Refresh()
    return true
end

function ns.NudgeControls(parent, owner)
    local cursor, x = parent.cursor, 0
    for _, direction in ipairs({
        { "Nudge up 1 pixel", 0, 1, "^" }, { "Nudge down 1 pixel", 0, -1, "v" },
        { "Nudge left 1 pixel", -1, 0, "<" }, { "Nudge right 1 pixel", 1, 0, ">" },
    }) do
        parent.cursor = cursor
        local button = ns.Button(parent, direction[4],
            function() ns.NudgeFrames(owner, direction[2], direction[3]) end, 40)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -cursor)
        button.tip = ns.L[direction[1]]
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(_, delta)
            if delta ~= 0 then ns.NudgeFrames(owner, direction[2] * delta, direction[3] * delta) end
        end)
        button:SetScript("OnEnter", tooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        x = x + button:GetWidth() + 4
    end
end

function ns.RefreshOptions(panel)
    for _, candidate in ipairs(panels) do
        local borrowed = floating and floating:IsShown() and floating.active
            and floating.active.panel == candidate
        if (not panel or candidate == panel) and (candidate:IsVisible() or borrowed) then
            for _, refresh in ipairs(candidate.optionRefreshes) do refresh() end
            if borrowed then layoutFrameOptions(floating.active.content, floating.active.content:GetWidth()) end
        end
    end
end

-- Borrow the actual panel controls so Settings and the floating window cannot diverge.
layoutFrameOptions = function(content, width)
    local extra = 0
    local additions = {}
    for _, item in ipairs(content.layoutWidgets) do
        local widget, kind = item.widget, item.widget.layoutKind
        local available = math.max(1, width - (item.points[1] and item.points[1][4] or 0) - 8)
        local text = widget.layoutText
        local added = 0
        if kind == "check" then
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", widget, "TOPRIGHT", 4, -3)
            text:SetWidth(math.max(1, available - 30))
            text:SetHeight(0)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(true)
            added = math.max(0, text:GetStringHeight() - 20)
        elseif kind == "button" then
            widget:SetWidth(math.min(widget.layoutWidth, available))
            text:SetWidth(math.max(1, widget:GetWidth() - 24))
            text:SetHeight(0)
            text:SetWordWrap(true)
            added = math.max(0, text:GetStringHeight() + 12 - 24)
            widget:SetHeight(24 + added)
        elseif kind == "slider" then
            text:SetWidth(math.min(260, available))
            text:SetHeight(0)
            text:SetWordWrap(true)
            added = math.max(0, text:GetStringHeight() - 16)
        elseif widget:GetObjectType() == "FontString" then
            widget:SetWidth(available)
            widget:SetHeight(0)
            widget:SetJustifyH("LEFT")
            widget:SetWordWrap(true)
            local base = kind == "description" and 36 or item.height - (item.height == 32 and 8 or 0)
            added = math.max(0, widget:GetStringHeight() - base)
            widget:SetHeight(base + added)
        end
        if added > 0 then
            additions[#additions + 1] = { top = item.top, amount = added }
            extra = extra + added
        end
        item.extra = kind == "slider" and added or 0
    end
    for _, item in ipairs(content.layoutWidgets) do
        item.widget:ClearAllPoints()
        for _, point in ipairs(item.points) do
            local offset = item.extra
            if point[2] == content then
                for _, addition in ipairs(additions) do
                    if addition.top < item.top then offset = offset + addition.amount end
                end
            else offset = 0 end
            item.widget:SetPoint(point[1], point[2], point[3], point[4], point[5] - offset)
        end
    end
    content:SetHeight(content.baseHeight + extra)
end

local function createFrameOptions()
    local window = CreateFrame("Frame", nil, UIParent)
    window:Hide()
    window:SetSize(460, 420)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetResizeBounds(400, 420)
    window:EnableMouse(true)
    window.Border = CreateFrame("Frame", nil, window, "DialogBorderTranslucentTemplate")
    window.Border:SetAllPoints(window)
    window.Border:EnableMouse(false)
    window.title = ns.Label(window, "GameFontHighlightLarge")
    window.title:SetPoint("TOP", 0, -15)
    window.title:SetWidth(window:GetWidth() - 80)
    window.title:SetJustifyH("CENTER")
    window:SetScript("OnSizeChanged", function(_, width) window.title:SetWidth(math.max(1, width - 80)) end)
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -36, 0)
    header:SetHeight(38)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    window.close:SetPoint("TOPRIGHT")
    window.close:SetScript("OnClick", function() window:Hide() end)
    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    window.scroll = scroll
    scroll.ScrollBar.scrollStep = 28
    scroll:SetPoint("TOPLEFT", 16, -44)
    scroll:SetPoint("BOTTOMRIGHT", -32, 24)
    local empty = CreateFrame("Frame", nil, scroll)
    empty:SetSize(1, 1)
    scroll:SetScrollChild(empty)
    window.resize = CreateFrame("Button", nil, window)
    window.resize:SetSize(20, 20)
    window.resize:SetPoint("BOTTOMRIGHT", -2, 2)
    window.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    window.resize:RegisterForDrag("LeftButton")
    window.resize:SetScript("OnDragStart", function() window:StartSizing("BOTTOMRIGHT") end)
    window.resize:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if not window.active then return end
        window.active.content:SetWidth(math.max(1, width))
        layoutFrameOptions(window.active.content, math.max(1, width))
    end)
    window:SetScript("OnHide", function()
        window:StopMovingOrSizing()
        local active = window.active
        if not active then return end
        window.active = nil
        scroll:SetScrollChild(empty)
        active.content:SetParent(active.scroll)
        active.scroll:SetScrollChild(active.content)
        active.content:ClearAllPoints()
        active.content:SetPoint("TOPLEFT", active.scroll, "TOPLEFT", 0, 0)
        local width = math.max(1, active.scroll:GetWidth())
        active.content:SetWidth(width)
        layoutFrameOptions(active.content, width)
    end)
    return window
end

local function positionFrameOptions(window, module, source)
    source = source or module.frame
    local function finite(value)
        return not ns.IsSecret(value) and type(value) == "number"
            and value == value and value ~= math.huge and value ~= -math.huge
    end
    local uiScale = UIParent:GetEffectiveScale()
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    if not finite(uiScale) or uiScale <= 0 or not finite(screenWidth) or not finite(screenHeight) then
        ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
    end
    local left, bottom, right, top
    local function include(frame)
        if not frame then return false end
        local x, y, width, height = frame:GetRect()
        local scale = frame:GetEffectiveScale()
        if not finite(x) or not finite(y) or not finite(width) or not finite(height)
            or not finite(scale) or scale <= 0 or width <= 0 or height <= 0 then return false end
        local ratio = scale / uiScale
        x, y, width, height = x * ratio, y * ratio, width * ratio, height * ratio
        left, bottom = math.min(left or x, x), math.min(bottom or y, y)
        right, top = math.max(right or x + width, x + width), math.max(top or y + height, y + height)
        return true
    end
    if not include(source) then
        ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
    end
    -- Unit overlays cover individual boxes; include the other boxes of that unit.
    local unit = source:GetAttribute("unit")
    if unit then
        for _, button in ipairs(module.buttons or {}) do
            if button:GetAttribute("unit") == unit and button:IsShown() then include(button:GetParent()) end
        end
    end
    local gap = 12
    local ratio = window:GetEffectiveScale() / uiScale
    local function choose(width, height)
        if width > screenWidth or height > screenHeight then return end
        local x = math.max(0, math.min(screenWidth - width, (left + right - width) / 2))
        local y = math.max(0, math.min(screenHeight - height, (bottom + top - height) / 2))
        local candidates = {
            { right + gap, y, (left + right) / (2 * screenWidth) },
            { left - gap - width, y, 1 - (left + right) / (2 * screenWidth) },
            { x, top + gap, (bottom + top) / (2 * screenHeight) },
            { x, bottom - gap - height, 1 - (bottom + top) / (2 * screenHeight) },
        }
        local best, distance
        for _, point in ipairs(candidates) do
            local px, py = point[1], point[2]
            if px >= 0 and py >= 0 and px + width <= screenWidth and py + height <= screenHeight then
                local score = point[3]
                if not distance or score < distance then best, distance = point, score end
            end
        end
        return best
    end
    local point = choose(window:GetWidth() * ratio, window:GetHeight() * ratio)
    if not point then
        point = choose(400 * ratio, 420 * ratio)
        if point then window:SetSize(400, 420) end
    end
    if not point then
        ns.Warn(ns.L["Not enough screen space beside this frame for its settings."]); return false
    end
    window:ClearAllPoints()
    window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", point[1] / ratio, point[2] / ratio)
    return true
end

function ns.OpenFrameOptions(module, source)
    if not ns.positioning or InCombatLockdown() then return false end
    local active
    for id, candidate in pairs(ns.modules) do
        if candidate == module then active = framePanels[id]; break end
    end
    if not active then ns.Warn(ns.L["Frame settings panel unavailable."]); return false end
    if not floating then floating = createFrameOptions() end
    if not positionFrameOptions(floating, module, source) then return false end
    if floating.active == active and floating:IsShown() then
        local width = math.max(1, floating:GetWidth() - 48)
        active.content:SetWidth(width)
        layoutFrameOptions(active.content, width)
        return true
    end
    floating:Hide()
    active.panel:BuildOptions()
    floating.active = active
    floating.title:SetText(active.title)
    active.placeholder = active.placeholder or CreateFrame("Frame", nil, active.scroll)
    active.placeholder:SetSize(1, 1)
    active.scroll:SetScrollChild(active.placeholder)
    active.content:SetParent(floating.scroll)
    floating.scroll:SetScrollChild(active.content)
    active.content:ClearAllPoints()
    active.content:SetPoint("TOPLEFT", floating.scroll, "TOPLEFT", 0, 0)
    local width = math.max(1, floating:GetWidth() - 48)
    active.content:SetWidth(width)
    layoutFrameOptions(active.content, width)
    floating:Show()
    ns.RefreshOptions(active.panel)
    floating.scroll.ScrollBar:SetValue(0)
    floating.scroll:SetVerticalScroll(0)
    return true
end

function ns.BindFrameOptions(frame, module)
    frame:EnableMouse(true)
    frame:HookScript("OnMouseUp", function(_, button)
        if button ~= "MiddleButton" or not ns.positioning or InCombatLockdown() then return end
        local owner, parent = module, frame
        while not owner and parent do
            owner = parent.frameOptionsOwner
            parent = parent:GetParent()
        end
        ns.OpenFrameOptions(owner, frame)
    end)
end
