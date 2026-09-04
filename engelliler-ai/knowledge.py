"""Hafif JSON bilgi tabanı (ChromaDB öncesi basit vektörsüz arama).

Kayıtlar KNOWLEDGE_FILE (varsayılan data/knowledge.json) içinde tutulur.
Arama: küçük harfli alt-dize eşleşmesi + başlık ağırlıklı basit skorlama.
ChromaDB/vektör aramaya geçilince bu modülün arayüzü (add/get/search/stats)
korunacak, içi değiştirilecek.
"""
from __future__ import annotations

import json
import logging
import threading

from config import settings

log = logging.getLogger("engelliler-biz-ai.knowledge")
_lock = threading.Lock()


def _load() -> dict:
    path = settings.knowledge_file
    if not path.exists():
        return {"threads": {}}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        log.warning("Bilgi tabanı okunamadı, sıfırdan başlanıyor: %s", exc)
        return {"threads": {}}


def _save(store: dict) -> None:
    settings.knowledge_file.write_text(
        json.dumps(store, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def add_entry(thread_id: int | str, title: str, text: str, url: str = "") -> dict:
    """Konuyu bilgi tabanına ekle/güncelle, kayıt özetini döndür."""
    tid = str(thread_id)
    with _lock:
        store = _load()
        store["threads"][tid] = {
            "title": title[:300],
            "text": text[:20000],
            "url": url,
        }
        _save(store)
    return {"thread_id": tid, "title": title[:300], "chars": len(text)}


def get_entry(thread_id: int | str) -> dict | None:
    with _lock:
        return _load()["threads"].get(str(thread_id))


def search(query: str, limit: int = 5) -> list[dict]:
    """Başlık eşleşmesine 3 kat ağırlık veren basit arama."""
    words = [w for w in query.lower().split() if len(w) > 2]
    if not words:
        return []
    with _lock:
        threads = _load()["threads"]
    scored: list[tuple[int, str, dict]] = []
    for tid, entry in threads.items():
        title = entry.get("title", "").lower()
        text = entry.get("text", "").lower()
        score = sum(3 * title.count(w) + text.count(w) for w in words)
        if score > 0:
            scored.append((score, tid, entry))
    scored.sort(reverse=True)
    return [
        {
            "thread_id": tid,
            "title": entry.get("title", ""),
            "url": entry.get("url", ""),
            "snippet": entry.get("text", "")[:500],
        }
        for _, tid, entry in scored[:limit]
    ]


def stats() -> dict:
    with _lock:
        threads = _load()["threads"]
    total_chars = sum(len(e.get("text", "")) for e in threads.values())
    return {
        "threads": len(threads),
        "total_chars": total_chars,
        "ai_enabled": settings.ai_enabled,
        "model": settings.openrouter_model,
    }


def list_entries(limit: int = 200) -> list[dict]:
    """Kayıtlı konuları [{thread_id, title, url}] olarak listele (arayüz için)."""
    with _lock:
        threads = _load()["threads"]
    return [
        {"thread_id": tid, "title": e.get("title", ""), "url": e.get("url", "")}
        for tid, e in sorted(threads.items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else kv[0])
    ][:limit]
