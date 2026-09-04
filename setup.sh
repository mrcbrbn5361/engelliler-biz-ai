#!/bin/bash
# engelliler-biz-ai kurulum scripti — Termux / Debian / macOS uyumlu.
# Mevcut kaynak dosyaları EZMEZ; sadece ortam hazırlar.
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
info()  { echo -e "${GREEN}[bilgi]${NC} $*"; }
warn()  { echo -e "${YELLOW}[uyarı]${NC} $*"; }
fail()  { echo -e "${RED}[hata]${NC} $*"; exit 1; }

echo -e "${YELLOW}>>> Engelliler.biz AI Kurulum <<<${NC}"

# 1. Python kontrolü
command -v python3 >/dev/null || fail "python3 bulunamadı. Önce Python 3.10+ kurun."
info "Python: $(python3 --version)"

# 2. Sanal ortam (Termux pkg dahil sistem paketine dokunmaz)
# --system-site-packages ŞART: pydantic-core gibi paketlerin Termux/Android için
# PyPI'da wheel'i yok; sistemdeki çalışan kopyalar venv'den görünür olmalı.
if [ ! -d ".venv" ]; then
    info "Sanal ortam oluşturuluyor (.venv)..."
    python3 -m venv --system-site-packages .venv || fail "venv oluşturulamadı."
fi
# shellcheck disable=SC1091
source .venv/bin/activate

# 3. Bağımlılıklar (--prefer-binary: kaynaktan derlemeye kalkışma)
info "Bağımlılıklar yükleniyor..."
pip install --upgrade pip >/dev/null 2>&1 || true
pip install --prefer-binary -r requirements.txt || fail "Bağımlılıklar yüklenemedi."

# 4. .env
if [ ! -f "./.env" ]; then
    warn ".env yok, .env.example dosyasından oluşturuluyor."
    cp .env.example .env
    warn "Lütfen .env içindeki OPENROUTER_API_KEY değerini düzenleyin (boş da çalışır: çevrimdışı kip)."
else
    info ".env zaten mevcut."
fi

# 5. Dizinler + sözdizimi kontrolü
info "Dizinler ve sözdizimi denetleniyor..."
PYTHONPATH=engelliler-ai python3 -c "import config; print('config OK, ai_enabled =', config.settings.ai_enabled)"
python3 -m compileall -q engelliler-ai tests || fail "Sözdizimi hatası var."
PYTHONPATH=engelliler-ai python3 -m unittest discover -s tests -v || fail "Testler başarısız."

echo -e "${YELLOW}>>> Kurulum tamam! Başlatmak için: <<<${NC}"
echo "  source .venv/bin/activate"
echo "  python engelliler-ai/api_server.py"
echo "  # Arayüz: http://localhost:8000/   API belgeleri: http://localhost:8000/docs"
