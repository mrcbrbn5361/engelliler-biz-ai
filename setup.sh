#!/bin/bash

# Renkli çıktılar için değişkenler
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${YELLOW}>>> Engelliler.biz AI Kurulum Scripti <<<${NC}"

# 1. Gereksinimleri yükle
echo -e "${GREEN}[1/4] Gereksinimleri yüklüyor...${NC}"
pkg update -y || { echo -e "${RED}Paket yöneticisi hatası.${NC}"; exit 1; }
pkg install python git -y || { echo -e "${RED}Python veya Git yüklenemedi.${NC}"; exit 1; }

# 2. Python bağımlılıklarını yükle
echo -e "${GREEN}[2/4] Python bağımlılıklarını yüklüyor...${NC}"
pip install --upgrade pip || { echo -e "${RED}Pip güncellenemedi.${NC}"; exit 1; }
pip install -r requirements.txt || { echo -e "${RED}Bağımlılıklar yüklenemedi.${NC}"; exit 1; }

# 3. .env dosyasını kontrol et
echo -e "${GREEN}[3/4] .env dosyasını kontrol ediyor...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}.env dosyası bulunamadı. Yeni bir tane oluşturuluyor...${NC}"
    cat > .env << 'EOF_ENV'
API_HOST=localhost
API_PORT=8000
OPENROUTER_API_KEY=your_openrouter_api_key_here
CACHE_DIR=data/cache
LOG_FILE=data/logs/ask.log
EOF_ENV
    echo -e "${GREEN}.env dosyası oluşturuldu. Lütfen OPENROUTER_API_KEY değerini düzenleyin.${NC}"
else
    echo -e "${GREEN}.env dosyası zaten mevcut.${NC}"
fi

# 4. API'yi başlat
echo -e "${GREEN}[4/4] API başlatılıyor...${NC}"
python api_server.py &
sleep 3
curl -s http://localhost:8000/health && echo -e "${GREEN}API başarıyla başlatıldı!${NC}" || echo -e "${RED}API başlatılamadı.${NC}"

echo -e "${YELLOW}>>> Kurulum tamamlandı! <<<${NC}"
