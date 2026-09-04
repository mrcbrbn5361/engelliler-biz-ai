# 🤖 engelliler.biz AI

engelliler.biz forum içeriği üzerinde çalışan, **erişilebilirlik öncelikli** yapay zeka asistanı.
Engelli bireylerin haklar, rapor, bürokrasi ve günlük yaşam sorularına sade Türkçe yanıt verir.

## ✨ Özellikler

- 🕷️ Güvenli XenForo scraper (robots.txt + SSRF koruması + önbellek)
- 🧠 OpenRouter yapay zekası + **anahtarsız çevrimdışı özet kipi**
- 📚 JSON bilgi tabanı (`/api/knowledge/*`) — ChromaDB'ye geçişe hazır arayüz
- 🌐 FastAPI backend + WCAG 2.2 AA hedefli erişilebilir web arayüzü (`/`)
- 🐳 Docker / docker-compose desteği
- 🧪 Ağ gerektirmeyen duman testleri

## 🚀 Hızlı Başlangıç

```bash
bash setup.sh
# .env dosyasını düzenle (OPENROUTER_API_KEY isteğe bağlı)

source .venv/bin/activate
python engelliler-ai/api_server.py
```

- Arayüz: http://localhost:8000/
- Swagger UI: http://localhost:8000/docs

```bash
curl -X POST http://localhost:8000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Engelli raporu nasıl alınır?"}'
```

## 📚 API Endpoints

| Endpoint | Method | Açıklama |
|----------|--------|----------|
| `/` | GET | Erişilebilir web arayüzü |
| `/health` | GET | Sağlık kontrolü |
| `/api/ask` | POST | Yapay zekaya soru sor |
| `/api/search?q=` | GET | Bilgi tabanında ara |
| `/api/thread/{id}` | GET | Konu verisini getir (önbellekli) |
| `/api/knowledge/add/{id}` | POST | Konuyu bilgi tabanına ekle |
| `/api/knowledge/get/{id}` | GET | Kayıtlı konuyu getir |
| `/api/knowledge/stats` | GET | İstatistikler |

## 🔑 OpenRouter Key (isteğe bağlı)

1. https://openrouter.ai/ adresine git, kaydol, API key oluştur
2. `.env` dosyasına `OPENROUTER_API_KEY=...` yaz
3. İstersen `OPENROUTER_MODEL` ile modeli değiştir (örn. `google/gemini-2.5-flash`)

Anahtar yoksa uygulama **çevrimdışı kipte** çalışır: bilgi tabanındaki kayıtlardan özet üretir.

## 📦 Docker

```bash
cp .env.example .env   # değerleri düzenle
docker compose up -d
```

## 🧪 Testler

```bash
PYTHONPATH=engelliler-ai python -m unittest discover -s tests -v
```

## ♿ Erişilebilirlik

- Arayüz: `lang="tr"`, skip-link, landmark'lar, `aria-live` yanıt bölgesi, klavye ile tam kullanım, yüksek kontrast düğmesi, yazı boyutu düğmeleri, `prefers-reduced-motion` desteği
- API yanıtları ve hatalar Türkçe, düz metin, ekran okuyucu dostu

## ⚠️ Yasal Uyarı

- Bu proje unofficial bir topluluk çalışmasıdır
- Forum yönetiminden izin alın, `robots.txt` kurallarına uyun
- Ticari kullanım için izin alın

## 📄 Lisans

MIT License — bkz. [LICENSE](LICENSE)
