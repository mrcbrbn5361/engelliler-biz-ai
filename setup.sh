#!/bin/bash

# Renkli çıktılar
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${YELLOW}>>> Engelliler.biz AI Kurulumu <<<${NC}"

# 1. Klasör yapısı
echo -e "${GREEN}[1/5] Klasör yapısı oluşturuluyor...${NC}"
mkdir -p data/chroma data/logs

# 2. Bağımlılıklar
echo -e "${GREEN}[2/5] Bağımlılıklar yükleniyor...${NC}"
pip install -r requirements.txt

# 3. Çevresel Değişkenler
echo -e "${GREEN}[3/5] .env kontrol ediliyor...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}!!! LÜTFEN .env DOSYASINA OPENROUTER_API_KEY EKLEYİN !!!${NC}"
fi

# 4. Sembolik Linkler (Eğer gerekliyse)
# Not: engelliler-ai içindeki kodlar ana dizindeki .env'yi okuyabilmeli

# 5. Başlatma Kontrolü
echo -e "${GREEN}[4/5] Kurulum tamamlandı.${NC}"
echo -e "${YELLOW}API'yi başlatmak için: python engelliler-ai/api_server.py${NC}"
