local addonName, ns = ...

ns.name = addonName
ns.title = "Hg Unit Frames"
ns.IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
ns.IsForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
ns.modules = {}
ns.order = {}
ns.pending = {}
_G.Hg_Rebirth = ns

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff80bfffHg Unit Frames:|r " .. message)
end

function ns.Warn(message)
    local core = ns.modules.Core
    if core and core.db and core.db.muteWarnings then return end
    ns.Print(message)
end

function ns.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function ns.AfterCombat(key, callback)
    if InCombatLockdown() then
        ns.pending[key] = callback
    else
        callback()
    end
end

function ns.Refresh()
    ns.stickyBatch = true
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        if module.Refresh then
            module:Refresh()
        end
        if ns.RefreshAnimation then ns.RefreshAnimation(module) end
    end
    ns.stickyBatch = false
    if ns.ApplySticky then ns.ApplySticky() end
    if ns.RefreshOptions then
        ns.RefreshOptions()
    end
end

function ns.RegisterModule(id, module)
    assert(not ns.modules[id], "Duplicate Hg_Rebirth module: " .. id)
    ns.modules[id] = module
    ns.order[#ns.order + 1] = id
    if ns.loggedIn then
        ns.InitializeModule(module)
        if module.Start then module:Start() end
        if ns.ApplySticky then ns.ApplySticky() end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        ns.InitializeStorage()
    elseif event == "PLAYER_LOGIN" then
        ns.loggedIn = true
        ns.characterKey = GetRealmName() .. "-" .. UnitName("player")
        for _, id in ipairs(ns.order) do ns.InitializeModule(ns.modules[id]) end
        for _, id in ipairs(ns.order) do
            local module = ns.modules[id]
            if module.Start then module:Start() end
        end
        ns.StartSticky()
        ns.StartPresetRules()
        ns.BuildOptions()
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.EndStickyDrag()
        if ns.positioning then
            ns.SetPositioning(false)
            ns.Print("Positioning mode ended on entering combat.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local pending = ns.pending
        ns.pending = {}
        for _, callback in pairs(pending) do callback() end
    end
end)

SLASH_HG_REBIRTH1 = "/hguf"
SlashCmdList.HG_REBIRTH = function()
    ns.OpenOptions()
end
