class_name GameVocalLocalizationLoader
extends Node

# Helps integrate fetched GameVocal translations with Godot's TranslationServer

static func register_translation_file(path: String):
	var translation = ResourceLoader.load(path)
	if translation is Translation:
		TranslationServer.add_translation(translation)
		print("[GameVocal] Registered translation: ", path)
