/*
 * SoloAdventurersCodex.cpp - the Adventurer's Codex item (entry 1099, ScriptName item_solo_adventurers_codex).
 *
 * The player-facing cousin of the GM Toolkit (SoloGMToolkit.cpp): the same one-click dungeon-quest granting, plus a
 * portable class trainer. One right-click opens a gossip menu with:
 *   - "Train my class": learns every class spell the character already qualifies for at its current level, for free.
 *     Re-usable - come back after each level-up to pick up the newly available ranks.
 *   - "Quests for this dungeon" (only while standing in one) and "Dungeon quests (pick a dungeon)": add every quest
 *     tied to a dungeon in one click (shared with the toolkit, see SoloDungeonQuests.cpp).
 * Unlike the toolkit this carries no GM cheats and is handed to every real player on login (bots are skipped).
 *
 * Stock data only: entry 1099 is "Deprecated Codex of Sustenance II", an item every 3.3.5 client already has in
 * Item.dbc (a book icon), renamed by sql/world/mod-solo-items.sql; its use spell is a stock instant dummy that OnUse
 * intercepts before it is cast.
 *
 * The trainer mirrors the core's `.learn all_my_class` trainer pass (cs_learn.cpp): it walks the class's trainers and
 * teaches every spell CanTeachSpell() approves. That check already enforces the level, race/class, skill and
 * prerequisite-rank requirements, so the player never gets a spell a real trainer would withhold at their level.
 */
#include "SoloDungeonQuests.h"

#include "Chat.h"
#include "GossipDef.h"
#include "Item.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerbotMgr.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "Trainer.h"
#include "WorldSession.h"

#include <string>
#include <vector>

namespace
{
    constexpr uint32 CODEX_ITEM = 1099;

    enum Menu : uint32 { MENU_MAIN = 1, MENU_DQ_EXP, MENU_DQ_LIST };
    enum MainAction : uint32 { MAIN_TRAIN = 1, MAIN_DQ, MAIN_DQ_HERE, MAIN_CLOSE };
    constexpr uint32 ACTION_MAIN = 1000;   // "back to the main menu" in every submenu
    constexpr uint32 ACTION_DQ_EXP = 999;  // "back to the expansion list" in a dungeon-quest list

    void Msg(Player* p, std::string const& text) { ChatHandler(p->GetSession()).SendSysMessage(text); }
    void Send(Player* p, Item* item) { SendGossipMenuFor(p, DEFAULT_GOSSIP_MESSAGE, item->GetGUID()); }

    bool IsBot(Player* p) { return PlayerbotsMgr::instance().GetPlayerbotAI(p) != nullptr; }

    // Learn every class spell the player already qualifies for at its current level (the core's trainer pass).
    void TrainClass(Player* p)
    {
        CloseGossipMenuFor(p);

        std::vector<Trainer::Trainer const*> const* trainers = nullptr;
        try { trainers = &sObjectMgr->GetClassTrainers(p->getClass()); }
        catch (std::out_of_range const&) { }
        if (!trainers)
        {
            Msg(p, "Adventurer's Codex: no trainer is available for your class.");
            return;
        }

        uint32 learned = 0;
        bool hadNew;
        do   // a fresh rank can unlock the next one, so keep passing until nothing new is taught
        {
            hadNew = false;
            for (Trainer::Trainer const* trainer : *trainers)
            {
                if (!trainer->IsTrainerValidForPlayer(p))
                    continue;
                for (Trainer::Spell const& spell : trainer->GetSpells())
                {
                    if (!trainer->CanTeachSpell(p, &spell))
                        continue;
                    if (spell.IsCastable())
                        p->CastSpell(p, spell.SpellId, true);
                    else
                        p->learnSpell(spell.SpellId, false);
                    ++learned;
                    hadNew = true;
                }
            }
        } while (hadNew);

        std::string lvl = std::to_string(p->GetLevel());
        if (learned)
            Msg(p, "Adventurer's Codex: learned " + std::to_string(learned) + " new spell" + (learned == 1 ? "" : "s") +
                   " for level " + lvl + ". Check your spellbook.");
        else
            Msg(p, "Adventurer's Codex: nothing new to train at level " + lvl + ". Level up and read it again.");
    }

