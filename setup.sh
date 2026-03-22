#!/bin/bash

# Renkli çıktılar için değişkenler
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${YELLOW}>>> Engelliler.biz AI Kurulum Scripti <<<${NC}"

# 1. Gereksinimleri yükle
echo -e "${GREEN}[1/6] Gereksinimleri yüklüyor...${NC}"
pkg update -y || { echo -e "${RED}Paket yöneticisi hatası.${NC}"; exit 1; }
pkg install python git -y || { echo -e "${RED}Python veya Git yüklenemedi.${NC}"; exit 1; }

# 2. Python bağımlılıklarını yükle
echo -e "${GREEN}[2/6] Python bağımlılıklarını yüklüyor...${NC}"
pip install -r requirements.txt || { echo -e "${RED}Bağımlılıklar yüklenemedi.${NC}"; exit 1; }

# 3. .env dosyasını kontrol et
echo -e "${GREEN}[3/6] .env dosyasını kontrol ediyor...${NC}"
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

# 4. engelliler-ai klasörünü oluştur
echo -e "${GREEN}[4/6] engelliler-ai klasörünü oluşturuyor...${NC}"
mkdir -p engelliler-ai
if [ $? -eq 0 ]; then
    echo -e "${GREEN}engelliler-ai klasörü başarıyla oluşturuldu.${NC}"
else
    echo -e "${RED}engelliler-ai klasörü oluşturulamadı.${NC}"
    exit 1
fi

# 5. engelliler-ai klasörüne dosyalar ekle
echo -e "${GREEN}[5/6] engelliler-ai klasörüne dosyalar ekleniyor...${NC}"
# config.py dosyasını oluştur
cat > engelliler-ai/config.py << 'EOF_CONFIG'
# Ayarlar dosyası
API_URL = "https://api.openrouter.ai/v1/chat/completions"
MODEL_NAME = "gemini-2.5-pro"
MAX_TOKENS = 4096
TEMPERATURE = 0.7
EOF_CONFIG

# scraper.py dosyasını oluştur
cat > engelliler-ai/scraper.py << 'EOF_SCRAPER'
# XenForo scraper
import requests

def scrape_forum(url):
    print(f"Scraping forum: {url}")
    response = requests.get(url)
    if response.status_code == 200:
        return response.text
    else:
        raise Exception(f"Failed to scrape forum: {response.status_code}")
EOF_SCRAPER

# ai_engine.py dosyasını oluştur
cat > engelliler-ai/ai_engine.py << 'EOF_AI_ENGINE'
# Gemini 2.5 Pro entegrasyonu
from dotenv import load_dotenv
import os
import requests

load_dotenv()

def generate_response(prompt):
    api_key = os.getenv("OPENROUTER_API_KEY")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "gemini-2.5-pro",
        "messages": [{"role": "user", "content": prompt}]
    }
    response = requests.post("https://api.openrouter.ai/v1/chat/completions", headers=headers, json=data)
    if response.status_code == 200:
        return response.json()["choices"][0]["message"]["content"]
    else:
        raise Exception(f"API error: {response.status_code}")
EOF_AI_ENGINE

# api_server.py dosyasını oluşturcat > engelliler-ai/api_server.py << 'EOF_API_SERVER'
# FastAPI backend
from fastapi import FastAPI
from pydantic import BaseModel
from ai_engine import generate_response

app = FastAPI()

class Query(BaseModel):
    prompt: str

@app.post("/ask")
async def ask(query: Query):
    try:
        response = generate_response(query.prompt)
        return {"response": response}
    except Exception as e:
        return {"error": str(e)}
EOF_API_SERVER

# requirements.txt dosyasını oluştur
cat > engelliler-ai/requirements.txt << 'EOF_REQUIREMENTS'
fastapi
uvicorn
requests
python-dotenv
EOF_REQUIREMENTS

if [ $? -eq 0 ]; then
    echo -e "${GREEN}engelliler-ai klasörüne dosyalar başarıyla eklendi.${NC}"
else
    echo -e "${RED}Dosyalar eklenirken bir hata oluştu.${NC}"
    exit 1
fi

# 6. API'yi başlat
echo -e "${GREEN}[6/6] API başlatılıyor...${NC}"
cd engelliler-ai
python api_server.py &
sleep 3
curl -s http://localhost:8000/health && echo -e "${GREEN}API başarıyla başlatıldı!${NC}" || echo -e "${RED}API başlatılamadı.${NC}"

echo -e "${YELLOW}>>> Kurulum tamamlandı! <<<${NC}"
