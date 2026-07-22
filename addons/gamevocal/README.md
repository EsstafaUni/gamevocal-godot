# GameVocal Godot Plugin

Connects Godot projects to GameVocal and imports dialogue audio, localization, lip-sync data, and integration metadata.

## Setup

1. Copy the `addons/gamevocal` folder to your Godot project's `addons` folder.
2. Enable the plugin in Project Settings -> Plugins.
3. Configure your GameVocal API Key (stored securely in editor settings, not project files).

## Supported Godot Versions

- Godot 4.7+ (Fully compatible with Godot 4.7)

## Character Mapping & Lip-Sync

GameVocal provides a AAA-grade lip-sync system out of the box, perfectly synchronized to your audio playback. It uses ARKit52 blendshapes and includes an auto-mapping feature to wire up your custom 3D models instantly.

### Quick Start
1. Add a `GameVocalCharacter` node to your scene.
2. In the Inspector, assign your 3D model with blendshapes to the **Target Mesh** slot.
3. Assign an `AudioStreamPlayer`, `AudioStreamPlayer2D`, or `AudioStreamPlayer3D` to the **Audio Player** slot.
4. Check the **Auto Map Blendshapes** box in the Inspector. This will intelligently scan your 3D model and map its custom blendshapes to the ARKit 52 standard using fuzzy matching (e.g. `Mouth_Smile_Left` -> `mouthSmileLeft`).
5. Play your synced audio using code:
   ```gdscript
   $GameVocalCharacter.play_dialogue("res://audio/rita_joe.ogg", "res://lipsync/rita_joe.json")
   ```

## License

Copyright (c) 2026 GameVocal (MIT License)
