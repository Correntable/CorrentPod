<div align="center">

# 🎵 CorrentPod

**An iPod Classic-inspired music player for Android, with lock screen persistence.**

![Screenshots](screenshots/combined.jpg)

<sub>Screenshots are from the original project and still show the original branding.</sub>

</div>

CorrentPod is a personal fork of [Classipod](https://github.com/adeeteya/Classipod) by Aditya R. It keeps everything that makes the original great: a click wheel interface, Cover Flow, local music playback and Subsonic/Navidrome streaming. On top of that, it adds a few tweaks of its own.

> **Unofficial fork.** This project is not affiliated with, endorsed by, or supported by the original author. All credit for the app itself goes to [Aditya R](https://github.com/adeeteya).

## ✨ What's different from Classipod

| Change | Details |
|--------|---------|
| 🔒 **Lock screen persistence** | The app can show above the lock screen. Press the power button while playing, wake the screen, and CorrentPod is already there, much like Google Maps during navigation. Your PIN or fingerprint still protects the rest of the phone. |
| 🏷️ **Rebranding** | The app name, the About screen, the menu preview and the playback notification now say **CorrentPod**. |
| 📝 **Colophon** | The About screen credits both the original author and this fork. |
| 🤖 **Automated builds** | A GitHub Actions workflow builds a ready-to-install Android APK on every push. |

Lock screen persistence needs Android 8.1 or newer.

## 📥 Download

Download the latest APK from the [Releases page](../../releases/latest), or directly:
[CorrentPod.apk](https://github.com/Correntable/CorrentPod/releases/latest/download/CorrentPod.apk)

Notes:

- The build uses the `dev` flavor, so it installs **next to** the original Classipod without replacing it.
- The signing key is generated fresh on every build. To install a newer build, **uninstall the previous CorrentPod first**.
- If playback stops in the background, exclude the app from battery optimization.

## 🛠️ Build it yourself

CorrentPod is a Flutter app. To build locally:

1. Install Flutter **3.47.6** (the exact version required by `pubspec.yaml`) and the Android SDK.
2. Run `flutter pub get`.
3. Run `flutter build apk --release --flavor dev`.

Release signing expects an `android/key.properties` file. The workflow in `.github/workflows/build.yml` shows how to generate a throwaway key.

## 🎶 Features

For the complete feature list (local library, Subsonic/Navidrome streaming, Cover Flow, themes, sleep timer, lyrics and more), see the [original project's README](https://github.com/adeeteya/Classipod#readme).

## 🙏 Credits and license

- **Original app:** [Classipod](https://github.com/adeeteya/Classipod) by [Aditya R](https://github.com/adeeteya)
- **This fork:** maintained by [Correntable](https://github.com/Correntable)
- Ipod icons created by [Freepik - Flaticon](https://www.flaticon.com/free-icons/ipod)

Licensed under the [BSD-4-Clause License](LICENSE), copyright (c) 2025 Aditya R. The original license and copyright notice are kept unchanged, as required.
