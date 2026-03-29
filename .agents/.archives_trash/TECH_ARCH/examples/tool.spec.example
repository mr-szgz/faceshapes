# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for faceless — single-file Windows exe
# Build: pyinstaller faceless.spec

a = Analysis(
    ["faceless/__main__.py"],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="faceless",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    console=True,       # CLI tool — keep console window
    onefile=True,
)
