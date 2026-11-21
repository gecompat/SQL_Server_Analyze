---
skill_format_version: "1.0.0"
name: "monitor.InternalPrepareResultTables"
schema_name: "monitor"
object_name: "InternalPrepareResultTables"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Prüft ein JSON-Objekt mit TABLE-Zuordnungen gegen die vom Aufrufer übergebene Namensliste, validiert vorhandene lokale Ergebnistabellen und hängt Zuordnungen an die Mapping-Tabelle des Aufrufers an."
source_path: "Code/01_Common/096_USP_InternalPrepareResultTables.sql"
---

# monitor.InternalPrepareResultTables

## Zweck und Einsatz

Prüft ein JSON-Objekt mit TABLE-Zuordnungen gegen die vom Aufrufer übergebene Namensliste, validiert vorhandene lokale Ergebnistabellen und hängt Zuordnungen an die Mapping-Tabelle des Aufrufers an.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalPrepareResultTables]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[columns]`, `[sys].[tables]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ResultTablesJson | nvarchar(max) | ja | kein Default |
| @AllowedResultNames | nvarchar(max) | ja | kein Default |
| @MappingTable | sysname | ja | kein Default |
| @StatusCode | varchar(40) OUTPUT | nein | NULL |
| @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |
| @ThrowOnError | bit | nein | 0 |
| @Hilfe | bit | nein | 0 |

**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). Erwartet ein JSON-Objekt, keine Liste; NULL, leerer Text, {} und Objekte ohne Zuordnung sind ungültig. Jedes Schlüssel-Wert-Paar muss Zeichenketten enthalten. Schlüssel und Zielwerte werden vor den Guards nach sysname konvertiert. Schlüssel werden nach der Konvertierung binär exakt mit @AllowedResultNames verglichen; es gibt keine Vorab-Trim-Regel. Doppelte Schlüssel werden binär erkannt. Werte müssen unqualifizierte, rohe lokale #Temp-Namen sein: kein ## und kein #Monitor-Präfix (CI), LEN höchstens 116 nach sysname-Konvertierung. Werte werden nicht getrimmt; doppelte Ziele werden CI erkannt. Klammer- oder Schemanamen sind nicht zulässig.

**@AllowedResultNames:** @AllowedResultNames nvarchar(max), Default: kein Default (Pflichtparameter). Vom Aufrufer gelieferte Pipe-Liste; NULL, leer oder nur leere Einträge ergibt keine zulässigen Namen. | hat keine Escape-Syntax. Nur U+0020 an den Rändern jedes Tokens wird entfernt; leere Tokens werden ignoriert. Tokens werden nach sysname konvertiert und binär verglichen. Doppelte Tokens nach Konvertierung können im nicht abgefangenen INSERT einen nativen Fehler auslösen. Die Wertemenge bleibt der offene Aufrufervertrag.

**@MappingTable:** @MappingTable sysname, Default: kein Default (Pflichtparameter). NULL oder leer ist ungültig; kein Trimmen. Name einer vom Aufrufer erstellten lokalen #Temp-Tabelle, kein ##, höchstens 116 Zeichen nach sysname-Konvertierung. Erwartet werden ResultName und TargetTable als sysname. TOP (0) mit Variablen beweist die Auflösung/Konvertierung dieser Spalten, nicht das exakte physische Tabellenschema. Zuordnungen werden angehängt; bestehende Zeilen werden nicht gelöscht.

