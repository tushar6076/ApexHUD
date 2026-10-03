from app import ApexHUDApp
from config import DevelopmentConfig

if __name__ == "__main__":
    app = ApexHUDApp(config_class=DevelopmentConfig)
    app.run()