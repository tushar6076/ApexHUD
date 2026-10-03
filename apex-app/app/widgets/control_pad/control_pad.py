from kivy.clock import Clock
from kivy.app import App
from kivy.properties import BooleanProperty
from kivy.uix.floatlayout import FloatLayout

from app.services.sound import audio_service

class ControlPad(FloatLayout):

    light_active = BooleanProperty(False)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.app = App.get_running_app()

    def send_command(self, cmd):
        # 1. Hardware Trigger
        self.app.sender.send(cmd)
        # 2. UI Audio Feedback
        if cmd == "F" or cmd == "B":
            audio_service.update_drive_audio(0.5)
        elif cmd == "L" or cmd == "R":
            audio_service.play("move")
        elif cmd.upper() == "X":
            audio_service.play("click")
        elif cmd == "S":
            audio_service.play("horn")
        elif cmd == "H":
            audio_service.update_drive_audio(0)

    def horn(self, btn):
        audio_service.play("horn")
        self.send_command("S")

    def toggle_headlight(self, btn):
        self.light_active = not self.light_active
        audio_service.play("click")
        
        if self.light_active:
            btn.icon = "car-light-high"
            btn.text_color = [1, 0.8, 0.8, 1] # Pure White Glow
            self.app.sender.send("X")
        else:
            btn.icon = "car-light-dimmed"
            btn.text_color = [1, 0.8, 0, 1] # Dimmed Gray
            self.app.sender.send("x")