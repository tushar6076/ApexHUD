import json
import socket
import threading
import time
from kivy.clock import mainthread


class TelemetryReceiver:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(TelemetryReceiver, cls).__new__(cls)
            cls._instance.running = False
            cls._instance.callback = None
            cls._instance.sock = None
            cls._instance.thread = None
            cls._instance.last_message_time = 0.0
        return cls._instance

    def start(self, port=4210):
        if self.running and self.thread and self.thread.is_alive():
            return  # Prevent duplicate thread instances

        self.stop()  # Clean up existing socket before binding
        self.running = True

        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

            if hasattr(socket, "SO_REUSEPORT"):
                self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)

            self.sock.bind(("", port))
            self.sock.settimeout(1.0)  # Unblocks thread loop every 1s

            self.thread = threading.Thread(
                target=self._listen_loop, daemon=True
            )
            self.thread.start()
            print(f"[TelemetryReceiver] Listening on UDP port {port}")
        except Exception as e:
            print(f"[TelemetryReceiver] Failed to start: {e}")
            self.running = False

    def _listen_loop(self):
        while self.running:
            try:
                data, addr = self.sock.recvfrom(1024)
                message = data.decode("utf-8").strip()
                print(f"[RAW UDP IN] From {addr}: {message}")  # DEBUG PRINT
                self._process_data(message)
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"[TelemetryReceiver] Loop Error: {e}")
                break

    def _process_data(self, message):
        """Parses ESP8266 JSON string: '{"B":"85","S":"24","D":"152"}'

        Fallback: Parses legacy pipe-delimited format 'B:85|S:24|D:152'.
        """
        try:
            # 1. Primary parser: ESP8266 JSON Payload
            telemetry_map = json.loads(message)
            if not isinstance(telemetry_map, dict):
                print(f"[TelemetryReceiver] Malformed packet: {message}")
                return
            self.last_message_time = time.time()
            self.dispatch_to_ui(telemetry_map)
        except json.JSONDecodeError:
            # 2. Fallback parser: Pipe-delimited strings
            try:
                telemetry_map = dict(
                    item.split(":") for item in message.split("|")
                )
                self.last_message_time = time.time()
                self.dispatch_to_ui(telemetry_map)
            except ValueError:
                print(f"[TelemetryReceiver] Malformed packet: {message}")

    @mainthread
    def dispatch_to_ui(self, data):
        """Safely pushes data payload to UI handlers."""
        print(f"[UI DISPATCH] Parsed Data: {data}")  # DEBUG PRINT
        if self.callback:
            self.callback(data)
        else:
            print("[TelemetryReceiver] Warning: No callback bound to receiver!")

    def stop(self):
        """Clean shutdown that frees port 4210."""
        self.running = False
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None
        print("[TelemetryReceiver] Listener stopped.")