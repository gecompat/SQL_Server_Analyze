# Ausgabe-Vertrag CONSOLE, RAW und JSON

Stand: 2026-07-16

## Parameter

```sql
@ResultSetArt varchar(16) = 'CONSOLE',
@JsonErzeugen bit = 0,
@Json nvarchar(max) = NULL OUTPUT
```

`@ResultSetArt` akzeptiert case-insensitiv `CONSOLE`, `RAW` und `NONE`. JSON kann unabhängig davon zusätzlich erzeugt werden.

## Default

`CONSOLE` ist der frameworkweite Default, weil die Procedures primär für interaktive Ad-hoc-Analysen in SSMS oder Azure Data Studio vorgesehen sind. Technische Verbraucher müssen `@ResultSetArt = 'RAW'` ausdrücklich setzen. Ausschließlich JSON wird mit `@ResultSetArt = 'NONE', @JsonErzeugen = 1` angefordert.

## CONSOLE

Menschenorientierte Projektion. Die erste Spalte bezeichnet je Zeile den Inhalt. Zahlen, Zeiten, Größen und Status dürfen lesbar formatiert werden. Identifikatoren wie `SessionId` werden in breiten Resultsets nur an tatsächlich sinnvollen fachlichen Blockgrenzen wiederholt, nicht mechanisch nach einer festen Spaltenanzahl.

CONSOLE ist kein stabiler Importvertrag. Darstellungsspalten, Reihenfolge und Formatierung dürfen zur besseren Ad-hoc-Diagnose weiterentwickelt werden.

## RAW

Stabiler maschinenlesbarer Vertrag: typisierte Werte, keine Darstellungseinheiten, keine redundanten Schlüsselspalten und keine Titelzeilen. Mehrere fachliche Resultsets bleiben erlaubt und werden über gemeinsame Schlüssel verbunden.

RAW muss explizit angefordert werden:

```sql
EXEC [monitor].[USP_CurrentRequests]
    @ResultSetArt = 'RAW';
```

## JSON

JSON verwendet ein Envelope mit `meta`, benannten fachlichen Arrays und `warnings`. Anonyme Namen wie `resultSet1` sind nicht zulässig. CONSOLE, RAW und JSON beruhen auf derselben einmal ermittelten Datenbasis.

Textuelle Steuerwerte werden getrimmt und case-insensitiv normalisiert. SQL-Identifier und fachliche Namensfilter bleiben unter `SQL_Latin1_General_CP1_CS_AS` exakt case-sensitiv.
