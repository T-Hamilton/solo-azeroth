-- mod-solo items. Applied by solo.cmd (configs / start / first-run) with the MySQL client; idempotent.
--
-- Both items reuse "Deprecated" entries from the stock world database, because every 3.3.5 client already has
-- those ids in Item.dbc (a brand-new id would need a client patch to show an icon). Only the columns that matter
-- are changed: displayid is left alone so the icon is whatever the client expects for that id.
-- The use spell on both is 18282 "Dummy Spell" (stock, instant, self, no visual): the item scripts intercept OnUse
-- before it is cast, so it never runs. The scripts live in src/ (ScriptName below).

-- GM Toolkit: entry 3878 "Deprecated Conjured Mana Jewel" (class 15 misc, gem icon).
UPDATE item_template SET
    name = 'GM Toolkit', description = 'Teleports, GM powers and character helpers. Right-click.',
    Quality = 6, ItemLevel = 1, RequiredLevel = 0, RequiredSkill = 0, AllowableClass = -1, AllowableRace = -1,
    BuyCount = 1, BuyPrice = 0, SellPrice = 0, stackable = 1, maxcount = 1, bonding = 1, Flags = 64,
    spellid_1 = 18282, spelltrigger_1 = 0, spellcharges_1 = 0, spellcooldown_1 = 1000, spellcategory_1 = 0, spellcategorycooldown_1 = -1,
    spellid_2 = 0, spellid_3 = 0, spellid_4 = 0, spellid_5 = 0,
    ScriptName = 'item_solo_gm_toolkit'
WHERE entry = 3878;

-- Potion of Experience: entry 2461 "Deprecated Elemental Resistance Potion" (class 0 consumable, subclass 1 potion).
UPDATE item_template SET
    name = 'Potion of Experience',
    description = 'Drink for +100% experience for one hour. Drink up to five for +500%.',
    Quality = 7, ItemLevel = 1, RequiredLevel = 0, RequiredSkill = 0, AllowableClass = -1, AllowableRace = -1,
    BuyCount = 1, BuyPrice = 0, SellPrice = 0, stackable = 20, maxcount = 0, bonding = 1, Flags = 64,
    spellid_1 = 18282, spelltrigger_1 = 0, spellcharges_1 = 0, spellcooldown_1 = 1000, spellcategory_1 = 0, spellcategorycooldown_1 = -1,
    spellid_2 = 0, spellid_3 = 0, spellid_4 = 0, spellid_5 = 0,
    ScriptName = 'item_solo_xp_potion'
WHERE entry = 2461;
