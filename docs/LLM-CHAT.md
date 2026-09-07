# The chat: how the bots talk, and how to change it

Everything here is set by `server\setup\gen_configs.py` (the `OLLAMA` table) and lands in
`runtime\configs\modules\mod_ollama_chat.conf`. The Bot Settings window exposes the handful you will touch most.
Change the model or the settings, then `.ollama reload` in game; no restart needed.

## How it works

1. A bot decides to say something (ambient chatter), or something happens that it may react to (someone spoke in
   its channel, someone nearby dinged, died, won a duel, got loot).
2. mod-ollama-chat builds a prompt from the bot's name, class, level, zone, faction, its personality, its memories
   of you, its recent conversation, and the message it is answering.
3. The prompt goes to Ollama over HTTP on this PC. The model answers with one chat line.
4. The bot "types" it (a short delay scaled to the length) into the right channel.

The server only ever talks to Ollama over HTTP, so the model can live on another machine on your LAN: set
`OllamaUrl` in `settings.local.json`.

## The model

Default: `hf.co/mlabonne/gemma-3-12b-it-abliterated-GGUF:Q4_K_M` (7.3 GB, needs ~9 GB VRAM), pulled straight from Hugging Face by Ollama. The Ollama-library tags of this model only come in fp16 (24 GB) and q8 (13 GB), which do not fit a 16 GB card next to the game. It was chosen because it will
actually play a nasty character. Ordinary instruction-tuned models (Llama, stock Gemma, Qwen) refuse insults,
soften trash talk and break character to add disclaimers, which kills the whole effect. "Abliterated" means the
refusal behaviour was removed from the weights; the model keeps its knowledge and style, it just does not say no.

That cuts both ways. The model has no line of its own any more, so the line is drawn by the prompt. Ours, in
`OllamaChat.SystemPrompt`: abuse is about gameplay, class, gear, guild, decisions and opinions, never about
real-world race, religion, nationality, sexuality or disability. It holds well in practice; it is a prompt, not a
guarantee.

Alternatives that fit a 16 GB card, all one `ollama pull` away, then set `OllamaModel`:

| Model | Size | Notes |
|---|---|---|
| `dolphin3:8b` | 4.9 GB | uncensored, twice as fast, noticeably dumber; drifts out of character over long threads |
| `mistral-nemo:12b` | 7.1 GB | best natural voice, lightly censored: fine for gamer toxicity, may soften the worst characters |
| `huihui_ai/gemma-4-abliterated:12b` | 7.6 GB | the newer Gemma generation, untested here |
| `huihui_ai/qwen3-abliterated:14b` | 9 GB | smarter, but a thinking model; slower replies |
| `huihui_ai/mistral-small-abliterated:24b` | 14 GB | the quality pick if Ollama runs on a second machine |
| `llama3.2:3b` | 2 GB | for small cards; it will refuse a lot |

Capacity is not about bot count. One model serves every bot; what scales is lines per second, and demand comes
from real players, because bots only speak where a real player can hear. A 12B model on a modern card produces a
line in about a second. The settings below produce maybe 5-10 lines a minute around one player; the hard caps
(`RateLimit.*`) stop it ever running away.

## The mix: 50% toxic, 30% normal, 20% nice

Personalities are prompt templates in the `mod_ollama_chat_personality_templates` table. A bot is handed one at
random, uniformly, from every template with `manual_only = 0`, the first time it speaks, and keeps it. So the
proportions in the pack are the distribution. `server\personalities\2026_09_06_00_personality_pack_genchat.sql`
has 10 toxic, 6 normal and 4 nice voices and flips the 33 stock ones to manual-only.

To change the mix, edit that file (or add another `*.sql` in the same folder; the server applies anything new on
its next start), then `.ollama reload`. To give one bot a specific voice: `.ollama personality set <bot> <KEY>`.
To wipe assignments and re-roll everyone: `DELETE FROM acore_characters.mod_ollama_chat_personality;`.

## The volume: what each knob does

| Setting | Ours | Module default | Effect |
|---|---|---|---|
| `EnableRandomChatter` | 1 | 1 | bots start lines on their own |
| `RandomChatterRealPlayerDistance` | 100000 | 40 | how close a real player must be for a bot to start a line. Huge = anyone on your map; the channel audience check below still applies |
| `RandomChatterBotCommentChance` | 20 | 5 | % chance per bot per tick; the main volume dial |
| `MinRandomInterval` / `Max` | 25 / 110 s | 45 / 180 | how often a bot considers speaking |
| `Chatter.UseLookingForGroupChannel` | 1 | 0 | LFG is realm-wide: this is the "world chat" feed |
| `BotReplyChance.Channel` | 35 | 3 | % chance a bot answers another bot in a channel. This is what makes conversations |
| `BotConversation.MaxChainDepth` | 6 | 3 | bot-to-bot hops before a thread is cut |
| `BotConversation.ChanceDecayPct` | 80 | 50 | reply chance multiplier per hop; higher = longer threads |
| `BotConversation.RequireRecentHuman` | 0 | 1 | on: bots only answer bots within 2 min of you speaking. Off: the chat lives without you |
| `Cooldown.PerScopeSeconds` | 6 | 15 | minimum gap between any two bot lines in one channel |
| `Cooldown.PerBotSeconds` | 30 | 45 | minimum gap between two lines from the same bot |
| `RateLimit.ScopePerMinute` / `GlobalPerMinute` | 14 / 60 | 8 / 40 | hard caps per channel and server-wide |
| `EnableEventChatter` | 1 | 1 | reactions to dings, drops, deaths, duels within 60 yd |
| `EnableTypingSimulation` | 1 | 0 | 0.8 s + 35 ms per character before a line appears |
| `Memory.Enable`, `Relationship.Enable`, `EnableSentimentTracking` | 1 | 1/1/0 | long-term memory, relationships, and a per-player like/dislike score that colours the tone |

Bots only ever post to a channel that a real player is actually in (General is per zone; you leave a zone, that
zone goes quiet). Bots also idle completely while nobody is logged in (`AiPlayerbot.DisabledWithoutRealPlayer`),
so the LLM is not burning power for an empty world.

Quieter: drop `RandomChatterBotCommentChance` to 8 and `BotReplyChance.Channel` to 15. Louder: raise the two
rate limits first, they are the ceiling.

## Diagnosing "the bots are not talking"

- `.ollama status` in game: endpoint, model, queue depth, delivered and dropped counters.
- `.ollama test say something rude about mages`: one raw prompt straight to the model; the reply is printed to
  the server console and log.
- `solo.cmd status`: is Ollama listening? `ollama list` in a terminal: is the model pulled?
- Are you in the channel? `/join General` after a zone change if you left it.
- Bots sit still and silent until a real player is online (by design).
- The worldserver console prints `[Ollama Chat]` lines on startup; errors about the endpoint mean Ollama is not up
  or `OllamaUrl` is wrong.
