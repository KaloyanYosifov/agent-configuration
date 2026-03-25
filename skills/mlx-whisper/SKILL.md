---
name: mlx-whisper
description: Local speech-to-text with MLX Whisper. Use whenever you see an audio file and have to get a transcription.
---

# MLX Whisper

Local speech-to-text using Apple MLX, optimized for Apple Silicon Macs.

## Quick Start

```bash
mlx_whisper /path/to/audio.mp3 --model mlx-community/whisper-large-v3-turbo
```

## Common Usage

```bash
# Transcribe to text file
mlx_whisper audio.m4a -f txt -o ./output

# Transcribe with language hint
mlx_whisper audio.mp3 --language en --model mlx-community/whisper-large-v3-turbo

# Generate subtitles (SRT)
mlx_whisper video.mp4 -f srt -o ./subs

# Translate to English
mlx_whisper foreign.mp3 --task translate
```

## Models (download on first use)

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| mlx-community/whisper-tiny | ~75MB | Fastest | Basic |
| mlx-community/whisper-small-mlx | ~470MB | Medium | Better |

## Notes

- Requires Apple Silicon Mac (M1/M2/M3/M4)
- Models cache to `~/.cache/huggingface/`
- Default model is `mlx-community/whisper-tiny`; use `--model whisper-small-mlx` if user requests more 
