# XenForo scraper
import requests

def scrape_forum(url):
    print(f"Scraping forum: {url}")
    response = requests.get(url)
    if response.status_code == 200:
        return response.text
    else:
        raise Exception(f"Failed to scrape forum: {response.status_code}")
