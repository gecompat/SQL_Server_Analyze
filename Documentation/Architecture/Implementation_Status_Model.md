# Implementierungsstatusmodell

Stand: 2026-07-22

Dieses Modell trennt Produktfunktion, automatisierte Repositoryevidenz, externe
Laufzeitnachweise und ausdrücklich optionale Erweiterungen. Ein offener
plattformabhängiger Nachweis darf eine vollständig implementierte
Current-State-Funktion nicht als unimplementiert erscheinen lassen. Umgekehrt
darf vorhandener Teilcode keinen vollständigen Produktvertrag vortäuschen.

## Kanonische Produktstatuswerte

| Status | Bedeutung | Zulässiger Einsatz |
|---|---|---|
| `IMPLEMENTED_ACTIONS_GATE` | Der definierte Produktumfang ist implementiert und durch die vorgesehene automatisierte Matrix nachgewiesen. | Code, Installer, Inventare, Dokumentation und verpflichtende Runtimeverträge stimmen überein. |
| `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING` | Der portable Produktkern ist implementiert; ein ausdrücklich externer, plattform- oder feature-positiver Nachweis steht noch aus. | Die fehlende Evidenz ist nicht Teil der portablen Kernfunktion und wird in `External_Evidence_Gates.csv` geführt. |
| `PARTIAL_PRODUCT_FUNCTION` | Nutzbare Bausteine sind vorhanden, der zugesagte öffentliche Gesamtvertrag ist aber noch nicht vollständig. | Der vorhandene und der offene Umfang müssen getrennt benannt werden. |
| `RESEARCHED_NOT_IMPLEMENTED` | Recherche oder Design liegen vor, jedoch kein auslieferbarer Produkt-Slice. | Capability-Erkennung allein gilt nicht als Implementierung der Analysefunktion. |
| `OPTIONAL_FUTURE` | Eine Erweiterung ist bewusst optional und blockiert keinen aktuellen Produktabschluss. | Sie darf nicht als fehlende Kernfunktion oder Releasefehler gezählt werden. |

Spezifische Evidence-Gate-Werte wie `IMPLEMENTED_AUTOMATED_GATE`,
`DESIGN_READY_EXTERNAL_COMPONENT_REQUIRED` oder
`RUNBOOK_READY_EXTERNAL_EXECUTION_REQUIRED` bleiben in ihren bestehenden
Qualitätsregistern gültig. Sie ersetzen den Produktstatus nicht.

## Bewertungsregeln

1. Der Status bezieht sich immer auf einen explizit abgegrenzten Umfang.
2. Ein Erweiterungsslice erhält eine eigene Zeile, wenn sein Status vom
   ausgelieferten Kern abweicht.
3. `IMPLEMENTED_ACTIONS_GATE` setzt keine reale Kundendaten- oder
   Produktionsumgebung voraus; Repositorytests verwenden ausschließlich
   synthetische Fixtures.
4. Externe Nachweise speichern keine Laufzeitlogs, Binärdateien, Identitäten,
   Pfade oder Umgebungswerte im Repository.
5. Ein Statuswechsel erfordert eine konsistente Änderung von Architekturvertrag,
   maschinenlesbarem Register, Tests und – falls betroffen – Installer und
   öffentlichem Resultsetinventar.

## Aktuelle Abgrenzung

Die kanonischen Zuordnungen stehen in
`Metadata/Quality/Implementation_Status.csv`. Für DIAG-003 bis DIAG-005 ist
der vorhandene Teilumfang ausdrücklich von den noch offenen Zielresultsets
getrennt. RUNTIME-001 ist als implementierter portabler Kern mit ausstehenden
externen Feature-Nachweisen eingestuft. Bei SC-023 bleibt der bereits
abgenommene Performance-Counter-Slice implementiert; weitere Collector und
Rollups sind optionaler Ausbau.
