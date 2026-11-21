---
skill_format_version: "1.0.0"
name: "monitor.InternalEmitTruncationWarning"
schema_name: "monitor"
object_name: "InternalEmitTruncationWarning"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus."
source_path: "Code/01_Common/099_USP_InternalEmitTruncationWarning.sql"
---

# monitor.InternalEmitTruncationWarning

## Zweck und Einsatz

Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitTruncationWarning]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @TruncatedValueCount | bigint | ja | kein Default |
| @ParameterName | sysname | ja | kein Default |
| @ParameterValue | int | ja | kein Default |
| @LargestRequiredCharacters | bigint | ja | kein Default |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@TruncatedValueCount:** @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der Caller meldet damit die Anzahl gekürzter Werte; der Helper ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab. NULL, 0 und negative Werte unterdrücken die Meldung.

**@ParameterName:** @ParameterName sysname, Default: keiner; Pflichtargument und ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu <unbekannter Parameter> und im Vorschlag zu den begrenzenden Parameter; ein leerer Wert bleibt leer.

**@ParameterValue:** @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.

**@LargestRequiredCharacters:** @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der Caller meldet damit den größten benötigten Zeichenbedarf; der Helper berechnet oder prüft diesen Wert nicht. NULL wird im Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.

**@PrintMeldungen:** @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare Zahlen auf 1 abbilden. Keine Parameter sind OUTPUT-Parameter.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Keine.


Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalEmitTruncationWarning';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=NULL, @ParameterName=NULL, @ParameterValue=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die Ausgabe aktiviert und mindestens ein Wert gekürzt ist.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalEmitTruncationWarning
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Gibt höchstens eine technische Severity-10-Warning für alle im
               Aufruf sichtbar gekürzten Werte aus.
Resultsets   : Keine.
Nebenwirkung : Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die
               Ausgabe aktiviert und mindestens ein Wert gekürzt ist.
Parameter    : @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit die Anzahl gekürzter Werte; der Helper
               ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab.
               NULL, 0 und negative Werte unterdrücken die Meldung.
               @ParameterName sysname, Default: keiner; Pflichtargument und
               ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu
               <unbekannter Parameter> und im Vorschlag zu den begrenzenden
               Parameter; ein leerer Wert bleibt leer.
               @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich
               Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.
               @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit den größten benötigten Zeichenbedarf; der
               Helper berechnet oder prüft diesen Wert nicht. NULL wird im
               Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.
               @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken
               die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale
               SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare
               Zahlen auf 1 abbilden.
               Keine Parameter sind OUTPUT-Parameter.
```

