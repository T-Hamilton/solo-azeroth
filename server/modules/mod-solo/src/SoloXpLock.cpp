/*
 * SoloXpLock.cpp - "Pause XP": freeze a character at its current level by dropping every XP award to 0.
 *
 * A per-character flag (persisted in the characters-DB table solo_xp_lock) that, while set, makes the
 * OnPlayerGiveXP hook zero out every experience gain. All XP sources - kills, quests, exploration,
 * battlegrounds - funnel through Player::GiveXP, so a single hook covers them all. The flag is toggled
 * from the GM Toolkit gossip (SoloGMToolkit.cpp) through the two helpers exposed here; it survives
 * relog and server restart, and is loaded into memory once at startup for a lock-free lookup on the
 * hot XP path.
 */
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <unordered_set>

namespace
{
    std::unordered_set<uint32> g_frozen;   // character low GUIDs whose XP is paused

    void LoadFrozen()
    {
        g_frozen.clear();
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS `solo_xp_lock` ("
            "`guid` INT UNSIGNED NOT NULL, PRIMARY KEY (`guid`)) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        if (QueryResult result = CharacterDatabase.Query("SELECT `guid` FROM `solo_xp_lock`"))
            do
                g_frozen.insert((*result)[0].Get<uint32>());
            while (result->NextRow());
    }
}

// Exposed to SoloGMToolkit.cpp (declared there).
bool SoloXpLock_IsFrozen(uint32 guid)
{
    return g_frozen.find(guid) != g_frozen.end();
}

// Flips the flag and persists it. Returns the new state (true = XP paused).
bool SoloXpLock_Toggle(uint32 guid)
{
    if (g_frozen.erase(guid))
    {
        CharacterDatabase.Execute("DELETE FROM `solo_xp_lock` WHERE `guid` = {}", guid);
        return false;
    }

    g_frozen.insert(guid);
    CharacterDatabase.Execute("INSERT IGNORE INTO `solo_xp_lock` (`guid`) VALUES ({})", guid);
    return true;
}

class SoloXpLockWorldScript : public WorldScript
{
public:
    SoloXpLockWorldScript() : WorldScript("SoloXpLockWorldScript") { }

    void OnStartup() override { LoadFrozen(); }
};

class SoloXpLockPlayerScript : public PlayerScript
{
public:
    SoloXpLockPlayerScript() : PlayerScript("SoloXpLockPlayerScript", { PLAYERHOOK_ON_GIVE_EXP }) { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
    {
        if (player && amount && SoloXpLock_IsFrozen(player->GetGUID().GetCounter()))
            amount = 0;
    }
};

void AddSoloXpLockScripts()
{
    new SoloXpLockWorldScript();
    new SoloXpLockPlayerScript();
}
