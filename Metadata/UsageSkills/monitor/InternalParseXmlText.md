---
skill_format_version: "1.0.0"
name: "monitor.InternalParseXmlText"
schema_name: "monitor"
object_name: "InternalParseXmlText"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle."
source_path: "Code/01_Common/099a_USP_InternalParseXmlText.sql"
---

# monitor.InternalParseXmlText

## Zweck und Einsatz

Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalParseXmlText]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @XmlText | nvarchar(max) | ja | kein Default |
| @XmlValue | xml OUTPUT | nein | NULL |
| @StatusCode | varchar(40) OUTPUT | nein | NULL |
| @ErrorNumber | int OUTPUT | nein | NULL |
| @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@XmlText:** - @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...) nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020 einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.

**@XmlValue:** - @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL. Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCode:** - @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus. Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener Fehler 6335, 6336 oder 6337) und XML_INVALID (jeder andere gefangene Fehler). PENDING ist nur der initiale Zwischenwert vor CONVERT und kein normaler Endstatus. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumber:** - @ErrorNumber int: OUTPUT-Empfänger für ERROR_NUMBER() eines gefangenen Fehlers. Default: NULL. Ein bestehender Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessage:** - @ErrorMessage nvarchar(2048): OUTPUT-Empfänger für den nativen ERROR_MESSAGE()-Text eines gefangenen Fehlers, begrenzt durch nvarchar(2048). Default: NULL. Der bisherige Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Im Normalpfad gibt es kein Resultset. `@XmlValue` (xml OUTPUT) enthält bei erfolgreicher Konvertierung den vollständigen XML-Wert, sonst NULL. `@StatusCode` (varchar(40) OUTPUT) meldet SOURCE_NULL bei NULL-Text, XML_EMPTY bei leerem/Whitespace-Text nach erfolgreicher Konvertierung, AVAILABLE bei anderem gültigem XML, XML_UNAVAILABLE_LIMIT bei den nativen Fehlern 6335/6336/6337 und sonst XML_INVALID. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) bleiben ohne abgefangenen Fehler NULL oder enthalten dessen Nummer und Meldung. Die Procedure kürzt den nvarchar(max)-Eingang nicht vor der Konvertierung; die aufrufende Procedure entscheidet über einen Textfallback.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalParseXmlText';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalParseXmlText] @XmlText=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Parametervertrag:
- @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...)
  nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL
  beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist
  XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020
  einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung
  AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.
- @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL.
  Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei
  einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei
  erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY.
- @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus.
  Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus
  sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener
  Fehler 6

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalParseXmlText
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne
               vorherige Kürzung in natives xml und klassifiziert Ausfälle.
Resultsets   : Keine; ausschließlich OUTPUT-Parameter.
Grenze       : Die aufrufende Procedure materialisiert den Quelltext genau
               einmal und entscheidet, ob ein Textfallback exportiert wird.
```

