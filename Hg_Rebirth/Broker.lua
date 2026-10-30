local _, ns = ...

local function launcherClick(button, mouseButton)
    if button and button.suppressClick then return end
    if mouseButton == "RightButton" then ns.TogglePositioning()
    else ns.OpenOptions() end
end

function Hg_Rebirth_OnCompartmentClick(_, buttonName)
    if mouseButton == "RightButton" then ns.TogglePositioning()
    else ns.OpenOptions() end
end

function Hg_Rebirth_OnCompartmentEnter(_, buttonFrame)
    MenuUtil.ShowTooltip(buttonFrame, function(tip)
        tip:SetOwner(buttonFrame, "ANCHOR_LEFT")
        tip:SetText(ns.title)
        tip:AddLine(ns.L["Open settings"], 1, 1, 1)
    end)
end

function Hg_Rebirth_OnCompartmentLeave(_, buttonFrame)
    MenuUtil.HideTooltip(buttonFrame)
end

local function minimapTooltip(self)
    MenuUtil.ShowTooltip(self, function(tip)
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(ns.title)
        tip:AddLine(ns.L["Left click: open settings."], 1, 1, 1)
        tip:AddLine(ns.L["Left drag: move minimap icon."], 1, 1, 1)
        tip:AddLine(ns.L["Right click: toggle positioning mode."], 1, 1, 1)
    end)
end

local function hideMinimapTooltip(self)
    MenuUtil.HideTooltip(self)
end

function ns.UpdateMinimap()
    if not ns.minimap then return end
    local settings = ns.modules.Core.db
    ns.minimap:SetShown(settings.minimap)
    local angle = math.rad(ns.minimap.dragAngle or settings.minimapAngle)
    ns.minimap:ClearAllPoints()
    ns.minimap:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * settings.minimapRadius, math.sin(angle) * settings.minimapRadius)
end

local function dragMinimap(button)
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    x = x / scale - Minimap:GetLeft() - Minimap:GetWidth() / 2
    y = y / scale - Minimap:GetBottom() - Minimap:GetHeight() / 2
    if x == 0 and y == 0 then return end
    button.dragAngle = math.deg(math.atan2(y, x)) % 360
    ns.UpdateMinimap()
end

local function stopMinimapDrag(button)
    button:SetScript("OnUpdate", nil)
    local angle = button.dragAngle
    button.dragAngle = nil
    if angle then ns.Set(ns.modules.Core, "minimapAngle", angle) end
end

function ns.InitializeBroker()
    local button = CreateFrame("Button", "Hg_Rebirth_MinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    button:SetSize(32, 32)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0, 0, 0, 1)
    background:SetSize(24, 24)
    background:SetPoint("CENTER", button)
    local backgroundMask = button:CreateMaskTexture()
    backgroundMask:SetAllPoints(background)
    backgroundMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    background:AddMaskTexture(backgroundMask)
    button.background = background
    button:SetNormalTexture("Interface\\Icons\\Inv_babymurlo3frost")
    local icon = button:GetNormalTexture()
    icon:ClearAllPoints()
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER", button)
    icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
    button.border = ns.Icon(button, "Interface\\Minimap\\MiniMap-TrackingBorder",
        56, 56, "TOPLEFT", button, "TOPLEFT", 0, 0)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function(self) self.suppressClick = nil end)
    button:SetScript("OnDragStart", function(self)
        self.suppressClick = true
        hideMinimapTooltip(self)
        self:SetScript("OnUpdate", dragMinimap)
        dragMinimap(self)
    end)
    button:SetScript("OnDragStop", stopMinimapDrag)
    button:SetScript("OnHide", stopMinimapDrag)
    button:SetScript("OnClick", launcherClick)
    button:SetScript("OnEnter", minimapTooltip)
    button:SetScript("OnLeave", hideMinimapTooltip)
    ns.minimap = button
    ns.UpdateMinimap()
    if LibStub then
        local broker = LibStub("LibDataBroker-1.1", true)
        if broker then
            broker:NewDataObject("Hg_Rebirth", {
                type = "launcher", text = ns.title, icon = "Interface\\Icons\\Inv_babymurlo3frost",
                OnClick = launcherClick,
            })
        end
    end
end
