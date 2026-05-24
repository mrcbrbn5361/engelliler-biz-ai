from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel
from ai_engine import AIEngine
from scraper import XenForoScraper
from knowledge_base import KnowledgeBase
from typing import Optional, List
from logger import get_logger
import time

logger = get_logger("API")

app = FastAPI(title="Engelliler.biz AI API", version="1.0.0")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logger.info(f"{request.method} {request.url.path} - {response.status_code} - {duration:.2f}s")
    return response

# Global instances
ai_engine = AIEngine()
scraper = XenForoScraper()
kb = KnowledgeBase()

class Query(BaseModel):
    prompt: str
    use_rag: Optional[bool] = True

class ThreadAddRequest(BaseModel):
    url: str

@app.get("/health")
async def health_check():
    return {"status": "healthy", "kb_count": kb.get_stats()["count"]}

@app.post("/api/ask")
async def ask(query: Query):
    try:
        response = ai_engine.generate_response(query.prompt, use_rag=query.use_rag)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/thread/{thread_id}")
async def get_thread(thread_id: str):
    # Not: thread_id'den URL oluşturma mantığı foruma göre değişebilir
    # Şimdilik örnek bir yapı
    url = f"https://www.engelliler.biz/forum/showthread.php?t={thread_id}"
    data = scraper.scrape_thread(url)
    if not data:
        raise HTTPException(status_code=404, detail="Konu bulunamadı")
    return data

@app.post("/api/knowledge/add")
async def add_knowledge(request: ThreadAddRequest, background_tasks: BackgroundTasks):
    # Arka planda kazıma ve ekleme işlemi
    def process_thread(url):
        data = scraper.scrape_thread(url)
        if data:
            kb.add_thread(data)

    background_tasks.add_task(process_thread, request.url)
    return {"message": "İşlem arka planda başlatıldı", "url": request.url}

@app.get("/api/knowledge/stats")
async def get_stats():
    return kb.get_stats()

@app.get("/api/search")
async def search(q: str):
    results = kb.query(q, n_results=5)
    return {"results": results}

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.getenv("API_PORT", 8000))
    host = os.getenv("API_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port)
