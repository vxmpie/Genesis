import copy
import html
import json
import os
import re
import socket
import threading
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from backend.core.config import DATA_DIR

# --- Constants, Paths & Regex Guards ---
DISCORD_DATA_DIR = DATA_DIR / "discord"
FEEDS_REGISTRY_PATH = DISCORD_DATA_DIR / "feeds.json"

USER_AGENT = "Genesis-Motherboard-Core/4.1"
_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF\uFE0F]")
_WHITESPACE_RE = re.compile(r"\s+")

_SENSOR_LOCK = threading.Lock()
_REGISTRY_LOCK = threading.RLock()
_SENSOR_CACHE: dict = {"updated_at": 0.0, "weather": None, "markets": None}

GITHUB_ACCOUNTS = ("vxmpie", "swnst")
VALID_FEED_CATEGORIES = ("ai", "tech", "world", "loot")

DEFAULT_FEEDS_REGISTRY: dict = {
    "ai": [
        {
            "name": "HuggingFace Daily Papers",
            "kind": "json_hf",
            "url": "https://huggingface.co/api/daily_papers?limit=5",
            "enabled": True,
        },
        {
            "name": "TechCrunch AI",
            "kind": "rss",
            "url": "https://techcrunch.com/category/artificial-intelligence/feed/",
            "enabled": True,
        },
        {
            "name": "OpenAI News",
            "kind": "rss",
            "url": "https://openai.com/news/rss.xml",
            "enabled": True,
        },
    ],
    "tech": [
        {
            "name": "Hacker News Front Page",
            "kind": "json_hn",
            "url": "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=6",
            "enabled": True,
        },
        {
            "name": "The Verge Tech Wire",
            "kind": "rss",
            "url": "https://www.theverge.com/rss/index.xml",
            "enabled": True,
        },
        {
            "name": "Lobsters Engineering",
            "kind": "json_lobsters",
            "url": "https://lobste.rs/hottest.json",
            "enabled": True,
        },
    ],
    "world": [
        {
            "name": "BBC World News",
            "kind": "rss",
            "url": "http://feeds.bbci.co.uk/news/world/rss.xml",
            "enabled": True,
        },
    ],
    "loot": [
        {
            "name": "Epic Games Freebies",
            "kind": "json_epic",
            "url": "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=TH&allowCountries=TH",
            "enabled": True,
        },
        {
            "name": "CheapShark 100% Off Deals",
            "kind": "json_cheapshark",
            "url": "https://www.cheapshark.com/api/1.0/deals?upperPrice=0&pageSize=6",
            "enabled": True,
        },
    ],
}


# --- Sanitization & Registry Storage ---
def strip_emojis(text: str) -> str:
    cleaned = _EMOJI_RE.sub("", str(text or ""))
    return _WHITESPACE_RE.sub(" ", html.unescape(cleaned)).strip()


def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _truncate(text: str, max_len: int = 84) -> str:
    clean = strip_emojis(text)
    if len(clean) <= max_len:
        return clean
    return clean[: max_len - 3].rstrip() + "..."


def _clip_field(lines: list[str], fallback: str = "Signal temporarily unavailable.") -> str:
    if not lines:
        return fallback
    text = "\n".join(lines)
    if len(text) <= 1020:
        return text
    clipped: list[str] = []
    total = 0
    for line in lines:
        if total + len(line) + 1 > 1015:
            break
        clipped.append(line)
        total += len(line) + 1
    return "\n".join(clipped) if clipped else text[:1020]


def load_feeds_registry() -> dict:
    with _REGISTRY_LOCK:
        DISCORD_DATA_DIR.mkdir(parents=True, exist_ok=True)
        if FEEDS_REGISTRY_PATH.exists():
            try:
                data = json.loads(FEEDS_REGISTRY_PATH.read_text(encoding="utf-8-sig"))
                if isinstance(data, dict):
                    changed = False
                    for cat in VALID_FEED_CATEGORIES:
                        if cat not in data or not isinstance(data[cat], list):
                            data[cat] = copy.deepcopy(DEFAULT_FEEDS_REGISTRY[cat])
                            changed = True
                    if changed:
                        save_feeds_registry(data)
                    return data
            except Exception:
                pass
        seeded = copy.deepcopy(DEFAULT_FEEDS_REGISTRY)
        save_feeds_registry(seeded)
        return seeded


