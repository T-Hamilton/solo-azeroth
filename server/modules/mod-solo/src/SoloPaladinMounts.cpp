/*
 * SoloPaladinMounts.cpp - class mounts for paladins of races that have no paladin trainer of their own.
 *
 * The Warhorse (13819) and Charger (23214) spells are race-locked in SkillLineAbility to the Alliance paladin races,
 * the Thalassian pair to Blood Elves, so a trainer never offers either to an Undead paladin (mod-solo-class-combos).
 * Learn them directly at the usual levels instead. Riding itself is still bought from a riding trainer.
 */
#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"

namespace
{
    constexpr uint32 SPELL_WARHORSE = 13819;
    constexpr uint32 SPELL_CHARGER  = 23214;

    bool NeedsHelp(Player* p)
    {
        // races that have no paladin trainer in 3.3.5 (Undead today; add others as combos are added)
        return p && p->getClass() == CLASS_PALADIN && p->getRace() == RACE_UNDEAD_PLAYER;
    }

    void GrantMounts(Player* p, bool announce)
    {
        if (!NeedsHelp(p))
            return;
        bool learned = false;
        if (p->GetLevel() >= 20 && !p->HasSpell(SPELL_WARHORSE))
        {
            p->learnSpell(SPELL_WARHORSE);
            learned = true;
        }
        if (p->GetLevel() >= 40 && !p->HasSpell(SPELL_CHARGER))
        {
            p->learnSpell(SPELL_CHARGER);
            learned = true;
        }
        if (learned && announce)
            ChatHandler(p->GetSession()).SendSysMessage("The Light, such as it is, grants you your warhorse. Riding skill is sold in Brill.");
    }
}

class SoloPaladinMountsPlayerScript : public PlayerScript
{
public:
    SoloPaladinMountsPlayerScript() : PlayerScript("SoloPaladinMountsPlayerScript", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEVEL_CHANGED }) { }

    void OnPlayerLogin(Player* p) override { GrantMounts(p, true); }
    void OnPlayerLevelChanged(Player* p, uint8 /*oldLevel*/) override { GrantMounts(p, true); }
};

void AddSoloPaladinMountsScripts()
{
    new SoloPaladinMountsPlayerScript();
}
