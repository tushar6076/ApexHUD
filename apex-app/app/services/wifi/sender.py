import socket


class CommandSender:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(CommandSender, cls).__new__(cls)
            cls._instance.socket = socket.socket(
                socket.AF_INET, socket.SOCK_DGRAM
            )
            cls._instance.socket.settimeout(0.1)
            cls._instance.target_ip = "192.168.4.1"
            cls._instance.target_port = 4210  # Matches ESP8266 localPort
        return cls._instance

    def send(self, command):
        """Sends control commands ('F', 'B', 'L', 'R', 'H', 'X', 'x', 'K') to the car."""
        try:
            self.socket.sendto(
                command.encode("utf-8"),
                (self.target_ip, self.target_port),
            )
        except Exception as e:
            print(f"Command Transmission Error: {e}")

    def update_settings(self, ip, port):
        self.target_ip = ip
        try:
            self.target_port = int(port)
        except ValueError:
            print("Invalid Port provided")