def save_feeds_registry(registry: dict) -> None:
    with _REGISTRY_LOCK:
        DISCORD_DATA_DIR.mkdir(parents=True, exist_ok=True)
        tmp_path = FEEDS_REGISTRY_PATH.with_suffix(".json.tmp")
        tmp_path.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8", newline="\n")
        os.replace(tmp_path, FEEDS_REGISTRY_PATH)


def add_custom_rss_feed(category: str, name: str, url: str) -> dict:
    cat = str(category or "").strip().lower()
    if cat not in VALID_FEED_CATEGORIES:
        raise ValueError(f"Category must be one of: {', '.join(VALID_FEED_CATEGORIES)}")
    clean_name = strip_emojis(name)[:48]
    if not clean_name:
        raise ValueError("Feed name cannot be empty")
    clean_url = str(url or "").strip()
    parsed = urllib.parse.urlsplit(clean_url)
    if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc:
        raise ValueError("Feed URL must be a valid http(s) URL")

    with _REGISTRY_LOCK:
        reg = load_feeds_registry()
        items = reg.setdefault(cat, [])
        for item in items:
            if str(item.get("name", "")).lower() == clean_name.lower():
                item["url"] = clean_url
                item["kind"] = "rss"
                item["enabled"] = True
                save_feeds_registry(reg)
                return {"action": "updated", "category": cat, "feed": item}
        entry = {"name": clean_name, "kind": "rss", "url": clean_url, "enabled": True}
        items.append(entry)
        save_feeds_registry(reg)
        return {"action": "added", "category": cat, "feed": entry}


def remove_feed_source(category: str, name: str) -> dict:
    cat = str(category or "").strip().lower()
    if cat not in VALID_FEED_CATEGORIES:
        raise ValueError(f"Category must be one of: {', '.join(VALID_FEED_CATEGORIES)}")
    target_low = strip_emojis(name).lower()
    with _REGISTRY_LOCK:
        reg = load_feeds_registry()
        items = reg.get(cat, [])
        kept = [it for it in items if str(it.get("name", "")).lower() != target_low]
        removed = len(items) - len(kept)
        if removed == 0:
            raise KeyError(f"Feed '{name}' not found in category '{cat}'")
        reg[cat] = kept
        save_feeds_registry(reg)
        return {"removed": removed, "category": cat, "name": name}


def list_feed_sources() -> dict:
    return load_feeds_registry()


# --- HTTP & XML Fetchers ---
def _fetch_text(url: str, timeout: float = 8.0) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def _fetch_json(url: str, timeout: float = 8.0) -> dict | list:
    raw = _fetch_text(url, timeout=timeout)
    return json.loads(raw)


def parse_rss_or_atom_xml(xml_text: str, limit: int = 5) -> list[dict]:
    items: list[dict] = []
    if not xml_text or not xml_text.strip():
        return items
    root = ET.fromstring(xml_text)

    for item in root.findall(".//item"):
        title_el = item.find("title")
        link_el = item.find("link")
        title = strip_emojis(title_el.text if title_el is not None and title_el.text else "")
        link = (link_el.text or "").strip() if link_el is not None and link_el.text else ""
        if title and link:
            items.append({"title": title, "url": link})
        if len(items) >= limit:
            return items

    atom_ns = "{http://www.w3.org/2005/Atom}"
    for entry in root.findall(f".//{atom_ns}entry"):
        title_el = entry.find(f"{atom_ns}title")
        link_el = entry.find(f"{atom_ns}link")
        title = strip_emojis(title_el.text if title_el is not None and title_el.text else "")
        link = ""
        if link_el is not None:
            link = (link_el.attrib.get("href") or link_el.text or "").strip()
        if title and link:
            items.append({"title": title, "url": link})
        if len(items) >= limit:
            break

    return items


