from kivy.app import App
from kivy.properties import StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivymd.uix.dialog import (
    MDDialog,
    MDDialogContentContainer,
    MDDialogHeadlineText,
)

from app.services.mic import AudioCapture, VoiceSender
from app.widgets.connection_modal.connection_modal import ConnectionContent


class TopUtilityBar(BoxLayout):
    battery_percent = StringProperty("100%")
    distance_text = StringProperty("000 M")

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.app = App.get_running_app()

        self.dialog = None
        self.mic_active = False

        self.mic_engine = AudioCapture(chunk_size=1024, sample_rate=8000)
        self.voice_streamer = VoiceSender(
            ip=self.app.app_config.ESP_IP,
            port=self.app.app_config.VOICE_PORT,
        )

        # Singleton Receiver connection
        self.app.receiver.callback = self.process_incoming_telemetry

    def process_incoming_telemetry(self, data):
        """Processes dict: {'B': '85', 'S': '24', 'D': '152'}"""
        if "B" in data:
            self.battery_percent = f"{data['B']}%"
        if "D" in data:
            self.distance_text = f"{str(data['D']).zfill(3)} M"

        if hasattr(self.app.root, "ids") and "telemetry_hud" in self.app.root.ids:
            self.app.root.ids.telemetry_hud.update_telemetry(data)

    def open_connection_dialog(self):
        """Triggers the Miracast-style Status Modal"""
        self.app.audio_service.play("click")
        if not self.dialog:
            self.dialog = MDDialog(
                MDDialogHeadlineText(
                    text="SYSTEM TERMINAL",
                    font_name="Orbitron",
                ),
                MDDialogContentContainer(
                    ConnectionContent(),
                ),
                auto_dismiss=True,
            )
        self.dialog.open()

    def mic_transmission(self):
        """Toggles Outbound Audio: 'Z' (On), 'z' (Off)"""
        self.mic_active = not self.mic_active
        self.app.audio_service.play("click")

        # 1. Update UI Visuals
        self.ids.mic_btn.icon = (
            "microphone-off" if not self.mic_active else "microphone"
        )
        self.ids.mic_btn.text_color = (
            [1, 0, 0, 1] if not self.mic_active else [0.4, 0.7, 1, 1]
        )

        # 2. Control Hardware & Stream
        if self.mic_active:
            self.app.sender.send("Z")
            self.mic_engine.start(
                on_data_callback=self.voice_streamer.send_audio_chunk
            )
            print("Mic Streaming Active...")
        else:
            self.mic_engine.stop()
            self.app.sender.send("z")
            print("Mic Streaming Stopped.")

    def speaker_transmission(self):
        """MASTER MUTE: Controls the SoundHandler engine."""
        is_muted = self.app.audio_service.toggle_mute()
        self.app.audio_service.play("click")

        if is_muted:
            self.speaker_start = True
            self.ids.speaker.icon = "volume-off"
            self.ids.speaker.text_color = [1, 0.2, 0.2, 1]
        else:
            self.speaker_start = False
            self.ids.speaker.icon = "volume-high"
            self.ids.speaker.text_color = [0.8, 1, 1, 1]
            self.app.audio_service.start_audio_engine()
            if self.app.is_connected:
                self.app.audio_service.start_engine()