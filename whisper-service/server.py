"""FastAPI server for Whisper transcription service."""

import os
import tempfile
from pathlib import Path

import yaml
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse

from transcribe import get_transcriber

# Load config
config_path = Path(__file__).parent / "config.yaml"
with open(config_path) as f:
    config = yaml.safe_load(f)

port_override = os.getenv("BABBLE_WHISPER_PORT")
if port_override:
    try:
        config["server"]["port"] = int(port_override)
    except ValueError:
        pass

app = FastAPI(title="Babble Whisper Service")

# Initialize transcriber with configured model
transcriber = get_transcriber(config["model"]["name"])


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "ready",
        "model": config["model"]["name"],
        "model_loaded": transcriber.is_loaded,
    }


@app.post("/warmup")
async def warmup():
    """
    Preload the model by running a minimal transcription.
    This triggers model download if not cached, and loads it into memory.
    Returns immediately if model is already loaded.
    """
    if transcriber.is_loaded:
        return {"status": "already_loaded", "model": config["model"]["name"]}

    # Trigger model loading by calling ensure_loaded which does actual loading
    transcriber.load_model()

    return {"status": "loaded", "model": config["model"]["name"]}


@app.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    language: str = Form(default=None),
):
    """
    Transcribe uploaded audio file.

    Args:
        audio: Audio file (wav, m4a, mp3, etc.)
        language: Optional language code (default from config)

    Returns:
        JSON with transcription result
    """
    # Use configured language if not specified
    lang = language or config["model"]["language"]

    # Validate file type
    allowed_extensions = {".wav", ".m4a", ".mp3", ".flac", ".ogg"}
    file_ext = Path(audio.filename or "").suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file_ext}. Allowed: {allowed_extensions}",
        )

    # Save to temp file
    with tempfile.NamedTemporaryFile(suffix=file_ext, delete=False) as tmp:
        content = await audio.read()
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        result = transcriber.transcribe(tmp_path, language=lang)
        return JSONResponse(content=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up temp file
        tmp_path.unlink(missing_ok=True)


def main():
    """Run the server."""
    import uvicorn

    uvicorn.run(
        app,
        host=config["server"]["host"],
        port=config["server"]["port"],
        log_level="info",
    )


if __name__ == "__main__":
    main()
