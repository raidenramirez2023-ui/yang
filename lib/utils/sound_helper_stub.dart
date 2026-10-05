import 'package:flutter/services.dart';

/// Native fallback for playing the order ready alert sound.
void playOrderReadySound() {
  try {
    SystemSound.play(SystemSoundType.alert);
  } catch (_) {}
}
