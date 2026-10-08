# Codis3D

A Godot 4.4.1 prototype of a mobile-first 3D creation workspace. Open `project.godot` and press F6 on the workspace scene, or F5 to launch the app. The enabled editor plugin adds **Project > Tools > Open Codis3D workspace**.

Implemented: primitive creation, bounding-box selection, ground-plane move, Y rotation, uniform scale, duplication/deletion, triangle subdivision, a screen-space radial inflate brush, 24-step undo/redo, transform keyframes with interpolation, JSON workspace persistence, multi-format mesh export, and viewport PNG capture. Controls use icon buttons with tooltips and 48px minimum targets. The object list hides below 760px. Mouse: drag to orbit, right drag to pan, wheel to zoom. Touch: one finger uses the selected tool; two fingers orbit and pinch. Save/load use a single app-private workspace; export paths appear in the status bar. Mobile file sharing is not implemented.

## Task workspaces

Use the four icon tabs at the top: **▣ Modeling**, **✎ Sculpting**, **▶ Animation**, and **▧ Rendering**. The adjacent label identifies the active workspace. All workspaces share objects, selection, animation tracks, and undo history; switching pauses playback and remembers each workspace's orbit view and tool in `user://workspace_layout.cfg`.

- Modeling: primitives, duplication/deletion, transforms and subdivision.
- Sculpting: inflate brush, radius/strength controls and subdivision. Drag up to inflate and down to deflate.
- Animation: transform tools, timeline, playback and keyframe insertion.
- Rendering: clean selection display, light energy, camera field of view, background color and grid visibility; use the PNG icon to capture the viewport. These scene settings are shared for the current session and are not stored in workspace JSON.

The timeline appears in Animation, the object list hides in Rendering and on narrow screens, and common save/load/export/undo controls remain available. Rendering uses the existing Godot real-time renderer. These task layouts do not add new rendering engines, rigging or simulation systems.

## Mesh exports

Click the workspace's **⇧** icon, or use **Project > Tools > Codis3D: Export scene meshes** in Godot. Editor exports gather MeshInstance3D nodes from the edited scene; selecting a parent includes its mesh descendants. Runtime workspace objects are exported from the running app.

Choose **OBJ**, **STL**, **PLY**, **GLB**, or **glTF**, then choose a destination or browse for a file. Options include selected objects only, apply world transforms, positive global scale, and Y-up/Z-up conversion. Disabling world transforms exports each object in its local coordinates; objects can overlap. glTF uses standard Y-up. Existing destination files prompt before replacement. Separate glTF can also write a companion `.bin` and texture files; keep them alongside the `.gltf` file.

OBJ supports optional normals and available UVs, with separate object names; it does not write MTL materials. STL supports binary or ASCII. PLY exports ASCII vertices and triangle faces. GLB/glTF preserve mesh surface materials and available attributes through Godot's GLTFDocument exporter; temporary selection highlight materials are excluded. Exporting does not change live objects. All formats currently export triangle meshes at the current pose, without animation tracks, rigs, cameras or lights. FBX, USD and Alembic exports are not implemented. STL/PLY have no units metadata, so choose scale to match the importing application's units.

The dialog scrolls on smaller screens. The default destination is `user://`; mobile filesystem access remains limited by the operating system. On Web this is app storage, and browser downloads are not yet implemented.

This is **not a complete Blender clone**. There is no vertex/edge/face selection, extrusion, UV/material editor, NURBS, Bézier editing, dynamic topology, multiresolution hierarchy, bone rigging, IK, shape keys, NLA, fluid/smoke/fire/cloth simulation, tracking, compositing, video editor, or Grease Pencil. PNG capture uses Godot's real-time Compatibility renderer; it is not Cycles or Eevee. Sculpting affects projected vertices including back-facing vertices and is a basic brush, not a production sculpting system.

## Builds

`.github/workflows/build.yml` imports and tests the project, then exports Windows, Linux, macOS, Web, and a debug-signed Android APK. Android has arm64 and x86_64 targets. Artifacts are desktop development builds and a development APK, not store-ready packages. The project and workflow are published at https://github.com/CodisGames1212/Codis3D. Download platform packages from the Artifacts section of a successful run at https://github.com/CodisGames1212/Codis3D/actions. Pushes and manual workflow dispatches start builds; CI uses Godot 4.4.1.

iOS has an export preset but requires a macOS machine, Xcode, an Apple development team and signing setup. iOS CI/store release is not configured. Platform compatibility is a target, not a verified claim; physical-device testing remains necessary. Web files must be served over HTTP.

Run integration checks with `godot --headless --path . --script tests/workspace_test.gd` and `godot --headless --path . --script tests/export_test.gd`. Export checks cover file structures, transforms, normals/UVs, STL encodings, glTF re-imports, error paths and dialog format controls.

## Native template and add-ons

`native/` vendors the requested [Godot++ template](https://github.com/nikoladevelops/godot-plus-plus) with its Unlicense and original tools. It is excluded from Godot imports using `.gdignore`. Its sample extension is not loaded by the app. See `native/UPSTREAM.md` for provenance and setup; the native backend is reserved for future high-performance operations.

Blender Python add-ons require Blender's `bpy` runtime and cannot be directly loaded in Godot. OBJ export currently provides geometry exchange with Blender. A future desktop bridge could run an installed Blender in background mode for selected add-on workflows; there is no such bridge or embedded Python runtime in this version. Mobile does not gain Blender add-on support from the export presets.
