/*
 * SoloQuestDrops.cpp - "Solo.QuestDropRate": multiply the drop chance of every quest item, everywhere.
 *
 * The core rolls each loot entry in LootStoreItem::Roll and asks the script hook OnItemRoll first. This script
 * scales the chance of entries flagged QuestRequired (creature, gameobject, item-container, skinning... every loot
 * store) and leaves everything else alone. Entries already at 100% stay at 100%; grouped entries (rare for quest
 * items) never reach Roll, so the rate does not touch them.
 *
 * The rate lives in worldserver.conf (Solo.QuestDropRate, from settings.json "QuestDropRate") and is re-read on
 * `.reload config`, so it can be changed on a running server.
 */
#include "Config.h"
#include "Log.h"
#include "LootMgr.h"
#include "ScriptMgr.h"

#include <algorithm>

namespace
{
    float questDropRate = 1.0f;

    void LoadQuestDropRate(bool reload)
    {
        questDropRate = std::max(0.0f, sConfigMgr->GetOption<float>("Solo.QuestDropRate", 1.0f));
        LOG_INFO("server.loading", "mod-solo: quest item drop rate x{:.2f}{}", questDropRate, reload ? " (reloaded)" : "");
    }
}

class SoloQuestDropsWorldScript : public WorldScript
{
public:
    SoloQuestDropsWorldScript() : WorldScript("SoloQuestDropsWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool reload) override { LoadQuestDropRate(reload); }
};

class SoloQuestDropsGlobalScript : public GlobalScript
{
public:
    SoloQuestDropsGlobalScript() : GlobalScript("SoloQuestDropsGlobalScript", { GLOBALHOOK_ON_ITEM_ROLL }) { }

    bool OnItemRoll(Player const* /*player*/, LootStoreItem const* item, float& chance, Loot& /*loot*/, LootStore const& /*store*/) override
    {
        if (item && item->needs_quest && !item->reference && questDropRate != 1.0f && chance > 0.0f && chance < 100.0f)
            chance = std::min(100.0f, chance * questDropRate);
        return true;   // the core still rolls; false would veto the drop
    }
};

void AddSoloQuestDropsScripts()
{
    new SoloQuestDropsWorldScript();
    new SoloQuestDropsGlobalScript();
}
