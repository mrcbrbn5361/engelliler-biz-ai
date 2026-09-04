# FastAPI backend — engelliler-biz-ai
# Çalıştırma (3 yoldan biri):
#   python engelliler-ai/api_server.py        (repo kökünden)
#   cd engelliler-ai && python api_server.py
#   cd engelliler-ai && uvicorn api_server:app --host 127.0.0.1 --port 8000
import logging
import sys
from pathlib import Path

# Kısa çizgili klasör adı import edilemediği için kendi dizinimizi yola ekle.
# Böylece dosya hem kökten hem klasör içinden çalışır (K1 düzeltmesi).
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from ai_engine import AIEngineError, generate_response
from config import settings
from knowledge import add_entry, get_entry, list_entries, search, stats
from scraper import (
    ScraperError,
    discover_forum_urls,
    list_thread_ids,
    scrape_forum,
    scrape_thread,
)

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(settings.log_file, encoding="utf-8"),
    ],
)
log = logging.getLogger("engelliler-biz-ai.api")

app = FastAPI(
    title="engelliler.biz AI API",
    description=(
        "Engelli bireyler için erişilebilir yapay zeka asistanı. "
        "Tüm hata iletileri Türkçe ve ekran okuyucu dostu düz metindir."
    ),
    version="0.2.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # demo; üretimde alan adınızla kısıtlayın
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000)


class AskResponse(BaseModel):
    answer: str
    sources: list[dict] = []
    ai_used: bool


class CrawlRequest(BaseModel):
    max_threads: int = Field(default=10, ge=1, le=200)
    max_pages_per_forum: int = Field(default=2, ge=1, le=10)


@app.get("/health", summary="Sağlık kontrolü")
def health() -> dict:
    return {"status": "ok", "ai_enabled": settings.ai_enabled, "version": "0.2.0"}


@app.post("/api/ask", response_model=AskResponse, summary="Yapay zekaya soru sor")
def ask(body: AskRequest) -> AskResponse:
    hits = search(body.question)
    context = "\n\n".join(
        f"Başlık: {h['title']}\n{h['snippet']}" for h in hits[:3]
    )
    try:
        answer, ai_used = generate_response(body.question, context)
    except AIEngineError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return AskResponse(answer=answer, sources=hits[:3], ai_used=ai_used)


@app.get("/api/search", summary="Bilgi tabanında konu ara")
def api_search(q: str, limit: int = 5) -> dict:
    q = (q or "").strip()
    if len(q) < 3:
        raise HTTPException(status_code=422, detail="Arama en az 3 karakter olmalıdır.")
    return {"query": q, "results": search(q, min(max(limit, 1), 20))}


@app.get("/api/thread/{thread_id}", summary="Konu verisini getir (önbellekli)")
def api_thread(thread_id: int, refresh: bool = False) -> dict:
    try:
        data = scrape_thread(thread_id, use_cache=not refresh)
    except ScraperError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return data


@app.post("/api/knowledge/add/{thread_id}", summary="Konuyu bilgi tabanına ekle")
def knowledge_add(thread_id: int) -> dict:
    try:
        data = scrape_thread(thread_id)
    except ScraperError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return add_entry(thread_id, data["title"], data["text"], data["url"])


@app.get("/api/knowledge/stats", summary="Bilgi tabanı istatistikleri")
def knowledge_stats() -> dict:
    entry_stats = stats()
    cached = get_entry("__none__")  # yok; sadece arayüz simetrisi için
    return {**entry_stats, "_self_check": cached is None}


@app.get("/api/knowledge/get/{thread_id}", summary="Kayıtlı konuyu getir")
def knowledge_get(thread_id: int) -> dict:
    entry = get_entry(thread_id)
    if entry is None:
        raise HTTPException(
            status_code=404,
            detail="Bu konu bilgi tabanında yok, önce /api/knowledge/add ile ekleyin.",
        )
    return {"thread_id": str(thread_id), **entry}


@app.get("/api/knowledge/threads", summary="Yüklü konuları listele")
def knowledge_threads(limit: int = 200) -> dict:
    entries = list_entries(min(max(limit, 1), 500))
    return {"count": len(entries), "threads": entries}


@app.post("/api/knowledge/crawl", summary="Sitedeki konuları topluca içe aktar")
def knowledge_crawl(body: CrawlRequest) -> dict:
    """Forum bölümlerini gezip yeni konuları bilgi tabanına ekler.

    Kibar tarama: robots.txt + 2 sn bekleme + önbellek. Büyük sayılar
    dakikalar sürebilir; küçük başlayın (örn. 10 konu).
    """
    try:
        forums = discover_forum_urls()
    except ScraperError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    if not forums:
        raise HTTPException(
            status_code=502, detail="Forum bölümleri bulunamadı, sonra tekrar deneyin."
        )
    added, skipped, errors = 0, 0, []
    done_ids: list[int] = []
    for forum_url in forums:
        if added >= body.max_threads:
            break
        try:
            tids = list_thread_ids(forum_url, body.max_pages_per_forum)
        except ScraperError as exc:
            errors.append(f"{forum_url}: {exc}")
            continue
        for tid in tids:
            if added >= body.max_threads:
                break
            if get_entry(tid) is not None:
                skipped += 1
                continue
            try:
                data = scrape_thread(tid)
            except ScraperError as exc:
                if len(errors) < 10:
                    errors.append(f"Konu {tid}: {exc}")
                continue
            add_entry(tid, data["title"], data["text"], data["url"])
            done_ids.append(tid)
            added += 1
    return {
        "added": added,
        "skipped": skipped,
        "forums_scanned": len(forums),
        "thread_ids": done_ids,
        "errors": errors,
    }


if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

    @app.get("/", include_in_schema=False)
    def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "index.html", media_type="text/html")


if __name__ == "__main__":
    import uvicorn

    log.info("API başlıyor: %s:%s (ai_enabled=%s)", settings.api_host, settings.api_port, settings.ai_enabled)
    uvicorn.run(app, host=settings.api_host, port=settings.api_port)
