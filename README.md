# Dusk

Menu bar app that dims every connected display on a hotkey, and restores them on the hotkey again or any mouse click.

- **Default hotkey:** ⌃⌥⌘D. To change it, choose **Hotkey…** in the menu.
- **Dim To:** Black, 10%, 25% or 50% of the current brightness.
- Every display is dimmed through its gamma table, which macOS resets if Dusk quits or crashes. Displays that support
  it (built-in, Apple, LG UltraFine) also get their real backlight lowered through the private DisplayServices
  framework, since some backlights stay visibly lit even at 0.
- Needs no Accessibility permission: the hotkey uses Carbon `RegisterEventHotKey`, and clicks are caught by an
  `NSEvent` global mouse monitor.

```sh
make test      # unit tests
make app       # build/Dusk.app
make install   # copy to /Applications and launch
```

## License

MIT, see [LICENSE](LICENSE).
