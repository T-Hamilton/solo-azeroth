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

Default: `huihui_ai/gemma-4-abliterated:12b` (7.6 GB, ~10 GB VRAM), one `ollama pull` away. It was chosen because
it will actually play a nasty character. Ordinary instruction-tuned models (Llama, stock Gemma, Qwen) refuse insults,
soften trash talk and break character to add disclaimers, which kills the whole effect. "Abliterated" means the
refusal behaviour was removed from the weights; the model keeps its knowledge and style, it just does not say no.

The first pick was `hf.co/mlabonne/gemma-3-12b-it-abliterated-GGUF:Q4_K_M` (7.3 GB). Nastier by a hair, but that
build drops the letter after an apostrophe in a quarter of its lines ("it' the best way", "let' go", "I'rew"), at
any temperature or penalty, and once one such line is in the shared transcript every bot copies the habit. Replayed
on a real in-game prompt, 12 lines each: Gemma 4 0 mangled, Gemma 3 4 mangled; same swearing when the personality
asks for it; 0.8 s a line against 0.9. Switch back in Bot Settings (Model) if you prefer its voice; the response
cleanup repairs the common cases either way.

That cuts both ways. The model has no line of its own any more, so the line is drawn by the prompt. Ours, in
`OllamaChat.SystemPrompt`: abuse is about gameplay, class, gear, guild, decisions and opinions, never about
real-world race, religion, nationality, sexuality or disability. It holds well in practice; it is a prompt, not a
guarantee.

Alternatives that fit a 16 GB card, all one `ollama pull` away, then set `OllamaModel`:

| Model | Size | Notes |
|---|---|---|
| `dolphin3:8b` | 4.9 GB | uncensored, twice as fast, noticeably dumber; drifts out of character over long threads |
| `mistral-nemo:12b` | 7.1 GB | best natural voice, lightly censored: fine for gamer toxicity, may soften the worst characters |
| `hf.co/mlabonne/gemma-3-12b-it-abliterated-GGUF:Q4_K_M` | 7.3 GB | the previous default; see above |
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

**Editing them:** the source of truth is the plain-text `server\personalities\personalities.txt`. The Desktop
shortcut **Solo Azeroth - Edit Personalities** opens it in Notepad and, when you close Notepad, rebuilds the SQL,
applies it and reloads the bots (no restart). Same thing from a prompt: `solo.cmd personalities`. Each entry starts
with `=== KEY ===` and the text until the next header is what the model is told; the file explains the rest. The
number of entries per kind is the mix. Bots keep the personality they already rolled; `solo.cmd personalities
--reroll` makes everyone pick again from the new list. To hand one bot a specific voice in game:
`.ollama personality set <bot> <KEY>`.

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

## What we had to fix in the module

Three things in mod-ollama-chat kept every bot silent on a fresh install; the fixes live in
`server\patches\mod-ollama-chat-solo.diff` and `clone-core.ps1` applies them:

- Bots join the General channel of the zone they log in to and never re-join as they travel. The module only let a
  bot reply if it was a member of your exact zone channel, so the crowd around you was ineligible. Now same-zone
  bots are eligible and get joined to the channel when they speak.
- The realm-wide LFG feed was gated on a bot being in your zone. Now any real player in that channel is an audience.
- With `"ChatDebug": 1` in `settings.local.json` the world log prints a funnel summary every 30 s
  (`ambient tick: bots= audience= due= rolled= topic= destination= governor= submitted=`) and every reply decision.

And one thing in our own config: `AiPlayerbot.SelfBotLevel` must stay at 1. At 3 the real player's character gets a
bot AI attached on login, the module counts them as a bot, and nothing is ever said.

## Why they now answer you (the conversation layer)

Out of the box the module makes quips, not conversation. What the code did, and what the patch changes:

| Stock behaviour | Effect you saw | Now |
|---|---|---|
| A reply prompt held one line: the message, plus this bot's private history with you. Nothing another bot had said, no channel context. | A bot answering a bot had never seen what you said; "you're just wrong" landed on a bot that did not know what it was wrong about. | Every scope (a channel instance, the say range in a zone, a party, a whisper pair) keeps a transcript of the last 16 lines with speaker names. Every reply and every ambient line is shown it. |
| Each message picked responders by a fresh dice roll; the bot mid-exchange with you rolled 95% and was then shuffled with the bystanders. | The answer usually came from someone who was not in the exchange. | Two participants who answered each other are *engaged* for 150 s. Engaged bots are picked first, bystanders fill at most one slot and only 35% of the time. |
| Only a person's line counted as direct address. A bot answering a bot sat on the 30 s per-bot cooldown and the 6 s channel cooldown. | Bot-to-bot threads died after one line. | Being engaged is direct address for bots too, so an argument can run to the chain-depth limit (8 hops) before a person has to feed it. |
| "Same first three words as any of the last 8 lines" was a repetition. | Short retorts ("no way, ...") were dropped after generation. | Opener check reduced to the last 2 lines; similarity threshold raised. |
| Ambient lines carried no context, fired into live threads and triggered replies. | "anyone farming badges?" in the middle of an argument. | While a scope has a line under 45 s old, only 25% of ambient lines get through, and those are told to join the conversation. |
| A separate model call classified every answered line as POSITIVE/NEGATIVE for a +-0.05 tone number. | One of four generation slots busy with nothing. | Off. The memory and relationship features carry how a bot feels. |
| "Reply in under 15 words", 60 tokens. | Every bot: "Ugh, seriously?" | Prompt is a chat log ending in "write your next line: answer what was said, use names, take a side, push back". 110 tokens. Both editable in `prompts.txt`. |

