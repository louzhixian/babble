# -*- mode: python ; coding: utf-8 -*-

import os
import shutil
from PyInstaller.utils.hooks import collect_data_files, collect_all

block_cipher = None

# Find ffmpeg binary (required by mlx-whisper for audio processing)
ffmpeg_path = shutil.which('ffmpeg')
if not ffmpeg_path:
    raise RuntimeError("ffmpeg not found. Please install ffmpeg (brew install ffmpeg)")

# Collect all data files from mlx (includes .metallib shader files)
mlx_datas, mlx_binaries, mlx_hiddenimports = collect_all('mlx')

# Collect mlx_whisper data files
mlx_whisper_datas = collect_data_files('mlx_whisper')

a = Analysis(
    ['server.py'],
    pathex=[],
    binaries=[(ffmpeg_path, '.')] + mlx_binaries,
    datas=[('config.yaml', '.')] + mlx_datas + mlx_whisper_datas,
    hiddenimports=[
        'mlx',
        'mlx.core',
        'mlx._reprlib_fix',
        'mlx.nn',
        'mlx.nn.layers',
        'mlx.optimizers',
        'mlx_whisper',
        'mlx_whisper.audio',
        'mlx_whisper.decoding',
        'mlx_whisper.load_models',
        'mlx_whisper.tokenizer',
        'mlx_whisper.transcribe',
        'uvicorn.logging',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'uvicorn.server',
        'uvicorn.config',
        'soundfile',
        'numpy',
    ] + mlx_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='whisper-service',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)
