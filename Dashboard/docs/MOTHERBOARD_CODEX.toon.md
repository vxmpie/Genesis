# GENESIS_MOTHERBOARD_CODEX [FORMAT: TOON-SPEC v1.0 | TARGET: ANTIGRAVITY_AGENT_ONLY]
@META{project:"Genesis Dashboard + Genesis Motherboard Discord Station",root:"C:/Dev/Genesis/Dashboard",vault:"C:/Dev/Genesis/Dashboard/data/discord",updated:"2026-11-21T18:30+07:00",policy:"ZERO_EMOJI|NO_DOUBLE_SLASH_PREFIX|ADMIN_TASK_ONLY|AUTO_COMMIT_PUSH"}

---

## @1_SESSION_COMMIT_LEDGER [branch:main]
| hash | type | summary | files_touched |
|---|---|---|---|
| `8feef3e` | `feat(discord)` | 2-way Discord Gateway v10 bot, slash commands, interactive buttons, live voice HUD, ADB/GDI screenshots | `discord_bot.py`, `routes.py`, `server.py`, `test_discord_bot.py` |
| `9fa8dad` | `feat(discord)` | Multi-category orbital station topology + Global Intel Cortex (`intel_feeds.py`) | `intel_feeds.py`, `discord_bot.py`, `routes.py`, `test_discord_bot.py` |
| `11d7f33` | `feat(discord)` | Renamed guild to `Genesis Motherboard`, purged `//` prefixes, added hoisted roles (`OVERLORD`,`MOTHERBOARD CORE`,`AUDIO DRONE`), `#command-wall`, dynamic feed/macro CRUD, encapsulated all runtime JSON into `Dashboard/data/discord/` | `intel_feeds.py`, `discord_bot.py`, `routes.py`, `.gitignore`, `test_discord_bot.py` |
| `f8b0b0a` | `feat(discord)` | Bilingual engine (`DUAL`/`TH`/`EN`), bilingual channel topics, GitHub Global Trending scraper, CISA Zero-Day CVE KEV radar, 08:30 Morning Briefing, `#captain-datacore` auto-ingest | `intel_feeds.py`, `discord_bot.py`, `test_discord_bot.py` |
| `82a6518` | `feat(discord)` | Added `#google-gemini-radar` channel, `/google` command, zero-overhead local Antigravity IDE watcher (`os.stat` on `version.txt` + `builtin/skills`) + 60s HTTP `ETag`/`304` Google/Gemini delta watcher | `intel_feeds.py`, `discord_bot.py`, `test_discord_bot.py` |
| `a0965a1` | `fix(discord)` | Fixed Epic Games 404 UUID `urlSlug` by resolving `offerMappings[0].pageSlug` & filtering 32-char hex UUIDs; added `_has_epic_zero_discount_offer` (`discountPercentage==0`); replaced CheapShark redirect with GamerPower PC Giveaways (`json_gamerpower`); added cross-field URL deduplication (`_dedupe_lines_by_url`) and board clutter cleanup | `intel_feeds.py`, `discord_bot.py`, `test_discord_bot.py` |
| `05beee0` | `feat(discord)` | Added Single-Slot Transient Popup Window (`POPUP_TTL_SECONDS=120.0`, instant delete-on-next-click + 2m auto-expiry) and Read-Only Board Channel Guard (`@everyone` `SEND_MESSAGES=DENY` + instant `MESSAGE_CREATE` auto-delete on 8 board rooms) | `discord_bot.py`, `test_discord_bot.py` |

---

