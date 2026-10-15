import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../../core/exceptions.dart';

class MicStreamer {
  static final MicStreamer _instance = MicStreamer._internal();
  factory MicStreamer() => _instance;
  MicStreamer._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  RawDatagramSocket? _voiceSocket;
  StreamSubscription<Uint8List>? _micStreamSub;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  Future<void> initSocket() async {
    try {
      _voiceSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      throw SocketTransmissionException("Failed to bind voice UDP socket: $e");
    }
  }

  Future<bool> startStreaming({String? ip, int? port}) async {
    if (_isStreaming) return true;

    final targetIp = ip ?? Config.espIp;
    final targetPort = port ?? Config.voicePort;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw AudioStreamException("Microphone permission denied");
      }

      await initSocket();

      // Configure raw 16-bit PCM Mono stream
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.voiceSampleRate,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      _isStreaming = true;

      final targetAddress = InternetAddress(targetIp);

      _micStreamSub = stream.listen((Uint8List chunk) {
        if (_voiceSocket != null && _isStreaming) {
          _voiceSocket!.send(chunk, targetAddress, targetPort);
        }
      }, onError: (err) {
        stopStreaming();
        throw AudioStreamException("Mic stream read error: $err");
      });

      return true;
    } catch (e) {
      _isStreaming = false;
      throw AudioStreamException("Failed to start mic streamer: $e");
    }
  }

  Future<void> stopStreaming() async {
    if (!_isStreaming) return;
    _isStreaming = false;

    await _micStreamSub?.cancel();
    _micStreamSub = null;

    try {
      await _audioRecorder.stop();
    } catch (_) {}

    _voiceSocket?.close();
    _voiceSocket = null;
  }

  void dispose() {
    stopStreaming();
    _audioRecorder.dispose();
  }
}