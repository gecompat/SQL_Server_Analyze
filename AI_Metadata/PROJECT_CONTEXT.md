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

- Das Datenschutz-Liefergate gilt ausschließlich für Repository-, GitHub- und Downloadartefakte. Resultsets, OUTPUT-Parameter sowie RAW-, CONSOLE- und JSON-Ausgaben werden deshalb weder anonymisiert noch fachlich reduziert.
- Reale personen-, benutzer-, kunden-, firmen-, organisations-, betriebs- oder umgebungsbezogene Informationen dürfen niemals in Code, Kommentaren, Dokumentation, Beispielen, Tests, Fixtures, Audits, Metadaten, Screenshots oder Downloads stehen.
- Das Verbot umfasst interne Datenbankstrukturen, Namenskonventionen und proprietäres Metadatenwissen aus Screenshots, Hardcopys, Chats, Uploads, bestehenden Skripten, Logs und Diagnoseausgaben.
- Technische Systemspalten und generische API-Namen sind zulässig; Beispiele verwenden ausschließlich eindeutig synthetische, generische Werte und bilden keine reale interne Struktur nach.
- Öffentliche Quellen-, Lizenz- und Urheberangaben sind beabsichtigte Attribution und werden nicht als versehentliche Umgebungsdaten behandelt.
- Eine Zustimmung oder vorhandener Zugriff hebt das Repositoryverbot nicht auf.
- Bei uneindeutigen Datenfunden muss vor dem Schreiben oder Verpacken angehalten und nach einer nicht sensitiven Alternative gefragt werden.
- Maßgebliche Entscheidung: `Documentation/Architecture/Runtime_Data_and_Repository_Privacy.md`.

### Verbindlicher Kurzprompt

> In Repository-, GitHub- und Downloadartefakte dürfen niemals reale personen-, firmen-, kunden-, organisations-, betriebs- oder umgebungsbezogene Informationen oder proprietäre interne Strukturen übernommen werden, auch nicht aus Screenshots, Hardcopys, Chats, Uploads, Skripten, Logs oder Diagnoseausgaben. Beispiele und Tests verwenden ausschließlich eindeutig synthetische, generische Werte ohne Nachbildung realer interner Strukturen. Resultsets und OUTPUT-Parameter der Procedures bleiben diagnostisch vollständig und werden durch diese Regel nicht anonymisiert. Bei Zweifeln vor dem Schreiben anhalten und nach einer nicht sensitiven Alternative fragen; eine Zustimmung hebt das Repositoryverbot nicht auf.
