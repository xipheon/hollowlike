# Localization

All the text the player sees lives here, in gettext `.po` files that Godot loads
natively: one folder per language, one file per feature.

```
localization/
  en/
    ui.po        menus, HUD, boss / ability / skin names
    dialog.po    character dialogue: lines (DLG_) and names (NPC_)
  fr/
    ui.po
    ...
```

Each entry is a **key** and the text it shows:

```
#. A note for translators: where it appears, what {placeholders} mean.
msgid "UI_MENU_START"
msgstr "Start"
```

Keys start with their feature (`UI_`; `DLG_` and `NPC_` for dialogue), so files never
clash. Keep `{named}` placeholders as they are; they can move anywhere in the
sentence. Poedit (free) or any text editor can edit these files.

## Where the keys are used

- **Scenes:** a Label's or Button's text is just the key (`UI_MENU_START`), and
  Godot shows its translation. In the editor, the 2D view's *Preview
  Translation* menu shows the text instead of the keys.
- **Scripts:** text built in code uses `tr("UI_...")`, with `.format({...})` for
  placeholders (hud.gd, room.gd). Text that doesn't come from a key, like the
  debug-only lines, stays as written.

## Adding text

1. Add the key and its English to the feature's file, `en/<feature>.po`, with
   a `#.` note.
2. Use the key in the scene, or `tr("KEY")` in the script.
3. Add it to the other languages' files (until then they show the English).

The tests check that every `UI_` key the scenes and scripts use has English.

## Adding a language

1. Make its folder, named by its code (`fr`, `de`, `pt_BR`...).
2. Copy each `.po` from `en/` into it, change `"Language: en\n"` at the top to
   the new code, and translate every `msgstr` (leave the `msgid` keys alone).
3. Register each file in Project Settings > Localization > Translations
   (the tests fail if one isn't).

It then shows up in the Language button of the main and pause menus. The
choice is saved in `user://settings.cfg`; until one is picked, the game uses
the computer's language if there's a translation for it, otherwise English
(`internationalization/locale/fallback`).

Languages in other scripts (Chinese, Japanese, Arabic...) need a font with
their characters, set as a fallback in the project theme; right-to-left ones
also need the Controls' layout direction.

## Adding a feature file

Make `<language>/<feature>.po` in each language folder with its own key prefix,
and register each one. Godot merges every file for a language, so keys only
need to be unique across them.
