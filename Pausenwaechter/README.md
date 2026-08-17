# Pausenwächter

Eine iPhone-App, die ausgewählte Apps nach Zeitplan oder Nutzungsdauer sperrt.
Wieder hinein kommst du entweder über einen selbst gesetzten Code oder über
eine Atempause, deren Länge du selbst festlegst — oder beides, je nachdem wie
schwer du es dir machen willst.

Alles bleibt auf dem Gerät. Kein Konto, kein Server, keine Datenübertragung.

---

## Was die App kann

| | |
|---|---|
| **Apps auswählen** | Einzelne Apps, ganze Kategorien und Webseiten — über Apples eigene Auswahl |
| **Sperren nach Uhrzeit** | Beliebig viele Zeitfenster, pro Wochentag, auch über Mitternacht |
| **Sperren nach Nutzungsdauer** | Tagesbudget, z. B. 60 Minuten — danach ist bis Mitternacht Schluss |
| **Entsperren per Code** | 4–12 Ziffern, nur als gesalzener Hash gespeichert, Sperre nach 5 Fehlversuchen |
| **Entsperren per Atempause** | 15 s bis 10 min, mit geführtem Atemrhythmus (4 s ein, 6 s aus) |
| **Kombinierbar** | Nur Code · nur Atempause · beides zur Wahl · beides hintereinander |
| **Freigabefenster** | Nach dem Entsperren 1–60 Minuten *tatsächlicher Nutzung*, dann sperrt es von selbst |
| **Tageslimit** | Höchstens *n* Entsperrungen pro Tag |
| **Eigener Sperrtext** | Dein Satz steht auf dem Bildschirm, der statt der App erscheint |
| **Strenger Modus** | Verhindert, dass die App gelöscht wird, solange gesperrt ist |

### Die Atempause

Der Zähler läuft **nur, solange die App im Vordergrund ist**. Wer wegwischt,
fängt von vorn an. Das ist Absicht: die Zeit soll dem Durchatmen gehören, nicht
dem Warten in einer anderen App.

---

## Bauen

Apps auf dem iPhone zu sperren geht ausschließlich über Apples
**Screen Time API** (FamilyControls, ManagedSettings, DeviceActivity). Das
heißt: eine echte native App, gebaut mit Xcode auf einem Mac. Eine Web-App oder
ein Shortcut kann das nicht.

### Voraussetzungen

- **Mac** mit **Xcode 15** oder neuer
- **iPhone mit iOS 16** oder neuer (auf dem Simulator sperrt nichts)
- **Apple-Developer-Account.** Ein kostenloser Account genügt zum Ausprobieren,
  muss aber alle 7 Tage neu signiert werden. Der bezahlte Account (99 €/Jahr)
  gibt dir ein Jahr Ruhe.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Schritte

```bash
git clone <dieses-repo>
cd Stuff/Pausenwaechter

# 1. Deine eigene Bundle-ID und Team-ID eintragen.
#    Die Team-ID steht auf developer.apple.com/account unter "Membership".
./configure.sh --bundle at.deinname.pausenwaechter --team ABCDE12345

# 2. Xcode-Projekt erzeugen
xcodegen generate

# 3. Öffnen
open Pausenwaechter.xcodeproj
```

In Xcode dann:

1. Alle **vier** Targets durchgehen (App + Monitor + Shield + ShieldAction).
   Unter *Signing & Capabilities* muss bei jedem
   - dein **Team** ausgewählt sein,
   - die Capability **Family Controls** stehen,
   - die Capability **App Groups** mit derselben Gruppe stehen
     (`group.at.deinname.pausenwaechter`).

   `configure.sh` hat die Entitlement-Dateien bereits geschrieben — Xcode legt
   die App-Group und die App-IDs beim ersten Bauen im Developer-Portal an.
2. iPhone per Kabel anschließen, als Ziel auswählen, **⌘R**.
3. Auf dem iPhone unter *Einstellungen → Allgemein → VPN & Geräteverwaltung*
   deinem Entwicklerzertifikat vertrauen.

### Beim ersten Start

