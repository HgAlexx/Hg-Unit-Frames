local _, ns = ...
local definitions = {
    { id = "Player", module = "Player", label = "Player" },
    { id = "Target", module = "Target", label = "Target", parent = "Player" },
    { id = "TargetTarget", module = "TargetTarget", label = "Target Target", entry = "tot", parent = "Target" },
    { id = "TargetTargetTarget", module = "TargetTarget", label = "Target Target Target",
        entry = "target", prefix = "targetSticky", parent = "TargetTarget" },
    { id = "PlayerPet", module = "PlayerPet", label = "Player Pet", parent = "Player" },
    { id = "PlayerPetTarget", module = "PlayerPet", label = "Pet's target",
        entry = "target", prefix = "targetSticky", parent = "PlayerPet" },
    { id = "Focus", module = "Focus", label = "Focus" },
    { id = "FocusTarget", module = "FocusTarget", label = "Focus Target", parent = "Focus" },
    { id = "Party", module = "Party", label = "Party" },
    { id = "PartyTarget", module = "PartyTarget", label = "Party Target", group = true, parent = "Party" },
    { id = "PartyPet", module = "PartyPet", label = "Party Pet", group = true, parent = "Party" },
}
local byId, cache = {}, {}
local applying, ready, dragging
local driver = CreateFrame("Frame")
for _, definition in ipairs(definitions) do byId[definition.id] = definition end

local function prefix(definition) return definition.prefix or "sticky" end
local function owner(definition) return ns.modules[definition.module] end
local function entries(definition)
    local module = owner(definition)
    if not module or not module.frame or module.unavailable then return end
    if definition.group then return module.members end
    local entry = definition.entry and module[definition.entry] or module
    return entry and { entry }
end
local function scaleKey(definition)
    return definition.entry == "target" and "targetScale" or "scale"
