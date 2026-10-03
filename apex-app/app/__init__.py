from kivymd.app import MDApp
from kivy.clock import Clock
from kivy.lang import Builder
from kivy.core.text import LabelBase
from kivy.properties import StringProperty, BooleanProperty

# Import Services
from app.services.wifi.sender import CommandSender
from app.services.wifi.receiver import TelemetryReceiver

from app.services.sound import audio_service

from app.utils import request_android_permissions, check_actual_connection

import os

class ApexHUDApp(MDApp):

    is_connected = BooleanProperty(False)
    robot_name = StringProperty("MIRANA_V1")
    manual_disconnect = False

    
    def __init__(self, config_class, **kwargs):
        super().__init__(**kwargs)
        self.app_config = config_class()
        
        # Services as Singletons
        self.audio_service = audio_service
        self.sender = CommandSender()
        self.sender.update_settings(
            self.app_config.ESP_IP, self.app_config.UDP_PORT
        )
        self.receiver = TelemetryReceiver()

    def build(self):
        # 1. Register specialized fonts
        try:
            LabelBase.register(name='Orbitron', 
                               fn_regular='app/assets/fonts/Orbitron-Regular.ttf')
        except Exception as e:
            print(f"Font loading failed: {e}")

        # Load KV files
        Builder.load_file("app/widgets/top_bar/top_bar.kv")
        Builder.load_file("app/widgets/control_pad/control_pad.kv")
        Builder.load_file("app/widgets/telemetry/dashboard.kv")
        Builder.load_file("app/widgets/connection_modal/connection_modal.kv")
        
        # 2. Cyberpunk aesthetic
        self.theme_cls.theme_style = "Dark"
        self.theme_cls.primary_palette = "Cyan"
        self.theme_cls.accent_palette = "Amber"
        
        # 3. Load Orchestrator
        BASE_DIR = os.path.abspath(os.path.dirname(__file__))
        return Builder.load_file(os.path.join(BASE_DIR, 'app.kv'))

    def on_start(self):
        """
        App is ready, but we wait for the 'Connect' button 
        to actually start the socket listeners.
        """
        # We delay it by 0.5s so the UI is visible behind the popup
        Clock.schedule_once(lambda dt: request_android_permissions(), 0.5)
        self.audio_service.start_audio_engine()

        # Listener always runs; the link is "up" only while the ESP answers.
        self.start_hardware_link()
        Clock.schedule_interval(self.link_tick, 1.0)

        print("MIRANA System Standby...")

    def link_tick(self, dt):
        """Pings the ESP and derives connection state from its replies."""
        if not self.receiver.running:
            self.start_hardware_link()
        self.sender.send("P")
        alive = check_actual_connection(self) and not self.manual_disconnect
        if alive == self.is_connected:
            return
        self.is_connected = alive
        if alive:
            self.audio_service.start_engine()
            self.bind_android_network()
            print("MIRANA Link Verified: Online")
        else:
            print("MIRANA Link Lost")

    def bind_android_network(self):
        """Routes local UDP over Wi-Fi even when it has no internet."""
        from kivy.utils import platform
        if platform != "android":
            return
        try:
            from jnius import autoclass
            PythonActivity = autoclass("org.kivy.android.PythonActivity")
            Context = autoclass("android.content.Context")
            cm = PythonActivity.mActivity.getSystemService(
                Context.CONNECTIVITY_SERVICE)
            for network in cm.getAllNetworks():
                caps = cm.getNetworkCapabilities(network)
                if caps and caps.hasTransport(1):  # TRANSPORT_WIFI
                    cm.bindProcessToNetwork(network)
                    break
        except Exception as e:
            print(f"Android Network Bind Exception: {e}")

    def start_hardware_link(self):
        """Called when the user confirms connection in the Modal"""
        self.receiver.start(port=self.app_config.TELEMETRY_PORT)

    def stop_hardware_link(self):
        """Call this to save battery or on app close"""
        self.receiver.stop()