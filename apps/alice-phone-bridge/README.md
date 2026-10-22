# ALICE Phone Bridge – erste Stufe: Speicherblick

Installierbare **lokale Android-Diagnose**, unabhängig von GLaDOS-Reader.
Ermittelt ohne besondere Rechte Total-/Frei-Speicher des /data-Dateisystems per StatFs, öffnet auf Wunsch die Android-Speicherverwaltung und zeigt nach ausdrücklicher Medienfreigabe die größten sichtbar gemachten Fotos/Videos.

- Kein Internet-Permission; keinerlei Upload, Serverzugang oder Hintergrunddienst.
- Keine Lösch-API; Diagnose und Freigabe bleiben auf dem Telefon.
- Bericht wird nur durch Androids Sharesheet nach Nutzerentscheidung geteilt. **Bericht kann sensible Dateinamen enthalten.**
- Androids Scoped Storage und Android-14/15-Teilauswahl bedeuten: Mediendateien sind möglicherweise unvollständig erfasst. App-Daten/Caches anderer Apps sind nicht lesbar.
- Der Bildschirmwert ist eine Dateisystem-Schätzung, keine geprüfte Android-Speicherkategorie.
- **Kein Fernsteuerungs-/Accessibility-Feature in dieser Buildstufe.** Der spätere private Befehlskanal benötigt eine gesonderte Sicherheits- und Geräteabnahme.

Build:
`gradle -p apps/alice-phone-bridge :app:assembleDebug`
APK: `apps/alice-phone-bridge/app/build/outputs/apk/debug/app-debug.apk`
