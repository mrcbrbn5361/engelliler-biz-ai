import chromadb
from chromadb.utils import embedding_functions
import os
from typing import List, Dict

class KnowledgeBase:
    def __init__(self, persist_directory: str = "data/chroma"):
        self.client = chromadb.PersistentClient(path=persist_directory)
        # Varsayılan olarak hafif bir model kullanıyoruz
        self.embedding_fn = embedding_functions.DefaultEmbeddingFunction()
        self.collection = self.client.get_or_create_collection(
            name="forum_posts",
            embedding_function=self.embedding_fn
        )

    def add_thread(self, thread_data: Dict):
        """
        Bir konudaki mesajları vektör veritabanına ekler.
        """
        if not thread_data or "posts" not in thread_data:
            return

        ids = []
        documents = []
        metadatas = []

        for post in thread_data["posts"]:
            if len(post["content"]) < 20: # Çok kısa mesajları atla
                continue

            ids.append(f"thread_{thread_data['thread_id']}_post_{post['post_id']}")
            documents.append(post["content"])
            metadatas.append({
                "thread_id": thread_data["thread_id"],
                "thread_title": thread_data["title"],
                "author": post["author"] or "Anonim",
                "url": thread_data["url"]
            })

        if documents:
            self.collection.add(
                ids=ids,
                documents=documents,
                metadatas=metadatas
            )

    def query(self, text: str, n_results: int = 5) -> List[Dict]:
        """
        Verilen metne en benzer içerikleri getirir.
        """
        results = self.collection.query(
            query_texts=[text],
            n_results=n_results
        )

        formatted_results = []
        if results["documents"]:
            for i in range(len(results["documents"][0])):
                formatted_results.append({
                    "content": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "distance": results["distances"][0][i] if "distances" in results else None
                })
        return formatted_results

    def get_stats(self):
        return {
            "count": self.collection.count()
        }