## @2_HOST_STORAGE_PURGE_MANIFEST [Drive_C_Reclaimed:+4.453_GB | 321.462_GB -> 325.915_GB_Free]
```yaml
purged_root_c:
  - C:/Drivers                  # 1.72 GB OEM driver installers (already installed in DriverStore)
  - C:/inetpub                  # Empty IIS root residue
  - C:/Setup.log                # Root installer log
  - C:/XboxGames                # Empty Xbox stub folder
purged_dev_workspace:
  - C:/Dev/Questbar RPG         # Legacy retired project (explicitly authorized by user)
purged_user_profile_C_Users_rocke:
  - .antigravity-ide            # 1,419.6 MB legacy duplicate IDE cache (active is .antigravity + .gemini)
  - w64devkit                   # 1,033.2 MB unused portable MinGW toolchain
  - pipx                        # 98.4 MB broken Python 3.13 venv residue
  - .node-red                   # 77.6 MB unused Node-RED runtime dir
  - AppData/Local/Temp/*        # 123.3 MB unlocked temp artifacts
  - orphan_dotfiles_24: [.abacusai, .agent, .agents, .antigravity_handover_vault, .claude.json, .claude.json.backup, .codex, .condarc, .cufflinks, .cursor, .dlt, .flowise, .local, .marimo, .matplotlib, .mem0, .opencode, .openclaw, .playwright-mcp, .qwen, .security_audit, .streamlit, .u2net, .yarnrc, nul, .lesshst, .viminfo, .wget-hsts, network_hardening.log]
workspace_encapsulation_contract:
  c_root_custom_dirs: [C:/Dev]  # Only custom folder at C:\ root
  dev_projects:
    - C:/Dev/Genesis            # Main Dashboard + Discord Motherboard monorepo
    - C:/Dev/Bot                # Standalone Roblox MuMu automation suite (keep separate)
  discord_runtime_vault: C:/Dev/Genesis/Dashboard/data/discord/ # Gitignored; holds station.json, feeds.json, commands.json, notes.json
```

---

## @3_DISCORD_GUILD_TOPOLOGY [Guild:"Genesis Motherboard" | guild_id:1541091932657426521 | app_id:1572960715151515829]

### @3.1_ROLES [Hoisted:True | Mentionable:True]
| key | name | role_id | color_hex | assigned_to |
|---|---|---|---|---|
| `overlord` | `OVERLORD` | `1573570198047690833` | `0xF59E0B` | Guild Owner (`rocke`) |
| `core` | `MOTHERBOARD CORE` | `1573570201608523989` | `0x06B6D4` | Genesis Bot (`1572960715151515829`) |
| `audio` | `AUDIO DRONE` | `1573570204557250610` | `0x8B5CF6` | Companion voice music bot slot (e.g. Jockie Music) |

### @3.2_CHANNELS_AND_PINNED_BOARDS
`LOCK_MODES`:
- `VOICE_HUD_LOCKED`: Voice channel (`type=2`), `@everyone` `VIEW_CHANNEL=ALLOW`, `CONNECT=DENY`; renamed every 5m (`300s`) by `_hud_updater_loop`.
- `BOARD_READONLY_GUARDED`: Text channel (`type=0`), `@everyone` `VIEW_CHANNEL|READ_MESSAGE_HISTORY|USE_APPLICATION_COMMANDS=ALLOW`, `SEND_MESSAGES|ADD_REACTIONS|THREADS=DENY` + active `MESSAGE_CREATE` auto-delete guard (deletes any non-bot chat or `type==6` pin system notice immediately) + Single-Slot 120s Transient Popup manager.
- `VAULT_AUTO_INGEST`: Text channel (`type=0`), writable; any non-bot message/attachment is ingested into `notes.json` and replied with `[VAULT #id]`.
- `CREW_WRITABLE` / `VOICE_OPEN`: Standard interactive chat or voice channels.

