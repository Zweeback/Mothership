# GLaDOS DE · Robot Reader (Android MVP)
A native Android app for Pixel using installed **German Android TTS** and a mild adjustable metallic chorus.

**This is not the original German GLaDOS voice or an official Portal app.** No copyrighted dialogue or proprietary voice weights included.

Features: read arbitrary-length German text (chunked), native voices, voice selection, pitch, speech speed, metallic effect, clipboard paste, receive text from Android's Share menu, no tracking / no app server / no internet permission.

## Install from GitHub Actions
Open **Actions > Build GLaDOS German Reader APK > latest successful run > Artifacts > glados-de-reader-debug-apk**, extract ZIP and open `app-debug.apk` on Pixel. Permit the installing app to install APKs if Android asks.

Build locally with Android SDK 35, Gradle 8.11.1, JDK 17: `gradle :app:assembleDebug`.

The text-to-speech engine/voice pack comes from Android and may need downloading once. The robotic effect only runs if the engine's WAV file contains PCM16 samples; otherwise the app plays the WAV or uses normal TTS. No actual physical-device testing has been completed.

Research: https://github.com/R2D2FISH/glados-tts | https://github.com/dnhkng/GLaDOS | https://github.com/rhasspy/piper