def _collect_feed_lines(source: dict, limit: int = 5) -> list[str]:
    kind = str(source.get("kind", "rss"))
    url = str(source.get("url", "")).strip()
    if not url or not bool(source.get("enabled", True)):
        return []

    lines: list[str] = []
    try:
        if kind == "json_hf":
            papers = _fetch_json(url, timeout=8.0)
            if isinstance(papers, list):
                for idx, entry in enumerate(papers[:limit], 1):
                    paper = entry.get("paper", {}) if isinstance(entry, dict) else {}
                    pid = str(paper.get("id", ""))
                    title = _truncate(paper.get("title") or entry.get("title", ""), 78)
                    upvotes = int(paper.get("upvotes", 0))
                    if pid and title:
                        lines.append(f"`{idx}.` [{title}](https://huggingface.co/papers/{pid}) (`+{upvotes}`)")
        elif kind == "json_hn":
            hn_data = _fetch_json(url, timeout=8.0)
            hits = hn_data.get("hits", []) if isinstance(hn_data, dict) else []
            for idx, hit in enumerate(hits[:limit], 1):
                title = _truncate(hit.get("title", ""), 74)
                oid = hit.get("objectID", "")
                link = hit.get("url") or f"https://news.ycombinator.com/item?id={oid}"
                pts = int(hit.get("points") or 0)
                if title:
                    lines.append(f"`{idx}.` [{title}]({link}) (`{pts} pts`)")
        elif kind == "json_lobsters":
            stories = _fetch_json(url, timeout=8.0)
            if isinstance(stories, list):
                for idx, st in enumerate(stories[:limit], 1):
                    title = _truncate(st.get("title", ""), 74)
                    link = st.get("url") or st.get("short_id_url") or ""
                    score = int(st.get("score") or 0)
                    if title and link:
                        lines.append(f"`{idx}.` [{title}]({link}) (`{score} pts`)")
        elif kind == "json_epic":
            epic = _fetch_json(url, timeout=8.0)
            elements = (
                epic.get("data", {})
                .get("Catalog", {})
                .get("searchStore", {})
                .get("elements", [])
                if isinstance(epic, dict)
                else []
            )
            for el in elements:
                if not isinstance(el, dict):
                    continue
                promos = el.get("promotions") or {}
                offers = promos.get("promotionalOffers") or []
                discount_price = el.get("price", {}).get("totalPrice", {}).get("discountPrice")
                if offers and discount_price == 0:
                    title = strip_emojis(el.get("title", "Unknown Title"))
                    slug = el.get("productSlug") or el.get("urlSlug") or ""
                    if not slug:
                        mappings = el.get("catalogNs", {}).get("mappings") or []
                        if mappings and isinstance(mappings[0], dict):
                            slug = mappings[0].get("pageSlug", "")
                    store_url = (
                        f"https://store.epicgames.com/en-US/p/{slug}"
                        if slug
                        else "https://store.epicgames.com/en-US/free-games"
                    )
                    lines.append(f"- [{_truncate(title, 70)}]({store_url}) (`FREE NOW`)")
        elif kind == "json_cheapshark":
            deals = _fetch_json(url, timeout=8.0)
            if isinstance(deals, list):
                for idx, d in enumerate(deals[:limit], 1):
                    title = _truncate(d.get("title", ""), 64)
                    orig = d.get("normalPrice", "0.00")
                    did = d.get("dealID", "")
                    if title and did:
                        lines.append(
                            f"`{idx}.` [{title}](https://www.cheapshark.com/redirect?dealID={did}) (Normal `${orig}` -> `$0.00`)"
                        )
        else:
            xml_data = _fetch_text(url, timeout=8.0)
            parsed = parse_rss_or_atom_xml(xml_data, limit=limit)
            for idx, item in enumerate(parsed, 1):
                lines.append(f"`{idx}.` [{_truncate(item['title'], 78)}]({item['url']})")
    except Exception:
        return []
    return lines


