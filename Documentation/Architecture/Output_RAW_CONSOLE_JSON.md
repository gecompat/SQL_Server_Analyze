# Ausgabe-Vertrag CONSOLE, RAW, TABLE und JSON

Stand: 2026-07-19

## Parameter

```sql
@ResultSetArt varchar(16) = 'CONSOLE',
@ResultTable sysname = NULL,
@JsonErzeugen bit = 0,
@Json nvarchar(max) = NULL OUTPUT
```

`@ResultSetArt` akzeptiert case-insensitiv `CONSOLE`, `RAW`, `TABLE` und `NONE`. JSON kann unabhängig davon zusätzlich erzeugt werden. `@ResultTable` wird nur für `TABLE` ausgewertet.

## Default

`CONSOLE` ist der frameworkweite Default, weil die Procedures primär für interaktive Ad-hoc-Analysen in SSMS oder Azure Data Studio vorgesehen sind. Technische Verbraucher müssen `RAW` oder `TABLE` ausdrücklich setzen. Ausschließlich JSON wird mit `@ResultSetArt = 'NONE', @JsonErzeugen = 1` angefordert.

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

## TABLE

`TABLE` schreibt die primäre, nativ typisierte Datenmenge einer Procedure in eine lokale `#Temp`-Tabelle des Aufrufers. Die Procedure erzeugt die Zieltabelle nicht selbst, weil eine in der Procedure erzeugte Temp-Tabelle nach deren Ende nicht mehr zuverlässig als Aufrufervertrag zur Verfügung stünde.

Der kanonische Aufruf ist:

```sql
CREATE TABLE #Result ([__MonitorPlaceholder] bit NULL);

EXEC [monitor].[USP_CurrentRequests]
      @MaxZeilen = 100
    , @ResultSetArt = 'TABLE'
    , @ResultTable = N'#Result';

SELECT * FROM #Result;
```

Der Writer kennt zwei zulässige Zielzustände:

1. Eine leere Tabelle mit exakt einer nullable Spalte `[__MonitorPlaceholder] bit NULL`. Der Writer ergänzt die nativen Quellspalten und entfernt danach den Platzhalter.
2. Eine bereits exakt passende Spaltenstruktur. Der Writer hängt weitere Zeilen an.

Spaltenname und -reihenfolge, Systemdatentyp, Länge beziehungsweise `MAX`, Precision, Scale, Collation und Nullability müssen übereinstimmen. Eine abweichende Struktur führt kontrolliert zu `TARGET_SCHEMA_MISMATCH`; eine gefüllte Platzhaltertabelle wird niemals umgebaut. Die öffentliche Procedure meldet Writerfehler als Fehler `51010`.

Bewusste Grenzen:

- Nur lokale `#Temp`-Tabellen sind erlaubt. Globale `##Temp`-Tabellen und permanente Tabellen werden abgelehnt.
- Das Präfix `#Monitor` ist für interne Tabellen reserviert.
- Tabellen besitzen keine garantierte Zeilenreihenfolge; Consumer müssen beim Lesen selbst `ORDER BY` setzen.
- Identity-, Computed-, CLR-/benutzerdefinierte, schema-gebundene XML- und `rowversion`-Spalten werden nicht automatisch reproduziert.
- Bei Procedures mit mehreren fachlichen Datenmengen wird das in `Metadata/Inventory/TableOutput.csv` ausgewiesene Primärergebnis geschrieben. Aggregatoren liefern ihren Modulstatus beziehungsweise ihre Modul-Envelopes; typisierte Details werden direkt über die jeweilige Kindprocedure angefordert.
- Die Analyse läuft vor dem Tabellen-Writer. Procedureabhängige Status-OUTPUT-Parameter und Warnmeldungen bleiben deshalb maßgeblich für Verfügbarkeit und Teilresultate.

Die Beschränkung auf lokale Temp-Tabellen ist auch eine Datenschutzgrenze: Persistenz, Aufbewahrung, Berechtigungen und Schema-Drift permanenter Ergebnistabellen müssen außerhalb des Frameworks bewusst entworfen werden.

## JSON

JSON verwendet ein Envelope mit `meta`, benannten fachlichen Arrays und `warnings`. Anonyme Namen wie `resultSet1` sind nicht zulässig. CONSOLE, RAW, TABLE und JSON beruhen auf derselben einmal ermittelten Datenbasis.

Textuelle Steuerwerte werden getrimmt und case-insensitiv normalisiert. SQL-Identifier und fachliche Namensfilter bleiben unter `SQL_Latin1_General_CP1_CS_AS` exakt case-sensitiv.
