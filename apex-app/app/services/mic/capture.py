import threading
from kivy.utils import platform

class AudioCapture:
    def __init__(self, chunk_size=1024, sample_rate=8000):
        self.chunk_size = chunk_size
        self.sample_rate = sample_rate
        self.recording = False
        self.stream = None
        self._thread = None

    def start(self, on_data_callback):
        """Starts the background thread to capture audio"""
        self.recording = True
        self._thread = threading.Thread(
            target=self._capture_loop, 
            args=(on_data_callback,), 
            daemon=True
        )
        self._thread.start()

    def _capture_loop(self, callback):
        if platform in ('macosx', 'win', 'linux'):
            import pyaudio  # Lazy import prevents crash on Android
            
            p = pyaudio.PyAudio()
            self.stream = p.open(format=pyaudio.paInt16, channels=1,
                               rate=self.sample_rate, input=True,
                               frames_per_buffer=self.chunk_size)
            
            while self.recording:
                data = self.stream.read(self.chunk_size, exception_on_overflow=False)
                callback(data)
                
            self.stream.stop_stream()
            self.stream.close()
            p.terminate()

        elif platform == 'android':
            from jnius import autoclass
            AudioRecord = autoclass('android.media.AudioRecord')
            MediaRecorder = autoclass('android.media.MediaRecorder')
            AudioFormat = autoclass('android.media.AudioFormat')
            
            buffer_size = AudioRecord.getMinBufferSize(
                self.sample_rate, 
                AudioFormat.CHANNEL_IN_MONO, 
                AudioFormat.ENCODING_PCM_16BIT
            )
            
            # Ensure buffer size isn't smaller than chunk size
            actual_buffer_size = max(buffer_size, self.chunk_size * 2)
            
            recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                self.sample_rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                actual_buffer_size
            )
            
            recorder.startRecording()
            
            # Pre-allocate byte array outside the loop for memory efficiency
            buffer = bytearray(self.chunk_size)
            
            while self.recording:
                bytes_read = recorder.read(buffer, 0, len(buffer))
                if bytes_read > 0:
                    callback(bytes(buffer[:bytes_read]))
            
            recorder.stop()
            recorder.release()

    def stop(self):
        self.recording = False