**@StatusCode:** @StatusCode varchar(40), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ varchar(40); nach eigener Temp-DDL auf AVAILABLE initialisiert; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. AVAILABLE bedeutet Preflight erfolgreich; INVALID_PARAMETER bedeutet ungültiger @ThrowOnError oder @MappingTable; INVALID_RESULT_TABLE_MAPPING bedeutet ungültige JSON-Form oder unzulässige, doppelte bzw. nicht erlaubte Zuordnung; INVALID_RESULT_TABLE_TARGET bedeutet Ziel fehlt, ist nicht leer, besteht nicht aus genau einer Seed-Spalte oder kann nicht sicher geprüft werden; INTERNAL_ERROR bedeutet, dass Mapping-Spalten nicht wie erwartet auflösbar/konvertierbar sind. Bei Auslassen gilt Default NULL; Aufrufer bindet eine Variable mit OUTPUT. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessage:** @ErrorMessage nvarchar(2048), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ nvarchar(2048); nach eigener Temp-DDL auf NULL initialisiert, bei erkanntem Fehler mit Meldung befüllt; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. Bei Auslassen gilt Default NULL; zum Empfang ist eine Aufrufervariable mit OUTPUT nötig. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ThrowOnError:** @ThrowOnError bit, Default: 0. Kann ausgelassen werden. 0 unterdrückt nur behandelte Preflightfehler und gibt Status/Meldung zurück; 1 wirft für behandelte Fehler 51011. NULL ist ungültig, ergibt INVALID_PARAMETER und löst wegen der NULL-Prüfung auf 1 keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe. Fehler- und Seiteneffektgrenzen: Eigene Prüftabellen-DDL liegt vor der Initialisierung von @StatusCode und @ErrorMessage; DDL-Fehler werden nach Wiederherstellung des vorherigen Lock-Timeouts erneut ausgelöst. Die Allowed-Liste wird außerhalb TRY/CATCH eingefügt, ebenso das finale Mapping-INSERT; native Fehler dort können entweichen. Ziele werden mit temporärer Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen, Bereinigung im Fehlerpfad ist best effort. Es gibt keine atomare Rücknahmezusage. Es erfolgt keine Erstellung oder dauerhafte Anpassung der Ergebnisspaltenstruktur. Eingehender LOCK_TIMEOUT 0 erhält pro eigener Temp-DDL-Anlage 1000 ms; andere Werte bleiben während dieser Anlage bestehen. Nach erfolgreicher Anlage wird LOCK_TIMEOUT 0 gesetzt; Zieloperationen verwenden NOWAIT.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Im Normalpfad gibt es kein fachliches Resultset. Die Procedure prüft die lokale TABLE-Zuordnung und hängt gültige `ResultName`/`TargetTable`-Paare an die vom Aufrufer bereitgestellte Mapping-#Temp-Tabelle an; vorhandene Mappingzeilen bleiben stehen. `@StatusCode` (varchar(40) OUTPUT) wird nach eigener Temp-DDL zunächst AVAILABLE und kann INVALID_PARAMETER, INVALID_RESULT_TABLE_MAPPING, INVALID_RESULT_TABLE_TARGET oder INTERNAL_ERROR melden. `@ErrorMessage` (nvarchar(2048) OUTPUT) ist bei Erfolg NULL und enthält bei erkanntem Fehler die Diagnose. Eigene Temp-DDL kann vor der Initialisierung scheitern; Allowed-Listen- und finale Mapping-INSERT-Fehler sind nicht generell in einen Status übersetzt.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalPrepareResultTables';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=NULL, @AllowedResultNames=NULL, @MappingTable=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalPrepareResultTables
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Prüft ein JSON-Objekt mit TABLE-Zuordnungen gegen die vom
               Aufrufer übergebene Namensliste, validiert vorhandene lokale
               Ergebnistabellen und hängt Zuordnungen an die Mapping-Tabelle
               des Aufrufers an.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). Erwartet ein JSON-Objekt, keine Liste; NULL, leerer Text, {} und Objekte ohne Zuordnung sind ungültig. Jedes Schlüssel-Wert-Paar muss Zeichenketten enthalten. Schlüssel und Zielwerte werden vor den Guards nach sysname konvertiert. Schlüssel werden nach der Konvertierung binär exakt mit @AllowedResultNames verglichen; es gibt keine Vorab-Trim-Regel. Doppelte Schlüssel werden binär erkannt. Werte müssen unqualifizierte, rohe lokale #Temp-Namen sein: kein ## und kein #Monitor-Präfix (CI), LEN höchstens 116 nach sysname-Konvertierung. Werte werden nicht getrimmt; doppelte Ziele werden CI erkannt. Klammer- oder Schemanamen sind nicht 

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalPrepareResultTables
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Prüft ein JSON-Objekt mit TABLE-Zuordnungen gegen die vom
               Aufrufer übergebene Namensliste, validiert vorhandene lokale
               Ergebnistabellen und hängt Zuordnungen an die Mapping-Tabelle
               des Aufrufers an.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). Erwartet ein JSON-Objekt, keine Liste; NULL, leerer Text, {} und Objekte ohne Zuordnung sind ungültig. Jedes Schlüssel-Wert-Paar muss Zeichenketten enthalten. Schlüssel und Zielwerte werden vor den Guards nach sysname konvertiert. Schlüssel werden nach der Konvertierung binär exakt mit @AllowedResultNames verglichen; es gibt keine Vorab-Trim-Regel. Doppelte Schlüssel werden binär erkannt. Werte müssen unqualifizierte, rohe lokale #Temp-Namen sein: kein ## und kein #Monitor-Präfix (CI), LEN höchstens 116 nach sysname-Konvertierung. Werte werden nicht getrimmt; doppelte Ziele werden CI erkannt. Klammer- oder Schemanamen sind nicht zulässig.
