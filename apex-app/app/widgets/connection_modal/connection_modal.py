import subprocess
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.utils import platform

from app.services.sound import audio_service


class ConnectionContent(BoxLayout):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.app = App.get_running_app()

    def disconnect_system(self):
        """Sever the link, unbind schedule, and update app state."""
        self.app.manual_disconnect = True
        self.app.is_connected = False
        audio_service.play("click")

        # Unbind process network on Android
        if platform == "android":
            try:
                from jnius import autoclass

                PythonActivity = autoclass("org.kivy.android.PythonActivity")
                Context = autoclass("android.content.Context")
                cm = PythonActivity.mActivity.getSystemService(
                    Context.CONNECTIVITY_SERVICE
                )
                cm.bindProcessToNetwork(None)
            except Exception as e:
                print(f"Android Network Unbind Exception: {e}")

        # Dismiss dialog
        if (
            hasattr(self.app.root, "ids")
            and "top_bar" in self.app.root.ids
            and self.app.root.ids.top_bar.dialog
        ):
            self.app.root.ids.top_bar.dialog.dismiss()

    def retry_connection(self):
        """Triggers OS Wi-Fi panel as a fallback without manually forcing socket threads."""
        audio_service.play("click")
        self.app.manual_disconnect = False

        if platform == "android":
            try:
                from jnius import autoclass

                PythonActivity = autoclass("org.kivy.android.PythonActivity")
                Intent = autoclass("android.content.Intent")
                Settings = autoclass("android.provider.Settings")

                intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                PythonActivity.mActivity.startActivity(intent)
            except Exception as e:
                print(f"Android Intent Failed: {e}")

        elif platform == "macosx":
            subprocess.run(
                ["open", "/System/Library/PreferencePanes/Network.prefPane"]
            )
