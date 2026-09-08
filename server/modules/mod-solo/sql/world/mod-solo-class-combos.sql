-- mod-solo: extra race/class combinations. Applied by solo.cmd (configs / start / first-run); idempotent.
--
-- Undead (race 5) Paladin (class 2). Never existed in retail, so the stock tables have no rows for it. Stats need
-- nothing (race stats and class stats are separate tables on this core) and the paladin spell/skill rows already
-- carry racemask 0 = every race. What is missing: a start position, an action bar, and starting gear (the client's
-- CharStartOutfit table has no entry for the combo, so without these rows the character would spawn naked).
-- The client also needs the combo in CharBaseInfo.dbc: client-patches\class-combos.txt, built into patch-Z.

-- start in Deathknell, same spot as an Undead warrior
DELETE FROM playercreateinfo WHERE race = 5 AND class = 2;
INSERT INTO playercreateinfo (race, class, map, zone, position_x, position_y, position_z, orientation)
SELECT 5, 2, map, zone, position_x, position_y, position_z, orientation FROM playercreateinfo WHERE race = 5 AND class = 1;

-- action bar: the Blood Elf paladin's
DELETE FROM playercreateinfo_action WHERE race = 5 AND class = 2;
INSERT INTO playercreateinfo_action (race, class, button, action, type)
SELECT 5, 2, button, action, type FROM playercreateinfo_action WHERE race = 10 AND class = 2;

-- starting gear: the Blood Elf paladin's outfit (CharStartOutfit.dbc race 10 class 2), plus the hearthstone
DELETE FROM playercreateinfo_item WHERE race = 5 AND class = 2;
INSERT INTO playercreateinfo_item (race, class, itemid, amount, Note) VALUES
    (5, 2, 24143, 1, 'Undead paladin: Initiate''s Chestguard'),
    (5, 2, 24145, 1, 'Undead paladin: Initiate''s Leggings'),
    (5, 2, 24146, 1, 'Undead paladin: Initiate''s Boots'),
    (5, 2, 23346, 1, 'Undead paladin: Battleworn Claymore'),
    (5, 2, 6948,  1, 'Undead paladin: Hearthstone');
