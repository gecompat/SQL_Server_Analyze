# Versionsadaptive Featurestrategie

Öffentliche Objekte werden nicht nach einer SQL-Server-Version benannt. Jede allgemeine Analyse wählt intern die beste verfügbare Quelle.

Statuswerte:
- `AVAILABLE`: native Information verfügbar.
- `PARTIAL`: Aussage ist möglich, einzelne Zusatzfelder fehlen.
- `UNAVAILABLE_VERSION`: die Information existiert auf dieser Serverversion nicht.
- `UNAVAILABLE_PLATFORM`: nur auf einer anderen Plattform verfügbar.
- `UNAVAILABLE_FEATURE`: Feature nicht installiert/aktiviert.
- `DENIED_PERMISSION`: Quelle existiert, ist aber nicht lesbar.

Wenn eine neue Quelle nur zusätzliche Details liefert, bleibt die ältere äquivalente Kernaussage erhalten. Beispiele: allgemeines Indexinventar ohne Vector-Metadaten, allgemeine Query-Store-Auswertung ohne Replica-Dimension, allgemeine OS-DMVs ohne Linux-Host-DMVs.
