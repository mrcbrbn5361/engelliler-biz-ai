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
# engelliler-biz-ai
# engelliler-biz-ai
# engelliler-biz-ai
# engelliler-biz-ai
