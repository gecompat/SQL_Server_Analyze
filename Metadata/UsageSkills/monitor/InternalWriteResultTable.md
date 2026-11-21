---
skill_format_version: "1.0.0"
name: "monitor.InternalWriteResultTable"
schema_name: "monitor"
object_name: "InternalWriteResultTable"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers."
source_path: "Code/01_Common/095_USP_InternalWriteResultTable.sql"
---

# monitor.InternalWriteResultTable

## Zweck und Einsatz

Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers. Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann an die Quellstruktur angepasst werden; eine passende Tabelle erhält die Zeilen als Anhang.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalWriteResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[columns]`, `[sys].[tables]`, `[sys].[types]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceTable | sysname | ja | kein Default |
| @TargetTable | sysname | ja | kein Default |
| @InsertedRows | bigint OUTPUT | nein | NULL |
| @StatusCode | varchar(40) OUTPUT | nein | NULL |
| @ErrorNumber | int OUTPUT | nein | NULL |
| @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |
| @ThrowOnError | bit | nein | 0 |
| @Hilfe | bit | nein | 0 |

**@SourceTable:** @SourceTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor nicht reserviert.

**@TargetTable:** @TargetTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch sein.

**@InsertedRows:** @InsertedRows bigint = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCode:** @StatusCode varchar(40) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status: AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang; INVALID_PARAMETER bezeichnet ungültige Parameter; LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten; SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare Quell- beziehungsweise Zieltabelle; METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile nicht sichtbar war; UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten oder mit nicht unterstützter Spaltenstruktur; TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch angepasst werden kann; TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen Fehler bei Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumber:** @ErrorNumber int = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessage:** @ErrorMessage nvarchar(2048) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ThrowOnError:** @ThrowOnError bit = 0 Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus. Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010 umgewandelt.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Im Normalpfad gibt die interne Procedure kein fachliches Resultset aus. Sie kopiert Zeilen aus der vorhandenen lokalen #Temp-Quelle in das lokale #Temp-Ziel; ein Dummy-Ziel kann an die Quellstruktur angepasst werden. `@InsertedRows` (bigint OUTPUT) zählt nach dem finalen INSERT dessen `@@ROWCOUNT`, nicht die gesamte Zielhistorie und keine atomar gesicherte Änderung. `@StatusCode` (varchar(40) OUTPUT) meldet AVAILABLE, INVALID_PARAMETER, LOCK_TIMEOUT, SOURCE_NOT_FOUND, TARGET_NOT_FOUND, METADATA_NOT_VISIBLE, UNSUPPORTED_SOURCE_SCHEMA, TARGET_SCHEMA_MISMATCH oder TABLE_WRITE_ERROR. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) enthalten einen abgefangenen nativen Fehler beziehungsweise eine Diagnose oder bleiben NULL. Die vier Ausgaben werden erst nach eigener Temp-DDL initialisiert; native Fehler außerhalb dieses Rahmens können entweichen.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalWriteResultTable';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalWriteResultTable] @SourceTable=NULL, @TargetTable=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalWriteResultTable
Version      : 1.1.0
Stand        : 2026-07-19
Typ          : Interne Stored Procedure
Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten
               Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.
               Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann
               an die Quellstruktur angepasst werden; eine passende Tabelle
               erhält die Zeilen als Anhang.
Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.
               Globale ##Temp-Tabellen, permanente Tabellen und das reservierte
               Zielpräfix #Monitor sind nicht zugelassen.
Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die
               tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale
               Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu
               1000 ms.
===============================================================================

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalWriteResultTable
Version      : 1.1.0
Stand        : 2026-07-19
Typ          : Interne Stored Procedure
Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten
               Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.
               Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann
               an die Quellstruktur angepasst werden; eine passende Tabelle
               erhält die Zeilen als Anhang.
Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.
               Globale ##Temp-Tabellen, permanente Tabellen und das reservierte
               Zielpräfix #Monitor sind nicht zugelassen.
Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die
               tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale
               Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu
               1000 ms.
===============================================================================

PARAMETER

@SourceTable sysname
  Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer
  vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen
  Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen
  und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig.
  Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder
  Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und
  Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um
  identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor
  nicht reserviert.

@TargetTable sysname
  Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer
  vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne
  führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der
  SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe
  ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen
  nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der
  Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach
  einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch
  sein.

@InsertedRows bigint = NULL OUTPUT
  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
  ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der
  Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er
  @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte
  Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren
  Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit
  OUTPUT übergeben; das Argument kann ausgelassen werden.

@StatusCode varchar(40) = NULL OUTPUT
  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf
  AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status:
  AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang;
  INVALID_PARAMETER bezeichnet ungültige Parameter;
  LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür
  vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten;
  SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare
  Quell- beziehungsweise Zieltabelle;
  METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile
  nicht sichtbar war;
  UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten
  oder mit nicht unterstützter Spaltenstruktur;
  TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch
  angepasst werden kann;
  TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen Fehler bei
  Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT
  wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss
  ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das
  Argument kann ausgelassen werden.

@ErrorNumber int = NULL OUTPUT
  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL
  initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen
  Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt
  er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der
  anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen
  Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine
  int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden.

@ErrorMessage nvarchar(2048) = NULL OUTPUT
  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL
  initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder
  Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener
  Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann
  ausgelassen werden.

@ThrowOnError bit = 0
  Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer
  Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte
  Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen
  behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als
  INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus.
  Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010
  umgewandelt.

VERARBEITUNG UND GRENZEN

Die vier OUTPUT-Parameter werden erst nach der eigenen Temp-DDL initialisiert.
Schlägt diese DDL fehl, werden ihre neuen Werte nicht zugesichert. Bei dieser
Anlage bleiben positive oder unbegrenzte eingehende LOCK_TIMEOUT-Werte erhalten;
nach erfolgreicher Anlage setzt der Baustein LOCK_TIMEOUT 0.

Die Quelle darf keine berechneten Spalten, benutzerdefinierten oder
Assembly-Datentypen, typisiertes XML sowie timestamp-/rowversion-Spalten
enthalten. Bei einer Identitätsspalte der Quelle werden die Werte in eine
gewöhnliche Zielspalte kopiert; das Ziel erhält dadurch keine
Identitätseigenschaft.

Eine bereits passende Zielstruktur muss in Spaltenanzahl und -reihenfolge,
Spaltennamen, vergleichbarem Datentyp, Länge, Genauigkeit, Skala, Sortierung
und NULL-Zulässigkeit übereinstimmen. Sie darf keine Identitäts- oder
berechneten Spalten, benutzerdefinierten oder Assembly-Datentypen oder
typisiertes XML enthalten. Eine abweichende Zieltabelle kann nur angepasst
werden, wenn sie leer ist und genau eine beliebige Dummy-Spalte besitzt.
Passende vorhandene Ziele dürfen bereits Zeilen enthalten; die neuen Zeilen
werden angehängt.

Die interne Auflösung fügt Quell- und Zieltabellen vorübergehend
Markierungsspalten hinzu und entfernt sie wieder. Die Schemaanpassung verwendet
einen Brücken- und ALTER-TABLE-Batch. Diese DDL kann sichtbare Tabellenänderungen
hinterlassen, wenn ein späterer Schritt fehlschlägt. Die Procedure garantiert
weder eine Transaktion noch atomaren Rollback oder Bereinigung nach Fehlern.
Die interne Schnittstelle ist an den versiongleichen Framework-Aufrufer
gebunden.
```

