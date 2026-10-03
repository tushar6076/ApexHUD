# config.py
import os

class Config:
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    DEBUG = False
    ESP_IP = "192.168.4.1"
    UDP_PORT = 4210
    TELEMETRY_PORT = 4210
    VOICE_PORT = 8081

class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    ANDROID_PERMISSIONS = [
        "INTERNET",
        "ACCESS_WIFI_STATE",
        "CHANGE_WIFI_STATE",
        "RECORD_AUDIO",
    ]