Die App führt dich durch vier Schritte: Bildschirmzeit freigeben, Apps
auswählen, Entsperrmethode wählen, scharf schalten. Ohne die
Bildschirmzeit-Freigabe kann iOS keine App sperren — das ist eine
Systemvorgabe, kein Detail der App.

---

## Aufbau

Vier Prozesse, die sich einen Speicher teilen. Extensions werden vom System
gestartet, nicht von der App — deshalb geht der Weg über die App-Group.

```
Sources/
├── Shared/          ← in alle vier Targets kompiliert
│   ├── AppGroup.swift        Zugriff auf den geteilten Speicher
│   ├── Models.swift          Einstellungen, Zeitfenster, Laufzeitzustand
│   ├── SettingsStore.swift   Lesen und Schreiben
│   ├── ActivityNames.swift   Bezeichner für Zeitpläne und Ereignisse
│   ├── Passcode.swift        Code-Hash, Fehlversuche, Sperre
│   └── BlockingEngine.swift  ← die eigentliche Logik
│
├── App/             Die sichtbare App (SwiftUI)
├── Monitor/         DeviceActivityMonitor — wird an Zeitgrenzen geweckt
├── ShieldConfig/    Gestaltet den Sperrbildschirm
└── ShieldAction/    Reagiert auf dessen zwei Knöpfe
```

### Der Kern: `BlockingEngine.refresh()`

Die Engine merkt sich nicht, ob gerade gesperrt ist. Sie **rechnet es jedes Mal
neu aus**:

```
gesperrt = (Zeitfenster aktiv ODER Tagesbudget aufgebraucht) UND keine Freigabe aktiv
```

`refresh()` stellt diesen Zustand her und ist beliebig oft aufrufbar. Egal ob
die App, der Monitor oder ein abgelaufenes Freigabefenster den Aufruf auslöst —
das Ergebnis ist dasselbe. Ein verpasstes Systemereignis kann dadurch nichts
dauerhaft verstellen; spätestens beim nächsten Öffnen der App stimmt es wieder.

---

## Grenzen, die von iOS kommen

Diese Punkte sind keine Auslassungen, sondern Vorgaben des Systems:

- **Der Sperrbildschirm kann die App nicht selbst öffnen.** Extensions dürfen
  keine andere App starten. Tippst du dort auf „Durchatmen und entsperren“,
  merkt sich die App die Anfrage; beim nächsten Öffnen des Pausenwächters
  springst du direkt in den Entsperr-Dialog.
- **Zeitpläne müssen mindestens 15 Minuten lang sein.** Kürzere Fenster lehnt
  iOS ab; der Editor weist darauf hin.
- **Das Freigabefenster zählt Nutzungszeit, nicht Uhrzeit.** Deshalb sind auch
  Freigaben unter 15 Minuten möglich. Zusätzlich greift ein
  Wanduhr-Sicherheitsnetz nach spätestens `Freigabe + 10 min`, mindestens aber
  15 Minuten.
- **Die App zeigt keine Namen der gesperrten Apps.** iOS gibt sie nie heraus,
  nur undurchsichtige Tokens. Im Auswahlfenster selbst steht alles im Klartext.
- **Nutzungsschwellen sind minutengenau, nicht sekundengenau.** Das System
  wertet sie in Intervallen aus; ein bis zwei Minuten Ungenauigkeit sind normal.
- **Veröffentlichung im App Store** braucht Apples ausdrückliche Freigabe des
  `Family Controls`-Entitlements. Für den Eigengebrauch auf dem eigenen Gerät
  ist das nicht nötig.

## Wenn du dich wirklich aussperren willst

Der Pausenwächter hält dich nicht davon ab, ihn unscharf zu schalten — du hast
schließlich Zugriff auf deine eigenen Einstellungen. Wenn das zu leicht ist:

1. Schalte den **strengen Modus** ein (verhindert das Löschen der App).
2. Vergib in *Einstellungen → Bildschirmzeit* einen **Bildschirmzeit-Code** und
   lass ihn dir von jemand anderem setzen, ohne ihn zu sehen. Dann kann auch die
   Bildschirmzeit-Freigabe nicht mehr zurückgenommen werden.
3. Lass dir den **Entsperr-Code** der App von derselben Person setzen und wähle
   als Methode *Nur Code*. Dann bleibt dir nur der Weg über sie.