@AllowedResultNames nvarchar(max), Default: kein Default (Pflichtparameter). Vom Aufrufer gelieferte Pipe-Liste; NULL, leer oder nur leere Einträge ergibt keine zulässigen Namen. | hat keine Escape-Syntax. Nur U+0020 an den Rändern jedes Tokens wird entfernt; leere Tokens werden ignoriert. Tokens werden nach sysname konvertiert und binär verglichen. Doppelte Tokens nach Konvertierung können im nicht abgefangenen INSERT einen nativen Fehler auslösen. Die Wertemenge bleibt der offene Aufrufervertrag.
@MappingTable sysname, Default: kein Default (Pflichtparameter). NULL oder leer ist ungültig; kein Trimmen. Name einer vom Aufrufer erstellten lokalen #Temp-Tabelle, kein ##, höchstens 116 Zeichen nach sysname-Konvertierung. Erwartet werden ResultName und TargetTable als sysname. TOP (0) mit Variablen beweist die Auflösung/Konvertierung dieser Spalten, nicht das exakte physische Tabellenschema. Zuordnungen werden angehängt; bestehende Zeilen werden nicht gelöscht.
@StatusCode varchar(40), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ varchar(40); nach eigener Temp-DDL auf AVAILABLE initialisiert; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. AVAILABLE bedeutet Preflight erfolgreich; INVALID_PARAMETER bedeutet ungültiger @ThrowOnError oder @MappingTable; INVALID_RESULT_TABLE_MAPPING bedeutet ungültige JSON-Form oder unzulässige, doppelte bzw. nicht erlaubte Zuordnung; INVALID_RESULT_TABLE_TARGET bedeutet Ziel fehlt, ist nicht leer, besteht nicht aus genau einer Seed-Spalte oder kann nicht sicher geprüft werden; INTERNAL_ERROR bedeutet, dass Mapping-Spalten nicht wie erwartet auflösbar/konvertierbar sind. Bei Auslassen gilt Default NULL; Aufrufer bindet eine Variable mit OUTPUT. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar.
@ErrorMessage nvarchar(2048), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ nvarchar(2048); nach eigener Temp-DDL auf NULL initialisiert, bei erkanntem Fehler mit Meldung befüllt; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. Bei Auslassen gilt Default NULL; zum Empfang ist eine Aufrufervariable mit OUTPUT nötig. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar.
@ThrowOnError bit, Default: 0. Kann ausgelassen werden. 0 unterdrückt nur behandelte Preflightfehler und gibt Status/Meldung zurück; 1 wirft für behandelte Fehler 51011. NULL ist ungültig, ergibt INVALID_PARAMETER und löst wegen der NULL-Prüfung auf 1 keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
Fehler- und Seiteneffektgrenzen: Eigene Prüftabellen-DDL liegt vor der Initialisierung von @StatusCode und @ErrorMessage; DDL-Fehler werden nach Wiederherstellung des vorherigen Lock-Timeouts erneut ausgelöst. Die Allowed-Liste wird außerhalb TRY/CATCH eingefügt, ebenso das finale Mapping-INSERT; native Fehler dort können entweichen. Ziele werden mit temporärer Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen, Bereinigung im Fehlerpfad ist best effort. Es gibt keine atomare Rücknahmezusage. Es erfolgt keine Erstellung oder dauerhafte Anpassung der Ergebnisspaltenstruktur. Eingehender LOCK_TIMEOUT 0 erhält pro eigener Temp-DDL-Anlage 1000 ms; andere Werte bleiben während dieser Anlage bestehen. Nach erfolgreicher Anlage wird LOCK_TIMEOUT 0 gesetzt; Zieloperationen verwenden NOWAIT.
```

