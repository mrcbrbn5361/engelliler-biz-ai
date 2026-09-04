"""Merkezi yapılandırma: tüm ortam değişkenleri buradan okunur.

Kurallar:
- Kodun hiçbir yerinde doğrudan os.getenv kullanılmaz, buradaki Settings kullanılır.
- Gerekli dizinler (cache, logs, knowledge) ilk import'ta oluşturulur.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()  # .env varsa yükle, yoksa sessizce geç

ROOT = Path(__file__).resolve().parent.parent


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class Settings:
    api_host: str = field(default_factory=lambda: _env("API_HOST", "127.0.0.1"))
    api_port: int = field(default_factory=lambda: _env_int("API_PORT", 8000))
    openrouter_api_key: str = field(default_factory=lambda: _env("OPENROUTER_API_KEY"))
    openrouter_model: str = field(
        default_factory=lambda: _env("OPENROUTER_MODEL", "minimax/minimax-m3:free")
    )
    allowed_scrape_domain: str = field(
        default_factory=lambda: _env("ALLOWED_SCRAPE_DOMAIN", "engelliler.biz")
    )
    cache_dir: Path = field(
        default_factory=lambda: Path(_env("CACHE_DIR", "data/cache"))
    )
    knowledge_file: Path = field(
        default_factory=lambda: Path(_env("KNOWLEDGE_FILE", "data/knowledge.json"))
    )
    log_file: Path = field(
        default_factory=lambda: Path(_env("LOG_FILE", "data/logs/app.log"))
    )
    request_timeout: int = field(
        default_factory=lambda: _env_int("REQUEST_TIMEOUT", 20)
    )

    def __post_init__(self) -> None:
        # Göreli yolları proje köküne sabitle ve dizinleri oluştur
        for attr in ("cache_dir", "knowledge_file", "log_file"):
            path = getattr(self, attr)
            if not path.is_absolute():
                object.__setattr__(self, attr, ROOT / path)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.knowledge_file.parent.mkdir(parents=True, exist_ok=True)
        self.log_file.parent.mkdir(parents=True, exist_ok=True)

    @property
    def ai_enabled(self) -> bool:
        """API anahtarı tanımlıysa çevrimiçi yapay zeka kullanılabilir."""
        return bool(self.openrouter_api_key)


settings = Settings()