# --- Planetary Sensors & Financial Feeds ---
def get_bangkok_weather_sync() -> dict:
    url = (
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=13.7299&longitude=100.7782"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,wind_speed_10m"
    )
    try:
        data = _fetch_json(url, timeout=7.0)
        cur = data.get("current", {}) if isinstance(data, dict) else {}
        return {
            "ok": True,
            "temp_c": float(cur.get("temperature_2m", 0.0)),
            "feels_c": float(cur.get("apparent_temperature", 0.0)),
            "humidity": float(cur.get("relative_humidity_2m", 0.0)),
            "wind_kmh": float(cur.get("wind_speed_10m", 0.0)),
            "precip_mm": float(cur.get("precipitation", 0.0)),
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)[:100]}


def get_markets_sync() -> dict:
    result: dict = {
        "ok": False,
        "btc_usd": 0.0,
        "btc_thb": 0.0,
        "btc_24h": 0.0,
        "eth_usd": 0.0,
        "eth_24h": 0.0,
        "sol_usd": 0.0,
        "sol_24h": 0.0,
        "usd_thb": 0.0,
    }
    try:
        cg = _fetch_json(
            "https://api.coingecko.com/api/v3/simple/price"
            "?ids=bitcoin,ethereum,solana&vs_currencies=usd,thb&include_24hr_change=true",
            timeout=7.0,
        )
        if isinstance(cg, dict):
            btc = cg.get("bitcoin", {})
            eth = cg.get("ethereum", {})
            sol = cg.get("solana", {})
            result["btc_usd"] = float(btc.get("usd", 0.0))
            result["btc_thb"] = float(btc.get("thb", 0.0))
            result["btc_24h"] = float(btc.get("usd_24h_change", 0.0))
            result["eth_usd"] = float(eth.get("usd", 0.0))
            result["eth_24h"] = float(eth.get("usd_24h_change", 0.0))
            result["sol_usd"] = float(sol.get("usd", 0.0))
            result["sol_24h"] = float(sol.get("usd_24h_change", 0.0))
            result["ok"] = True
    except Exception:
        pass

    try:
        fx = _fetch_json("https://open.er-api.com/v6/latest/USD", timeout=7.0)
        if isinstance(fx, dict):
            thb = fx.get("rates", {}).get("THB")
            if thb:
                result["usd_thb"] = float(thb)
                result["ok"] = True
    except Exception:
        pass
    return result


def get_cached_hud_sensors_sync(max_age_sec: float = 300.0) -> tuple[dict, dict]:
    now = time.time()
    with _SENSOR_LOCK:
        if (now - float(_SENSOR_CACHE.get("updated_at", 0.0))) < max_age_sec:
            w = _SENSOR_CACHE.get("weather")
            m = _SENSOR_CACHE.get("markets")
            if isinstance(w, dict) and isinstance(m, dict):
                return w, m

    weather = get_bangkok_weather_sync()
    markets = get_markets_sync()
    with _SENSOR_LOCK:
        _SENSOR_CACHE["updated_at"] = now
        _SENSOR_CACHE["weather"] = weather
        _SENSOR_CACHE["markets"] = markets
    return weather, markets


def get_github_radar_sync(limit_per_user: int = 3) -> list[str]:
    lines: list[str] = []
    for user in GITHUB_ACCOUNTS:
        try:
            events = _fetch_json(f"https://api.github.com/users/{user}/events/public?per_page=8", timeout=7.0)
            if not isinstance(events, list):
                continue
            added = 0
            for ev in events:
                if not isinstance(ev, dict):
                    continue
                ev_type = str(ev.get("type", ""))
                repo = str(ev.get("repo", {}).get("name", ""))
                if ev_type == "PushEvent":
                    commits = ev.get("payload", {}).get("commits", [])
                    msg = commits[0].get("message", "push") if commits else "push"
                    short_msg = _truncate(msg.splitlines()[0], 54)
                    lines.append(f"- `{user}` pushed `{repo}`: {short_msg}")
                    added += 1
                elif ev_type in ("CreateEvent", "ReleaseEvent", "PullRequestEvent"):
                    lines.append(f"- `{user}` `{ev_type.replace('Event', '')}` on `{repo}`")
                    added += 1
                if added >= limit_per_user:
                    break
        except Exception:
            continue
    return lines