end
local function finite(value)
    return not ns.IsSecret(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function rect(entry)
    local result
    local boxes = { entry.nameBox or entry.frame }
    for _, key in ipairs({ "stats", "levelBox", "portraitBox" }) do
        if entry[key] then boxes[#boxes + 1] = entry[key] end
    end
    for _, box in ipairs(boxes) do
        if box and (box == entry.frame or box:IsShown()) then
            local scale = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local left, right, top, bottom = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
            if not finite(scale) or scale <= 0 or not finite(left) or not finite(right)
                or not finite(top) or not finite(bottom) then return end
            left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
            if not result then result = { left, bottom, right, top }
            else
                result[1], result[2] = math.min(result[1], left), math.min(result[2], bottom)
                result[3], result[4] = math.max(result[3], right), math.max(result[4], top)
            end
        end
    end
    return result
end

local function bounds(definition)
    local module = owner(definition)
    local list = definition.id == "Party" and module and module.members or entries(definition)
    local result
    for _, entry in ipairs(list or {}) do
        local current = rect(entry)
        if not current then return end
        if not result then result = current
        else
            result[1], result[2] = math.min(result[1], current[1]), math.min(result[2], current[2])
            result[3], result[4] = math.max(result[3], current[3]), math.max(result[4], current[4])
        end
    end
    return result
end

local function anchor(child, parent, low, high)
    local best, ca, pa
    for c = 0, 1 do
        for p = 0, 1 do
            local gap = child[c == 0 and low or high] - parent[p == 0 and low or high]
            if not best or math.abs(gap) < math.abs(best) then best, ca, pa = gap, c, p end
        end
    end
    return best, ca, pa
end

local function positionKeys(definition, entry)
    if definition.entry == "target" then return "targetX", "targetY" end
    return entry.xKey or "x", entry.yKey or "y"
end

function ns.StickyWouldCycle(id, parent, candidates)
    local visited = { [id] = true }
    while parent ~= "" do
        if visited[parent] then return true end
        visited[parent] = true
        local definition = byId[parent]
        if not definition then return true end
        local module = owner(definition)
        local db = candidates and candidates[definition.module] or module and module.db
        parent = db and db[prefix(definition) .. "Parent"] or ""
    end
    return false
end

function ns.ValidateSticky(candidates)
    for _, definition in ipairs(definitions) do
        local db = candidates[definition.module]
        if db and ns.StickyWouldCycle(definition.id, db[prefix(definition) .. "Parent"] or "", candidates) then
            return false, ns.L["Sticky links cannot form a circular chain."]
        end
    end
    return true
end

function ns.InitializeStickyModule(module)
    local matched
    local legacyDefaults = {}
    for _, definition in ipairs(definitions) do
        if owner(definition) == module then
            matched = true
            local key = prefix(definition)
            local function default(suffix, value)
                legacyDefaults[key .. suffix] = value
                if module.defaults[key .. suffix] == nil then module.defaults[key .. suffix] = value end
            end
            default("Parent", definition.parent or "")
            default("Move", definition.parent ~= nil)
            default("Scale", false)
            for index = 1, definition.group and 4 or 1 do
                default(index .. "Placed", false)
                for _, suffix in ipairs({ "X", "Y", "ChildX", "ChildY", "ParentX", "ParentY" }) do
                    default(index .. suffix, 0)
                end
                module.ranges = module.ranges or {}
                for _, suffix in ipairs({ "ChildX", "ChildY", "ParentX", "ParentY" }) do
                    module.ranges[key .. index .. suffix] = { 0, 1 }
                end
            end
        end
    end
    if not matched then return end
    if module == ns.modules.TargetTarget then
        if module.defaults.targetScale == nil then module.defaults.targetScale = module.defaults.scale end
        module.ranges.targetScale = { 0.01, 1.49 }
    end
    for _, preset in pairs(ns.presets) do
        for id, candidate in pairs(ns.modules) do
            if candidate == module and preset[id] then
                if module == ns.modules.TargetTarget and preset[id].targetScale == nil then
                    preset[id].targetScale = preset[id].scale
                end
                for key, value in pairs(module.defaults) do
                    if preset[id][key] == nil then
                        local legacy = legacyDefaults[key]
                        if legacy ~= nil then value = legacy end
                        preset[id][key] = ns.Copy(value)
                    end
                end
            end
        end
    end
    ns.HookStickyLayout(module)
end

function ns.HookStickyLayout(module)
    if not module.Layout or module.stickyLayout == module.Layout then return end
    local layout = module.Layout
    module.Layout = function(self, ...)
        layout(self, ...)
        ns.ApplySticky()
    end
    module.stickyLayout = module.Layout
end

local function applyDefinition(definition, visited)
    if visited[definition.id] then return end
    visited[definition.id] = true
    local module, list = owner(definition), entries(definition)
    if not module or not list then return end
    local db, key = module.db, prefix(definition)
    local parent = byId[db[key .. "Parent"]]
    if parent and not ns.StickyWouldCycle(definition.id, parent.id) then
        applyDefinition(parent, visited)
    else parent = nil end
    local parentEntries = parent and entries(parent)
    if parentEntries and db[key .. "Scale"] then
        local value = owner(parent).db[scaleKey(parent)]
        if db[scaleKey(definition)] ~= value then
            db[scaleKey(definition)] = value
            module:Layout()
        end
    end
    for index, entry in ipairs(list) do
        local xKey, yKey = positionKeys(definition, entry)
        local stored = key .. index
        local previous = cache[stored .. definition.id]
        local child = definition.id == "Party" and bounds(definition) or rect(entry)
        local relative = parentEntries and
            (definition.group and parent.id == "Party" and rect(owner(parent).members[index]) or bounds(parent))
        if relative and child and db[key .. "Move"] then
            if not db[stored .. "Placed"] or (previous and
                (previous.x ~= db[xKey] or previous.y ~= db[yKey] or previous.parent ~= parent.id)) then
                db[stored .. "X"], db[stored .. "ChildX"], db[stored .. "ParentX"] = anchor(child, relative, 1, 3)
                db[stored .. "Y"], db[stored .. "ChildY"], db[stored .. "ParentY"] = anchor(child, relative, 2, 4)
                if definition.group and parent.id ~= "Party" then
                    local groupBounds = bounds(definition)
                    local _, _, px = anchor(groupBounds, relative, 1, 3)
                    local _, _, py = anchor(groupBounds, relative, 2, 4)
                    db[stored .. "ParentX"], db[stored .. "ParentY"] = px, py
                    db[stored .. "X"] = child[1] + (child[3] - child[1]) * db[stored .. "ChildX"]
                        - relative[1] - (relative[3] - relative[1]) * px
                    db[stored .. "Y"] = child[2] + (child[4] - child[2]) * db[stored .. "ChildY"]
                        - relative[2] - (relative[4] - relative[2]) * py
                end
                db[stored .. "Placed"] = true
            end
            local cx, cy = db[stored .. "ChildX"], db[stored .. "ChildY"]
            local px, py = db[stored .. "ParentX"], db[stored .. "ParentY"]
            local dx = relative[1] + (relative[3] - relative[1]) * px + db[stored .. "X"]
                - child[1] - (child[3] - child[1]) * cx
            local dy = relative[2] + (relative[4] - relative[2]) * py + db[stored .. "Y"]
                - child[2] - (child[4] - child[2]) * cy
            local ratio = entry.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            if finite(dx) and finite(dy) and finite(ratio) and ratio > 0 then
                db[xKey], db[yKey] = db[xKey] + dx / ratio, db[yKey] + dy / ratio
                if not dragging or dragging.frame ~= entry.frame then
                    entry.frame:ClearAllPoints()
                    entry.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[xKey], db[yKey])
                end
            else ns.Warn(ns.L["Sticky frame geometry is unavailable."]) end
        end
        cache[stored .. definition.id] = { x = db[xKey], y = db[yKey], parent = parent and parent.id }
    end
end

function ns.ApplySticky()
    if not ready or applying or ns.stickyBatch then return end
    if InCombatLockdown() then ns.AfterCombat("Sticky", ns.ApplySticky); return end
    applying = true
    local visited = {}
    for _, definition in ipairs(definitions) do applyDefinition(definition, visited) end
    applying = false
end

function ns.StartSticky()
    local candidates = {}
    for _, id in ipairs(ns.order) do candidates[id] = ns.modules[id].db end
    local valid, err = ns.ValidateSticky(candidates)
    if not valid then error(err) end
    ready = true
    ns.ApplySticky()
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:SetScript("OnEvent", function()
    if not ready then return end
    for _, definition in ipairs(definitions) do
        local module = owner(definition)
        if module then ns.HookStickyLayout(module) end
    end
    ns.ApplySticky()
end)

function ns.ResetStickyCache() cache = {} end

function ns.BeginStickyDrag(module, frame, xKey, yKey)
    dragging = { module = module, frame = frame, x = xKey, y = yKey }
    driver:SetScript("OnUpdate", function()
        if InCombatLockdown() then ns.EndStickyDrag(); return end
        local frame = dragging.frame
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, top = frame:GetLeft(), frame:GetTop()
        if not finite(scale) or scale <= 0 or not finite(x) or not finite(top) then
            ns.Warn(ns.L["Sticky frame geometry is unavailable."])
            ns.EndStickyDrag()
            return
        end
        dragging.module.db[dragging.x] = x
        dragging.module.db[dragging.y] = top - UIParent:GetHeight() / scale
        ns.ApplySticky()
    end)
end

function ns.EndStickyDrag()
    dragging = nil
    driver:SetScript("OnUpdate", nil)
end

function ns.StickyScaleControlled(module, key)
    for _, definition in ipairs(definitions) do
        if owner(definition) == module and scaleKey(definition) == key then
            local p = prefix(definition)
            local parent = byId[module.db[p .. "Parent"]]
            return parent ~= nil and entries(parent) ~= nil and module.db[p .. "Scale"]
        end
    end
    return false
end

function ns.StickyOptions(content, module)
    ns.Section(content, "Sticky mode")
    ns.Description(content, "Keep the current edge gap when the parent moves or scales. Dragging a child updates its offset without detaching it.")
    for _, definition in ipairs(definitions) do
        if owner(definition) == module then
            local id, key = definition.id, prefix(definition)
            ns.Select(content, definition.label, function()
                local choices = { { text = "None", value = "" } }
                for _, candidate in ipairs(definitions) do
                    if entries(candidate) and not ns.StickyWouldCycle(id, candidate.id) then
                        choices[#choices + 1] = { text = candidate.label, value = candidate.id }
                    end
                end
                return choices
            end, function() return module.db[key .. "Parent"] end, function(value)
                ns.Set(module, key .. "Parent", value)
            end)
            ns.SubOptions(content, function() return module.db[key .. "Parent"] ~= "" end, function()
                ns.Check(content, module, key .. "Move", "Move with parent")
                ns.Check(content, module, key .. "Scale", "Scale with parent")
            end)
        end
    end
end
