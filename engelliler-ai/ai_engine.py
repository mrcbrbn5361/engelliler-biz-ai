"""OpenRouter yapay zeka motoru + çevrimdışı yedek.

- API anahtarı yoksa: bilgi tabanı/bağlam metninden çıkarımcı özet döndürür
  (anahtarsız kurulumda da uygulama çalışır, testler ağ gerektirmez).
- Anahtar varsa: OpenRouter Chat Completions + sade Türkçe sistem istemi,
  zaman aşımı ve 1 otomatik tekrar denemesi.
"""
from __future__ import annotations

import logging
import re

import requests

from config import settings

log = logging.getLogger("engelliler-biz-ai.ai")

API_URL = "https://openrouter.ai/api/v1/chat/completions"

SYSTEM_PROMPT = (
    "Sen engelli bireyler için sade Türkçe konuşan erişilebilirlik asistanısın. "
    "Kurallar: kısa cümleler kur, teknik terimleri açıkla, adım adım anlat, "
    "ekran okuyucuyla rahat okunacak düz metin kullan (tablo, emoji ve "
    "karmaşık biçimlendirmeden kaçın). Emin olmadığın yasal/bürokratik "
    "bilgilerde kullanıcıyı resmi kuruma (SHÇEK, SGK, e-Devlet) yönlendir."
)


class AIEngineError(Exception):
    """Türkçe, kullanıcıya gösterilebilir yapay zeka hatası."""


def clean_text(text: str, limit: int = 6000) -> str:
    """Bağlam metnini tek satırlık temiz metne indir."""
    text = re.sub(r"\s+", " ", (text or "")).strip()
    return text[:limit]


def offline_summary(question: str, context: str = "") -> str:
    """API anahtarı yokken bilgi tabanı metninden çıkarımcı yanıt üret."""
    context = clean_text(context, 1500)
    if not context:
        return (
            "Çevrimdışı kipteyim (API anahtarı tanımlı değil) ve bu soruyla ilgili "
            "kayıtlı bilgi bulamadım. Lütfen önce bir forum konusunu bilgi "
            "tabanına ekleyin ya da .env dosyasına OPENROUTER_API_KEY yazın. "
            f"Sorunuz: {question}"
        )
    # Bağlamın ilk cümlelerini yanıt olarak derle
    sentences = re.split(r"(?<=[.!?])\s+", context)
    snippet = " ".join(sentences[:4])
    return (
        "Çevrimdışı kipteyim; bilgi tabanındaki ilgili kayıtlara göre özet:\n\n"
        f"{snippet}\n\n"
        "Not: Bu otomatik bir özet, yapay zeka yanıtı değildir. "
        "Resmi işlemler için e-Devlet veya ilgili kurumu kontrol edin."
    )


def generate_response(prompt: str, context: str = "") -> tuple[str, bool]:
    """(yanıt, ai_kullanıldı_mı) döndür. Hatalarda AIEngineError yükseltir."""
    question = (prompt or "").strip()
    if not question:
        raise AIEngineError("Soru boş olamaz.")
    if len(question) > 2000:
        raise AIEngineError("Soru en fazla 2000 karakter olabilir.")
    context = clean_text(context)

    if not settings.ai_enabled:
        log.info("OPENROUTER_API_KEY yok, çevrimdışı özet kullanılıyor.")
        return offline_summary(question, context), False

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    user_content = question
    if context:
        user_content += f"\n\nBilgi tabanından ilgili kayıtlar:\n{context}"
    messages.append({"role": "user", "content": user_content})

    headers = {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/mrcbrbn5361/engelliler-biz-ai",
        "X-Title": "engelliler-biz-ai",
    }
    payload = {"model": settings.openrouter_model, "messages": messages}

    last_error = "bilinmeyen hata"
    for attempt in (1, 2):
        try:
            response = requests.post(
                API_URL, headers=headers, json=payload,
                timeout=settings.request_timeout,
            )
            if response.status_code == 401:
                raise AIEngineError("API anahtarı geçersiz. .env dosyasını kontrol edin.")
            if response.status_code == 429:
                raise AIEngineError("Yoğunluk nedeniyle sınırlamaya takıldık, biraz sonra deneyin.")
            if response.status_code >= 400:
                raise AIEngineError(f"Yapay zeka servisi hata verdi (HTTP {response.status_code}).")
            data = response.json()
            content = data["choices"][0]["message"]["content"]
            if not content or not content.strip():
                raise AIEngineError("Yapay zeka boş yanıt verdi, tekrar deneyin.")
            return content.strip(), True
        except (AIEngineError, requests.Timeout) as exc:
            last_error = str(exc)
            log.warning("OpenRouter deneme %d başarısız: %s", attempt, exc)
        except (requests.RequestException, KeyError, IndexError, ValueError) as exc:
            last_error = str(exc)
            log.warning("OpenRouter deneme %d başarısız: %s", attempt, exc)
    raise AIEngineError(f"Yapay zeka yanıtı alınamadı ({last_error}).")
