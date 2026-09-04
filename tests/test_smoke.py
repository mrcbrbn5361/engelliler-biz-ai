"""Duman testleri — ağ ve API anahtarı gerektirmez (unittest, stdlib only)."""
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "engelliler-ai"))

from ai_engine import offline_summary  # noqa: E402
from config import settings  # noqa: E402
from knowledge import add_entry, get_entry, search, stats  # noqa: E402
from scraper import ScraperError, validate_url  # noqa: E402


class TestConfig(unittest.TestCase):
    def test_defaults(self):
        self.assertEqual(settings.api_port, 8000)
        self.assertTrue(settings.cache_dir.is_dir())
        self.assertTrue(settings.log_file.parent.is_dir())


class TestScraperSecurity(unittest.TestCase):
    def test_allowed_domain_ok(self):
        url = validate_url("https://engelliler.biz/threads/123/")
        self.assertIn("engelliler.biz", url)

    def test_subdomain_ok(self):
        validate_url("https://forum.engelliler.biz/konu")

    def test_external_domain_blocked(self):
        with self.assertRaises(ScraperError):
            validate_url("https://ornek.com/kotu")

    def test_non_http_blocked(self):
        with self.assertRaises(ScraperError):
            validate_url("file:///etc/passwd")


class TestKnowledge(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.orig = settings.knowledge_file
        object.__setattr__(settings, "knowledge_file", Path(self.tmp.name) / "kb.json")

    def tearDown(self):
        object.__setattr__(settings, "knowledge_file", self.orig)
        self.tmp.cleanup()

    def test_add_get_search_stats(self):
        add_entry(1, "Engelli raporu nasıl alınır", "rapor için hastaneye başvurun", "http://x/1")
        entry = get_entry(1)
        self.assertIsNotNone(entry)
        self.assertIn("rapor", entry["title"])
        self.assertIsNone(get_entry(999))
        hits = search("engelli raporu")
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["thread_id"], "1")
        self.assertEqual(search("xyz alakasız qqq") or [], [])
        st = stats()
        self.assertEqual(st["threads"], 1)
        self.assertGreater(st["total_chars"], 0)

    def test_short_query_empty(self):
        self.assertEqual(search("a"), [])


class TestOfflineAI(unittest.TestCase):
    def test_empty_question_rejected(self):
        from ai_engine import AIEngineError, generate_response

        with self.assertRaises(AIEngineError):
            generate_response("  ")

    def test_offline_summary_without_context(self):
        out = offline_summary("rapor nasıl alınır?", "")
        self.assertIn("Çevrimdışı", out)

    def test_offline_summary_with_context(self):
        out = offline_summary("rapor?", "Rapor için hastaneye başvurun. Heyet günü alınır.")
        self.assertIn("hastaneye", out)


class TestAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            from fastapi.testclient import TestClient

            from api_server import app

            cls.client = TestClient(app)
        except Exception as exc:  # bağımlılık eksikse API testlerini atla
            raise unittest.SkipTest(f"TestClient yok: {exc}")

    def test_health(self):
        r = self.client.get("/health")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["status"], "ok")

    def test_ask_validation(self):
        r = self.client.post("/api/ask", json={"question": "ab"})
        self.assertEqual(r.status_code, 422)

    def test_ask_offline(self):
        r = self.client.post("/api/ask", json={"question": "Engelli raporu nasıl alınır?"})
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertIn("answer", body)
        self.assertIn("ai_used", body)

    def test_search_validation(self):
        self.assertEqual(self.client.get("/api/search", params={"q": "ab"}).status_code, 422)

    def test_knowledge_404(self):
        self.assertEqual(self.client.get("/api/knowledge/get/999999").status_code, 404)

    def test_index_served(self):
        r = self.client.get("/")
        self.assertEqual(r.status_code, 200)
        self.assertIn('lang="tr"', r.text)
        self.assertIn("aria-live", r.text)

    def test_threads_endpoint(self):
        r = self.client.get("/api/knowledge/threads")
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertIn("count", body)
        self.assertIn("threads", body)

    def test_crawl_validation(self):
        r = self.client.post("/api/knowledge/crawl", json={"max_threads": 0})
        self.assertEqual(r.status_code, 422)

    def test_crawl_mocked(self):
        import api_server

        orig_discover = api_server.discover_forum_urls
        orig_list = api_server.list_thread_ids
        orig_scrape = api_server.scrape_thread
        api_server.discover_forum_urls = lambda: ["https://engelliler.biz/forum/x.60/"]
        api_server.list_thread_ids = lambda url, n: [111, 222]
        api_server.scrape_thread = lambda tid, use_cache=True: {
            "url": f"https://engelliler.biz/konu/x.{tid}/",
            "title": f"Konu {tid}",
            "text": "örnek metin",
            "posts": 1,
        }
        try:
            with tempfile.TemporaryDirectory() as tmp:
                orig_kb = api_server.settings.knowledge_file
                object.__setattr__(api_server.settings, "knowledge_file", Path(tmp) / "kb.json")
                try:
                    r = self.client.post(
                        "/api/knowledge/crawl",
                        json={"max_threads": 5, "max_pages_per_forum": 1},
                    )
                finally:
                    object.__setattr__(api_server.settings, "knowledge_file", orig_kb)
            self.assertEqual(r.status_code, 200)
            body = r.json()
            self.assertEqual(body["added"], 2)
            self.assertEqual(body["thread_ids"], [111, 222])
        finally:
            api_server.discover_forum_urls = orig_discover
            api_server.list_thread_ids = orig_list
            api_server.scrape_thread = orig_scrape


class TestThreadParsing(unittest.TestCase):
    def test_extract_thread_ids(self):
        from scraper import extract_thread_ids

        html = (
            '<a href="/konu/birinci-konu.262199/">x</a>'
            '<a href="https://engelliler.biz/konu/ikinci.4306/">y</a>'
            '<a href="/konu/birinci-konu.262199/">tekrar</a>'
            '<a href="/forum/ulasim.60/">forum</a>'
            '<a href="/uye/ali.123/">uye</a>'
        )
        self.assertEqual(extract_thread_ids(html), [262199, 4306])

    def test_extract_empty(self):
        from scraper import extract_thread_ids

        self.assertEqual(extract_thread_ids(""), [])
        self.assertEqual(extract_thread_ids("<p>konu yok</p>"), [])

    def test_parse_thread_id(self):
        from scraper import ScraperError, parse_thread_id

        self.assertEqual(parse_thread_id("262199"), 262199)
        with self.assertRaises(ScraperError):
            parse_thread_id("abc")
        with self.assertRaises(ScraperError):
            parse_thread_id("-5")


if __name__ == "__main__":
    unittest.main(verbosity=2)
