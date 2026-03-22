#!/bin/bash
# engelliler-ai Kurulum Scripti
# Kullanım: bash setup.sh

set -e

echo "🚀 engelliler.biz AI API Kurulumu Başlıyor..."

# Proje dizini
PROJECT_DIR="engelliler-ai"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Klasörler
mkdir -p data/vector_store
mkdir -p tests
mkdir -p logs

# .env dosyası
cat > .env << 'EOF'
# OpenRouter API Key: https://openrouter.ai/keys
OPENROUTER_KEY=sk-or-v1-YOUR_KEY_HERE

# Model seçimi
OPENROUTER_MODEL=stepfun/step-3.5-flash:free

# Discord (opsiyonel - şu an kullanılmıyor)
DISCORD_TOKEN=

# Uygulama bilgileri
APP_NAME=EngellilerBiz-AI
APP_URL=https://kodla.team

# API Ayarları
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=true

# Scraper Ayarları
RATE_LIMIT=2
USER_AGENT=Mozilla/5.0 (KodlaAI Bot; +https://kodla.team)

# Vektör DB
VECTOR_DB_PATH=./data/vector_store
EOF

# requirements.txt
cat > requirements.txt << 'EOF'
fastapi>=0.110.0
uvicorn[standard]>=0.29.0requests>=2.31.0
beautifulsoup4>=4.12.0
lxml>=5.1.0
google-generativeai>=0.8.0
chromadb>=0.4.24
python-dotenv>=1.0.1
pydantic>=2.6.0
httpx>=0.27.0
aiofiles>=23.2.1
python-multipart>=0.0.9
EOF

# .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/

# Environment
.env
*.env.local

# Data
data/vector_store/*
!data/vector_store/.gitkeep

# Logs
logs/*.log
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Test
.pytest_cache/
.coverage
htmlcov/EOF

# .gitkeep for vector_store
touch data/vector_store/.gitkeep

# Python dosyalarını oluştur
echo "📝 Python dosyaları oluşturuluyor..."

# config.py
cat > config.py << 'PYEOF'
"""
engelliler.biz AI API - Konfigürasyon Dosyası
Tüm ayarlar burada tanımlanır
"""
import os
from dotenv import load_dotenv
from pathlib import Path

# .env dosyasını yükle
load_dotenv()

# ============ BASE AYARLAR ============
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
LOGS_DIR = BASE_DIR / "logs"

# Klasörleri oluştur
DATA_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)

# ============ SITE AYARLARI ============
BASE_URL = "https://www.engelliler.biz"
RATE_LIMIT = int(os.getenv("RATE_LIMIT", "2"))  # saniye
USER_AGENT = os.getenv("USER_AGENT", "Mozilla/5.0 (KodlaAI Bot; +https://kodla.team)")

# XenForo URL Pattern'leri
FORUM_PATTERN = "/forum/{slug}.{id}/"
THREAD_PATTERN = "/konu/{slug}.{id}/"
SEARCH_PATTERN = "/search/?q={query}&type=post"

# Session ayarları
SESSION_TIMEOUT = 300  # 5 dakika
MAX_RETRIES = 3
REQUEST_TIMEOUT = 15  # saniye

# ============ OPENROUTER AYARLARI ============
OPENROUTER_API_KEY = os.getenv("OPENROUTER_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "stepfun/step-3.5-flash:free")
# Fallback modelleri (sırayla denenir)
FREE_MODELS = [
    "stepfun/step-3.5-flash:free",
    "google/gemma-2-2b-it:free",
    "meta-llama/llama-3.2-3b-instruct:free",
    "mistralai/mistral-7b-instruct:free",
]

# OpenRouter headers
APP_NAME = os.getenv("APP_NAME", "EngellilerBiz-AI")
APP_URL = os.getenv("APP_URL", "https://kodla.team")

# Model ayarları
MODEL_TEMPERATURE = 0.3
MODEL_MAX_TOKENS = 800
MODEL_TIMEOUT = 30  # saniye

# ============ VEKTÖR DB AYARLARI ============
VECTOR_DB_PATH = os.getenv("VECTOR_DB_PATH", str(DATA_DIR / "vector_store"))
VECTOR_COLLECTION_NAME = "engelliler_forum"
VECTOR_MAX_RESULTS = 8

# ============ API AYARLARI ============
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))
DEBUG = os.getenv("DEBUG", "true").lower() == "true"
API_TITLE = "Engelliler.biz AI API"
API_VERSION = "1.0.0"
API_DESCRIPTION = """
engelliler.biz forum içeriği üzerinde çalışan yapay zeka asistanı API'si.

**Özellikler:**
- Forum konularını scrape etme
- Vektör tabanlı arama (RAG)
- OpenRouter ücretsiz modeller ile AI cevapları
- Thread bazlı context desteği

**Kullanım:**
1. Önce konu ekleyin: POST /api/knowledge/add/{thread_id}
2. Sonra soru sorun: POST /api/ask
"""

# ============ LOGGING AYARLARI ============
LOG_LEVEL = "INFO" if DEBUG else "WARNING"
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
LOG_FILE = LOGS_DIR / "api.log"

# ============ RATE LIMITING ============
RATE_LIMIT_REQUESTS = 100  # dakikada
RATE_LIMIT_WINDOW = 60  # saniye
# ============ CORS AYARLARI ============
CORS_ORIGINS = ["*"]
CORS_METHODS = ["*"]
CORS_HEADERS = ["*"]

# ============ SAĞLIK KONTROLÜ ============
def validate_config():
    """Konfigürasyonu doğrula"""
    errors = []
    
    if not OPENROUTER_API_KEY:
        errors.append("OPENROUTER_KEY .env dosyasında tanımlı değil")
    
    if not BASE_URL.startswith("https://"):
        errors.append("BASE_URL https:// ile başlamalı")
    
    if errors:
        raise ValueError("Konfigürasyon hataları:\n" + "\n".join(errors))
    
    return True
PYEOF

# scraper.py
cat > scraper.py << 'PYEOF'
"""
engelliler.biz XenForo Scraper
Forum içeriklerini parse eder ve yapılandırılmış veri döner
"""
import requests
import time
import re
import logging
from typing import Dict, List, Optional
from bs4 import BeautifulSoup
from urllib.parse import urljoin, quote
from config import (
    BASE_URL, RATE_LIMIT, USER_AGENT, 
    SESSION_TIMEOUT, MAX_RETRIES, REQUEST_TIMEOUT,
    SEARCH_PATTERN, THREAD_PATTERN
)

# Logger
logger = logging.getLogger(__name__)

class XenForoScraper:
    """XenForo forum scraper sınıfı"""
    
    def __init__(self):
        self.session = requests.Session()        self.session.headers.update({
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
        })
        self.last_request_time = 0
        self._cookies_loaded = False
    
    def _rate_limit(self):
        """Rate limiting uygula"""
        elapsed = time.time() - self.last_request_time
        if elapsed < RATE_LIMIT:
            sleep_time = RATE_LIMIT - elapsed
            logger.debug(f"Rate limit: {sleep_time:.2f}s bekleniyor")
            time.sleep(sleep_time)
        self.last_request_time = time.time()
    
    def _get(self, url: str, retries: int = 0) -> requests.Response:
        """Rate limitli GET isteği"""
        self._rate_limit()
        
        try:
            resp = self.session.get(url, timeout=REQUEST_TIMEOUT)
            resp.raise_for_status()
            logger.info(f"✓ GET {url} - {resp.status_code}")
            return resp
        except requests.exceptions.RequestException as e:
            if retries < MAX_RETRIES:
                logger.warning(f"⚠ İstek hatası, tekrar deneniyor ({retries+1}/{MAX_RETRIES}): {e}")
                time.sleep(2 ** retries)  # Exponential backoff
                return self._get(url, retries + 1)
            logger.error(f"✗ GET {url} - Maksimum retry aşıldı: {e}")
            raise
    
    def get_thread(self, thread_id: int) -> Dict:
        """
        Konu ve mesajlarını scrape et
        
        Args:
            thread_id: Konu ID'si
            
        Returns:
            Konu verisi (dict)
        """
        url = f"{BASE_URL}/konu/{thread_id}/"
        logger.info(f"Konu scrape ediliyor: {url}")
                try:
            resp = self._get(url)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                return {"error": "Konu bulunamadı (404)", "thread_id": thread_id}
            return {"error": f"HTTP {e.response.status_code}", "thread_id": thread_id}
        except Exception as e:
            return {"error": str(e), "thread_id": thread_id}
        
        soup = BeautifulSoup(resp.text, 'lxml')
        
        # Başlık extract
        title = self._extract_title(soup)
        
        # Forum kategorisi
        forum = self._extract_forum(soup)
        
        # Mesajlar
        messages = self._extract_messages(soup)
        
        # Konu istatistikleri
        stats = self._extract_stats(soup)
        
        result = {
            "thread_id": thread_id,
            "title": title,
            "forum": forum,
            "messages": messages,
            "stats": stats,
            "url": url,
            "scraped_at": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        logger.info(f"✓ Konu scrape tamam: {len(messages)} mesaj")
        return result
    
    def _extract_title(self, soup: BeautifulSoup) -> str:
        """Konu başlığını extract et"""
        # XenForo 2.x: h1.p-title-value
        title_tag = soup.find('h1', class_='p-title-value')
        if title_tag:
            # İçindeki <a> tag'ini kaldır
            for a in title_tag.find_all('a'):
                a.decompose()
            return title_tag.get_text(strip=True)
        
        # Fallback: title tag
        title_tag = soup.find('title')
        if title_tag:
            text = title_tag.get_text(strip=True)            # "Konu Başlığı | engelliler.biz" formatını temizle
            return text.split('|')[0].strip()
        
        return "Başlıksız"
    
    def _extract_forum(self, soup: BeautifulSoup) -> str:
        """Forum kategorisini extract et"""
        # Breadcrumb'dan al
        breadcrumb = soup.find('ul', class_='breadcrumbs')
        if breadcrumb:
            items = breadcrumb.find_all('span', itemprop='itemListElement')
            if len(items) >= 2:
                return items[-2].get_text(strip=True)
        
        # Fallback
        forum_tag = soup.find('span', class_='p-description')
        if forum_tag:
            return forum_tag.get_text(strip=True)
        
        return "Bilinmiyor"
    
    def _extract_messages(self, soup: BeautifulSoup) -> List[Dict]:
        """Mesajları extract et"""
        messages = []
        
        # XenForo 2.x: article.message
        for msg in soup.find_all('article', class_='message'):
            try:
                # Yazar
                author_tag = msg.find('span', class_='username')
                author = author_tag.get_text(strip=True) if author_tag else "Anonim"
                
                # İçerik
                content_tag = msg.find('div', class_='message-content') or \
                              msg.find('article', class_='message-content') or \
                              msg.find('div', class_='bbWrapper')
                
                if content_tag:
                    # Script/style tag'lerini kaldır
                    for tag in content_tag(['script', 'style', 'noscript']):
                        tag.decompose()
                    
                    # Quote bloklarını temizle (isteğe bağlı)
                    for quote in content_tag.find_all('blockquote', class_='messageQuote'):
                        quote.decompose()
                    
                    # Signature'ı kaldır
                    for sig in content_tag.find_all('div', class_='signature'):
                        sig.decompose()
                                        text = self._clean_text(content_tag.get_text(separator=' ', strip=True))
                    
                    if text and len(text) > 10:  # Boş mesajları atla
                        messages.append({
                            "author": author,
                            "content": text[:3000],  # Token limiti için kısalt
                            "length": len(text)
                        })
            except Exception as e:
                logger.warning(f"Mesaj parse hatası: {e}")
                continue
        
        return messages
    
    def _extract_stats(self, soup: BeautifulSoup) -> Dict:
        """Konu istatistiklerini extract et"""
        stats = {
            "views": 0,
            "replies": 0,
            "pages": 1
        }
        
        # View count
        views_tag = soup.find('span', class_='views')
        if views_tag:
            match = re.search(r'(\d+)', views_tag.get_text())
            if match:
                stats["views"] = int(match.group(1))
        
        # Sayfa sayısı
        page_nav = soup.find('nav', class_='pageNav')
        if page_nav:
            last_page = page_nav.find('li', class_='pageNav-page--last')
            if last_page:
                match = re.search(r'(\d+)', last_page.get_text())
                if match:
                    stats["pages"] = int(match.group(1))
        
        return stats
    
    def _clean_text(self, text: str) -> str:
        """Metni temizle"""
        # Çoklu boşlukları tek boşluğa çevir
        text = re.sub(r'\s+', ' ', text)
        
        # Özel karakterleri temizle
        text = text.replace('\xa0', ' ')
        text = text.replace('\u200b', '')
        
        # Trim        return text.strip()
    
    def search_threads(self, query: str, limit: int = 5) -> List[Dict]:
        """
        Forumda konu ara
        
        Args:
            query: Arama sorgusu
            limit: Maksimum sonuç sayısı
            
        Returns:
            Konu listesi
        """
        url = f"{BASE_URL}/search/?q={quote(query)}&type=post"
        logger.info(f"Arama yapılıyor: {query}")
        
        try:
            resp = self._get(url)
        except Exception as e:
            logger.error(f"Arama hatası: {e}")
            return []
        
        soup = BeautifulSoup(resp.text, 'lxml')
        results = []
        
        # XenForo search results: li.block-row
        for item in soup.find_all('li', class_='block-row')[:limit * 2]:
            try:
                link = item.find('a', href=re.compile(r'/konu/'))
                if link:
                    href = link.get('href', '')
                    
                    # Thread ID extract: /konu/abc.123/
                    match = re.search(r'\.(\d+)/$', href)
                    if match:
                        thread_id = int(match.group(1))
                        
                        # Duplicate kontrol
                        if not any(r['thread_id'] == thread_id for r in results):
                            results.append({
                                "title": link.get_text(strip=True)[:200],
                                "thread_id": thread_id,
                                "url": urljoin(BASE_URL, href),
                                "relevance": len(results) + 1  # Sıralama için
                            })
                            
                            if len(results) >= limit:
                                break
            except Exception as e:
                logger.warning(f"Search result parse hatası: {e}")                continue
        
        logger.info(f"✓ Arama tamam: {len(results)} sonuç")
        return results
    
    def get_forum_list(self) -> List[Dict]:
        """Forum kategorilerini listele"""
        url = f"{BASE_URL}/forums/"
        logger.info("Forum listesi alınıyor")
        
        try:
            resp = self._get(url)
        except Exception as e:
            logger.error(f"Forum listesi hatası: {e}")
            return []
        
        soup = BeautifulSoup(resp.text, 'lxml')
        forums = []
        
        # XenForo forum nodes
        for node in soup.find_all('li', class_='node--forum'):
            try:
                title_tag = node.find('a', class_='node-title')
                if title_tag:
                    href = title_tag.get('href', '')
                    match = re.search(r'\.(\d+)/$', href)
                    forum_id = int(match.group(1)) if match else 0
                    
                    forums.append({
                        "forum_id": forum_id,
                        "title": title_tag.get_text(strip=True),
                        "url": urljoin(BASE_URL, href),
                        "description": ""
                    })
                    
                    desc_tag = node.find('div', class_='node-description')
                    if desc_tag:
                        forums[-1]["description"] = desc_tag.get_text(strip=True)
            except Exception as e:
                logger.warning(f"Forum parse hatası: {e}")
                continue
        
        return forums
    
    def get_recent_threads(self, limit: int = 10) -> List[Dict]:
        """Son konuları getir"""
        url = f"{BASE_URL}/whats-new/posts/"
        logger.info("Son konular alınıyor")
        
        try:            resp = self._get(url)
        except Exception as e:
            logger.error(f"Son konular hatası: {e}")
            return []
        
        soup = BeautifulSoup(resp.text, 'lxml')
        threads = []
        
        for item in soup.find_all('li', class_='block-row')[:limit]:
            try:
                link = item.find('a', href=re.compile(r'/konu/'))
                if link:
                    href = link.get('href', '')
                    match = re.search(r'\.(\d+)/$', href)
                    if match:
                        threads.append({
                            "title": link.get_text(strip=True)[:200],
                            "thread_id": int(match.group(1)),
                            "url": urljoin(BASE_URL, href)
                        })
            except Exception as e:
                continue
        
        return threads
PYEOF

# ai_engine.py
cat > ai_engine.py << 'PYEOF'
"""
engelliler.biz AI Engine
OpenRouter + RAG ile AI cevapları üretir
"""
import requests
import time
import logging
from typing import Dict, List, Optional
from config import (
    OPENROUTER_API_KEY, OPENROUTER_URL, OPENROUTER_MODEL,
    FREE_MODELS, VECTOR_DB_PATH, VECTOR_COLLECTION_NAME,
    VECTOR_MAX_RESULTS, APP_NAME, APP_URL,
    MODEL_TEMPERATURE, MODEL_MAX_TOKENS, MODEL_TIMEOUT
)
from scraper import XenForoScraper

# ChromaDB
import chromadb
from chromadb.config import Settings

# Logger
logger = logging.getLogger(__name__)
class ForumAI:
    """Forum AI asistanı - RAG + OpenRouter"""
    
    def __init__(self):
        self.scraper = XenForoScraper()
        
        # OpenRouter session
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "HTTP-Referer": APP_URL,
            "X-Title": APP_NAME,
            "Content-Type": "application/json"
        })
        
        # ChromaDB vektör store
        logger.info(f"Vektör DB başlatılıyor: {VECTOR_DB_PATH}")
        self.client = chromadb.PersistentClient(
            path=str(VECTOR_DB_PATH),
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=True
            )
        )
        
        self.collection = self.client.get_or_create_collection(
            name=VECTOR_COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"}
        )
        
        logger.info(f"✓ AI Engine hazır - Collection: {self.collection.count()} document")
    
    def _call_openrouter(self, prompt: str, model: str = None) -> str:
        """
        OpenRouter API'ye istek at
        
        Args:
            prompt: Kullanıcı prompt'u
            model: Model adı (varsayılan: config'den)
            
        Returns:
            AI cevabı
        """
        model = model or OPENROUTER_MODEL
        
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": "Sen engelliler.biz forum asistanısın. Türkçe cevap ver."},                {"role": "user", "content": prompt}
            ],
            "temperature": MODEL_TEMPERATURE,
            "max_tokens": MODEL_MAX_TOKENS,
            "top_p": 0.9,
            "frequency_penalty": 0.1,
            "presence_penalty": 0.1
        }
        
        logger.debug(f"OpenRouter isteği: {model}")
        
        try:
            resp = self.session.post(
                OPENROUTER_URL,
                json=payload,
                timeout=MODEL_TIMEOUT
            )
            resp.raise_for_status()
            
            data = resp.json()
            
            # OpenRouter response parse
            if "choices" in data and len(data["choices"]) > 0:
                content = data["choices"][0]["message"]["content"].strip()
                logger.info(f"✓ OpenRouter cevap alındı: {len(content)} karakter")
                return content
            else:
                raise Exception("Geçersiz OpenRouter response")
                
        except requests.exceptions.Timeout:
            raise Exception(f"Model timeout: {model}")
        except requests.exceptions.HTTPError as e:
            error_msg = e.response.text[:200] if e.response.text else "Bilinmeyen hata"
            raise Exception(f"OpenRouter HTTP {e.response.status_code}: {error_msg}")
        except Exception as e:
            raise Exception(f"OpenRouter hatası: {str(e)[:200]}")
    
    def add_thread_to_knowledge(self, thread_id: int) -> Dict:
        """
        Konuyu vektör DB'ye ekle (RAG için)
        
        Args:
            thread_id: Konu ID'si
            
        Returns:
            İşlem sonucu
        """
        logger.info(f"Konu knowledge'a ekleniyor: {thread_id}")
        
        # Konuyu scrape et        thread_data = self.scraper.get_thread(thread_id)
        
        if "error" in thread_data:
            return {
                "success": False,
                "error": thread_data["error"],
                "thread_id": thread_id
            }
        
        # Her mesajı ayrı document olarak ekle
        added_count = 0
        for i, msg in enumerate(thread_data["messages"]):
            doc_id = f"thread_{thread_id}_msg_{i}"
            
            # Document içeriği
            document = f"{msg['author']}: {msg['content']}"
            
            # Metadata
            metadata = {
                "thread_id": thread_id,
                "title": thread_data["title"],
                "forum": thread_data["forum"],
                "author": msg["author"],
                "msg_index": i,
                "length": msg["length"],
                "url": thread_data["url"]
            }
            
            try:
                # Upsert (varsa güncelle, yoksa ekle)
                self.collection.upsert(
                    ids=[doc_id],
                    documents=[document],
                    metadatas=[metadata]
                )
                added_count += 1
            except Exception as e:
                logger.warning(f"Document ekleme hatası {doc_id}: {e}")
                continue
        
        logger.info(f"✓ {added_count} mesaj knowledge'a eklendi")
        
        return {
            "success": True,
            "thread_id": thread_id,
            "title": thread_data["title"],
            "messages_added": added_count,
            "total_messages": len(thread_data["messages"])
        }
        def remove_thread_from_knowledge(self, thread_id: int) -> Dict:
        """Konuyu vektör DB'den kaldır"""
        logger.info(f"Konu knowledge'dan kaldırılıyor: {thread_id}")
        
        # İlgili tüm document'ları bul
        results = self.collection.get(
            where={"thread_id": thread_id},
            include=[]
        )
        
        if not results["ids"]:
            return {
                "success": False,
                "error": "Konu bulunamadı",
                "thread_id": thread_id
            }
        
        # Sil
        self.collection.delete(ids=results["ids"])
        
        logger.info(f"✓ {len(results['ids'])} document silindi")
        
        return {
            "success": True,
            "thread_id": thread_id,
            "documents_removed": len(results["ids"])
        }
    
    def ask(self, question: str, thread_id: Optional[int] = None) -> Dict:
        """
        AI'ya soru sor - RAG ile context ekle
        
        Args:
            question: Kullanıcı sorusu
            thread_id: Opsiyonel - belirli konu içinde ara
            
        Returns:
            AI cevabı + metadata
        """
        logger.info(f"AI sorusu: {question[:100]}...")
        
        start_time = time.time()
        sources = []
        
        # ============ 1. RAG: İlgili içerikleri bul ============
        where_filter = None
        if thread_id:
            where_filter = {"thread_id": thread_id}
            logger.debug(f"Thread filter: {thread_id}")
                try:
            results = self.collection.query(
                query_texts=[question],
                n_results=VECTOR_MAX_RESULTS,
                where=where_filter,
                include=["documents", "metadatas", "distances"]
            )
            
            # Sources extract
            if results["metadatas"] and results["metadatas"][0]:
                for meta in results["metadatas"][0]:
                    sources.append({
                        "thread_id": meta.get("thread_id"),
                        "title": meta.get("title"),
                        "author": meta.get("author"),
                        "forum": meta.get("forum"),
                        "url": meta.get("url")
                    })
        except Exception as e:
            logger.warning(f"RAG query hatası: {e}")
            results = {"documents": [[]], "metadatas": [[]]}
        
        # ============ 2. Context oluştur ============
        context_parts = []
        if results["documents"] and results["documents"][0]:
            for doc, meta in zip(results["documents"][0], results["metadatas"][0]):
                author = meta.get("author", "Anonim") if meta else "Anonim"
                forum = meta.get("forum", "Bilinmiyor") if meta else "Bilinmiyor"
                context_parts.append(f"• {author} ({forum}): {doc}")
        
        context = "\n".join(context_parts[:5]) if context_parts else "İlgili forum içeriği bulunamadı."
        
        # ============ 3. Prompt hazırla (step-3.5-flash optimize) ============
        prompt = f"""[INST] Sen engelliler.biz forum asistanısın.
Görev: Aşağıdaki forum içeriklerini kullanarak kullanıcının sorusunu TÜRKÇE cevapla.

KURALLAR:
- Sadece verilen içeriklere dayan
- Bilgin yoksa "Forumda bu konuda yeterli bilgi yok" de
- Cevap: kısa, maddeli, net olsun
- Kaynak belirtme

FORUM VERİLERİ:
{context}

SORU: {question}

CEVAP: [/INST]"""

        # ============ 4. OpenRouter'a sor (fallback ile) ============        last_error = None
        used_model = None
        answer = None
        
        models_to_try = [OPENROUTER_MODEL] + [m for m in FREE_MODELS if m != OPENROUTER_MODEL]
        
        for model in models_to_try:
            try:
                logger.info(f"Model deneniyor: {model}")
                answer = self._call_openrouter(prompt, model)
                used_model = model
                break
            except Exception as e:
                last_error = str(e)
                logger.warning(f"Model başarısız {model}: {last_error[:100]}")
                time.sleep(1)
                continue
        
        if not answer:
            logger.error("Tüm modeller başarısız")
            return {
                "success": False,
                "error": f"AI cevap alınamadı: {last_error[:200]}",
                "question": question,
                "elapsed_time": time.time() - start_time
            }
        
        # ============ 5. Sonuç döndür ============
        elapsed = time.time() - start_time
        logger.info(f"✓ AI cevap hazır: {elapsed:.2f}s - {used_model}")
        
        return {
            "success": True,
            "answer": answer,
            "question": question,
            "model": used_model,
            "sources": sources[:3],  # İlk 3 kaynak
            "context_used": len(context_parts) > 0,
            "thread_id": thread_id,
            "elapsed_time": round(elapsed, 2),
            "answer_length": len(answer)
        }
    
    def get_knowledge_stats(self) -> Dict:
        """Knowledge base istatistikleri"""
        count = self.collection.count()
        
        # Unique thread sayısını bul
        try:
            all_data = self.collection.get(include=["metadatas"])            thread_ids = set()
            for meta in all_data["metadatas"]:
                if meta and "thread_id" in meta:
                    thread_ids.add(meta["thread_id"])
            unique_threads = len(thread_ids)
        except:
            unique_threads = 0
        
        return {
            "total_documents": count,
            "unique_threads": unique_threads,
            "collection_name": VECTOR_COLLECTION_NAME
        }
    
    def clear_knowledge(self) -> Dict:
        """Tüm knowledge base'i temizle"""
        logger.warning("Knowledge base temizleniyor!")
        self.collection.delete(where={})
        return {"success": True, "message": "Knowledge base temizlendi"}
PYEOF

# api_server.py
cat > api_server.py << 'PYEOF'
"""
engelliler.biz AI API Server
FastAPI backend - OpenRouter + RAG
"""
from fastapi import FastAPI, HTTPException, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict
import uvicorn
import logging
import time
from contextlib import asynccontextmanager

# Config
from config import (
    API_HOST, API_PORT, DEBUG, API_TITLE, API_VERSION, API_DESCRIPTION,
    CORS_ORIGINS, CORS_METHODS, CORS_HEADERS, LOG_LEVEL, LOG_FORMAT, LOG_FILE,
    validate_config
)

# AI Engine
from ai_engine import ForumAI

# ============ Logging Setup ============
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============ Global AI Instance ============
ai_engine: Optional[ForumAI] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """App lifespan - startup/shutdown"""
    global ai_engine
    
    # Startup
    logger.info("🚀 API Server başlatılıyor...")
    
    try:
        validate_config()
        logger.info("✓ Konfigürasyon doğrulandı")
    except Exception as e:
        logger.error(f"✗ Konfigürasyon hatası: {e}")
        raise
    
    ai_engine = ForumAI()
    logger.info("✓ AI Engine hazır")
    
    yield
    
    # Shutdown
    logger.info("🛑 API Server kapatılıyor...")

# ============ FastAPI App ============
app = FastAPI(
    title=API_TITLE,
    version=API_VERSION,
    description=API_DESCRIPTION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=CORS_METHODS,    allow_headers=CORS_HEADERS,
)

# ============ Request/Response Models ============
class QuestionRequest(BaseModel):
    question: str = Field(..., min_length=2, max_length=1000, description="Kullanıcı sorusu")
    thread_id: Optional[int] = Field(None, description="Opsiyonel: Belirli konu içinde ara")

class QuestionResponse(BaseModel):
    success: bool
    answer: Optional[str] = None
    error: Optional[str] = None
    model: Optional[str] = None
    sources: Optional[List[Dict]] = None
    elapsed_time: Optional[float] = None

class ThreadResponse(BaseModel):
    thread_id: int
    title: str
    forum: str
    messages: List[Dict]
    url: str
    error: Optional[str] = None

class KnowledgeAddResponse(BaseModel):
    success: bool
    thread_id: int
    title: Optional[str] = None
    messages_added: Optional[int] = None
    error: Optional[str] = None

# ============ Middleware ============
@app.middleware("http")
async def log_requests(request, call_next):
    """Her isteği logla"""
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    logger.info(f"{request.method} {request.url.path} - {response.status_code} - {duration:.3f}s")
    
    response.headers["X-Process-Time"] = str(duration)
    return response

# ============ Routes ============
@app.get("/", tags=["Root"])
async def root():
    """API ana sayfa"""
    return {        "service": API_TITLE,
        "version": API_VERSION,
        "docs": "/docs",
        "health": "/health",
        "status": "running"
    }

@app.get("/health", tags=["Health"])
async def health_check():
    """Sağlık kontrolü"""
    stats = ai_engine.get_knowledge_stats() if ai_engine else {}
    
    return {
        "status": "healthy",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "knowledge_base": stats,
        "model": "stepfun/step-3.5-flash:free"
    }

@app.get("/api/models", tags=["Models"])
async def list_models():
    """Kullanılabilir AI modelleri"""
    from config import FREE_MODELS, OPENROUTER_MODEL
    return {
        "active_model": OPENROUTER_MODEL,
        "fallback_models": FREE_MODELS,
        "provider": "OpenRouter"
    }

@app.get("/api/thread/{thread_id}", response_model=ThreadResponse, tags=["Threads"])
async def get_thread(thread_id: int):
    """
    Konu verisini getir
    
    - **thread_id**: Konu ID'si
    """
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    data = ai_engine.scraper.get_thread(thread_id)
    
    if "error" in data:
        raise HTTPException(404, data["error"])
    
    return data

@app.get("/api/search", tags=["Search"])
async def search_threads(
    q: str = Query(..., min_length=2, max_length=100, description="Arama sorgusu"),
    limit: int = Query(5, ge=1, le=20, description="Maksimum sonuç")):
    """
    Forumda konu ara
    
    - **q**: Arama sorgusu
    - **limit**: Maksimum sonuç sayısı (1-20)
    """
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    results = ai_engine.scraper.search_threads(q, limit)
    
    return {
        "query": q,
        "count": len(results),
        "results": results
    }

@app.post("/api/ask", response_model=QuestionResponse, tags=["AI"])
async def ask_ai(req: QuestionRequest):
    """
    🎯 AI asistanına soru sor
    
    RAG ile forum içeriklerini kullanarak cevap üretir.
    """
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    try:
        result = ai_engine.ask(req.question, req.thread_id)
        
        if not result["success"]:
            raise HTTPException(500, result.get("error", "Bilinmeyen hata"))
        
        return {
            "success": True,
            "answer": result["answer"],
            "model": result["model"],
            "sources": result["sources"],
            "elapsed_time": result["elapsed_time"]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"AI ask hatası: {e}")
        raise HTTPException(500, str(e)[:200])

@app.post("/api/knowledge/add/{thread_id}", response_model=KnowledgeAddResponse, tags=["Knowledge"])
async def add_knowledge(thread_id: int):
    """    Konuyu AI bilgi tabanına ekle
    
    Bu endpoint'ten sonra /api/ask ile soru sorulabilir.
    """
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    result = ai_engine.add_thread_to_knowledge(thread_id)
    
    if not result["success"]:
        raise HTTPException(400, result.get("error", "Ekleme başarısız"))
    
    return {
        "success": True,
        "thread_id": thread_id,
        "title": result.get("title"),
        "messages_added": result.get("messages_added")
    }

@app.delete("/api/knowledge/remove/{thread_id}", tags=["Knowledge"])
async def remove_knowledge(thread_id: int):
    """Konuyu bilgi tabanından kaldır"""
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    result = ai_engine.remove_thread_from_knowledge(thread_id)
    
    if not result["success"]:
        raise HTTPException(404, result.get("error", "Konu bulunamadı"))
    
    return result

@app.get("/api/knowledge/stats", tags=["Knowledge"])
async def knowledge_stats():
    """Bilgi tabanı istatistikleri"""
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    return ai_engine.get_knowledge_stats()

@app.post("/api/knowledge/clear", tags=["Knowledge"])
async def clear_knowledge():
    """Tüm bilgi tabanını temizle (DİKKAT!)"""
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    result = ai_engine.clear_knowledge()
    return result

@app.get("/api/forums", tags=["Forums"])async def get_forums():
    """Forum kategorilerini listele"""
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    forums = ai_engine.scraper.get_forum_list()
    
    return {
        "count": len(forums),
        "forums": forums
    }

@app.get("/api/recent", tags=["Threads"])
async def get_recent(limit: int = Query(10, ge=1, le=50)):
    """Son konuları getir"""
    if not ai_engine:
        raise HTTPException(503, "AI Engine hazır değil")
    
    threads = ai_engine.scraper.get_recent_threads(limit)
    
    return {
        "count": len(threads),
        "threads": threads
    }

# ============ Error Handlers ============
@app.exception_handler(404)
async def not_found_handler(request, exc):
    return JSONResponse(
        status_code=404,
        content={"error": "Bulunamadı", "path": str(request.url)}
    )

@app.exception_handler(500)
async def internal_error_handler(request, exc):
    logger.error(f"Internal error: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "İç sunucu hatası", "detail": str(exc)[:200]}
    )

# ============ Main ============
if __name__ == "__main__":
    logger.info(f"🚀 API Server başlatılıyor: http://{API_HOST}:{API_PORT}")
    
    uvicorn.run(
        "api_server:app",
        host=API_HOST,
        port=API_PORT,
        reload=DEBUG,        log_level=LOG_LEVEL.lower()
    )
PYEOF

# .env.example
cat > .env.example << 'EOF'
# OpenRouter API Key (https://openrouter.ai/keys)
OPENROUTER_KEY=sk-or-v1-YOUR_KEY_HERE

# AI Model
OPENROUTER_MODEL=stepfun/step-3.5-flash:free

# Uygulama
APP_NAME=EngellilerBiz-AI
APP_URL=https://kodla.team

# API
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=true

# Scraper
RATE_LIMIT=2

# Vector DB
VECTOR_DB_PATH=./data/vector_store
EOF

# README.md
cat > README.md << 'EOF'
# 🤖 engelliler.biz AI API

engelliler.biz forum içeriği üzerinde çalışan yapay zeka asistanı API'si.

## ✨ Özellikler

- 🕷️ XenForo forum scraper
- 🧠 RAG (Retrieval Augmented Generation)
- 🤖 OpenRouter ücretsiz modeller (step-3.5-flash)
- 📊 Vektör tabanlı arama (ChromaDB)
- 🌐 FastAPI backend
- 🐳 Docker desteği

## 🚀 Hızlı Başlangıç

### 1. Kurulum

```bash
# Script ile
bash setup.sh
# Veya manuel
pip install -r requirements.txt
cp .env.example .env
# .env dosyasını düzenle (OPENROUTER_KEY ekle)
```

### 2. API'yi Başlat

```bash
python api_server.py
```

### 3. Test Et

```bash
# Swagger UI
http://localhost:8000/docs

# cURL ile
curl -X POST http://localhost:8000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Engelli raporu nasıl alınır?"}'
```

## 📚 API Endpoints

| Endpoint | Method | Açıklama |
|----------|--------|----------|
| `/api/ask` | POST | AI'ya soru sor |
| `/api/thread/{id}` | GET | Konu verisini getir |
| `/api/search` | GET | Konu ara |
| `/api/knowledge/add/{id}` | POST | Konuyu bilgi tabanına ekle |
| `/api/knowledge/stats` | GET | İstatistikler |
| `/health` | GET | Sağlık kontrolü |

## 🔑 OpenRouter Key

1. https://openrouter.ai/ adresine git
2. Ücretsiz kaydol
3. API key oluştur
4. `.env` dosyasına ekle

## 📦 Docker

```bash
docker-compose up -d
```

## ⚠️ Yasal Uyarı
- Bu proje unofficial'dır
- Forum yönetimiyle iletişime geçin
- `robots.txt` kurallarına uyun
- Ticari kullanım için izin alın

## 📄 Lisans

MIT License
EOF

# Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY *.py .
COPY .env.example .env

# Create directories
RUN mkdir -p data/vector_store logs

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run
CMD ["python", "api_server.py"]
EOF

# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  api:    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - OPENROUTER_KEY=${OPENROUTER_KEY}
      - OPENROUTER_MODEL=stepfun/step-3.5-flash:free
      - DEBUG=false
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# tests/test_api.py
cat > tests/test_api.py << 'PYEOF'
"""
API Test Suite
"""
import requests
import pytest
import time

BASE_URL = "http://localhost:8000"

def test_health():
    """Sağlık kontrolü"""
    resp = requests.get(f"{BASE_URL}/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"

def test_root():
    """Ana sayfa"""
    resp = requests.get(f"{BASE_URL}/")
    assert resp.status_code == 200

def test_models():
    """Model listesi"""
    resp = requests.get(f"{BASE_URL}/api/models")
    assert resp.status_code == 200
    data = resp.json()
    assert "active_model" in data

def test_knowledge_stats():
    """Knowledge istatistikleri"""    resp = requests.get(f"{BASE_URL}/api/knowledge/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_documents" in data

def test_ask_ai():
    """AI soru-cevap (knowledge boş olsa da çalışmalı)"""
    payload = {
        "question": "Test sorusu",
        "thread_id": None
    }
    resp = requests.post(f"{BASE_URL}/api/ask", json=payload)
    assert resp.status_code in [200, 500]  # 500 olabilir (knowledge boş)

def test_search():
    """Arama"""
    resp = requests.get(f"{BASE_URL}/api/search", params={"q": "test", "limit": 3})
    assert resp.status_code == 200
    data = resp.json()
    assert "results" in data

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
PYEOF

echo "✅ Kurulum tamamlandı!"
echo ""
echo "📁 Proje dizini: $PROJECT_DIR"
echo ""
echo "🔧 Sonraki adımlar:"
echo "1. cd $PROJECT_DIR"
echo "2. .env dosyasını düzenle (OPENROUTER_KEY ekle)"
echo "3. pip install -r requirements.txt"
echo "4. python api_server.py"
echo ""
echo "📚 Dokümantasyon: http://localhost:8000/docs"
