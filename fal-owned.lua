-------------------------------------------------------------------------------------------------------------------
-- fal-owned.lua -- how many copies of an item this account owns, for items where it matters.
--
-- WHY SEPARATE FROM ItemStats.lua: ItemStats is generated from an inventory export and
-- its header says not to hand-edit generated values. Ownership counts are maintained by
-- hand, so they live here and survive an ItemStats regeneration.
--
-- ONLY items owned in quantity > 1 need an entry. validate.lua uses this to decide
-- whether a set placing the same item in both rings (or both ears) is legal.
-- Anything absent is assumed to be a single copy.
--
-- Confirmed by the player, 2026-09-03.
-------------------------------------------------------------------------------------------------------------------

return {
    ['Stikini Ring +1']   = 2,
    ['Chirich Ring +1']   = 2,
    ["Blenmot's Ring +1"] = 2,
    ['Mache Earring +1']  = 2,
}
