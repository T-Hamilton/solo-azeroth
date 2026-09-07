/*
 * SoloXPPotion.cpp - "Potion of Experience": +100% experience per potion for one hour, drink up to five (+500%).
 *
 * Built on stock data only, so no client patch is needed:
 *   item  2461  "Deprecated Elemental Resistance Potion" (a potion the stock client knows) is renamed and given
 *               ScriptName item_solo_xp_potion (sql/world/mod-solo-items.sql). Its use spell is a stock instant dummy
 *               that the script intercepts, so nothing is actually cast.
 *   spell 42138 "Brewfest Enthusiast" is borrowed as the buff icon / timer / stack counter. Its own +10% kill-XP
 *               effect is taken back out below; the tooltip text is the stock one, the real bonus is +100% per stack.
 *
 * XP math: the core multiplies kill XP by every SPELL_AURA_MOD_XP_PCT aura before calling OnPlayerGiveXP and applies
 * nothing to quest / exploration / battleground XP. We undo the kill multiplier and apply our own bonus to every source.
 */
#include "Chat.h"
#include "Item.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraDefines.h"
#include "SpellAuras.h"

#include <algorithm>

namespace
{
    constexpr uint32 XP_POTION_ITEM   = 2461;
    constexpr uint32 XP_POTION_AURA   = 42138;       // Brewfest Enthusiast: stock MOD_XP_PCT aura used as the buff
    constexpr uint8  XP_POTION_MAX    = 5;
    constexpr int32  XP_POTION_MS     = 60 * 60 * 1000;

    void Msg(Player* p, std::string const& text) { ChatHandler(p->GetSession()).SendSysMessage(text); }
}

class item_solo_xp_potion : public ItemScript
{
public:
    item_solo_xp_potion() : ItemScript("item_solo_xp_potion") { }

    bool OnUse(Player* player, Item* item, SpellCastTargets const& /*targets*/) override
    {
        if (!player || !item)
            return false;

        Aura* aura = player->GetAura(XP_POTION_AURA);
        uint8 stacks = aura ? aura->GetStackAmount() : 0;
        if (stacks >= XP_POTION_MAX)
        {
            Msg(player, "You are already at +500% experience. Drink another when this one runs low.");
            return true;
        }
        if (!aura)
            aura = player->AddAura(XP_POTION_AURA, player);
        if (!aura)
        {
            Msg(player, "The potion fizzles (aura could not be applied).");
            return true;
        }
        aura->SetStackAmount(stacks + 1);
        aura->SetMaxDuration(XP_POTION_MS);
        aura->SetDuration(XP_POTION_MS);

        uint32 one = 1;
        player->DestroyItemCount(item, one, true);
        Msg(player, "Potion of Experience: +" + std::to_string(100 * (stacks + 1)) + "% experience for the next hour.");
        return true;   // handled: the item's placeholder spell is not cast
    }
};

class SoloXPPotionPlayerScript : public PlayerScript
{
public:
    SoloXPPotionPlayerScript() : PlayerScript("SoloXPPotionPlayerScript", { PLAYERHOOK_ON_GIVE_EXP }) { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 /*xpSource*/) override
    {
        if (!player || !amount)
            return;
        Aura* aura = player->GetAura(XP_POTION_AURA);
        if (!aura)
            return;

        float base = float(amount);
        if (victim)   // KillRewarder already applied the borrowed aura's own +10% per stack: take it back out
        {
            float coreMult = player->GetTotalAuraMultiplier(SPELL_AURA_MOD_XP_PCT);
            if (coreMult > 0.0f)
                base /= coreMult;
        }
        uint32 pct = 100 * std::min<uint32>(aura->GetStackAmount(), XP_POTION_MAX);
        amount = uint32(base * (100 + pct) / 100.0f + 0.5f);
    }
};

void AddSoloXPPotionScripts()
{
    new item_solo_xp_potion();
    new SoloXPPotionPlayerScript();
}
