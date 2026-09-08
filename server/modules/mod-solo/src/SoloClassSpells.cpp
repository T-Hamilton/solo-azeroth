/*
 * SoloClassSpells.cpp - spells every character of a class simply gets at a level, no trainer, no talent point.
 *
 * Granted on login and on every level-up, so bots and existing characters pick them up too. A talent reset removes
 * talent spells (Crusader Strike is a Retribution talent in 3.3.5): the reset hook fires before the removal, so the
 * character is queued and re-granted on its next update tick instead.
 */
#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"

#include <unordered_set>

namespace
{
    struct ClassSpell
    {
        uint8       playerClass;
        uint8       level;
        uint32      spell;
        char const* note;   // shown once, when the spell is granted
    };

    ClassSpell const CLASS_SPELLS[] =
    {
        { CLASS_PALADIN, 8, 35395, "Crusader Strike is yours early. Retribution starts at 8 here." },
    };

    std::unordered_set<ObjectGuid> pendingAfterReset;

    void Grant(Player* p)
    {
        if (!p || !p->GetSession())
            return;
        for (ClassSpell const& cs : CLASS_SPELLS)
        {
            if (p->getClass() != cs.playerClass || p->GetLevel() < cs.level || p->HasSpell(cs.spell))
                continue;
            p->learnSpell(cs.spell);
            if (cs.note && *cs.note)
                ChatHandler(p->GetSession()).SendSysMessage(cs.note);
        }
    }
}

class SoloClassSpellsPlayerScript : public PlayerScript
{
public:
    SoloClassSpellsPlayerScript() : PlayerScript("SoloClassSpellsPlayerScript",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_TALENTS_RESET, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* p) override { Grant(p); }
    void OnPlayerLevelChanged(Player* p, uint8 /*oldLevel*/) override { Grant(p); }
    void OnPlayerTalentsReset(Player* p, bool /*noCost*/) override { if (p) pendingAfterReset.insert(p->GetGUID()); }

    void OnPlayerUpdate(Player* p, uint32 /*diff*/) override
    {
        if (pendingAfterReset.empty() || !p)
            return;
        auto it = pendingAfterReset.find(p->GetGUID());
        if (it == pendingAfterReset.end())
            return;
        pendingAfterReset.erase(it);
        Grant(p);
    }
};

void AddSoloClassSpellsScripts()
{
    new SoloClassSpellsPlayerScript();
}
