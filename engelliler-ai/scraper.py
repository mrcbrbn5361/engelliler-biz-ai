import requests
from bs4 import BeautifulSoup
import re
from typing import List, Dict

class XenForoScraper:
    def __init__(self, base_url: str = "https://www.engelliler.biz/forum"):
        self.base_url = base_url
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

    def scrape_thread(self, thread_url: str) -> Dict:
        """
        Bir forum konusundaki tüm mesajları ve meta verileri çeker.
        """
        try:
            response = requests.get(thread_url, headers=self.headers, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            thread_id = self._extract_id(thread_url)
            title = soup.select_one('h1.p-title-value')
            title = title.get_text(strip=True) if title else "Başlıksız"

            posts = []
            post_elements = soup.select('article.message')

            for post in post_elements:
                post_id = post.get('data-content')
                author = post.get('data-author')

                content_elem = post.select_one('.bbWrapper')
                # Bazı alıntıları veya gereksiz tagleri temizle
                if content_elem:
                    for quote in content_elem.select('blockquote'):
                        quote.decompose()

                content = content_elem.get_text(separator="\n", strip=True) if content_elem else ""

                if content:
                    posts.append({
                        "post_id": post_id,
                        "author": author,
                        "content": content
                    })

            return {
                "thread_id": thread_id,
                "url": thread_url,
                "title": title,
                "posts": posts
            }
        except Exception as e:
            print(f"Hata oluştu ({thread_url}): {e}")
            return None

    def _extract_id(self, url: str) -> str:
        match = re.search(r'\.(\d+)/?$', url)
        if match:
            return match.group(1)
        return url.split('/')[-1]

    def search_threads(self, query: str) -> List[Dict]:
        """
        Basit bir arama simülasyonu veya belirli bir kategoriyi listeleme.
        Gerçek XenForo araması login veya CSRF gerektirebilir.
        Burada şimdilik url yapısından tahmin yürütüyoruz.
        """
        # Not: XenForo arama motoru genellikle POST isteği ve token gerektirir.
        # Bu aşamada direkt URL'den veri çekmeye odaklanıyoruz.
        return []

def scrape_forum(url):
    scraper = XenForoScraper()
    return scraper.scrape_thread(url)
