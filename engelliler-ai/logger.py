import logging
import os
from datetime import datetime

# Log dizinini oluştur
log_dir = "data/logs"
os.makedirs(log_dir, exist_ok=True)

# Log formatı
log_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
log_file = os.path.join(log_dir, "app.log")

logging.basicConfig(
    level=logging.INFO,
    format=log_format,
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)

def get_logger(name):
    return logging.getLogger(name)
