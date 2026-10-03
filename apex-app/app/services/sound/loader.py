from kivy.core.audio import SoundLoader
import os

class AudioLoader:
    @staticmethod
    def load_sfx(filename):
        path = os.path.join("app", "assets", "sfx", filename)
        sound = SoundLoader.load(path)
        if not sound:
            print(f"⚠️ Audio Error: Could not find {path}")
        return sound