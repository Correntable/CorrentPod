# CorrentPod

CorrentPod is a personal fork of [Classipod](https://github.com/adeeteya/Classipod) by Aditya R. It keeps everything that makes the original great: a click wheel interface, Cover Flow, local music playback and Subsonic/Navidrome streaming. On top of that, it adds a few tweaks of its own.

> **Unofficial fork.** This project is not affiliated with, endorsed by, or supported by the original author. All credit for the app itself goes to [Aditya R](https://github.com/adeeteya).

## What's different

I'm not a developer so I'm doing everything with Claude and for Android only. I'm trying to add some features that may improve the great experience we can already have with ClassiPod. Here's a list of the main features (done or in backlog):

DONE
- When the app is open and you lock the device, when you press the power button or any other method to wake up the screen, the app is already there, ready to be used. Everything else remains locked beneath the app. If the app was not open and you lock the phone, when tapping from the lockscreen on the Media Control Notification, the app will popup without unlocking.
- "Play Next" and "Add to queue" feature, both for single songs and albums, with enhanced management of the index of the songs of the queue.
- Shake to Shuffle (with an amazing starting sound)
- Improve text encoding for better management of string with special characters
- Artwork in the Now Playing screen are now tilted correctly also on the top side
- New shuffle algorithm to try to be as much Smart Shuffle as we can

TO-DO
- In the original Classipod, Shuffle Song or (now) Shake to Shuffle overwrite the "Shuffle" setting in the "Setting" screen. This cause the app to play in shuffle mode whaterver play list you might select. I'm trying to let the "Shuffle" setting to be indipendent from any launch of "Shuffle Song" so that you can choose how the app behave when launching a song from the Artist/Album menu
- Cover Flow sorted by artist, then by album release year, then alphabetically, as in the old good Apple Cover Flow
- Lockscreen behaviour described aboce as an option
- New About screen
- Better Now Playing texts positioning
- Playlists
- New icon

Lock screen persistence needs Android 8.1 or newer.

## Download

Download the latest APK from the [Releases page](../../releases/latest)

Notes:

- The build uses the `dev` flavor, so it installs **next to** the original Classipod without replacing it.
- If playback stops in the background, exclude the app from battery optimization.

## Features

For the complete feature list (local library, Subsonic/Navidrome streaming, Cover Flow, themes, sleep timer, lyrics and more), see the [original project's README](https://github.com/adeeteya/Classipod#readme).

## Credits and license

- **Original app:** [Classipod](https://github.com/adeeteya/Classipod) by [Aditya R](https://github.com/adeeteya)
- **This fork:** maintained by [Correntable](https://github.com/Correntable)
- Ipod icons created by [Freepik - Flaticon](https://www.flaticon.com/free-icons/ipod)
- Sound when Shaking to Shuffle from [TUNER88](https://github.com/TUNER88/iOSSystemSoundsLibrary)

Licensed under the [BSD-4-Clause License](LICENSE), copyright (c) 2025 Aditya R. The original license and copyright notice are kept unchanged, as required.
