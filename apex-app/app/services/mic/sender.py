import socket

class VoiceSender:
    def __init__(self, ip="192.168.4.1", port=8081):
        self.addr = (ip, port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP Socket

    def send_audio_chunk(self, chunk):
        """Sends a raw PCM byte chunk to the Robot"""
        try:
            # We don't wait for a response, just fire and forget for speed
            self.sock.sendto(chunk, self.addr)
        except Exception as e:
            print(f"Voice Stream Error: {e}")