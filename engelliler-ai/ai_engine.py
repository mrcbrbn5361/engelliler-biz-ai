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
