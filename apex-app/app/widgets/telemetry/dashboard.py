import time
from kivy.app import App
from kivy.clock import Clock
from kivy.properties import StringProperty
from kivy.uix.floatlayout import FloatLayout


class TelemetryDashboard(FloatLayout):
    speed_text = StringProperty("0")
    distance_text = StringProperty("000")
    mission_time = StringProperty("00:00:00")

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.start_time = None

        # Bind to Kivy App connection status safely
        self.app = App.get_running_app()
        if self.app:
            self.app.bind(is_connected=self.on_connection_change)
            # Initialize state based on current connection status
            self.on_connection_change(self.app, self.app.is_connected)

        Clock.schedule_interval(self.update_mission_clock, 1)

    def on_connection_change(self, instance, is_connected):
        """Starts timer when connected; resets to 00:00:00 on disconnect."""
        if is_connected:
            self.reset_mission_clock()
        else:
            self.start_time = None
            self.mission_time = "00:00:00"

    def reset_mission_clock(self):
        """Resets the timer baseline."""
        self.start_time = time.time()

    def update_mission_clock(self, dt):
        if self.start_time is None:
            self.mission_time = "00:00:00"
            return

        elapsed = int(time.time() - self.start_time)
        self.mission_time = time.strftime("%H:%M:%S", time.gmtime(elapsed))

    def update_telemetry(self, data):
        """Processes dictionary from TelemetryReceiver.

        Expects keys: 'S' (Speed), 'D' (Distance)
        """
        if "S" in data:
            self.speed_text = str(int(float(data["S"])))

        if "D" in data:
            self.distance_text = str(int(float(data["D"]))).zfill(3)