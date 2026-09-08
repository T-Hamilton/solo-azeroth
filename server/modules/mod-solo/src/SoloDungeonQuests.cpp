/*
 * SoloDungeonQuests.cpp - grant every quest tied to a dungeon in one click (GM Toolkit > Dungeon quests).
 *
 * The map of dungeon -> quests is data, not code: world table solo_dungeon_quests, written by
 * tools/build_dungeon_quests.py from the quest/creature/loot tables (a quest belongs to a dungeon when something it
 * needs - a kill, an object, a dungeon-only drop, an in-instance quest giver - is inside that map). The table is
 * read at startup and on `.reload config`, so regenerating it never needs a rebuild.
 *
 * Granting mirrors `.quest add`: quests already in the log / done are skipped, quests for another race or class are
 * skipped, quests that start from an item are skipped (the core cannot add those cleanly), and the run stops when
 * the 25-slot quest log is full. Level and chain prerequisites are ignored on purpose - this is a GM tool.
 */
#include "SoloDungeonQuests.h"

#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <unordered_set>

namespace
{
    std::vector<SoloDungeon> dungeons;
    std::vector<std::string> expansions;

    void LoadDungeonQuests(bool reload)
    {
        std::vector<SoloDungeon> list;
        std::vector<std::string> exps;
        QueryResult r = WorldDatabase.Query(
            "SELECT map, quest, dungeon, expansion, level_hint FROM solo_dungeon_quests ORDER BY sort_order, quest_level, quest");
        if (r)
        {
            do
            {
                Field* f = r->Fetch();
                uint32 map = f[0].Get<uint32>();
                if (list.empty() || list.back().map != map)
                {
                    SoloDungeon d;
                    d.map = map;
                    d.name = f[2].Get<std::string>();
                    d.expansion = f[3].Get<std::string>();
                    d.level = f[4].Get<uint32>();
                    if (std::find(exps.begin(), exps.end(), d.expansion) == exps.end())
                        exps.push_back(d.expansion);
                    list.push_back(std::move(d));
                }
                list.back().quests.push_back(f[1].Get<uint32>());
            } while (r->NextRow());
        }
        size_t total = 0;
        for (SoloDungeon const& d : list)
            total += d.quests.size();
        dungeons = std::move(list);
        expansions = std::move(exps);
        LOG_INFO("server.loading", "mod-solo: dungeon quests: {} dungeons, {} quests{}", dungeons.size(), total,
                 reload ? " (reloaded)" : "");
        if (dungeons.empty())
            LOG_WARN("server.loading", "mod-solo: solo_dungeon_quests is empty - run tools/build_dungeon_quests.py and solo.cmd configs");
    }

    // quests that start from an item: `.quest add` refuses these too (the quest item logic breaks without the item)
    std::unordered_set<uint32> const& ItemStartedQuests()
    {
        static std::unordered_set<uint32> set;
        static bool built = false;
        if (!built)
        {
            built = true;
            for (auto const& kv : *sObjectMgr->GetItemTemplateStore())
                if (kv.second.StartQuest)
                    set.insert(kv.second.StartQuest);
        }
        return set;
    }
}

std::vector<SoloDungeon> const& SoloDungeonList() { return dungeons; }
std::vector<std::string> const& SoloDungeonExpansions() { return expansions; }

SoloDungeon const* SoloDungeonForMap(uint32 map)
{
    for (SoloDungeon const& d : dungeons)
        if (d.map == map)
            return &d;
    return nullptr;
}

std::string SoloGrantDungeonQuests(Player* p, SoloDungeon const& d)
{
    uint32 added = 0, have = 0, wrongFor = 0, itemStart = 0, unknown = 0, noRoom = 0;
    for (uint32 id : d.quests)
    {
        Quest const* quest = sObjectMgr->GetQuestTemplate(id);
        if (!quest) { ++unknown; continue; }
        if (p->GetQuestStatus(id) != QUEST_STATUS_NONE || p->IsQuestRewarded(id)) { ++have; continue; }
        if (!p->SatisfyQuestRace(quest, false) || !p->SatisfyQuestClass(quest, false)) { ++wrongFor; continue; }
        if (ItemStartedQuests().count(id)) { ++itemStart; continue; }
        if (!p->SatisfyQuestLog(false)) { ++noRoom; continue; }
        p->AddQuestAndCheckCompletion(quest, nullptr);
        ++added;
    }
    std::string s = d.name + ": " + std::to_string(added) + " quest" + (added == 1 ? "" : "s") + " added";
    if (have)      s += ", " + std::to_string(have) + " already in log or done";
    if (wrongFor)  s += ", " + std::to_string(wrongFor) + " for another race/class";
    if (itemStart) s += ", " + std::to_string(itemStart) + " start from an item (loot it)";
    if (unknown)   s += ", " + std::to_string(unknown) + " unknown";
    if (noRoom)    s += ", " + std::to_string(noRoom) + " skipped: quest log full (25). Turn some in and click again";
    return s + ".";
}

class SoloDungeonQuestsWorldScript : public WorldScript
{
public:
    SoloDungeonQuestsWorldScript() : WorldScript("SoloDungeonQuestsWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool reload) override { LoadDungeonQuests(reload); }
};

void AddSoloDungeonQuestsScripts()
{
    new SoloDungeonQuestsWorldScript();
}
