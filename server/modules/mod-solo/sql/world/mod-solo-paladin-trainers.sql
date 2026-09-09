-- mod-solo: paladin trainers for the Forsaken (Undead Paladin, mod-solo-class-combos.sql). Idempotent.
--
-- In 3.3.5 the Horde's only paladin trainers are Blood Elves in Eversong / Silvermoon. Three copies of those
-- trainers, wearing Forsaken models, stand next to the warrior trainers in Deathknell (starter list: the first five
-- spells), Brill and Undercity (the full 177-spell list, trainer 4). Entries 9200101-9200103, spawn guids
-- 7100001-7100003. Loaded at world start.

DELETE FROM creature WHERE guid IN (7100001, 7100002, 7100003);
DELETE FROM creature_default_trainer WHERE CreatureId IN (9200101, 9200102, 9200103);
DELETE FROM creature_template_model WHERE CreatureID IN (9200101, 9200102, 9200103);
DELETE FROM creature_template WHERE entry IN (9200101, 9200102, 9200103);

-- templates: copies of Jesthenis Sunstriker (15280, starter), Noellene (16275) and Champion Bachi (16681)
INSERT INTO creature_template (entry, name, subname,
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, VerifiedBuild)
SELECT 9200101, 'Aldric the Redeemed', 'Paladin Trainer',
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, 0
FROM creature_template WHERE entry = 15280;

INSERT INTO creature_template (entry, name, subname,
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, VerifiedBuild)
SELECT 9200102, 'Sister Ophelia Blackthorn', 'Paladin Trainer',
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, 0
FROM creature_template WHERE entry = 16275;

INSERT INTO creature_template (entry, name, subname,
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, VerifiedBuild)
SELECT 9200103, 'Lord Corvane Duskbane', 'Paladin Trainer',
    difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, IconName, gossip_menu_id,
    minlevel, maxlevel, exp, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, `rank`,
    dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags,
    unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId,
    mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, ManaModifier, ArmorModifier,
    ExperienceModifier, RacialLeader, movementId, RegenHealth, CreatureImmunitiesId, flags_extra, ScriptName, 0
FROM creature_template WHERE entry = 16681;

-- Forsaken looks: the models of the warrior trainers they stand next to
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT 9200101, 0, CreatureDisplayID, DisplayScale, Probability, 0 FROM creature_template_model WHERE CreatureID = 2119 AND Idx = 0;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT 9200102, 0, CreatureDisplayID, DisplayScale, Probability, 0 FROM creature_template_model WHERE CreatureID = 2131 AND Idx = 0;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT 9200103, 0, CreatureDisplayID, DisplayScale, Probability, 0 FROM creature_template_model WHERE CreatureID = 4595 AND Idx = 0;

-- what they teach: trainer 6 = the five starter spells, trainer 4 = the full Horde paladin list
INSERT INTO creature_default_trainer (CreatureId, TrainerId) VALUES (9200101, 6), (9200102, 4), (9200103, 4);

-- where they stand: a few yards from Dannal Stern (Deathknell), Austil de Mon (Brill), Baltus Fowler (Undercity)
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation,
    spawntimesecs, wander_distance, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, dynamicflags, ScriptName, VerifiedBuild, CreateObject, Comment)
VALUES
    (7100001, 9200101, 0, 0, 0, 1, 1, 0, 1866.0, 1553.0, 94.88, 2.5, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'mod-solo: Forsaken paladin trainer, Deathknell'),
    (7100002, 9200102, 0, 0, 0, 1, 1, 0, 2258.5, 236.0, 33.72, 0.5, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'mod-solo: Forsaken paladin trainer, Brill'),
    (7100003, 9200103, 0, 0, 0, 1, 1, 0, 1771.0, 415.0, -57.11, 0.12, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 0, 'mod-solo: Forsaken paladin trainer, Undercity');

-- the source trainers carry SmartAI scripts keyed by their own entry; the copies have none, so no AI name
UPDATE creature_template SET AIName = '' WHERE entry IN (9200101, 9200102, 9200103);

-- list 4 was copied from the Blood Elf paladin trainer, so it natively carries the Thalassian (Blood Elf) mounts
-- Summon Thalassian Warhorse (34767) and Summon Thalassian Charger (34769). Undead paladins ride the Alliance-model
-- Warhorse / Charger recoloured to the Ochre Skeletal palette (server/local/ghost-mounts.sql), so drop the Blood Elf
-- pair here or the trainer offers a second, un-recoloured 60%/100% horse next to the right one.
DELETE FROM trainer_spell WHERE TrainerId = 4 AND SpellId IN (34767, 34769);

-- the Forsaken trainers (trainer list 4, the Horde paladin list) also offer the Alliance-model Warhorse / Charger
-- spells, which is what mod-solo teaches Undead paladins; their race lock is cleared in SkillLineAbility.dbc
DELETE FROM trainer_spell WHERE TrainerId = 4 AND SpellId IN (13819, 23214);
INSERT INTO trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqAbility2, ReqAbility3, ReqLevel, VerifiedBuild) VALUES
    (4, 13819, 1000, 0, 0, 0, 0, 0, 20, 0),
    (4, 23214, 3500, 0, 0, 13819, 33391, 0, 40, 0);