| category | pos | channel_name | channel_id | pinned_board_msg_id | mode | purpose |
|---|---|---|---|---|---|---|
| `[00] TELEMETRY ARRAY` | 0..3 | `CORE: ..% \| RAM: ../..G`<br>`FLEET: .. MUMU \| PING: ..ms`<br>`HULL C: ...G FREE \| BOOST: ..`<br>`BKK: ..C \| BTC: $..K` | `1573558490599915580`<br>`1573558494286577787`<br>`1573558498074038282`<br>`1573565224819228683` | `N/A` | `VOICE_HUD_LOCKED` | Live 4-slot hardware/fleet/storage/planetary HUD |
| `[01] BRIDGE COMMAND` | 0 | `bridge-command` | `1573561735980519424` | `1573561759468617863` | `BOARD_READONLY_GUARDED` | 20-button interactive Bridge Console (`build_deck_payload`) |
| `[01] BRIDGE COMMAND` | 1 | `command-wall` | `1573570363349278750` | `1573570375705432099` | `BOARD_READONLY_GUARDED` | Dynamic 22-command directory, custom macros, feed summary (`build_command_wall_payload`) |
| `[01] BRIDGE COMMAND` | 2 | `reactor-telemetry` | `1541092042204254278` | `N/A (alert stream)` | `BOARD_READONLY_GUARDED` | Automated watchdog, crash, RAM guard, and 08:30 Morning Briefing stream |
| `[01] BRIDGE COMMAND` | 3 | `captain-datacore` | `1573561739495342174` | `N/A (vault stream)` | `VAULT_AUTO_INGEST` | Drop text/links/files or `/log` to archive into `notes.json` |
| `[02] INTEL CORTEX` | 0 | `google-gemini-radar` | `1573597220593205258` | `1573597260934029336` | `BOARD_READONLY_GUARDED` | Local Antigravity IDE telemetry + Google AI / Gemini / DeepMind / CLI / SDK feeds + instant delta alerts |
| `[02] INTEL CORTEX` | 1 | `ai-singularity-feed` | `1573565227335942226` | `1573565257866027179` | `BOARD_READONLY_GUARDED` | HuggingFace Daily Papers, TechCrunch AI, OpenAI News |
| `[02] INTEL CORTEX` | 2 | `tech-cyber-radar` | `1573565229420515389` | `1573565265872945243` | `BOARD_READONLY_GUARDED` | Hacker News, Lobsters, CISA Zero-Day KEV CVEs, GitHub Global Trending |
| `[02] INTEL CORTEX` | 3 | `world-market-pulse` | `1573565231488303116` | `1573565276966887435` | `BOARD_READONLY_GUARDED` | Bangkok Open-Meteo sensors, BTC/ETH/SOL + USD/THB FX, BBC World News, GitHub user activity (`vxmpie`/`swnst`) |
| `[02] INTEL CORTEX` | 4 | `free-games-loot` | `1573565233694507160` | `1573597297214881954` | `BOARD_READONLY_GUARDED` | Epic Games Store (`FREE NOW` & `UPCOMING FREE`) + GamerPower Verified PC Giveaways |
| `[03] CREW QUARTERS` | 0..1 | `observation-lounge`<br>`holodeck-archives` | Guild dynamic | `N/A` | `CREW_WRITABLE` | Personal chat lounge & media/clips archive |
| `[04] COMMS & AIRLOCKS` | 0..1 | `Bridge Comms [01]`<br>`Tactical Ops [02]` | Guild dynamic | `N/A` | `VOICE_OPEN` | Open voice channels for owner & `AUDIO DRONE` music bot |

---

## @4_SERVICE_INTERNALS_AND_STATE_MACHINES

### @4.1_DISCORD_BOT_ENGINE [`Dashboard/backend/services/discord_bot.py`]
```yaml
constants:
  GUILD_MOTHERSHIP_NAME: "Genesis Motherboard"
  BOT_MOTHERSHIP_NICK: "MOTHERBOARD CORE"
  POPUP_TTL_SECONDS: 120.0
  GATEWAY_INTENTS: 513 # (1 << 0) GUILDS | (1 << 9) GUILD_MESSAGES

background_tasks_in_DiscordBotService:
  1_gateway_supervisor_loop:
    - Connects wss://gateway.discord.gg/?v=10&encoding=json
    - Auto-provisions guild if intel_channel_ids.google is missing
    - Dispatches INTERACTION_CREATE -> _handle_interaction()
    - Dispatches MESSAGE_CREATE -> _handle_datacore_message()
  2_hud_updater_loop:
    - Interval: 300s (5 min) -> update_hud_once() -> format_hud_channel_names()
    - Skips PATCH if names match state.hud_last_names
  3_intel_broadcast_loop:
    - Interval: 1800s (30 min) -> sync_intel_channels() + refresh_bridge_console() + refresh_command_wall()
  4_morning_briefing_loop:
    - Checks local clock every 45s; fires once/day at 08:30 (state.last_morning_briefing_date != YYYY-MM-DD)
    - Posts build_omni_briefing_payload(is_morning_dispatch=True) to #reactor-telemetry
  5_google_antigravity_watcher_loop:
    - Interval: 60s -> check_google_antigravity_updates_once()
    - Stage A (0ms local stat): check_local_antigravity_delta_sync(state) checks mtime of ~/.gemini/antigravity/version.txt & builtin/skills
    - Stage B (60s HTTP conditional GET): check_google_external_feeds_delta_sync(state) sends If-None-Match (ETag) / If-Modified-Since
    - On delta: posts [GOOGLE RADAR ALERT] embed to #google-gemini-radar and refreshes the pinned Google board

interaction_and_single_slot_popup_state_machine:
  in_place_board_update_ack_type_6:
    triggers:
      - action in ("deck_refresh", "wall_refresh") or action.startswith("lang_cycle:")
      - action in ("bridge", "deck") when clicked on #bridge-command pinned board
      - action == "wall" when clicked on #command-wall pinned board
      - action in ("google", "ai", "tech", "world", "loot") when clicked inside its own dedicated Intel channel
    behavior:
      - Sends callback type=6 (DEFERRED_UPDATE_MESSAGE)
      - PATCHes /webhooks/{app_id}/{token}/messages/@original in-place (zero new messages created)
      - If clicked_msg != board_msg_id (i.e. inside an existing popup), resets the 120s TTL timer for clicked_msg
  single_slot_transient_popup_ack_type_5:
    triggers:
      - All button clicks from #bridge-command / #command-wall that open status/boost/mumu/processes/briefing/screenshots/intel/clean/purge
      - All slash commands (/status, /boost, /mumu, /google, /ai, /tech, /world, /loot, /briefing, etc.)
    behavior:
      1. Callback type=5 (DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE)
      2. Immediately awaits _dismiss_active_popup(channel_id): cancels prior timer & DELETEs prior popup_msg_id in that channel
      3. Executes _execute_command_action() and appends " | Auto-closes in 2m" to embed footer
      4. PATCHes /webhooks/{app_id}/{token}/messages/@original -> extracts new_popup_id
      5. _register_transient_popup(channel_id, new_popup_id):
         - Saves state.active_popups[channel_id] = new_popup_id
         - Runs _cleanup_board_channel_clutter(keep_msg_id=board_msg_id, active_popup_id=new_popup_id)
         - Schedules _expire_after_ttl() task -> sleeps 120s -> DELETEs /channels/{channel_id}/messages/{new_popup_id}

slash_commands_22:
  bridge_overview: [/bridge, /wall, /briefing, /lang]
  intel_cortex: [/google, /ai, /tech, /world, /loot, /feed-add, /feed-remove, /feeds]
  reactor_fleet_ops: [/status, /boost, /mumu, /recover, /processes, /screenshot, /clean, / purge] # (/purge)
  datacore_macros: [/log, /cmd-add, /cmd-remove, /run]
```

