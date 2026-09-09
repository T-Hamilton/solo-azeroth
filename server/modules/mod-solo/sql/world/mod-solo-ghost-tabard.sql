-- mod-solo: a ghostly-blue recolour of the Contest Winner's Tabard, as a NEW item (the purple original, 19160, is
-- untouched). We reuse the spare "Unused Tabard of Chow" (item 3557, ItemDisplayInfo 1680) which the Ascension client
-- already knows; patch-Z (tools/ghost_tabard.py) supplies the blue Contest design under that display's
-- Tabard_A_01Lordaeron_Chest_TU / _TL texture names, so only this item changes appearance. Idempotent.
UPDATE item_template
SET name = "Contest Winner's Tabard (Ghost)", Quality = 3
WHERE entry = 3557;
