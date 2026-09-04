# AGENTS.md — engelliler-biz-ai

> Engelli bireylerin erişilebilirliğini artıran yapay zeka çözümleri.
> Bu dosyadaki kurallar, bu repoda çalışan tüm ajanlar (insan + AI) için bağlayıcıdır.

## 1. Proje Amacı

engelliler.biz forumundaki bilgi birikimini, engelli bireylerin kolayca tüketebileceği
sade Türkçe yanıtlara dönüştüren erişilebilir AI asistanı. Birincil kullanıcı engelli
bireylerdir; her teknik karar erişilebilirlik merceğinden geçer.

## 2. Mimari

```
.                          # proje kökü
├── requirements.txt       # TEK bağımlılık kaynağı ( sürümlü aralıklar, örn. fastapi>=0.115,<0.142 )
├── .env.example           # tüm ortam değişkenlerinin şablonu (.env asla commitlenmez)
├── Dockerfile / docker-compose.yml
├── setup.sh               # taşınabilir kurulum (Termux/Debian/macOS); kaynak dosyaları EZMEZ
├── LICENSE (MIT), README.md, AGENTS.md (bu dosya)
├── data/                  # çalışma zamanı: cache/, knowledge.json, logs/ (git dışı)
├── tests/test_smoke.py    # stdlib unittest; ağ + API anahtarı gerektirmez
└── engelliler-ai/         # uygulama paketi (klasör adında kısa çizgi var!)
    ├── __init__.py        # sürüm tek kaynağı (__version__)
    ├── config.py          # TEK config kaynağı (Settings dataclass); kodda doğrudan os.getenv YASAK
    ├── scraper.py         # XenForo çekici: validate_url (SSRF guard) → robots.txt → throttle → cache → parse
    ├── ai_engine.py       # generate_response(prompt, context) -> (yanıt, ai_kullanıldı)
    ├── knowledge.py       # JSON bilgi tabanı: add/get/search/stats (arayüz sabit, içi değişebilir)
    ├── api_server.py      # FastAPI: /health, /api/{ask,search,thread,knowledge}, / (statik UI)
    ├── requirements.txt   # sadece `-r ../requirements.txt` içerir, düzenlemeyin
    └── static/index.html   # WCAG 2.2 AA hedefli tek dosyalık arayüz (lang=tr, ARIA live, klavye)
```

### Klasör adı uyarısı (K1)
`engelliler-ai/` kısa çizgi içerdiğinden `import` edilemez. `api_server.py` kendi dizinini
`sys.path`'e ekler; çalıştırma yolları: `python engelliler-ai/api_server.py` (kökten) veya
`cd engelliler-ai && uvicorn api_server:app`. Yeni modül eklerken düz `from x import ...`
kullanın, paketli import denemeyin.

## 3. Zorunlu Kurallar

1. **Erişilebilirlik önce gelir (WCAG 2.2 AA):** her UI değişikliğinde `lang`, landmark,
   etiket, `aria-live`, klavye odağı, kontrast (≥4.5:1), `prefers-reduced-motion` kontrol et.
2. **Türkçe + sade dil:** kullanıcıya görünen her metin (API hataları dahil) Türkçe, kısa
   cümleli, ekrandan okunabilir düz metin olacak. Yeni endpoint'te `detail` mesajlarını Türkçe yaz.
3. **Güvenlik:** scraper'da `validate_url` atlanamaz; yeni dış HTTP isteği = timeout + hata
   çevirisi (Türkçe) + log. Gizli anahtarları loglama/koda gömme.
4. **Config disiplini:** yeni ortam değişkeni → `.env.example` + `config.py:Settings` +
   `README` üçlüsünü birlikte güncelle.
5. **Bağımlılık disiplini:** yeni paket → kök `requirements.txt`'e sürümlü aralıkla ekle;
   Termux'ta derlenemeyen ağır paketlerden (lxml, ChromaDB vb.) kaçın, gerekçeyi PR'a yaz.
6. **Test:** her davranış değişikliği `tests/test_smoke.py`'a stdlib-only test olarak eklenir;
   `PYTHONPATH=engelliler-ai python -m unittest discover -s tests` yeşil olmadan bitirme.
7. **Kaynak ezme yasağı:** kurulum/migrasyon scriptleri version'lı dosyaları heredoc'la
   yeniden YAZMAZ; yalnızca ortam hazırlar.
8. **Yasal saygı:** scraping varsayılanı kibar (robots.txt + 2 sn throttle + cache);
   engelliler.biz dışı alan adı `ALLOWED_SCRAPE_DOMAIN` değişmeden eklenemez.

## 4. Bilinen Teknik Borç / Sonraki Adımlar

- [ ] ChromaDB + embedding ile gerçek vektör RAG (`knowledge.py` arayüzü sabit kalacak)
- [ ] Rate-limit (slowapi) + üretim CORS kısıtlaması
- [ ] `OPENROUTER_MODEL` varsayılanını ücretsiz model listesine göre periyodik doğrula
- [ ] E2E erişilebilirlik denetimi (axe-core) ve ekran okuyucu testi (NVDA/VoiceOver)
- [ ] `engelliler-ai/` → `engelliler_ai/` yeniden adlandırma (kökten import için; setup.sh + README ile eşzamanlı)

## 5. Sık Komutlar

```bash
bash setup.sh                                            # kurulum
source .venv/bin/activate && python engelliler-ai/api_server.py
PYTHONPATH=engelliler-ai python -m unittest discover -s tests -v
python -m compileall -q engelliler-ai tests
docker compose up -d
```
