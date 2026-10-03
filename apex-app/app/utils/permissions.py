from kivy.utils import platform

def request_android_permissions():
    """
    Handles the runtime permission requests for Android devices.
    """
    if platform != 'android':
        return

    try:
        from android.permissions import request_permissions, Permission
        
        # List the critical permissions for your ApexHUD HUD
        permissions = [
            Permission.RECORD_AUDIO,      # For Mic/Buzzer features
            Permission.ACCESS_WIFI_STATE, # For the 'Miracast' style handshake
            Permission.CHANGE_WIFI_STATE, # To jump to settings
            Permission.INTERNET           # To talk to the ESP8266
        ]

        def callback(permissions, results):
            """Checks if the user actually said 'Allow'"""
            if all(results):
                print("All System Permissions Authorized.")
            else:
                print("Warning: Some permissions were denied. HUD may be limited.")

        request_permissions(permissions, callback)
        
    except Exception as e:
        print(f"Permission Request Failed: {e}")