# --- Domain Intelligence Collectors ---
def fetch_ai_cortex_intel(limit: int = 4) -> dict:
    reg = load_feeds_registry()
    sources = [s for s in reg.get("ai", []) if s.get("enabled", True)]
    fields: list[dict] = []

    for src in sources[:6]:
        lines = _collect_feed_lines(src, limit=limit)
        if lines or src.get("kind") == "rss":
            fields.append(
                {
                    "name": strip_emojis(src.get("name", "AI Feed")),
                    "value": _clip_field(lines),
                    "inline": False,
                }
            )

    if not fields:
        fields.append({"name": "AI Feeds", "value": "No active AI sources returned items.", "inline": False})

    embed = {
        "title": "[INTEL] ORBITAL AI & SINGULARITY CORTEX",
        "description": "Dynamic research papers and artificial intelligence dispatches (`feeds.json` -> `ai`).",
        "color": 0x8B5CF6,
        "fields": fields,
        "footer": {"text": f"Genesis Motherboard Intel Cortex | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 2, "label": "Command Wall", "custom_id": "cmd:wall"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def fetch_tech_radar_intel(limit: int = 5) -> dict:
    reg = load_feeds_registry()
    sources = [s for s in reg.get("tech", []) if s.get("enabled", True)]
    fields: list[dict] = []

    for src in sources[:6]:
        lines = _collect_feed_lines(src, limit=limit)
        fields.append(
            {
                "name": strip_emojis(src.get("name", "Tech Feed")),
                "value": _clip_field(lines),
                "inline": False,
            }
        )

    embed = {
        "title": "[INTEL] DEEP-SPACE TECH & CYBERNETICS RADAR",
        "description": "Dynamic engineering, software architecture, and tech sector transmissions (`feeds.json` -> `tech`).",
        "color": 0x06B6D4,
        "fields": fields,
        "footer": {"text": f"Genesis Motherboard Intel Cortex | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 2, "label": "Free Loot", "custom_id": "cmd:loot"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def fetch_world_pulse_intel(limit: int = 5) -> dict:
    weather, markets = get_cached_hud_sensors_sync(max_age_sec=120.0)
    reg = load_feeds_registry()
    sources = [s for s in reg.get("world", []) if s.get("enabled", True)]
    gh_lines = get_github_radar_sync(limit_per_user=2)

    weather_val = "Telemetry offline"
    if weather.get("ok"):
        weather_val = (
            f"Temp: `{weather['temp_c']:.1f}C` (Feels `{weather['feels_c']:.1f}C`)\n"
            f"Humidity: `{weather['humidity']:.0f}%` | Wind: `{weather['wind_kmh']:.1f} km/h`\n"
            f"Rain: `{weather['precip_mm']:.1f} mm`"
        )

    market_val = "Market feed offline"
    if markets.get("ok"):
        market_val = (
            f"BTC: `${markets['btc_usd']:,.0f}` (`{markets['btc_24h']:+.1f}%`)\n"
            f"ETH: `${markets['eth_usd']:,.0f}` (`{markets['eth_24h']:+.1f}%`) | SOL: `${markets['sol_usd']:,.1f}`\n"
            f"USD/THB: `{markets['usd_thb']:.2f} THB`"
        )

    fields: list[dict] = [
        {"name": "Bangkok / Lat Krabang Sensors", "value": weather_val, "inline": True},
        {"name": "Crypto & FX Tickers", "value": market_val, "inline": True},
    ]

    for src in sources[:5]:
        lines = _collect_feed_lines(src, limit=limit)
        fields.append(
            {
                "name": strip_emojis(src.get("name", "World Feed")),
                "value": _clip_field(lines),
                "inline": False,
            }
        )

    fields.append(
        {
            "name": "Overlord GitHub Activity (vxmpie / swnst)",
            "value": _clip_field(gh_lines, fallback="No recent public events."),
            "inline": False,
        }
    )

    embed = {
        "title": "[INTEL] PLANETARY WORLD PULSE, MARKETS & SENSORS",
        "description": "Global geopolitics, Bangkok planetary atmosphere, financial tickers, and GitHub fleet activity.",
        "color": 0x10B981,
        "fields": fields,
        "footer": {"text": f"Genesis Motherboard Planetary Array | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 2, "label": "AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "Omni-Briefing", "custom_id": "cmd:briefing"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def fetch_free_loot_intel(limit: int = 6) -> dict:
    reg = load_feeds_registry()
    sources = [s for s in reg.get("loot", []) if s.get("enabled", True)]
    fields: list[dict] = []

    for src in sources[:5]:
        lines = _collect_feed_lines(src, limit=limit)
        fields.append(
            {
                "name": strip_emojis(src.get("name", "Loot Feed")),
                "value": _clip_field(lines, fallback="No active zero-cost drops returned right now."),
                "inline": False,
            }
        )

    embed = {
        "title": "[INTEL] ORBITAL SUPPLY DROP - FREE GAMES & LOOT",
        "description": "Active 100%-discount PC game giveaways and zero-cost store drops (`feeds.json` -> `loot`).",
        "color": 0xF59E0B,
        "fields": fields,
        "footer": {"text": f"Genesis Motherboard Supply Scanner | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Scan Loot", "custom_id": "cmd:loot"},
                {"type": 2, "style": 2, "label": "Omni-Briefing", "custom_id": "cmd:briefing"},
                {"type": 2, "style": 2, "label": "Bridge Console", "custom_id": "cmd:bridge"},
                {"type": 2, "style": 2, "label": "Command Wall", "custom_id": "cmd:wall"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def build_omni_briefing_payload(
    metrics: dict,
    mumu_health: dict,
    tunnel: dict,
    summary: dict,
) -> dict:
    weather, markets = get_cached_hud_sensors_sync(max_age_sec=180.0)
    reg = load_feeds_registry()

    ai_first = next((s for s in reg.get("ai", []) if s.get("enabled", True)), None)
    tech_first = next((s for s in reg.get("tech", []) if s.get("enabled", True)), None)

    ai_top = _collect_feed_lines(ai_first, limit=3) if ai_first else []
    tech_top = _collect_feed_lines(tech_first, limit=3) if tech_first else []

    ram = metrics.get("ram", {})
    cpu_pct = float(metrics.get("cpu", {}).get("total_percent", 0.0))
    c_free = float(metrics.get("storage", {}).get("c_drive", {}).get("free_gb", 0.0))
    tunnel_url = tunnel.get("tunnel_url") or tunnel.get("local_url") or "http://127.0.0.1:7700"

    weather_str = f"`{weather['temp_c']:.1f}C` | Hum `{weather['humidity']:.0f}%`" if weather.get("ok") else "Offline"
    market_str = (
        f"BTC `${markets['btc_usd']:,.0f}` ({markets['btc_24h']:+.1f}%) | USD/THB `{markets['usd_thb']:.2f}`"
        if markets.get("ok")
        else "Offline"
    )

    embed = {
        "title": "[BRIEFING] GENESIS MOTHERBOARD OMNI-BRIEFING",
        "description": "Unified situational awareness across reactor hardware and global planetary intelligence.",
        "color": 0x3B82F6,
        "fields": [
            {
                "name": "Ship Reactor & Fleet",
                "value": (
                    f"CPU `{cpu_pct:.1f}%` | RAM `{ram.get('used_gb', 0)}/{ram.get('total_gb', 0)} GB` | C: `{c_free:.1f} GB`\n"
                    f"MuMu Active: `{mumu_health.get('count', 0)}` | Session Boosts: `{summary.get('session_boosts', 0)}`\n"
                    f"Ingress: `{tunnel_url}`"
                ),
                "inline": False,
            },
            {"name": "Bangkok Sensors", "value": weather_str, "inline": True},
            {"name": "Markets & FX", "value": market_str, "inline": True},
            {
                "name": "Top AI Breakthroughs",
                "value": _clip_field(ai_top, fallback="No feed signal."),
                "inline": False,
            },
            {
                "name": "Top Tech Radar",
                "value": _clip_field(tech_top, fallback="No feed signal."),
                "inline": False,
            },
        ],
        "footer": {"text": f"Genesis Motherboard | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh Briefing", "custom_id": "cmd:briefing"},
                {"type": 2, "style": 2, "label": "AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 3, "label": "RAM Boost", "custom_id": "cmd:boost"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}
