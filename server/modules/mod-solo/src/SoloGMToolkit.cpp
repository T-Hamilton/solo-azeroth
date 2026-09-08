/*
 * SoloGMToolkit.cpp - the GM Toolkit item (entry 3878, ScriptName item_solo_gm_toolkit).
 *
 * One right-click opens a gossip menu with the things a solo GM reaches for all day: teleports (cities, starting
 * zones, dungeons/raids, "back to where I was"), GM toggles (god, GM mode, visibility, fly, speed, cast time,
 * cooldowns, infinite power, water walking, all flight paths, explore all) and character helpers (heal, revive,
 * clear cooldowns, level up, max skills, repair, gold, XP potions). Every GM-level account gets the item on login.
 *
 * Stock data only: entry 3878 is "Deprecated Conjured Mana Jewel", an item every 3.3.5 client already has in Item.dbc,
 * renamed by sql/world/mod-solo-items.sql; its use spell is a stock instant dummy that OnUse intercepts before it is
 * cast. Teleport targets are looked up in game_tele by name; names missing from the table are simply not listed.
 */
#include "Chat.h"
#include "GossipDef.h"
#include "Item.h"
#include "Log.h"
#include "MotionMaster.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "SharedDefines.h"
#include "WorldSession.h"

#include <cmath>
#include <string>
#include <unordered_map>

namespace
{
    constexpr uint32 GM_TOOLKIT_ITEM = 3878;
    constexpr uint32 XP_POTION_ITEM  = 2461;   // Potion of Experience (SoloXPPotion.cpp)

    enum Menu : uint32 { MENU_MAIN = 1, MENU_CITIES, MENU_START, MENU_DUNGEONS, MENU_GM, MENU_CHAR };
    enum MainAction : uint32 { MAIN_CITIES = 1, MAIN_START, MAIN_DUNGEONS, MAIN_GM, MAIN_CHAR, MAIN_BACK, MAIN_CLOSE };
    enum GmAction : uint32
    {
        GM_GOD = 1, GM_GMMODE, GM_VISIBLE, GM_FLY, GM_SPEED, GM_CASTTIME, GM_COOLDOWN, GM_POWER, GM_WATERWALK,
        GM_TAXI, GM_EXPLORE, GM_ALL_ON, GM_ALL_OFF
    };
    enum CharAction : uint32
    {
        CHAR_HEAL = 1, CHAR_REVIVE, CHAR_COOLDOWNS, CHAR_LEVEL1, CHAR_LEVEL5, CHAR_LEVEL10, CHAR_MAXSKILL,
        CHAR_REPAIR, CHAR_GOLD, CHAR_XPPOTIONS, CHAR_MOUNTS
    };
    constexpr uint32 ACTION_MAIN = 1000;   // "back to the main menu" in every submenu

