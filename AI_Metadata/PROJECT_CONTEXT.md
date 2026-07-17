# Projektkontext für KI-gestützte Fortsetzung

## Ziel

Entwicklung eines performanten, read-only orientierten SQL-Server-Diagnoseframeworks im Schema `[monitor]` für SQL Server 2019 und höher.

## Feste Verträge

- Collation: `SQL_Latin1_General_CP1_CS_AS`; Objekt-, Parameter-, Spalten- und Aliasnamen sind case-sensitiv.
- Jedes SQL-Skript beginnt mit `USE [DeineDatenbank];` und `GO`.
- Beispielaufrufe sind nur als `[monitor].[Objektname]` zu schreiben.
- Öffentliche Procedures verwenden `@ResultSetArt = 'CONSOLE'` als Default; Steuerwerte werden intern case-insensitiv normalisiert.
- `RAW` ist der stabile technische Vertrag, `CONSOLE` die formatierte Ad-hoc-Ausgabe, `NONE` unterdrückt fachliche Resultsets.
- JSON wird optional über `@Json nvarchar(max) OUTPUT` mit Metadaten und benannten Arrays geliefert.
- `@MaxZeilen`: positiv begrenzt, `NULL` oder `0` bedeutet vollständig, negativ ist ungültig.
- Exakte Mehrfachfilter verwenden bracket-aware Pipe-Listen; Pipe trennt nur außerhalb von `[...]`.
- Patternfilter sind von exakten Listen getrennt und unterstützen `like:`, versionsabhängig `regex:` und `regexi:`.
- Query Store wird im Kontext jeder ausgewählten Quelldatenbank gelesen.
- Statementtext wird zentral anhand der Byte-Offsets extrahiert; Batch-, Modul- und Input-Buffer-Text sind getrennte Diagnoseinformationen.
- Katalogzugriffe sollen Locking/Blocking minimieren; ressourcenintensive Pfade sind nicht der Default.

## Datenschutz und Portabilität

- Interaktive, berechtigte Runtime-Ausgaben dürfen die diagnostisch erforderlichen Benutzer-, Login-, Session-, Firmen-, Host-, Server-, Datenbank-, Schema-, Objekt- und Freitextinformationen anzeigen.
- Reale Runtime-Werte dürfen niemals in Code, Dokumentation, Beispielen, Tests, Fixtures, Audits, Metadaten, Screenshots oder downloadbaren Lieferartefakten stehen.
- Technische Systemspalten und generische API-Namen sind zulässig; Beispiele verwenden ausschließlich synthetische Platzhalter.
- Öffentliche Quellen-, Lizenz- und Urheberangaben sind beabsichtigte Attribution und werden nicht als versehentliche Umgebungsdaten behandelt.
- Persistenz und Export benötigen vor ihrer Implementierung ein eigenes Datenschutz- und Retentionkonzept.
- Bei uneindeutigen Datenfunden muss vor der Aufnahme in ein Artefakt nachgefragt werden.
- Maßgebliche Entscheidung: `Documentation/Architecture/Runtime_Data_and_Repository_Privacy.md`.
