from dotenv import load_dotenv
import os
import requests
from knowledge_base import KnowledgeBase
from typing import Optional
from logger import get_logger

logger = get_logger("AI_ENGINE")

load_dotenv()

class AIEngine:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        # Ücretsiz ve hızlı model: google/gemini-flash-1.5-8b
        self.model = os.getenv("AI_MODEL", "google/gemini-flash-1.5-8b")
        self.kb = KnowledgeBase()

    def generate_response(self, prompt: str, use_rag: bool = True):
        context = ""
        if use_rag:
            relevant_docs = self.kb.query(prompt, n_results=3)
            if relevant_docs:
                context = "\n\nİlgili Forum Bilgileri:\n"
                for doc in relevant_docs:
                    context += f"- {doc['content']} (Kaynak: {doc['metadata']['thread_title']})\n"

        full_prompt = f"""Sen engelliler.biz forumunun asistanısın.
Aşağıdaki forum bilgilerini kullanarak kullanıcının sorusunu yanıtla.
Eğer bilgi yetersizse, genel bilginle cevap ver ama forumda bu konuda kesin bir bilgi olmadığını belirt.

{context}

Kullanıcı Sorusu: {prompt}
Cevap:"""

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/engelliler-biz/ai", # Gerekli: OpenRouter için
            "X-Title": "Engelliler AI"
        }

        data = {
            "model": self.model,
            "messages": [{"role": "user", "content": full_prompt}]
        }

        try:
            logger.info(f"AI isteği gönderiliyor. Model: {self.model}")
            response = requests.post(
                "https://api.openrouter.ai/v1/chat/completions",
                headers=headers,
                json=data,
                timeout=30
            )
            response.raise_for_status()
            result = response.json()["choices"][0]["message"]["content"]
            logger.info("AI yanıtı başarıyla alındı.")
            return result
        except Exception as e:
            logger.error(f"AI hatası: {str(e)}")
            return f"AI yanıt üretirken bir hata oluştu: {str(e)}"

# Geriye dönük uyumluluk için
def generate_response(prompt):
    engine = AIEngine()
    return engine.generate_response(prompt)