    struct Tele { char const* label; char const* tele; };   // tele = game_tele.name
    Tele const CITIES[] =
    {
        { "Stormwind",       "Stormwind"      }, { "Ironforge",      "Ironforge"      }, { "Darnassus",  "Darnassus"  },
        { "The Exodar",      "TheExodar"      }, { "Orgrimmar",      "Orgrimmar"      }, { "Undercity",  "Undercity"  },
        { "Thunder Bluff",   "ThunderBluff"   }, { "Silvermoon City","SilvermoonCity" }, { "Shattrath",  "Shattrath"  },
        { "Dalaran",         "Dalaran"        }, { "Booty Bay",      "BootyBay"       }, { "Gadgetzan",  "Gadgetzan"  },
        { "Ratchet",         "Ratchet"        }, { "Everlook",       "Everlook"       }, { "GM Island",  "GMIsland"   },
    };
    Tele const DUNGEONS[] =
    {
        { "Ragefire Chasm",     "RagefireChasm"     }, { "Deadmines",         "Deadmines"        },
        { "Wailing Caverns",    "WailingCaverns"    }, { "Shadowfang Keep",   "ShadowFangKeep"   },
        { "Scarlet Monastery",  "ScarletMonastery"  }, { "Zul'Farrak",        "ZulFarrak"        },
        { "Stratholme",         "Stratholme"        }, { "Scholomance",       "Scholomance"      },
        { "Blackrock Mountain", "BlackrockMountain" }, { "Molten Core",       "MoltenCore"       },
        { "Karazhan",           "Karazhan"          }, { "Naxxramas",         "Naxxramas"        },
        { "Ulduar",             "Ulduar"            }, { "Icecrown Citadel",  "IcecrownCitadelRaid" },
    };
    struct Start { char const* name; uint32 map; float x, y, z, o; };
    Start const STARTS[] =
    {
        { "Northshire Valley (Human)",       0,   -8949.95f,  -132.49f,    83.53f, 0.0f  },
        { "Coldridge Valley (Dwarf, Gnome)", 0,   -6240.32f,   331.03f,   382.76f, 6.17f },
        { "Shadowglen (Night Elf)",          1,   10311.30f,   832.46f,  1326.41f, 5.69f },
        { "Ammen Vale (Draenei)",            530, -3961.64f, -13931.20f,  100.62f, 2.08f },
        { "Valley of Trials (Orc, Troll)",   1,    -618.52f, -4251.67f,    38.72f, 0.0f  },
        { "Deathknell (Undead)",             0,    1676.71f,  1678.31f,   121.67f, 2.71f },
        { "Camp Narache (Tauren)",           1,   -2917.58f,  -257.98f,    53.00f, 0.0f  },
        { "Sunstrider Isle (Blood Elf)",     530, 10349.60f, -6357.29f,    33.40f, 5.32f },
    };
    float const SPEEDS[] = { 1.0f, 2.0f, 3.0f, 5.0f };

    std::unordered_map<ObjectGuid, WorldLocation> lastPos;   // where the player was before the last toolkit teleport

    char const* OnOff(bool b) { return b ? "ON" : "off"; }

    void Msg(Player* p, std::string const& text) { ChatHandler(p->GetSession()).SendSysMessage(text); }

    void Go(Player* p, uint32 map, float x, float y, float z, float o)
    {
        if (p->IsInCombat())
        {
            Msg(p, "GM Toolkit: not while in combat (turn on God mode and kill it, or wait).");
            return;
        }
        lastPos[p->GetGUID()] = WorldLocation(p->GetMapId(), p->GetPositionX(), p->GetPositionY(), p->GetPositionZ(), p->GetOrientation());
        if (p->IsInFlight())
        {
            p->GetMotionMaster()->MovementExpired();
            p->CleanupAfterTaxiFlight();
        }
        p->TeleportTo(map, x, y, z, o);
    }

    void GoTele(Player* p, char const* name)
    {
        GameTele const* t = sObjectMgr->GetGameTele(name, true);
        if (!t)
        {
            Msg(p, std::string("GM Toolkit: no game_tele entry named ") + name);
            return;
        }
        Go(p, t->mapId, t->position_x, t->position_y, t->position_z, t->orientation);
    }

    // run a GM chat command as the player with nothing selected, so self-targeting commands never hit a bot/NPC
    void RunCommand(Player* p, char const* cmd)
    {
        ObjectGuid sel = p->GetTarget();
        p->SetSelection(ObjectGuid::Empty);
        ChatHandler(p->GetSession()).ParseCommands(cmd);
        p->SetSelection(sel);
    }

    void SetSpeedAll(Player* p, float rate)
    {
        p->SetSpeed(MOVE_WALK, rate, true);
        p->SetSpeed(MOVE_RUN, rate, true);
        p->SetSpeed(MOVE_SWIM, rate, true);
        p->SetSpeed(MOVE_FLIGHT, rate, true);
    }

    void SetCheat(Player* p, uint32 flag, bool on)
    {
        if (on) p->SetCommandStatusOn(flag); else p->SetCommandStatusOff(flag);
        if (flag == CHEAT_WATERWALK)
            p->SetWaterWalking(on);
    }

