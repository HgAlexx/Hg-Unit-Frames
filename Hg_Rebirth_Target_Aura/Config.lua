local ns = Hg_Rebirth
local Buff = ns.modules.TargetAura

function Buff:BuildOptions(category)
    ns.BuildAuraOptions(self, category, "Target Aura",
        "Target buffs and debuffs anchored to Target.", {
        { "enabled", "Show target auras" }, { "durationText", "Show original text timers" },
        { "auraTimers", "Show aura native cooldown" },
        { "showAuraBackground", "Show aura backgrounds" },
        { "castableBuffs", "Only show castable buffs" }, { "curableDebuffs", "Only show curable debuffs" },
        { "ownDebuffs", "Only show own debuffs on hostile targets" },
    },
        "Reset Target Aura settings", "Reset Target Aura settings for this character?")
end

if ns.loggedIn then
    Buff:Start()
    if ns.category then Buff:BuildOptions(ns.category); ns.RefreshOptions() end
end
