# Vendored Godot++ template

Source: https://github.com/nikoladevelops/godot-plus-plus at commit `b5ecd5cf4f3bf647bfc2fcab25bec07f6a3bc709` (retrieved 2026-10-07). Original LICENSE retained. This folder is a native development scaffold, not a compiled Codis3D backend.

The upstream `godot-cpp` submodule contents are not vendored. To initialize them outside the original nested Git checkout, clone `https://github.com/godotengine/godot-cpp.git` into `native/godot-cpp` using a Godot 4.4-compatible branch and configure the API version to 4.4 with `python setup.py`. Select a separate test project so generated sample manifests do not enter the standalone workspace. Follow the upstream README for SCons toolchains and Android/iOS/Web compilation. The original workflow lives under `native/.github/workflows` as reference; GitHub does not execute workflows in nested directories. App export CI is at the repository root.