    void FillPowers(Player* p)
    {
        p->SetFullHealth();
        for (uint8 i = 0; i < MAX_POWERS; ++i)
        {
            Powers pw = Powers(i);
            if (p->GetMaxPower(pw) > 0 && pw != POWER_RAGE && pw != POWER_RUNIC_POWER)
                p->SetPower(pw, p->GetMaxPower(pw));
        }
    }

    // ---- menus --------------------------------------------------------------------------------------------------
    void Send(Player* p, Item* item) { SendGossipMenuFor(p, DEFAULT_GOSSIP_MESSAGE, item->GetGUID()); }

    void ShowMain(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       "Teleport: cities and hubs",      MENU_MAIN, MAIN_CITIES);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       "Teleport: starting zones",       MENU_MAIN, MAIN_START);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       "Teleport: dungeons and raids",   MENU_MAIN, MAIN_DUNGEONS);
        if (lastPos.count(p->GetGUID()))
            AddGossipItemFor(p, GOSSIP_ICON_TAXI,   "Back to where I was",            MENU_MAIN, MAIN_BACK);
        AddGossipItemFor(p, GOSSIP_ICON_BATTLE,     "GM powers (god, fly, speed...)", MENU_MAIN, MAIN_GM);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, "Character (heal, level, gold...)", MENU_MAIN, MAIN_CHAR);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT,       "Close",                          MENU_MAIN, MAIN_CLOSE);
        Send(p, item);
    }

    template <size_t N>
    void ShowTeleList(Player* p, Item* item, Menu menu, Tele const (&list)[N])
    {
        ClearGossipMenuFor(p);
        for (uint32 i = 0; i < N; ++i)
            if (sObjectMgr->GetGameTele(list[i].tele, true))
                AddGossipItemFor(p, GOSSIP_ICON_TAXI, list[i].label, menu, i);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "<- Back", menu, ACTION_MAIN);
        Send(p, item);
    }

    void ShowStarts(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        for (uint32 i = 0; i < std::size(STARTS); ++i)
            AddGossipItemFor(p, GOSSIP_ICON_TAXI, STARTS[i].name, MENU_START, i);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT, "<- Back", MENU_START, ACTION_MAIN);
        Send(p, item);
    }

    void ShowGM(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        char buf[64];
        snprintf(buf, sizeof(buf), "Speed: %.0fx (click to cycle)", p->GetSpeedRate(MOVE_RUN));
        AddGossipItemFor(p, GOSSIP_ICON_BATTLE,     std::string("God mode: ") + OnOff(p->GetCommandStatus(CHEAT_GOD)),          MENU_GM, GM_GOD);
        AddGossipItemFor(p, GOSSIP_ICON_BATTLE,     std::string("No cast time: ") + OnOff(p->GetCommandStatus(CHEAT_CASTTIME)), MENU_GM, GM_CASTTIME);
        AddGossipItemFor(p, GOSSIP_ICON_BATTLE,     std::string("No cooldowns: ") + OnOff(p->GetCommandStatus(CHEAT_COOLDOWN)), MENU_GM, GM_COOLDOWN);
        AddGossipItemFor(p, GOSSIP_ICON_BATTLE,     std::string("Infinite power: ") + OnOff(p->GetCommandStatus(CHEAT_POWER)),  MENU_GM, GM_POWER);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, std::string("Fly: ") + OnOff(p->CanFly()),                                   MENU_GM, GM_FLY);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, buf,                                                                         MENU_GM, GM_SPEED);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, std::string("Water walking: ") + OnOff(p->GetCommandStatus(CHEAT_WATERWALK)), MENU_GM, GM_WATERWALK);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, std::string("GM mode (tag, no aggro): ") + OnOff(p->IsGameMaster()),        MENU_GM, GM_GMMODE);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, std::string("Visible to players: ") + OnOff(p->isGMVisible()),               MENU_GM, GM_VISIBLE);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       std::string("All flight paths: ") + OnOff(p->isTaxiCheater()),               MENU_GM, GM_TAXI);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       "Explore the whole map",                                                      MENU_GM, GM_EXPLORE);
        AddGossipItemFor(p, GOSSIP_ICON_DOT,        "Everything ON (god, cast, cooldown, power)",                                 MENU_GM, GM_ALL_ON);
        AddGossipItemFor(p, GOSSIP_ICON_DOT,        "Everything OFF (play normally)",                                             MENU_GM, GM_ALL_OFF);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT,       "<- Back",                                                                    MENU_GM, ACTION_MAIN);
        Send(p, item);
    }

    void ShowChar(Player* p, Item* item)
    {
        ClearGossipMenuFor(p);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, "Heal to full (health and power)", MENU_CHAR, CHAR_HEAL);
        if (!p->IsAlive())
            AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, "Revive",                      MENU_CHAR, CHAR_REVIVE);
        AddGossipItemFor(p, GOSSIP_ICON_INTERACT_1, "Clear all cooldowns",             MENU_CHAR, CHAR_COOLDOWNS);
        AddGossipItemFor(p, GOSSIP_ICON_TRAINER,    "Level up +1",                     MENU_CHAR, CHAR_LEVEL1);
        AddGossipItemFor(p, GOSSIP_ICON_TRAINER,    "Level up +5",                     MENU_CHAR, CHAR_LEVEL5);
        AddGossipItemFor(p, GOSSIP_ICON_TRAINER,    "Level up +10",                    MENU_CHAR, CHAR_LEVEL10);
        AddGossipItemFor(p, GOSSIP_ICON_TRAINER,    "Max all weapon skills",           MENU_CHAR, CHAR_MAXSKILL);
        AddGossipItemFor(p, GOSSIP_ICON_VENDOR,     "Repair all gear",                 MENU_CHAR, CHAR_REPAIR);
        AddGossipItemFor(p, GOSSIP_ICON_MONEY_BAG,  "Add 100 gold",                    MENU_CHAR, CHAR_GOLD);
        AddGossipItemFor(p, GOSSIP_ICON_VENDOR,     "Give 5 Potions of Experience",    MENU_CHAR, CHAR_XPPOTIONS);
        AddGossipItemFor(p, GOSSIP_ICON_TAXI,       "Learn class mounts + riding",     MENU_CHAR, CHAR_MOUNTS);
        AddGossipItemFor(p, GOSSIP_ICON_CHAT,       "<- Back",                         MENU_CHAR, ACTION_MAIN);
        Send(p, item);
    }

    // ---- actions ------------------------------------------------------------------------------------------------
    void DoGM(Player* p, uint32 action)
    {
        switch (action)
        {
            case GM_GOD:       SetCheat(p, CHEAT_GOD, !p->GetCommandStatus(CHEAT_GOD)); break;
            case GM_CASTTIME:  SetCheat(p, CHEAT_CASTTIME, !p->GetCommandStatus(CHEAT_CASTTIME)); break;
            case GM_COOLDOWN:  SetCheat(p, CHEAT_COOLDOWN, !p->GetCommandStatus(CHEAT_COOLDOWN)); break;
            case GM_POWER:     SetCheat(p, CHEAT_POWER, !p->GetCommandStatus(CHEAT_POWER)); break;
            case GM_WATERWALK: SetCheat(p, CHEAT_WATERWALK, !p->GetCommandStatus(CHEAT_WATERWALK)); break;
            case GM_FLY:       p->SetCanFly(!p->CanFly()); break;
            case GM_GMMODE:    p->SetGameMaster(!p->IsGameMaster()); break;
            case GM_VISIBLE:   p->SetGMVisible(!p->isGMVisible()); break;
            case GM_TAXI:      p->SetTaxiCheater(!p->isTaxiCheater()); break;
            case GM_SPEED:
            {
                float cur = p->GetSpeedRate(MOVE_RUN);
                float next = SPEEDS[0];
                for (uint32 i = 0; i < std::size(SPEEDS); ++i)
                    if (cur < SPEEDS[i] - 0.01f) { next = SPEEDS[i]; break; }
                SetSpeedAll(p, next);
                break;
            }
            case GM_EXPLORE:
                for (uint16 i = 0; i < PLAYER_EXPLORED_ZONES_SIZE; ++i)
                    p->SetFlag(PLAYER_EXPLORED_ZONES_1 + i, 0xFFFFFFFF);
                Msg(p, "GM Toolkit: whole map explored.");
                break;
            case GM_ALL_ON:
                for (uint32 f : { CHEAT_GOD, CHEAT_CASTTIME, CHEAT_COOLDOWN, CHEAT_POWER })
                    SetCheat(p, f, true);
                break;
            case GM_ALL_OFF:
                for (uint32 f : { CHEAT_GOD, CHEAT_CASTTIME, CHEAT_COOLDOWN, CHEAT_POWER, CHEAT_WATERWALK })
                    SetCheat(p, f, false);
                if (p->CanFly()) p->SetCanFly(false);
                SetSpeedAll(p, 1.0f);
                if (p->IsGameMaster()) p->SetGameMaster(false);
                if (!p->isGMVisible()) p->SetGMVisible(true);
                break;
            default: break;
        }
    }

    void DoChar(Player* p, uint32 action)
    {
        switch (action)
        {
            case CHAR_HEAL:      FillPowers(p); Msg(p, "GM Toolkit: healed."); break;
            case CHAR_REVIVE:
                if (!p->IsAlive()) { p->ResurrectPlayer(1.0f); p->SpawnCorpseBones(); }
                break;
            case CHAR_COOLDOWNS: p->RemoveAllSpellCooldown(); Msg(p, "GM Toolkit: cooldowns cleared."); break;
            case CHAR_LEVEL1:    RunCommand(p, ".levelup 1"); break;
            case CHAR_LEVEL5:    RunCommand(p, ".levelup 5"); break;
            case CHAR_LEVEL10:   RunCommand(p, ".levelup 10"); break;
            case CHAR_MAXSKILL:  p->UpdateSkillsToMaxSkillsForLevel(); Msg(p, "GM Toolkit: weapon skills maxed."); break;
            case CHAR_REPAIR:    p->DurabilityRepairAll(false, 0.0f, false); Msg(p, "GM Toolkit: gear repaired."); break;
            case CHAR_GOLD:      p->ModifyMoney(100 * GOLD); break;
            case CHAR_XPPOTIONS:
                if (!p->AddItem(XP_POTION_ITEM, 5))
                    Msg(p, "GM Toolkit: no bag space for the potions.");
                break;
            case CHAR_MOUNTS:
            {
                // riding first (Journeyman implies Apprentice), then the class mounts by class
                for (uint32 s : { 33388u, 33391u })
                    if (!p->HasSpell(s)) p->learnSpell(s);
                std::string what = "riding";
                switch (p->getClass())
                {
                    case CLASS_PALADIN:
                        for (uint32 s : { 13819u, 23214u })   // Warhorse, Charger (Alliance models; any race on this realm)
                            if (!p->HasSpell(s)) p->learnSpell(s);
                        what += ", Summon Warhorse, Summon Charger";
                        break;
                    case CLASS_WARLOCK:
                        for (uint32 s : { 5784u, 23161u })    // Felsteed, Dreadsteed
                            if (!p->HasSpell(s)) p->learnSpell(s);
                        what += ", Felsteed, Dreadsteed";
                        break;
                    case CLASS_DEATH_KNIGHT:
                        if (!p->HasSpell(48778u)) p->learnSpell(48778u);   // Acherus Deathcharger
                        what += ", Acherus Deathcharger";
                        break;
                    default:
                        break;
                }
                Msg(p, "GM Toolkit: learned " + what + ". Check the General and Mounts tabs of the spellbook.");
                break;
            }
            default: break;
        }
    }
}

