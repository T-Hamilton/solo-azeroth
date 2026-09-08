#!/usr/bin/env python3
"""Render runtime/configs/{worldserver,authserver}.conf and modules/{playerbots,mod_ollama_chat}.conf
from the installed *.conf.dist templates, using server/settings.json overlaid with server/settings.local.json.
Re-run any time (solo.cmd configs); it only rewrites the generated .conf files and never touches the .dist ones.
Hand edits to the generated files are lost - put your changes in settings.local.json or in the override tables below."""
import json, os, re, sys

SERVER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNTIME = os.path.join(SERVER, "runtime")


def load_settings():
    # utf-8-sig: PowerShell (the Bot Settings window) writes the local file with a byte-order mark
    s = json.load(open(os.path.join(SERVER, "settings.json"), encoding="utf-8-sig"))
    local = os.path.join(SERVER, "settings.local.json")
    if os.path.exists(local):
        s.update(json.load(open(local, encoding="utf-8-sig")))
    return s


def find_dist(name):
    for d in (os.path.join(RUNTIME, "configs"), os.path.join(RUNTIME, "etc"), os.path.join(RUNTIME, "bin", "configs")):
        for root, _, files in os.walk(d):
            if name in files:
                return os.path.join(root, name)
    sys.exit("missing template %s - build and install the core first (setup\\build-core.cmd)" % name)


def render(dist, overrides):
    txt = open(dist, encoding="utf-8", errors="replace").read()
    seen = set()

    def sub(m):
        key = m.group(1)
        if key in overrides:
            seen.add(key)
            return "%s = %s" % (key, overrides[key])
        return m.group(0)

    txt = re.sub(r"^([A-Za-z0-9_.]+)\s*=\s*.*$", sub, txt, flags=re.M)
    missing = [k for k in overrides if k not in seen]
    if missing:
        txt += "\n# --- keys not present in the template, appended by gen_configs.py ---\n"
        txt += "".join("%s = %s\n" % (k, overrides[k]) for k in missing)
    return txt


def q(s):
    """quoted config value"""
    return '"%s"' % str(s).replace('"', '\\"')


S = load_settings()


def db(name):
    return q("127.0.0.1;%s;%s;%s;%s_%s" % (S["MySQLPort"], S["DbUser"], S["DbPassword"], S["DbPrefix"], name))


mysql_exe = os.path.join(SERVER, "mysql", "mysql-8.4.0-winx64", "bin", "mysql.exe").replace("\\", "/")
data_dir = os.path.join(RUNTIME, "data").replace("\\", "/")

