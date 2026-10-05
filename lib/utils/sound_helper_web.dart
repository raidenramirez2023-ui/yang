import 'package:web/web.dart' as web;
import 'package:flutter/services.dart';

/// Web implementation: Synthesizes a crisp, pleasant restaurant bell chime (Ding-Dong 🔔)
/// using the Web Audio API without requiring any external audio files.
void playOrderReadySound() {
  try {
    final ctx = web.AudioContext();
    final now = ctx.currentTime;

    // Tone 1: Crisp high bell chime (880 Hz - A5)
    final osc1 = ctx.createOscillator();
    final gain1 = ctx.createGain();
    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(880, now);
    gain1.gain.setValueAtTime(0.35, now);
    gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.45);

    // Tone 2: Harmonic response chime (1318.5 Hz - E6)
    final osc2 = ctx.createOscillator();
    final gain2 = ctx.createGain();
    osc2.type = 'sine';
    osc2.frequency.setValueAtTime(1318.5, now + 0.12);
    gain2.gain.setValueAtTime(0.32, now + 0.12);
    gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.65);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.12);
    osc2.stop(now + 0.65);
  } catch (_) {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