class item_solo_gm_toolkit : public ItemScript
{
public:
    item_solo_gm_toolkit() : ItemScript("item_solo_gm_toolkit") { }

    bool OnUse(Player* player, Item* item, SpellCastTargets const& /*targets*/) override
    {
        if (!player || !item)
            return false;
        if (player->GetSession()->GetSecurity() < SEC_GAMEMASTER)
        {
            Msg(player, "The toolkit does not answer to you.");
            return true;
        }
        ShowMain(player, item);
        return true;   // handled: the item's placeholder spell is not cast
    }

    void OnGossipSelect(Player* p, Item* item, uint32 sender, uint32 action) override
    {
        if (!p || !item || p->GetSession()->GetSecurity() < SEC_GAMEMASTER)
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
                    case MAIN_CITIES:   ShowTeleList(p, item, MENU_CITIES, CITIES); return;
                    case MAIN_START:    ShowStarts(p, item); return;
                    case MAIN_DUNGEONS: ShowTeleList(p, item, MENU_DUNGEONS, DUNGEONS); return;
                    case MAIN_GM:       ShowGM(p, item); return;
                    case MAIN_CHAR:     ShowChar(p, item); return;
                    case MAIN_BACK:
                    {
                        CloseGossipMenuFor(p);
                        auto it = lastPos.find(p->GetGUID());
                        if (it != lastPos.end())
                        {
                            WorldLocation back = it->second;
                            Go(p, back.GetMapId(), back.GetPositionX(), back.GetPositionY(), back.GetPositionZ(), back.GetOrientation());
                        }
                        return;
                    }
                    default: CloseGossipMenuFor(p); return;
                }
            case MENU_CITIES:
                CloseGossipMenuFor(p);
                if (action < std::size(CITIES)) GoTele(p, CITIES[action].tele);
                return;
            case MENU_DUNGEONS:
                CloseGossipMenuFor(p);
                if (action < std::size(DUNGEONS)) GoTele(p, DUNGEONS[action].tele);
                return;
            case MENU_START:
                CloseGossipMenuFor(p);
                if (action < std::size(STARTS))
                {
                    Start const& s = STARTS[action];
                    Go(p, s.map, s.x, s.y, s.z, s.o);
                }
                return;
            case MENU_GM:
                DoGM(p, action);
                ShowGM(p, item);   // stay in the menu, labels refresh with the new state
                return;
            case MENU_CHAR:
                DoChar(p, action);
                if (action == CHAR_LEVEL1 || action == CHAR_LEVEL5 || action == CHAR_LEVEL10 || action == CHAR_REVIVE)
                    CloseGossipMenuFor(p);
                else
                    ShowChar(p, item);
                return;
            default:
                CloseGossipMenuFor(p);
                return;
        }
    }
};

// every GM-level account gets the toolkit on login (also covers freshly created characters)
class SoloGMToolkitPlayerScript : public PlayerScript
{
public:
    SoloGMToolkitPlayerScript() : PlayerScript("SoloGMToolkitPlayerScript", { PLAYERHOOK_ON_LOGIN }) { }

    void OnPlayerLogin(Player* p) override
    {
        if (!p || p->GetSession()->GetSecurity() < SEC_GAMEMASTER)
            return;
        if (p->HasItemCount(GM_TOOLKIT_ITEM, 1, true))
            return;
        if (p->AddItem(GM_TOOLKIT_ITEM, 1))
            Msg(p, "A GM Toolkit has been slipped into your bags. Right-click it.");
        else
            LOG_INFO("server.loading", "mod-solo: could not give the GM Toolkit to {} (bags full?)", p->GetName());
    }
};

void AddSoloGMToolkitScripts()
{
    new item_solo_gm_toolkit();
    new SoloGMToolkitPlayerScript();
}
