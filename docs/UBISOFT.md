# Ubisoft Connect

Ubisoft's PC games start through Ubisoft Connect, Ubisoft's launcher: a Steam
copy of Far Cry 3 or Far Cry 4 hands over to it, and its game starter starts
the game again. Madeira runs the launcher itself, in the game's Wine session,
as Windows would. Nothing about sign-in, ownership or licences is changed or
skipped: the launcher signs in to Ubisoft's servers and starts the game as it
does on Windows. What Madeira adds is what the launcher and the games need
from Windows that Wine on iOS did not provide (willfaust/Madeira#189 shows the
same failures for Trackmania).

Tested: Ubisoft Connect (client 175.0.13393), Far Cry 3 and Far Cry 4, Steam
copies started through Madeira Dock, on an iPhone18,2 (iOS 27.2, 2026-11-10):
both games sign in through Ubisoft Connect and play.

## Source

- `build/ntdll-unix/virtual_ios.c`:
  - `ios_self_write`: a program's `WriteProcessMemory` into its own memory, done
    in ntdll (the server has no task port for a pseudo-process and refused
    every such write; the launcher's hook installer and Far Cry 4's FC64.dll
    then ended with 0xdeadc0de, "Error at hooking");
  - the hook zone: free address space above a 64-bit process's ntdll for hook
    trampolines (`env.MADEIRA_X64_HOOK_ZONE`);
  - `ios_ubi_cef_patch`: the two-byte libcef.dll change that keeps the
    launcher browser's Chromium switches, for the builds it lists;
  - the code-buffer rules for a game behind a launcher
    (`env.MADEIRA_POOL_CARVE_MERGE`, `env.MADEIRA_POOL_CODE_FOREGROUND`).
- `build/ntdll-unix/process_ios.c`: the launcher browser's command line
  (`ubi_cef_kind`, `ubi_cef_cmdline`), and the teardown of a process another
  process ends (`env.MADEIRA_KILL_REAP`).
- `wine` (`dlls/ntdll/unix/sync.c`, `dlls/ntdll/sync.c`, `dlls/dxdiagn`): I/O
  completions during a non-alertable sleep (`env.MADEIRA_SLEEP_KERNEL_APC`), a
  bounded re-check of infinite waits on an address in 32-bit programs
  (`env.MADEIRA_WOA_RECHECK`), and a DxDiag provider that initialises without
  DirectShow.
- `build/hidpad/hidpad_ids.h`: the Xbox 360 controller identity
  (`env.MADEIRA_PAD_MODE = xbox360`).
- `app/Madeira/DockInstallers.swift`: the launcher's installer is not run again
  when the launcher is in the prefix, a game whose install script runs it gets
  the launcher's session line, and the launcher's `InstallDir` value, which its
  installer leaves out, is written where the prefix has none
  (`sharedLauncherInstallers`, `env.MADEIRA_INSTALL_LAUNCHER_REGISTRY`).
- `app/Madeira/GameRecommendations.swift`: the lists for Ubisoft Connect, Far
  Cry 3 and Far Cry 4.

## Playing

1. Install the game in Madeira Dock and start it there. Its Steam install script
   runs Ubisoft Connect's installer once; for the next Ubisoft game the Dock
   sees the launcher in the prefix and records that step as done.
2. The game hands over to Ubisoft Connect. Sign in to your Ubisoft account the
   first time; the launcher then starts the game. The game's recommended
   settings apply on first sight (Game details › Reset to Recommended brings
   them back).
3. In Far Cry 3, set Overall Quality to Custom before changing the graphics
   options: the Optimal preset reads the detected GPU.

Ubisoft Connect can also be added to the library on its own
(`C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe`),
for example to sign in before a game. Its list starts it in the Wine desktop
with Windows services first; without them it did not open. It is slow, and
the first sign-in can take a while.

The games and Ubisoft Connect's processes together need more code buffers than
one JIT pool region holds, so the three lists turn on the split pool
(`pool-split = 1`; about 860 to 880 MB in two regions in the tested sessions).
If a session still runs out ("JIT pool exhausted" in the log), start it
again.

## Not supported

- Ubisoft Connect's in-game overlay: the game starter's injection does not take,
  and the game runs without it.
- Far Cry 4 offline: the Dock's offline logon starts it, but the game ends
  (exit code 3) at its own "Logging in" step after Ubisoft Connect has
  opened. Ubisoft Connect's offline mode was not tried.
- Far Cry 3: one start in three ended during the game's hardware detection
  after its OpenGL probe (a read of memory another thread had freed, in
  ucrtbase). Starting it again worked.
- A libcef.dll build the table in `ios_ubi_cef_patch` does not list: the log
  names it, and the launcher's browser then runs with Chromium's defaults
  (more processes; it may not fit in the session's 32-bit windows). Adding a
  build is one table row once its site is checked.
- Other Ubisoft games have not been tried.

## Checks

    python3 tests/host/check-self-write.py
    python3 tests/host/check-x64-hook-zone.py
    python3 tests/host/check-reserved-area-merge.py
    python3 tests/host/check-ubi-cef.py
    python3 tests/host/check-kill-reap.py
    python3 tests/host/check-pool-carve-merge.py
    python3 tests/host/check-pool-code-policy.py
    python3 tests/host/check-sleep-kernel-apc.py
    python3 tests/host/check-woa-recheck.py
    python3 tests/host/check-hidpad.py
    python3 tests/host/check-dock-installers.py
    python3 tests/host/check-game-recommendations.py

They compile the production code on the host (ASan/UBSan) against models of
what it calls; the Swift parts need `swiftc`. None of them runs a game.

## Credits

The work was found and first tested in BCD
([thebcd69/bcd-games](https://github.com/thebcd69/bcd-games), a fork of
Madeira) and contributed there as thebcd69/bcd-games#46; it was written for
Madeira here by the same author.
