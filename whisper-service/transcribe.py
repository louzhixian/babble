"""MLX Whisper transcription module."""

import time
from pathlib import Path
from typing import Optional

import mlx_whisper


class Transcriber:
    """Handles MLX Whisper model loading and transcription."""

    def __init__(self, model_name: str = "mlx-community/whisper-large-v3-turbo"):
        self.model_name = model_name
        self._model_loaded = False
        self._last_used: float = 0

    def ensure_loaded(self) -> None:
        """Ensure model is loaded (lazy loading on first use)."""
        if not self._model_loaded:
            # mlx_whisper loads model on first transcribe call
            self._model_loaded = True
        self._last_used = time.time()

    def transcribe(
        self,
        audio_path: Path,
        language: str = "zh",
    ) -> dict:
        """
        Transcribe audio file to text.

        Args:
            audio_path: Path to audio file (wav, m4a, mp3)
            language: Language code for transcription

        Returns:
            dict with keys: text, segments, duration, processing_time
        """
        self.ensure_loaded()

        start_time = time.time()

        result = mlx_whisper.transcribe(
            str(audio_path),
            path_or_hf_repo=self.model_name,
            language=language,
        )

        processing_time = time.time() - start_time

        return {
            "text": result.get("text", "").strip(),
            "segments": result.get("segments", []),
            "language": result.get("language", language),
            "processing_time": round(processing_time, 3),
        }

    @property
    def idle_seconds(self) -> float:
        """Seconds since last use."""
        if self._last_used == 0:
            return 0
        return time.time() - self._last_used

    def unload(self) -> None:
        """Unload model to free memory."""
        # mlx_whisper doesn't have explicit unload, but we can reset state
        self._model_loaded = False
        self._last_used = 0


# Global instance
_transcriber: Optional[Transcriber] = None


def get_transcriber(model_name: str = "mlx-community/whisper-large-v3-turbo") -> Transcriber:
    """Get or create global transcriber instance."""
    global _transcriber
    if _transcriber is None:
        _transcriber = Transcriber(model_name)
    return _transcriber
