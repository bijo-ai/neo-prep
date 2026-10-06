# neo-prep

A small Windows script that force-closes the apps Neo Browser asks you to quit,
so you can get into your exam or test without hunting through Task Manager.

Double-click the **Neo Prep** shortcut, accept one UAC prompt, and it closes
every app on its lists, then shows what it closed and anything it couldn't.
It does **not** open Neo Browser for you (Neo rejects launches from scripts).
Open Neo yourself once it says you're done.

If Neo still complains, paste its message into the Neo Prep window. Neo Prep
closes those apps too and remembers them for next time.

> **Save your work first.** Apps are force-closed, so unsaved documents, open
> chats and browser tabs that don't restore will be lost.
>
> **Exit terminals and AI coding tools first**, such as Claude Code, which runs
> as `claude` and `node`. If you start Neo Prep from inside one of them, it will
> close itself partway through.

## Install

1. Download or clone this repo to a permanent folder, e.g. `C:\Projects\neo-prep`.

   > **Downloaded a zip?** Windows may block `.ps1` files that came from the
   > internet. Before extracting, right-click the zip > **Properties** > tick
   > **Unblock** > **OK**. If you already extracted it, open PowerShell in the
   > folder and run:
   >
   > ```powershell
   > Get-ChildItem -Recurse | Unblock-File
   > ```

2. Open PowerShell in that folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   This puts a **Neo Prep** shortcut on your desktop with a generic Windows icon.
   If you move the folder later, run `install.ps1` again.

To run it without the shortcut:

```powershell
powershell -ExecutionPolicy Bypass -File .\neo-prep.ps1
```

## The app lists

Neo Prep reads two lists from its folder and closes everything on both:

| File               | What it is                                                            |
|--------------------|-----------------------------------------------------------------------|
| `apps.default.txt` | The built-in list. Ships with neo-prep and may change when you update. |
| `apps.local.txt`   | Your additions. Created empty on first run, ignored by git, never overwritten by updates. |

Put your own apps in `apps.local.txt`, not `apps.default.txt`. That way
updating neo-prep never loses them. (To stop Neo Prep closing a default app,
delete or comment out its line in `apps.default.txt`. You'll need to do that
again after updating.)

Both files use the same format:

- One process name per line, **without `.exe`**.
- Lines starting with `#` are comments; blank lines are ignored.
- Wildcards work: `WhatsApp*` matches `WhatsApp` and `WhatsApp.Root`.

## Adding apps

There are two ways to add apps, plus editing `apps.local.txt` by hand. Both
ways use the same rules:

- `.exe` is removed, and a path like `C:\...\Foo.exe` becomes `Foo`.
- Each name becomes a wildcard **family**: `bravecrashhandler` is saved as
  `bravecrashhandler*`, which also catches its helper processes.
- Names already covered by a list are skipped. For example, `bravecrashhandler`
  is skipped when `brave*` is already on the list.
- Names that would match Windows itself, PowerShell, your terminal or Neo
  Browser are refused, and so are names shorter than 3 characters.

### 1. Paste what Neo says (easiest)

After its summary, Neo Prep keeps its window open and asks:

```
Did Neo still complain? Paste the app names it listed, or press Enter to finish.
```

Open Neo. If it still lists apps to close, copy its message, paste the whole
thing into the Neo Prep window (right-click or `Ctrl+V`) and press Enter. Neo
Prep picks out every `something.exe` name in the text, adds the new ones to
`apps.local.txt`, and closes them right away. Repeat until Neo is happy, then
press Enter on an empty line to finish.

### 2. `-Add` from the command line

```powershell
powershell -ExecutionPolicy Bypass -File .\neo-prep.ps1 -Add bravecrashhandler.exe Slack
```

Names can be separated by spaces or commas, with or without `.exe`. This only
updates `apps.local.txt` and shows what it added. It doesn't close anything and
doesn't ask for admin rights.

### Finding a process name yourself

1. Press `Ctrl+Shift+Esc` to open Task Manager.
2. Go to the **Details** tab.
3. Find the app in the **Name** column, e.g. `Spotify.exe`.
4. Add it with `-Add Spotify`, or put `Spotify` on its own line in `apps.local.txt`.

The friendly names on the **Processes** tab often differ from the real process
names, so use **Details**.

> **Tip:** if Neo lists a helper process such as `bravecrashhandler.exe`, use
> the app's name with a `*` (e.g. `brave*`) to close the whole family of
> processes (`brave`, `bravecrashhandler`, `BraveUpdate`, ...) in one line.

## Files

| File               | Purpose                                                   |
|--------------------|-----------------------------------------------------------|
| `neo-prep.ps1`     | Elevates, closes the listed apps, shows a summary; `-Add` |
| `apps.default.txt` | Built-in list of process names to close                   |
| `apps.local.txt`   | Your additions (created on first run, not in git)         |
| `install.ps1`      | Creates the desktop shortcut                              |

## Disclaimer

neo-prep only closes apps running on your own computer, the same thing you
could do by hand in Task Manager. It doesn't modify, bypass or interfere with
Neo Browser or any of its checks; it just saves you the clicking.

This project is not affiliated with, endorsed by, or connected to Neo Browser
or iamneo.

## License

MIT. See [LICENSE](LICENSE).
