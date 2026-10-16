# Die Speis

Haushalts-Tool für Lebensmittel und Haushaltsbedarf. Ziel: auf den Monat gerechnet
weniger ausgeben, ohne auf die gewohnten Produkte zu verzichten.

**Live:** https://claude.ai/artifact/Dny5fKaroE7ZY3JnArJQ4S (privat, nur für den Besitzer)
**Quelltext:** [`index.html`](index.html)

## Die vier Bereiche

| Bereich | Wozu |
|---|---|
| Vorrat | Was ist daheim, wo liegt es, was ist leer oder knapp, welches MHD läuft ab. Bestand mit −/+ anpassen. |
| Einkauf | Automatische Liste, sortiert nach dem Markt mit dem besten Grundpreis. „Gekauft“ erhöht den Bestand, merkt den Preis und verbucht die Ausgabe in einem Schritt. |
| Preise | Preisgedächtnis je Produkt, umgerechnet auf €/kg, €/l oder €/Stk. Zeigt, welcher Markt für die meisten Produkte am günstigsten ist. |
| Ausgaben | Monatssumme gegen Budget, Hochrechnung, geschätzte Ersparnis, Verlauf über sechs Monate, Aufteilung nach Markt und Kategorie. |

## Die Logik dahinter

Jedes Produkt hat drei Zahlen:

- **Nachkaufen bei** – fällt der Bestand darauf, kommt es auf die Liste.
- **Vorrat höchstens** – so viel, wie vor Ablauf verbraucht wird und Platz hat.
- **Zielpreis** (je kg/l/Stk) – ab hier gilt ein Preis als günstig. Leer gelassen,
  setzt die Speis ab drei erfassten Preisen den Bestpreis plus 5 %.

Daraus folgt die Einkaufsregel:

1. Muss nachgekauft werden und der Preis ist günstig → bis zur Obergrenze auffüllen.
2. Muss nachgekauft werden, aber kein guter Preis → nur das Nötigste, auf die Aktion warten.
3. Muss nicht nachgekauft werden, aber gerade Aktion unter Zielpreis → Vorrat auffüllen.

Eine Aktion zählt 14 Tage, danach gilt wieder der zuletzt erfasste Normalpreis des Markts.

## Kassenbon scannen

Auf claude.ai kann die Speis ein Foto vom Kassenbon von Claude auslesen lassen.
Positionen werden Produkten zugeordnet, Rabattpickerl mit der Position verrechnet.
Vor dem Übernehmen lässt sich alles prüfen.

## Daten

Die Daten liegen in der Datenbank des Artifacts (Sammlungen `products`, `months`,
`settings`). Claude kann sie im Chat lesen und schreiben, etwa um eine Produktliste
einzutragen oder eine Auswertung zu machen. Die mitgelieferten Einträge mit der
Markierung „Beispiel“ haben erfundene Preise und lassen sich mit einem Knopf entfernen.