| First session with the layer: four engaged bots, two answers per bot line, and engaged replies exempt from every cap. | Forty lines a minute, all opening "Seriously, Name?" because each bot copied the transcript. | A bot's line gets exactly one answer; bot-to-bot lines are capped per channel per minute (`ChainLinesPerMinute`, 8); the opener filter applies to engaged replies too; a repeat/presence penalty on generation; the prompt names the exact line to answer and forbids copying openers; transcript trimmed to 10 lines; "Name:" labels the model writes are stripped whoever's name it is. |

| Only bots in your zone could speak or reply in General. | 1000 bots over four continents is a handful per zone, and the funnel showed it: `due=85 ... destination=0 submitted=0`, forty "nowhere to speak" per tick. Quiet the moment you left Mulgore. | `Chatter.ZoneChannelsAcrossMap`: any bot on your continent may speak and reply in the zone channel you are reading (it is joined to it at delivery). Off restores the same-zone rule. |

| Every line opened "Ugh," / "Hmph," / "Seriously," and quoted the line above ("a moose all day?" nine times in a row). The prompt told the bot to "pick up its actual words", and one system prompt listed thirty adjectives that every bot then tried to be at once. | One voice, one phrase, all night. | The prompt says react in your own words and do not reuse phrases from the chat; the system prompt frames the adjectives as the range of the room and tells the bot its personality picks which; every prompt gets one random **style hint** ("open with a question", "under ten words", "no interjection at all", ...) from the STYLE_HINTS section of `prompts.txt`; a line that copies a run of five words from one of the last three lines is dropped. |
| "Okay, here we go... " / "Right, here's my reply: " in front of the line. | | Stripped. |
| The transcript ran into the instruction on one line (prompts.txt joins lines with spaces). | The model answered the instruction text. | The chat log always gets its own lines. |

Knobs: `Chatter.ZoneChannelsAcrossMap`, `Transcript.Lines`, `Transcript.WindowSeconds`, `BotConversation.EngagedWindowSeconds`,
`BotConversation.ChainLinesPerMinute`, `Ambient.HoldSeconds`, `Ambient.HoldPassPct`, `Repetition.CheckDirectAddress`
(all under `OllamaChat.` in `setup\gen_configs.py`), and the ADDRESSED and AMBIENT_JOIN sections of
`personalities\prompts.txt`.

## Diagnosing "the bots are not talking"

- `Server.log` lines carry a timestamp, and the previous log is kept as `Server.log.<date>` on every restart, so
  "it was quiet at 18:40" can be checked. With `"ChatDebug": 2` every generation logs `Raw response:` (what the model
  said before cleanup) and every channel line logs `Delivered to '<channel>' (... real players in channel: <names>)`.
  If your name is in that list, the line reached your client; if you did not see it, look at the client's chat
  filters or which channel tab you are on.
- `.ollama status` in game: endpoint, model, queue depth, delivered and dropped counters. `0 submitted` after a few
  minutes with you standing among bots means the module doesn't see you as a real player: check SelfBotLevel.
- `.ollama test say something rude about mages`: one raw prompt straight to the model; the reply is printed to
  the server console and log.
- `solo.cmd status`: is Ollama listening? `ollama list` in a terminal: is the model pulled?
- First bot line after a quiet spell takes 6+ s, then they're fast: the model got unloaded. `ollama ps` should say
  UNTIL = Forever; if not, `solo.cmd ollama --restart` (the start script sets `OLLAMA_KEEP_ALIVE=-1` as a user
  environment variable, but an Ollama started by its tray app before that only picks it up after a restart).
- Are you in the channel? `/join General` after a zone change if you left it.
- Bots sit still and silent until a real player is online (by design).
- The worldserver console prints `[Ollama Chat]` lines on startup; errors about the endpoint mean Ollama is not up
  or `OllamaUrl` is wrong.