    // ---- menus --------------------------------------------------------------------------------------------------
    void ShowMain(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        AddGossipItemFor(p, GOSSIP_ICON_TRAINER, "Train my class (learn all spells for my level)", MENU_MAIN, MAIN_TRAIN);
        if (SoloDungeon const* here = SoloDungeonForMap(p->GetMapId()))
            AddGossipItemFor(p, GOSSIP_ICON_DOT, "Quests for this dungeon: " + here->name + " (" + std::to_string(here->quests.size()) + ")", MENU_MAIN, MAIN_DQ_HERE);
        if (!SoloDungeonList().empty())
            AddGossipItemFor(p, GOSSIP_ICON_DOT, "Dungeon quests (pick a dungeon)", MENU_MAIN, MAIN_DQ);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "Close", MENU_MAIN, MAIN_CLOSE);
        Send(p, item);
    }

    // Dungeon quests: expansion -> dungeon -> add all of its quests (32 rows per page, so split by expansion).
    void ShowDungeonQuestExpansions(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        std::vector<std::string> const& exps = SoloDungeonExpansions();
        for (uint32 i = 0; i < exps.size(); ++i)
        {
            uint32 n = 0;
            for (SoloDungeon const& d : SoloDungeonList())
                if (d.expansion == exps[i]) ++n;
            AddGossipItemFor(p, GOSSIP_ICON_DOT, exps[i] + " (" + std::to_string(n) + " dungeons)", MENU_DQ_EXP, i);
        }
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "<- Back", MENU_DQ_EXP, ACTION_MAIN);
        Send(p, item);
    }

    void ShowDungeonQuestList(Player* p, Item* item, uint32 expIndex)
    {
        std::vector<std::string> const& exps = SoloDungeonExpansions();
        if (expIndex >= exps.size()) { ShowDungeonQuestExpansions(p, item); return; }
        ClearGossipMenuFor(p);
        std::vector<SoloDungeon> const& list = SoloDungeonList();
        for (uint32 i = 0; i < list.size(); ++i)
        {
            SoloDungeon const& d = list[i];
            if (d.expansion != exps[expIndex])
                continue;
            std::string label = d.name + " (lvl " + std::to_string(d.level) + ", " + std::to_string(d.quests.size()) + " quest" + (d.quests.size() == 1 ? "" : "s") + ")";
            AddGossipItemFor(p, d.map == p->GetMapId() ? GOSSIP_ICON_BATTLE : GOSSIP_ICON_DOT, label, MENU_DQ_LIST, i);
        }
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "<- Expansions", MENU_DQ_LIST, ACTION_DQ_EXP);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "<- Back", MENU_DQ_LIST, ACTION_MAIN);
        Send(p, item);
    }

    void GrantDungeon(Player* p, SoloDungeon const& d)
    {
        CloseGossipMenuFor(p);
        Msg(p, SoloGrantDungeonQuests(p, d));
    }
}

class item_solo_adventurers_codex : public ItemScript
{
public:
    item_solo_adventurers_codex() : ItemScript("item_solo_adventurers_codex") { }

    bool OnUse(Player* player, Item* item, SpellCastTargets const& /*targets*/) override
    {
        if (!player || !item)
            return false;
        ShowMain(player, item);
        return true;   // handled: the item's placeholder spell is not cast
    }

    void OnGossipSelect(Player* p, Item* item, uint32 sender, uint32 action) override
    {
        if (!p || !item)
        {
            CloseGossipMenuFor(p);
            return;
        }
        if (sender != MENU_MAIN && action == ACTION_MAIN)
        {
            ShowMain(p, item);
            return;
        }
        switch (sender)
        {
            case MENU_MAIN:
                switch (action)
                {
                    case MAIN_TRAIN: TrainClass(p); return;
                    case MAIN_DQ:    ShowDungeonQuestExpansions(p, item); return;
                    case MAIN_DQ_HERE:
                        if (SoloDungeon const* here = SoloDungeonForMap(p->GetMapId()))
                            GrantDungeon(p, *here);
                        else
                            CloseGossipMenuFor(p);
                        return;
                    default: CloseGossipMenuFor(p); return;
                }
            case MENU_DQ_EXP:
                ShowDungeonQuestList(p, item, action);
                return;
            case MENU_DQ_LIST:
                if (action == ACTION_DQ_EXP)
                    ShowDungeonQuestExpansions(p, item);
                else if (action < SoloDungeonList().size())
                    GrantDungeon(p, SoloDungeonList()[action]);
                else
                    CloseGossipMenuFor(p);
                return;
            default:
                CloseGossipMenuFor(p);
                return;
        }
    }
};

// every real player gets the codex on login (bots are skipped: they never read it and it only clutters their bags)
class SoloAdventurersCodexPlayerScript : public PlayerScript
{
public:
    SoloAdventurersCodexPlayerScript() : PlayerScript("SoloAdventurersCodexPlayerScript", { PLAYERHOOK_ON_LOGIN }) { }

    void OnPlayerLogin(Player* p) override
    {
        if (!p || IsBot(p))
            return;
        if (p->HasItemCount(CODEX_ITEM, 1, true))
            return;
        if (p->AddItem(CODEX_ITEM, 1))
            Msg(p, "An Adventurer's Codex has been slipped into your bags. Right-click it to train or grab dungeon quests.");
        else
            LOG_INFO("server.loading", "mod-solo: could not give the Adventurer's Codex to {} (bags full?)", p->GetName());
    }
};

void AddSoloAdventurersCodexScripts()
{
    new item_solo_adventurers_codex();
    new SoloAdventurersCodexPlayerScript();
}
