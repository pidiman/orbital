# Procedural ambience

`scripts/ambient_music.gd` is a non-spatial AudioStreamPlayer using
AudioStreamGenerator at 22,050 Hz with a 0.2-second buffer. It fills packed stereo
buffers in batches. No audio assets or gameplay RNG are used.

- Three low sine voices with a faint third harmonic, independent slow breathing,
  and stereo spread. Random chord changes every 24–48 seconds glide gradually.
- Gentle chord-related high notes every 5–14 seconds, with soft attacks,
  exponential decay and randomized stereo placement.
- Very quiet nine-second resonance sweeps, spaced 28–55 seconds apart.
- A four-second startup fade and conservative layer amplitudes keep it background.

Settings → Music defaults ON. Volume defaults to 30% (range 0–100%). Preferences
are stored in the `audio` section of `user://orbital-client.cfg`; gameplay saves
are unchanged. Turning music off stops the player and synthesis. Turning it on
continues the evolving session. Engine hard-pause freezes playback and synthesis,
including when save dialogs pause the game.

Verification: `tests/ambient_music_playthrough.gd` checks an actual mixed audio
signal, toggles, gain, paused playback and synthesis, resume, preference reload,
and bounded output across over a minute of generated audio. On the test machine,
68 seconds of samples synthesized in about 1.26 seconds (~1.9% of one CPU core).
This is a synthesis microbenchmark, not a guarantee on every device. The default
mixed level measured about -42 dB during the startup fade. Musical feel still
benefits from a listening pass on the player's speakers/headphones.
