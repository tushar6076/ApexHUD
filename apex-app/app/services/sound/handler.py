from .loader import AudioLoader
from kivy.clock import Clock

class SoundHandler:
    def __init__(self):
        self.muted = False
        # Pre-cache the main loops
        self.sfx = {
            "click": AudioLoader.load_sfx("ui_blip.wav"),
            "idle":  AudioLoader.load_sfx("engine_idle.wav"),
            "start": AudioLoader.load_sfx("engine_start.wav"),
            "move":  AudioLoader.load_sfx("servo_fizz.wav"),
            "horn": None
        }

    def play(self, type="click"):
        if not self.muted and self.sfx[type]:
            self.sfx[type].play()

    def start_audio_engine(self):
        """Preload the audio engine and play the idle loop"""
        if self.muted: return
        
        # Play the idle loop at 0 volume
        idle = self.sfx["idle"]
        if idle:
            idle.loop = True
            idle.volume = 1
            idle.play()

    def start_engine(self):
        """Play the engine start sound and then transition to the idle loop"""
        if self.muted: return
        
        # 1. Play the start sound
        start = self.sfx["start"]
        if not start:
            return
        start.play()
        
        # 2. Schedule the idle loop to start after the start sound finishes
        start_duration = start.length
        Clock.schedule_once(lambda dt: self.move_engine(), start_duration)

    def move_engine(self):
        """Play idle and drive loops at 0 volume until needed"""
        if self.muted: return
        
        move = self.sfx["move"]
        if move:
            move.loop = True
            move.volume = 0.5
            move.play()

    def update_drive_audio(self, throttle_level):
        """
        throttle_level: 0.0 to 1.0 (from your joystick/buttons)
        This creates the 'Game Feel' by shifting pitch.
        """
        if self.muted: return
        drive = self.sfx["move"]
        if not drive:
            return
        drive.volume = throttle_level * 0.8
        drive.pitch = 1.0 + (throttle_level * 0.7) # Sound gets higher as you go faster

    def toggle_mute(self):
        self.muted = not self.muted
        for sound in self.sfx.values():
            if sound: sound.stop()
        return self.muted