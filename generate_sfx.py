#!/usr/bin/env python3
"""
ApexHUD Audio Synthesizer (True Seamless Looping Edition)
Generates all 8 procedural WAV assets for the cyberpunk HUD controller:
1. horn.wav
2. ui_blip.wav
3. relay_switch.wav
4. indicator_tick.wav
5. engine_drive.wav (6s true circular loop)
6. turn_strain.wav (6s true circular loop)
7. engine_start.wav
8. engine_idle.wav (6s true circular loop)
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
SFX_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "assets", "sfx"
)
if not os.path.exists(os.path.dirname(SFX_DIR)):
    SFX_DIR = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "apex-app", "assets", "sfx"
    )

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    filepath = os.path.join(SFX_DIR, filename)
    with wave.open(filepath, "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)

        raw_data = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            int_sample = int(val * 32767.0)
            raw_data.extend(struct.pack("<h", int_sample))

        wav_file.writeframes(raw_data)
    print(f"[+] Generated: {filepath} ({len(samples)/sample_rate:.2f}s)")

def make_circular_loop(raw_samples, fade_seconds=0.25):
    """Blends the tail of the audio into the head for a gap-free loop."""
    fade_len = int(SAMPLE_RATE * fade_seconds)
    total_len = len(raw_samples) - fade_len
    out = list(raw_samples[:total_len])

    for i in range(fade_len):
        progress = i / fade_len
        # Equal-power sine/cosine crossfade
        gain_tail = math.cos(progress * (math.pi / 2))
        gain_head = math.sin(progress * (math.pi / 2))
        
        tail_sample = raw_samples[total_len + i]
        head_sample = raw_samples[i]
        out[i] = (head_sample * gain_head) + (tail_sample * gain_tail)

    return out

# 1. HORN
def gen_horn():
    duration = 0.35
    total = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        env = t / 0.015 if t < 0.015 else ((duration - t) / 0.04 if t > duration - 0.04 else 1.0)
        sig = 0.55 * math.sin(2 * math.pi * 440.0 * t) + 0.35 * math.sin(2 * math.pi * 554.37 * t) + 0.15 * math.sin(2 * math.pi * 880.0 * t)
        samples.append(math.tanh(sig * 1.6) * env * 0.9)
    write_wav("horn.wav", samples)

# 2. UI BLIP
def gen_ui_blip():
    duration = 0.055
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 85.0)
        freq = 2200.0 - (1400.0 * (t / duration))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        samples.append((math.sin(phase) + 0.15 * math.sin(3 * phase)) * env * 0.75)
    write_wav("ui_blip.wav", samples)

# 3. RELAY SWITCH
def gen_relay_switch():
    duration = 0.08
    total = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        click = random.uniform(-1.0, 1.0) * math.exp(-t * 400.0) if t < 0.02 else 0.0
        ring = (0.6 * math.sin(2 * math.pi * 850.0 * t) + 0.3 * math.sin(2 * math.pi * 2400.0 * t)) * math.exp(-t * 65.0)
        samples.append((click * 0.7 + ring * 0.5) * 0.85)
    write_wav("relay_switch.wav", samples)

# 4. INDICATOR TICK
def gen_indicator_tick():
    duration = 0.035
    total = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 160.0)
        tone = math.sin(2 * math.pi * 1450.0 * t)
        noise = random.uniform(-0.4, 0.4) if t < 0.006 else 0.0
        samples.append((tone * 0.75 + noise * 0.25) * env * 0.8)
    write_wav("indicator_tick.wav", samples)

# 5. ENGINE DRIVE (6s True Seamless Loop)
def gen_engine_drive():
    duration = 6.25
    total = int(SAMPLE_RATE * duration)
    raw = []
    base_f = 220.0
    pwm_f = 880.0

    for i in range(total):
        t = i / SAMPLE_RATE
        rotor = 0.45 * math.sin(2 * math.pi * base_f * t) + 0.30 * math.sin(2 * math.pi * (base_f * 2) * t) + 0.15 * math.sin(2 * math.pi * (base_f * 3) * t)
        inverter = 0.18 * math.sin(2 * math.pi * pwm_f * t) * (1.0 + 0.12 * math.sin(2 * math.pi * 18.0 * t))
        raw.append((rotor + inverter + random.uniform(-0.02, 0.02)) * 0.75)

    samples = make_circular_loop(raw, fade_seconds=0.25)
    write_wav("engine_drive.wav", samples)

# 6. TURN STRAIN (6s True Seamless Loop)
def gen_turn_strain():
    duration = 6.25
    total = int(SAMPLE_RATE * duration)
    raw = []
    prev_noise = 0.0

    for i in range(total):
        t = i / SAMPLE_RATE
        white = random.uniform(-0.6, 0.6)
        prev_noise = prev_noise * 0.90 + white * 0.10
        strain_hum = 0.18 * math.sin(2 * math.pi * 260.0 * t) * (1.0 + 0.2 * math.sin(2 * math.pi * 8.0 * t))
        raw.append((prev_noise * 0.5 + strain_hum) * 0.65)

    samples = make_circular_loop(raw, fade_seconds=0.25)
    write_wav("turn_strain.wav", samples)

# 7. ENGINE START
def gen_engine_start():
    duration = 1.8
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        thud = math.sin(2 * math.pi * 65.0 * t) * (math.exp(-t * 8.0) if t < 0.4 else 0.0) * 0.7
        spool_env = (t / 1.1) if t < 1.1 else math.exp(-(t - 1.1) * 3.0)
        freq = 70.0 + (550.0 * (t / duration) ** 2.2)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        turbine = (math.sin(phase) + 0.25 * math.sin(2 * phase)) * spool_env * 0.6
        samples.append((thud + turbine) * 0.85)
    write_wav("engine_start.wav", samples)

# 8. ENGINE IDLE (6s True Seamless Loop)
def gen_engine_idle():
    duration = 6.25
    total = int(SAMPLE_RATE * duration)
    raw = []
    f_sub = 55.0
    f_mid = 110.0

    for i in range(total):
        t = i / SAMPLE_RATE
        throb = 1.0 + 0.15 * math.sin(2 * math.pi * 4.0 * t)
        sub = 0.60 * math.sin(2 * math.pi * f_sub * t) * throb
        mid = 0.25 * math.sin(2 * math.pi * f_mid * t)
        buzz = 0.08 * math.sin(2 * math.pi * (f_sub * 4) * t)
        raw.append((sub + mid + buzz) * 0.8)

    samples = make_circular_loop(raw, fade_seconds=0.25)
    write_wav("engine_idle.wav", samples)

def main():
    print(f"Synthesizing Seamless Audio Pack into:\n-> {SFX_DIR}")
    ensure_dir(SFX_DIR)
    gen_horn()
    gen_ui_blip()
    gen_relay_switch()
    gen_indicator_tick()
    gen_engine_drive()
    gen_turn_strain()
    gen_engine_start()
    gen_engine_idle()
    print("[*] Complete! All files generated with circular crossfades.")

if __name__ == "__main__":
    main()