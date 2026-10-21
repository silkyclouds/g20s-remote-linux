# Adding an app

The layer is app agnostic. Anything with a window works with the app switcher, Home and the remote's keys. What an app needs on top, to get the
keyboard and voice search, depends on what kind of app it is. This page lists the four places an app can plug in, from simplest to most specific,
and what the three apps of the author's setup (Steam Big Picture, Plezy, VacuumTube) use.

## 1. Find your app's window class

```bash
qdbus org.kde.KWin /KWin org.kde.KWin.queryWindowInfo
```

Click the app's window. The answer has `resourceClass` and `desktopFileName`: this is the name every setting below matches against (case insensitive, "contains").
Examples: `plezy`, `steam`, `rocks.shy.vacuumtube`.

## 2. Home button

`~/.config/g20/g20.conf`:

```ini
G20_HOME_MATCH=plezy     # part of the window class: the window to raise
G20_HOME_PROC=plezy      # process name, to know whether the app runs
G20_HOME_CMD=plezy       # command that starts it when it does not run
```

Only one app is "home". Steam is always one press away through the app switcher, and the author's Home is Plezy.

## 3. The keyboard opens by itself when OK lands on a text field

* **Wayland apps** (Qt, GTK, Plezy, Electron with Wayland text input) need nothing: KWin tells the daemon that a text field has the focus.
* **Steam** needs its local debug port: `touch ~/.local/share/Steam/.cef-enable-remote-debugging`, then restart Steam.
* **An Electron or Chromium app** needs a debug port. Start it with `--remote-debugging-port=9223` and list it in the configuration:

  ```ini
  G20_CDP_PORTS=vacuumtube:9223,otherapp:9224
  ```

  The name before the colon must be part of the window class. For a Flatpak app, put the flag after the app id in its launch command:
  `flatpak run rocks.shy.VacuumTube --remote-debugging-port=9223`. The port listens on localhost only.

`G20_AUTO_KEYBOARD=0` turns the automatic opening off.

## 4. The Mic key: open the app's search first

The Mic key runs `bin/g20-micro` with the class of the window in front. If your app needs a step before its search field exists, add a line to the `case`:

```bash
case "$cls" in
  *plezy*) ydotool key 29:1 33:1 33:0 29:0; sleep 0.8 ;;   # Ctrl+F opens Plezy's search page
  *myapp*) ydotool key 15:1 15:0; sleep 0.5 ;;              # whatever key opens the app's search
esac
```

Key numbers are Linux input codes (`ydotool key CODE:1 CODE:0`; Ctrl is 29). Apps that open the search field on their own need no line.

## 5. Where the voice text goes

After you speak, `type_text()` in `switcher/g20-switcher-server` puts the words in the app, through the first of these that applies:

1. **Steam**: the page "Steam Big Picture" is reached through port 8080. Its search box (`input[type=search]`) is focused, selected, filled with the words, and Enter is sent.
2. **An app in `G20_CDP_PORTS`**: the words are inserted through the Chrome DevTools Protocol (`Input.insertText`), replacing the field's content, then Enter.
   If the app needs more than a focused field (a search page to open, a route to visit), add it in `cdp_target()`: it returns the port, a page title filter and a JavaScript expression that prepares the field.
3. **An app with its own voice search** (`G20_NATIVE_VOICE_APPS`): nothing is typed and no keyboard opens. The Mic key reaches the app's search page and presses its microphone button (`yttv_native_voice()` for YouTube for TV).
4. **Any other app**: Ctrl+A then Ctrl+V into the field that has the focus, then Enter. Nothing is typed when no text field has the focus, so a voice search can never press Enter on a poster.

To try your app end to end without the remote: `curl -X POST http://127.0.0.1:48765/api/voice/start`, speak, and watch `journalctl --user -u g20-switcher -f`.

## What the author's setup uses

| App | Class | Steps used |
|---|---|---|
| Steam Big Picture | `steam` | debug port file (3), Steam's search box (5.1) |
| Plezy | `plezy` | Wayland text input (3), Ctrl+F in `g20-micro` (4), paste (5.3) |
| VacuumTube | `rocks.shy.vacuumtube` | `--remote-debugging-port=9223` (3), debug port typing (5.2) |

## Sharing it

A pull request that adds an app should change as little as possible: one line in `g20-micro` or one entry in `cdp_target()`, and a row in the table of the README.
Say which app version you tested.
