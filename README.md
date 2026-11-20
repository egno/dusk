# Dusk

Menu bar app that dims every connected display on a hotkey, and restores them on the hotkey again or any mouse click.

- **Default hotkey:** ⌃⌥⌘D. To change it, choose **Hotkey…** in the menu.
- **Dim To:** Black, 10%, 25% or 50% of the current brightness.
- **Hardware backlight** (built-in and Apple displays) through the private DisplayServices framework. Other displays
  are dimmed through their gamma tables, which macOS resets if Dusk quits or crashes.
- Needs no Accessibility permission: the hotkey uses Carbon `RegisterEventHotKey`, and clicks are caught by an
  `NSEvent` global mouse monitor.

```sh
make test      # unit tests
make app       # build/Dusk.app
make install   # copy to /Applications and launch
```
