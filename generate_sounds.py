import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100

def generate_wav(filename, duration, gen_sample_fn):
    num_samples = int(duration * SAMPLE_RATE)
    audio = []
    
    for i in range(num_samples):
        t = i / float(SAMPLE_RATE)
        sample = gen_sample_fn(t, i, num_samples)
        
        # Clamp exactly to 16-bit range
        sample = max(-32768, min(32767, int(sample * 32767.0)))
        audio.append(struct.pack('<h', sample))
        
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(b''.join(audio))
    print(f"Generated {filename}")

# --- Sound Generators ---

def s_fireball(t, i, max_i):
    # A quick frequency sweep down (pew) with some noise
    envelope = max(0, 1.0 - (i / max_i)) ** 2
    freq = 800 * math.exp(-t * 15) + (random.random() * 200 * envelope)
    return math.sin(2 * math.pi * freq * t) * envelope * 0.6

def s_pop(t, i, max_i):
    # Enemy death pop - quick bouncy chirp
    envelope = max(0, 1.0 - (i / max_i)) ** 3
    freq = 400 + 600 * math.sin(t * 50)
    return (1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0) * envelope * 0.5

def s_hit(t, i, max_i):
    # Player taking damage - crunchy noise burst
    envelope = max(0, 1.0 - (i / max_i))
    noise = random.random() * 2.0 - 1.0
    return noise * envelope * 0.8

def s_shield(t, i, max_i):
    # Metallic clang / forcefield
    envelope = math.sin((i / max_i) * math.pi)
    freq = 600 * math.exp(-t * 5)
    return math.sin(2 * math.pi * freq * t + math.sin(t * 100)) * envelope * 0.5

def s_heal(t, i, max_i):
    # Shimmering chime
    envelope = max(0, 1.0 - (i / max_i))
    return (math.sin(2 * math.pi * 600 * t) + math.sin(2 * math.pi * 800 * t)) * envelope * 0.4

def s_explode(t, i, max_i):
    # Deep rumble
    envelope = max(0, 1.0 - (i / max_i)) ** 1.5
    noise = random.random() * 2.0 - 1.0
    freq = max(20, 100 * math.exp(-t * 3))
    rumble = math.sin(2 * math.pi * freq * t)
    return (noise * 0.5 + rumble * 0.5) * envelope * 0.9

def s_wave(t, i, max_i):
    # Rising alarm / gong
    envelope = math.sin((i / max_i) * math.pi)
    freq = 200 + t * 50
    return (1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0) * envelope * 0.4

def main():
    os.makedirs('assets/audio', exist_ok=True)
    generate_wav('assets/audio/fireball.wav', 0.25, s_fireball)
    generate_wav('assets/audio/pop.wav', 0.15, s_pop)
    generate_wav('assets/audio/hit.wav', 0.3, s_hit)
    generate_wav('assets/audio/shield.wav', 0.4, s_shield)
    generate_wav('assets/audio/heal.wav', 0.6, s_heal)
    generate_wav('assets/audio/explode.wav', 0.8, s_explode)
    generate_wav('assets/audio/wave.wav', 1.2, s_wave)

if __name__ == "__main__":
    main()
