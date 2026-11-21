import html
import json
import re
import socket
import threading
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# --- Constants & Regex Guards ---
USER_AGENT = "Genesis-Mothership-Core/4.0"
_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF\uFE0F]")
_WHITESPACE_RE = re.compile(r"\s+")

_SENSOR_LOCK = threading.Lock()
_SENSOR_CACHE: dict = {"updated_at": 0.0, "weather": None, "markets": None}

GITHUB_ACCOUNTS = ("vxmpie", "swnst")


# --- Sanitization & HTTP Fetchers ---
def strip_emojis(text: str) -> str:
    cleaned = _EMOJI_RE.sub("", str(text or ""))
    return _WHITESPACE_RE.sub(" ", html.unescape(cleaned)).strip()


def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _truncate(text: str, max_len: int = 88) -> str:
    clean = strip_emojis(text)
    if len(clean) <= max_len:
        return clean
    return clean[: max_len - 3].rstrip() + "..."


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
    result: dict = {"ok": False, "btc_usd": 0.0, "btc_thb": 0.0, "btc_24h": 0.0, "eth_usd": 0.0, "eth_24h": 0.0, "sol_usd": 0.0, "sol_24h": 0.0, "usd_thb": 0.0}
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
def fetch_ai_cortex_intel(limit: int = 5) -> dict:
    hf_lines: list[str] = []
    tc_lines: list[str] = []

    try:
        papers = _fetch_json(f"https://huggingface.co/api/daily_papers?limit={limit}", timeout=8.0)
        if isinstance(papers, list):
            for idx, entry in enumerate(papers[:limit], 1):
                paper = entry.get("paper", {}) if isinstance(entry, dict) else {}
                pid = str(paper.get("id", ""))
                title = _truncate(paper.get("title") or entry.get("title", ""), 80)
                upvotes = int(paper.get("upvotes", 0))
                if pid and title:
                    hf_lines.append(f"`{idx}.` [{title}](https://huggingface.co/papers/{pid}) (`+{upvotes}`)")
    except Exception:
        pass

    try:
        xml_data = _fetch_text("https://techcrunch.com/category/artificial-intelligence/feed/", timeout=8.0)
        articles = parse_rss_or_atom_xml(xml_data, limit=limit)
        for idx, art in enumerate(articles, 1):
            tc_lines.append(f"`{idx}.` [{_truncate(art['title'], 80)}]({art['url']})")
    except Exception:
        pass

    embed = {
        "title": "// ORBITAL AI & SINGULARITY CORTEX",
        "description": "Live research breakthroughs and artificial intelligence dispatches intercepted by GENESIS-01 sensors.",
        "color": 0x8B5CF6,
        "fields": [
            {
                "name": "HuggingFace Trending AI Papers",
                "value": "\n".join(hf_lines) if hf_lines else "Signal temporarily unavailable.",
                "inline": False,
            },
            {
                "name": "TechCrunch AI Dispatches",
                "value": "\n".join(tc_lines) if tc_lines else "Signal temporarily unavailable.",
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Intel Cortex | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 2, "label": "Omni-Briefing", "custom_id": "cmd:briefing"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def fetch_tech_radar_intel(limit: int = 6) -> dict:
    hn_lines: list[str] = []
    verge_lines: list[str] = []

    try:
        hn_data = _fetch_json(
            f"https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage={limit}",
            timeout=8.0,
        )
        hits = hn_data.get("hits", []) if isinstance(hn_data, dict) else []
        for idx, hit in enumerate(hits[:limit], 1):
            title = _truncate(hit.get("title", ""), 76)
            oid = hit.get("objectID", "")
            url = hit.get("url") or f"https://news.ycombinator.com/item?id={oid}"
            pts = int(hit.get("points") or 0)
            if title:
                hn_lines.append(f"`{idx}.` [{title}]({url}) (`{pts} pts`)")
    except Exception:
        pass

    try:
        xml_data = _fetch_text("https://www.theverge.com/rss/index.xml", timeout=8.0)
        entries = parse_rss_or_atom_xml(xml_data, limit=limit)
        for idx, item in enumerate(entries, 1):
            verge_lines.append(f"`{idx}.` [{_truncate(item['title'], 80)}]({item['url']})")
    except Exception:
        pass

    embed = {
        "title": "// DEEP-SPACE TECH & CYBERNETICS RADAR",
        "description": "Engineering, software architecture, and global tech sector transmissions.",
        "color": 0x06B6D4,
        "fields": [
            {
                "name": "Hacker News Front Page",
                "value": "\n".join(hn_lines) if hn_lines else "Signal temporarily unavailable.",
                "inline": False,
            },
            {
                "name": "The Verge Tech Wire",
                "value": "\n".join(verge_lines) if verge_lines else "Signal temporarily unavailable.",
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Intel Cortex | Host: {socket.gethostname()}"},
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
    bbc_lines: list[str] = []
    try:
        xml_data = _fetch_text("http://feeds.bbci.co.uk/news/world/rss.xml", timeout=8.0)
        news = parse_rss_or_atom_xml(xml_data, limit=limit)
        for idx, item in enumerate(news, 1):
            bbc_lines.append(f"`{idx}.` [{_truncate(item['title'], 80)}]({item['url']})")
    except Exception:
        pass

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

    embed = {
        "title": "// PLANETARY WORLD PULSE, MARKETS & SENSORS",
        "description": "Global geopolitics, Bangkok planetary atmosphere, financial tickers, and GitHub fleet activity.",
        "color": 0x10B981,
        "fields": [
            {"name": "Bangkok / Lat Krabang Sensors", "value": weather_val, "inline": True},
            {"name": "Crypto & FX Tickers", "value": market_val, "inline": True},
            {
                "name": "BBC World News Headlines",
                "value": "\n".join(bbc_lines) if bbc_lines else "Signal temporarily unavailable.",
                "inline": False,
            },
            {
                "name": "Commander GitHub Activity (vxmpie / swnst)",
                "value": "\n".join(gh_lines) if gh_lines else "No recent public events.",
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Planetary Array | Host: {socket.gethostname()}"},
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
    epic_lines: list[str] = []
    deal_lines: list[str] = []

    try:
        epic = _fetch_json(
            "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=TH&allowCountries=TH",
            timeout=8.0,
        )
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
                store_url = f"https://store.epicgames.com/en-US/p/{slug}" if slug else "https://store.epicgames.com/en-US/free-games"
                epic_lines.append(f"- [{_truncate(title, 70)}]({store_url}) (`FREE NOW`)")
    except Exception:
        pass

    try:
        deals = _fetch_json(f"https://www.cheapshark.com/api/1.0/deals?upperPrice=0&pageSize={limit}", timeout=8.0)
        if isinstance(deals, list):
            for idx, d in enumerate(deals[:limit], 1):
                title = _truncate(d.get("title", ""), 66)
                orig = d.get("normalPrice", "0.00")
                did = d.get("dealID", "")
                if title and did:
                    deal_lines.append(
                        f"`{idx}.` [{title}](https://www.cheapshark.com/redirect?dealID={did}) (Normal `${orig}` -> `$0.00`)"
                    )
    except Exception:
        pass

    embed = {
        "title": "// ORBITAL SUPPLY DROP // FREE GAMES & LOOT",
        "description": "Active 100%-discount PC game giveaways and zero-cost store drops.",
        "color": 0xF59E0B,
        "fields": [
            {
                "name": "Epic Games Store Freebies",
                "value": "\n".join(epic_lines) if epic_lines else "Check Epic Games Store directly for active rotation.",
                "inline": False,
            },
            {
                "name": "100% Off PC Deals Radar",
                "value": "\n".join(deal_lines) if deal_lines else "No zero-price deals returned right now.",
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Supply Scanner | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Scan Loot", "custom_id": "cmd:loot"},
                {"type": 2, "style": 2, "label": "Omni-Briefing", "custom_id": "cmd:briefing"},
                {"type": 2, "style": 2, "label": "Bridge Deck", "custom_id": "cmd:deck"},
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

    ai_top: list[str] = []
    try:
        papers = _fetch_json("https://huggingface.co/api/daily_papers?limit=3", timeout=6.0)
        if isinstance(papers, list):
            for idx, entry in enumerate(papers[:3], 1):
                paper = entry.get("paper", {}) if isinstance(entry, dict) else {}
                pid = str(paper.get("id", ""))
                title = _truncate(paper.get("title") or entry.get("title", ""), 68)
                if pid and title:
                    ai_top.append(f"`{idx}.` [{title}](https://huggingface.co/papers/{pid})")
    except Exception:
        pass

    tech_top: list[str] = []
    try:
        hn = _fetch_json("https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=3", timeout=6.0)
        for idx, hit in enumerate(hn.get("hits", [])[:3], 1):
            title = _truncate(hit.get("title", ""), 68)
            url = hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID', '')}"
            if title:
                tech_top.append(f"`{idx}.` [{title}]({url})")
    except Exception:
        pass

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
        "title": "// GENESIS-01 MOTHERSHIP OMNI-BRIEFING",
        "description": "Unified situational awareness across local reactor hardware and global planetary intelligence.",
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
                "value": "\n".join(ai_top) if ai_top else "No feed signal.",
                "inline": False,
            },
            {
                "name": "Top Tech Radar",
                "value": "\n".join(tech_top) if tech_top else "No feed signal.",
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Orbital Mothership | Host: {socket.gethostname()}"},
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
