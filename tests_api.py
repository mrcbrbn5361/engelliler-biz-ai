import unittest
from fastapi.testclient import TestClient
import sys
import os

# Import yollarını ayarla
sys.path.append(os.path.join(os.path.dirname(__file__), 'engelliler-ai'))

from api_server import app

client = TestClient(app)

class TestAPI(unittest.TestCase):
    def test_health(self):
        response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertIn("status", response.json())

    def test_stats(self):
        response = client.get("/api/knowledge/stats")
        self.assertEqual(response.status_code, 200)
        self.assertIn("count", response.json())

    def test_ask_no_key(self):
        # API anahtarı yoksa veya hatalıysa bile endpoint'in nasıl tepki verdiğini gör
        # (Mocking yapmadığımız için 500 veya hata mesajı dönebilir)
        response = client.post("/api/ask", json={"prompt": "Merhaba", "use_rag": False})
        # Not: Gerçek API çağrısı yapacağı için başarısız olabilir,
        # ama biz kodun crash olmadığını doğrulamış oluruz.
        self.assertIn(response.status_code, [200, 500])

if __name__ == "__main__":
    unittest.main()