### @4.2_GLOBAL_INTEL_ENGINE [`Dashboard/backend/services/intel_feeds.py`]
```yaml
bilingual_engine:
  valid_modes: [dual, th, en] # Stored in station.json -> lang; cycled via /lang or "Lang: DUAL/TH/EN" button on every board
  helpers: [normalize_lang, tr, tr_block, lang_button_label]

feed_registry_schema_v4: # Stored in Dashboard/data/discord/feeds.json
  google:
    - {name: "Google AI & Gemini Official Blog", kind: "rss", url: "https://blog.google/innovation-and-ai/technology/ai/rss/"}
    - {name: "Google Developers Blog", kind: "rss", url: "https://developers.googleblog.com/feeds/posts/default"}
    - {name: "Google DeepMind Blog", kind: "rss", url: "https://deepmind.google/blog/rss.xml"}
    - {name: "Gemini CLI Releases (GitHub)", kind: "rss", url: "https://github.com/google-gemini/gemini-cli/releases.atom"}
    - {name: "Google GenAI Python SDK Releases", kind: "rss", url: "https://github.com/googleapis/python-genai/releases.atom"}
  ai:
    - {name: "HuggingFace Daily Papers", kind: "json_hf", url: "https://huggingface.co/api/daily_papers"}
    - {name: "TechCrunch AI", kind: "rss", url: "https://techcrunch.com/category/artificial-intelligence/feed/"}
    - {name: "OpenAI News", kind: "rss", url: "https://openai.com/news/rss.xml"}
  tech:
    - {name: "Hacker News Front Page", kind: "json_hn", url: "https://hacker-news.firebaseio.com/v0/topstories.json"}
    - {name: "CISA Zero-Day & KEV CVE Radar", kind: "json_cisa_kev", url: "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"}
    - {name: "GitHub Global Trending", kind: "html_gh_trending", url: "https://github.com/trending"}
    - {name: "Lobsters Computing", kind: "json_lobsters", url: "https://lobste.rs/hottest.json"}
  world:
    - {name: "BBC World News", kind: "rss", url: "https://feeds.bbci.co.uk/news/world/rss.xml"}
  loot:
    - {name: "Epic Games Store (Free Now & Upcoming)", kind: "json_epic", url: "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=TH&allowCountries=TH"}
    - {name: "Verified PC Giveaways (Steam / IndieGala / Itch)", kind: "json_gamerpower", url: "https://www.gamerpower.com/api/giveaways?platform=pc&type=game"}

critical_link_resolution_invariants:
  1_epic_store_slug_resolution (_resolve_epic_store_url):
    - NEVER prefer el.urlSlug first: Epic returns a 32-char hex internal UUID (e.g. "2fd257a6cd80405a833f9004ff07993a") in urlSlug when productSlug is null, which causes HTTP 404 on store.epicgames.com/en-US/p/{slug}.
    - Resolution priority:
      1) el.offerMappings[*].pageSlug (rejecting [0-9a-fA-F]{32})
      2) el.catalogNs.mappings[*].pageSlug (rejecting [0-9a-fA-F]{32})
      3) el.productSlug (strip trailing "/home", rejecting [0-9a-fA-F]{32})
      4) el.urlSlug (only if not matching [0-9a-fA-F]{32})
      5) Fallback: "https://store.epicgames.com/en-US/p/{slug}" else "https://store.epicgames.com/en-US/free-games"
  2_epic_100_percent_free_filter (_has_epic_zero_discount_offer):
    - In Epic freeGamesPromotions API, discountSetting.discountPercentage == 0 means 0% price remaining (100% FREE).
    - Non-zero values (e.g. 20, 35, 55, 70) in upcomingPromotionalOffers are paid discounts and MUST be excluded.
  3_cross_feed_deduplication (_dedupe_lines_by_url):
    - Applied across all fields within fetch_google_gemini_intel, fetch_ai_cortex_intel, fetch_tech_radar_intel, fetch_world_pulse_intel, and fetch_free_loot_intel.
    - json_gamerpower also filters out titles containing "(epic games)" so Epic freebies never appear twice on #free-games-loot.
```