WORLD = {
    "RealmID": "1",
    "WorldServerPort": str(S["WorldPort"]),
    "BindIP": q("0.0.0.0"),
    "LoginDatabaseInfo": db("auth"),
    "WorldDatabaseInfo": db("world"),
    "CharacterDatabaseInfo": db("characters"),
    "DataDir": q(data_dir),
    "LogsDir": q("logs"),
    "MySQLExecutable": q(mysql_exe),
    "Updates.EnableDatabases": "7",
    "Updates.AutoSetup": "1",
    "Warden.Enabled": "0",
    "PlayerLimit": "100",
    "Expansion": "2",
    "MaxPlayerLevel": "80",
    "AllowTwoSide.Accounts": "1",
    "AllowTwoSide.Interaction.Chat": "1",
    "AllowTwoSide.Interaction.Group": "1",
    "AllowTwoSide.Interaction.Guild": "1",
    "AllowTwoSide.Interaction.Channel": "1",
    "StrictPlayerNames": "0",
    "Motd": q(S["Motd"]),
    "CloseIdleConnections": "0",
    "SOAP.Enabled": "1", "SOAP.IP": q("127.0.0.1"), "SOAP.Port": str(S["SoapPort"]),
    "Appender.Server": "2,6,0,Server.log,w",
}
AUTH = {
    "RealmServerPort": str(S["AuthPort"]),
    "BindIP": q("0.0.0.0"),
    "LoginDatabaseInfo": db("auth"),
    "LogsDir": q("logs"),
    "MySQLExecutable": q(mysql_exe),
    "Updates.EnableDatabases": "1",
    "Updates.AutoSetup": "1",
    "Appender.Auth": "2,6,0,Auth.log,w",
}
BOTS = {
    "PlayerbotsDatabaseInfo": db("playerbots"),
    "AiPlayerbot.Enabled": "1",
    "AiPlayerbot.RandomBotAutologin": "1",
    "AiPlayerbot.MinRandomBots": str(S["Bots"]),
    "AiPlayerbot.MaxRandomBots": str(S["Bots"]),
    "AiPlayerbot.RandomBotMinLevel": str(S["BotMinLevel"]),
    "AiPlayerbot.RandomBotMaxLevel": str(S["BotMaxLevel"]),
    "AiPlayerbot.RandomBotMaps": S["BotMaps"],
    "AiPlayerbot.RandomBotsPerInterval": str(max(60, S["Bots"] // 8)),   # logins per 20 s cycle: the whole population is in within ~3 min
    "AiPlayerbot.DisabledWithoutRealPlayer": "1",   # bots idle while you are logged out (saves CPU and LLM calls)
    # the canned playerbots chatter is OFF: the LLM event chatter covers dings/loot/deaths with actual personality.
    # RandomBotTalk = scripted one-liners; EnableBroadcasts = "accepted quest X" / "looted Y" / "suggest dungeon" spam
    "AiPlayerbot.RandomBotTalk": "0",
    "AiPlayerbot.EnableBroadcasts": "0",
    "AiPlayerbot.RandomBotSayWithoutMaster": "0",
    "AiPlayerbot.SelfBotLevel": "1",                # 1 = GM may turn their own character into a bot with a command.
                                                    # NEVER 3: that attaches a bot AI to YOU on login, and the chat module then treats you as a bot.
}
# The chat governor, tuned for an always-on, bot-to-bot general chat (docs/LLM-CHAT.md explains each knob).
SYSTEM_PROMPT = (
    "You are a real World of Warcraft player typing in chat on a 3.3.5 private server. Stay completely in character "
    "as the player described; never mention being an AI, a bot, a model or a prompt. Profanity, insults, trash talk "
    "and rage are all fine when they fit your personality. Aim them at people's gameplay, class, gear, guild, "
    "decisions and opinions, never at real-world race, religion, nationality, sexuality or disability. Write one short "
    "chat line, the way people actually type in game: lowercase is fine, typos are fine, no narration, no quotes, no markdown."
)
OLLAMA = {
    "OllamaChat.Enable": "1",
    "OllamaChat.DebugEnabled": str(1 if S.get("ChatDebug", 0) else 0),   # 1 = log the chat funnel (ambient tick summaries, reply decisions)
    "OllamaChat.DebugShowFullPrompt": str(1 if S.get("ChatDebug", 0) >= 2 else 0),   # ChatDebug 2 = also log every full prompt sent to the model
    "OllamaChat.Url": S["OllamaUrl"].rstrip("/") + "/api/generate",
    "OllamaChat.Model": S["OllamaModel"],
    "OllamaChat.NumPredict": "110",       # room for a two-sentence retort (chat lines are capped at 240 chars anyway)
    "OllamaChat.NumCtx": "4096",          # explicit context window: system + persona + 16 transcript lines + memories fit with room
    "OllamaChat.Temperature": "0.9",
    "OllamaChat.RandomChatterQuestionChance": "20",
    # the conversation layer (our module patch): shared transcript per channel, partner stickiness, ambient hold
    "OllamaChat.Transcript.Lines": "10",   # enough context to follow a thread; more and the model imitates the crowd instead of answering
    "OllamaChat.Transcript.WindowSeconds": "600",
    "OllamaChat.BotConversation.EngagedWindowSeconds": "150",
    "OllamaChat.Ambient.HoldSeconds": "45",
    "OllamaChat.Ambient.HoldPassPct": "40",
    "OllamaChat.MaxConcurrentQueries": str(S["OllamaParallel"]),
    "OllamaChat.WorkerThreads": str(S["OllamaParallel"]),
    "OllamaChat.SystemPrompt": q(SYSTEM_PROMPT),
    # personalities: assigned per bot at random from the non-manual templates in the DB (our pack sets the 50/30/20 mix)
    "OllamaChat.EnableRPPersonalities": "1",
    # ambient chatter: any bot on your map may start a line in General / Trade / LFG as long as you are in that channel
    "OllamaChat.EnableRandomChatter": "1",
    "OllamaChat.MinRandomInterval": "25",
    "OllamaChat.MaxRandomInterval": "110",
    "OllamaChat.RandomChatterRealPlayerDistance": "100000",
    "OllamaChat.RandomChatterBotCommentChance": "18",
    "OllamaChat.RandomChatterMaxBotsPerPlayer": "4",
    "OllamaChat.Chatter.ZoneChannelsAcrossMap": "1",   # any bot on your continent may talk in YOUR zone's General/Trade (else only same-zone bots)
    "OllamaChat.Chatter.UseGeneralChannel": "1",
    "OllamaChat.Chatter.UseTradeChannel": "1",
    "OllamaChat.Chatter.UseLookingForGroupChannel": "1",   # realm-wide: the 'world chat' feed
    # reactions to things that happen around you (levels, loot, deaths, duels)
    "OllamaChat.EnableEventChatter": "1",
    "OllamaChat.EventChatterRealPlayerDistance": "60",
    # bots answering bots: this is what makes it a conversation instead of a wall of openers
    "OllamaChat.BotReplyChance.Say": "30",
    "OllamaChat.BotReplyChance.Channel": "30",
    "OllamaChat.BotReplyChance.Party": "30",
    "OllamaChat.BotReplyChance.Guild": "25",
    "OllamaChat.PlayerReplyChance.Say": "90",
    "OllamaChat.PlayerReplyChance.Channel": "70",
    "OllamaChat.BotConversation.MaxChainDepth": "6",     # an argument may run six bot-to-bot hops before a person has to feed it
    "OllamaChat.BotConversation.ChanceDecayPct": "75",
    "OllamaChat.BotConversation.ChainLinesPerMinute": "12",  # hard cap on bot-to-bot lines per channel per minute; replies to a person are not counted
    "OllamaChat.RepeatPenalty": "1.15",                  # discourage parroting the transcript's words and openers
    "OllamaChat.PresencePenalty": "0.3",
    "OllamaChat.BotConversation.RequireRecentHuman": "0",
    # pacing: a bot mid-exchange is exempt from these (direct address); they only pace the crowd
    "OllamaChat.Cooldown.PerBotSeconds": "10",
    "OllamaChat.Cooldown.PerScopeSeconds": "2",
    "OllamaChat.RateLimit.ScopePerMinute": "30",
    "OllamaChat.RateLimit.GlobalPerMinute": "100",
    # repetition: the opener check ("same first three words") killed short retorts; keep only the near-duplicate check
    "OllamaChat.Repetition.OpenerHistorySize": "6",       # "Seriously, Name?" x40: the opener check is what stops a whole channel copying one opener
    "OllamaChat.Repetition.CheckDirectAddress": "1",      # ...so it applies to engaged replies too (a dropped line ends that thread, nothing worse)
    "OllamaChat.Repetition.SimilarityThreshold": "0.82",
    "OllamaChat.Repetition.WindowSeconds": "600",
    # they remember you, and each other
    "OllamaChat.EnableChatHistory": "1",
    "OllamaChat.Memory.Enable": "1",
    "OllamaChat.Relationship.Enable": "1",
    "OllamaChat.EnableSentimentTracking": "0",   # an extra model call per answered line for a +-0.05 tone number; the memories cover it
    # looks like typing instead of a teleporting wall of text
    "OllamaChat.EnableTypingSimulation": "1",
    "OllamaChat.TypingSimulationBaseDelay": "700",
    "OllamaChat.TypingSimulationDelayPerChar": "22",
    "OllamaChat.TypingSimulationMaxDelay": "4500",
    "OllamaChat.DisableRepliesInCombat": "1",
    "OllamaChat.EnableWhisperReplies": "1",
}

# The prompt frame (system prompt + the templates around every bot line) is edited as plain text in
# server/personalities/prompts.txt (Edit Prompts shortcut / solo.cmd prompts). Sections present there win over the
# defaults above; a missing section keeps the module's own default.
PROMPT_KEYS = {
    "SYSTEM": "OllamaChat.SystemPrompt",
    "REPLY": "OllamaChat.ChatPromptTemplate",
    "REPLY_INFO": "OllamaChat.ChatExtraInfoTemplate",
    "AMBIENT": "OllamaChat.RandomChatterPromptTemplate",
    "AMBIENT_TOPICS": "OllamaChat.RandomChatterPromptVariations",
    "AMBIENT_JOIN": "OllamaChat.Ambient.JoinLine",
    "ADDRESSED": "OllamaChat.AddressedTemplate",
    "EVENT": "OllamaChat.EventChatterPromptTemplate",
    "DEFAULT_PERSONALITY": "OllamaChat.DefaultPersonalityPrompt",
}


def load_prompts(path):
    sections, key, buf = {}, None, []
    if not os.path.exists(path):
        return sections
    for raw in open(path, encoding="utf-8-sig"):
        line = raw.rstrip("\n")
        m = re.match(r"^===\s*([A-Za-z0-9_]+)\s*===\s*$", line)
        if m:
            if key:
                sections[key] = buf
            key, buf = m.group(1).upper(), []
            continue
        if line.lstrip().startswith("#"):
            continue
        if key and line.strip():
            buf.append(line.strip())
    if key:
        sections[key] = buf
    out = {}
    for name, lines in sections.items():
        if name not in PROMPT_KEYS or not lines:
            continue
        text = "|".join(lines) if name == "AMBIENT_TOPICS" else " ".join(lines)
        out[PROMPT_KEYS[name]] = q(text.replace("\\", "").replace('"', "'"))   # the .conf value is a "..." string
    return out


PROMPTS = load_prompts(os.path.join(SERVER, "personalities", "prompts.txt"))
OLLAMA.update(PROMPTS)
if PROMPTS:
    print("prompts.txt: %d sections applied (%s)" % (len(PROMPTS), ", ".join(k for k in PROMPT_KEYS if PROMPT_KEYS[k] in PROMPTS)))

# Anything saved in the Bot Settings window lands in settings.local.json under "ConfOverrides" and is applied last,
# so it survives every regeneration: {"ConfOverrides": {"playerbots.conf": {...}, "mod_ollama_chat.conf": {...}}}
CONF_OVERRIDES = S.get("ConfOverrides", {})

out = os.path.join(RUNTIME, "configs")
os.makedirs(os.path.join(out, "modules"), exist_ok=True)
for name, ov, sub in (("worldserver.conf", WORLD, ""), ("authserver.conf", AUTH, ""),
                      ("playerbots.conf", BOTS, "modules"), ("mod_ollama_chat.conf", OLLAMA, "modules")):
    dist = find_dist(name + ".dist")
    dst = os.path.join(out, sub, name)
    user = CONF_OVERRIDES.get(name, {})
    ov = dict(ov, **{k: (q(v) if isinstance(v, str) and not re.fullmatch(r"-?[0-9.]+", v) and v not in ("0", "1") else str(v)) for k, v in user.items()})
    open(dst, "w", encoding="utf-8").write(render(dist, ov))
    print("wrote", os.path.relpath(dst, SERVER), ("(+%d from Bot Settings)" % len(user)) if user else "")
