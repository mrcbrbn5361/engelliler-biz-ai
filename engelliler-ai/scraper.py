"""XenForo (engelliler.biz) scraper — güvenli ve saygılı.

Güvenlik kuralları:
- Yalnızca ALLOWED_SCRAPE_DOMAIN (varsayılan engelliler.biz) ve alt alan adlarına istek atılır (SSRF koruması).
- robots.txt kontrol edilir; disallow olan yollar çekilmez.
- Her istekte zaman aşımı + tarayıcı User-Agent kullanılır.

Not: Bu proje unofficial'dır. Forum yönetiminden izin alın, robots.txt'ye uyun,
ticari kullanım öncesi onay alın, istek sıklığını düşük tutun.
"""
from __future__ import annotations

import hashlib
import json
import logging
import time
from pathlib import Path
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup

from config import settings

log = logging.getLogger("engelliler-biz-ai.scraper")

USER_AGENT = (
    "Mozilla/5.0 (compatible; engelliler-biz-ai/0.2; +https://github.com/mrcbrbn5361/engelliler-biz-ai)"
)
CRAWL_DELAY = 2.0  # robots.txt'ye ek olarak istekler arası bekleme (sn)
_last_request_at = 0.0


class ScraperError(Exception):
    """Türkçe, kullanıcıya gösterilebilir scraping hatası."""


def _throttle() -> None:
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < CRAWL_DELAY:
        time.sleep(CRAWL_DELAY - elapsed)
    _last_request_at = time.monotonic()


def validate_url(url: str) -> str:
    """URL'yi doğrula; izin verilmeyen hedefe ScraperError yükselt."""
    parsed = urlparse(url.strip())
    if parsed.scheme not in ("http", "https"):
        raise ScraperError("Yalnızca http ve https adresleri çekilebilir.")
    host = (parsed.hostname or "").lower()
    allowed = settings.allowed_scrape_domain.lower()
    if not (host == allowed or host.endswith("." + allowed)):
        raise ScraperError(
            f"Güvenlik gereği yalnızca {settings.allowed_scrape_domain} "
            "adreslerinden içerik alınabilir."
        )
    return parsed.geturl()


def robots_allowed(url: str) -> bool:
    """robots.txt'e göre çekime izin var mı? (Hata durumunda tedbiri elden bırakma: False)."""
    try:
        parsed = urlparse(url)
        robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"
        rp = RobotFileParser()
        rp.set_url(robots_url)
        rp.read()
        return rp.can_fetch(USER_AGENT, url)
    except Exception as exc:  # ağ hatası vb.
        log.warning("robots.txt okunamadı (%s), çekim engellendi: %s", url, exc)
        return False


def _cache_path(url: str) -> Path:
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:32]
    return settings.cache_dir / f"{digest}.json"


def _read_cache(url: str, max_age_hours: int = 24) -> dict | None:
    path = _cache_path(url)
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if time.time() - payload.get("fetched_at", 0) < max_age_hours * 3600:
            return payload["data"]
    except Exception as exc:
        log.warning("Önbellek okunamadı: %s", exc)
    return None


def _write_cache(url: str, data: dict) -> None:
    try:
        _cache_path(url).write_text(
            json.dumps({"fetched_at": time.time(), "data": data}, ensure_ascii=False),
            encoding="utf-8",
        )
    except Exception as exc:
        log.warning("Önbelleğe yazılamadı: %s", exc)


def _extract(url: str, html: str) -> dict:
    """XenForo sayfasından başlık + mesaj gövdelerini çıkar."""
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "nav", "header", "footer", "aside"]):
        tag.decompose()
    title = soup.title.get_text(strip=True) if soup.title else url
    # XenForo mesaj gövdeleri
    bodies = [
        el.get_text(" ", strip=True)
        for el in soup.select(".message-body .bbWrapper, .bbWrapper")
    ]
    if bodies:
        text = "\n\n".join(b for b in bodies if b)
    else:  # XenForo dışı sayfa: ana gövde metni
        main = soup.find("main") or soup.body
        text = main.get_text(" ", strip=True) if main else ""
    # Aşırı uzun sayfaları kırp (bellek + LLM bağlamı için)
    text = " ".join(text.split())
    return {"url": url, "title": title, "text": text[:20000], "posts": len(bodies)}


def scrape_forum(url: str, use_cache: bool = True) -> dict:
    """Forum sayfasını çek ve {url, title, text, posts} sözlüğü döndür."""
    url = validate_url(url)
    if use_cache:
        cached = _read_cache(url)
        if cached is not None:
            log.info("Önbellekten sunuldu: %s", url)
            return cached
    if not robots_allowed(url):
        raise ScraperError(
            "Bu sayfanın çekilmesine robots.txt kuralları izin vermiyor."
        )
    _throttle()
    try:
        response = requests.get(
            url,
            headers={"User-Agent": USER_AGENT, "Accept-Language": "tr-TR,tr;q=0.9"},
            timeout=settings.request_timeout,
        )
        response.raise_for_status()
    except requests.Timeout:
        raise ScraperError("Sayfa zamanında yanıt vermedi, sonra tekrar deneyin.")
    except requests.HTTPError as exc:
        raise ScraperError(f"Sayfa alınamadı (HTTP {exc.response.status_code}).")
    except requests.RequestException as exc:
        raise ScraperError(f"Bağlantı hatası: {exc}")
    data = _extract(url, response.text)
    _write_cache(url, data)
    return data


def scrape_thread(thread_id: int | str, use_cache: bool = True) -> dict:
    """Konu numarasından URL üretip çeker: /threads/<id>."""
    try:
        thread_id = int(str(thread_id).strip())
        if thread_id <= 0:
            raise ValueError
    except (ValueError, AttributeError):
        raise ScraperError("Konu numarası pozitif bir sayı olmalıdır.")
    base = f"https://{settings.allowed_scrape_domain}"
    return scrape_forum(f"{base}/threads/{thread_id}/", use_cache=use_cache)