---

## @5_RUNTIME_VAULT_SCHEMAS [`Dashboard/data/discord/*.json`]
```json
{
  "station.json": {
    "guild_id": "1541091932657426521",
    "app_id": "1572960715151515829",
    "lang": "dual | th | en",
    "roles": {"overlord": "role_id", "core": "role_id", "audio": "role_id"},
    "command_deck_channel_id": "1573561735980519424",
    "deck_message_id": "1573561759468617863",
    "command_wall_channel_id": "1573570363349278750",
    "command_wall_message_id": "1573570375705432099",
    "reactor_channel_id": "1541092042204254278",
    "dropzone_channel_id": "1573561739495342174",
    "hud_channel_ids": ["id0", "id1", "id2", "id3"],
    "hud_last_names": ["CORE:...", "FLEET:...", "HULL C:...", "BKK:..."],
    "intel_channel_ids": {"google": "id", "ai": "id", "tech": "id", "world": "id", "loot": "id"},
    "intel_message_ids": {"google": "mid", "ai": "mid", "tech": "mid", "world": "mid", "loot": "mid"},
    "active_popups": {"channel_id": "active_transient_popup_msg_id"},
    "google_watcher_baseline": {
      "agy_version": "1.23.2",
      "agy_skills": ["agy-customizations", "..."],
      "http_cache": {"feed_url": {"etag": "...", "last_modified": "..."}}
    },
    "last_morning_briefing_date": "YYYY-MM-DD",
    "last_intel_sync_utc": "ISO8601"
  },
  "commands.json": [
    {"name": "macro-slug", "description": "Short label", "response": "Text/URL output", "updated_at": "ISO8601"}
  ],
  "notes.json": [
    {"id": 1, "text": "Archived content or attachment URLs", "author": "username", "timestamp_utc": "ISO8601"}
  ]
}
```

---

## @6_FAST_OPS_COMMANDS [For Future Agent Turns]
```powershell
# 1. Run full 53-test backend unit suite:
Set-Location "C:\Dev\Genesis\Dashboard"; .\venv\Scripts\python.exe -m unittest discover -s tests -v

# 2. Run frontend linter & build:
Set-Location "C:\Dev\Genesis\Dashboard\frontend"; npx oxlint; if ($LASTEXITCODE -eq 0) { npm run build }

# 3. Restart elevated Genesis Dashboard server (NEVER run python server.py non-elevated):
Stop-Process -Name python,pythonw -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; Start-ScheduledTask -TaskName "Genesis-Dashboard-Startup"

# 4. Force live Discord guild re-provision & board clutter sweep:
Set-Location "C:\Dev\Genesis\Dashboard"; .\venv\Scripts\python.exe -c "import asyncio; from backend.services.discord_bot import CONFIG, provision_guild_station; print(asyncio.run(provision_guild_station(CONFIG['alerts']['discord_bot_token'])))"
```
