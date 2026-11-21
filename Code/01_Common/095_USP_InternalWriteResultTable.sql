USE [DeineDatenbank];
GO

/*
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
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- USAGE_SKILL_BEGIN monitor.InternalWriteResultTable 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalWriteResultTable"
-- schema_name: "monitor"
-- object_name: "InternalWriteResultTable"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers."
-- source_path: "Code/01_Common/095_USP_InternalWriteResultTable.sql"
-- ---
-- 
-- # monitor.InternalWriteResultTable
-- 
-- ## Zweck und Einsatz
-- 
-- Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers. Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann an die Quellstruktur angepasst werden; eine passende Tabelle erhält die Zeilen als Anhang.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalWriteResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[columns]`, `[sys].[tables]`, `[sys].[types]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SourceTable | sysname | ja | kein Default |
-- | @TargetTable | sysname | ja | kein Default |
-- | @InsertedRows | bigint OUTPUT | nein | NULL |
-- | @StatusCode | varchar(40) OUTPUT | nein | NULL |
-- | @ErrorNumber | int OUTPUT | nein | NULL |
-- | @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |
-- | @ThrowOnError | bit | nein | 0 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SourceTable:** @SourceTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor nicht reserviert.
-- 
-- **@TargetTable:** @TargetTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch sein.
-- 
-- **@InsertedRows:** @InsertedRows bigint = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@StatusCode:** @StatusCode varchar(40) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status: AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang; INVALID_PARAMETER bezeichnet ungültige Parameter; LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten; SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare Quell- beziehungsweise Zieltabelle; METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile nicht sichtbar war; UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten oder mit nicht unterstützter Spaltenstruktur; TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch angepasst werden kann; TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen Fehler bei Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorNumber:** @ErrorNumber int = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessage:** @ErrorMessage nvarchar(2048) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ThrowOnError:** @ThrowOnError bit = 0 Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus. Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010 umgewandelt.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Im Normalpfad gibt die interne Procedure kein fachliches Resultset aus. Sie kopiert Zeilen aus der vorhandenen lokalen #Temp-Quelle in das lokale #Temp-Ziel; ein Dummy-Ziel kann an die Quellstruktur angepasst werden. `@InsertedRows` (bigint OUTPUT) zählt nach dem finalen INSERT dessen `@@ROWCOUNT`, nicht die gesamte Zielhistorie und keine atomar gesicherte Änderung. `@StatusCode` (varchar(40) OUTPUT) meldet AVAILABLE, INVALID_PARAMETER, LOCK_TIMEOUT, SOURCE_NOT_FOUND, TARGET_NOT_FOUND, METADATA_NOT_VISIBLE, UNSUPPORTED_SOURCE_SCHEMA, TARGET_SCHEMA_MISMATCH oder TABLE_WRITE_ERROR. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) enthalten einen abgefangenen nativen Fehler beziehungsweise eine Diagnose oder bleiben NULL. Die vier Ausgaben werden erst nach eigener Temp-DDL initialisiert; native Fehler außerhalb dieses Rahmens können entweichen.
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalWriteResultTable';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalWriteResultTable] @SourceTable=NULL, @TargetTable=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- ===============================================================================
-- Objekt       : monitor.InternalWriteResultTable
-- Version      : 1.1.0
-- Stand        : 2026-07-19
-- Typ          : Interne Stored Procedure
-- Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten
--                Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.
--                Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann
--                an die Quellstruktur angepasst werden; eine passende Tabelle
--                erhält die Zeilen als Anhang.
-- Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.
--                Globale ##Temp-Tabellen, permanente Tabellen und das reservierte
--                Zielpräfix #Monitor sind nicht zugelassen.
-- Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die
--                tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale
--                Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu
--                1000 ms.
-- ===============================================================================
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalWriteResultTable
-- Version      : 1.1.0
-- Stand        : 2026-07-19
-- Typ          : Interne Stored Procedure
-- Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten
--                Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.
--                Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann
--                an die Quellstruktur angepasst werden; eine passende Tabelle
--                erhält die Zeilen als Anhang.
-- Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.
--                Globale ##Temp-Tabellen, permanente Tabellen und das reservierte
--                Zielpräfix #Monitor sind nicht zugelassen.
-- Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die
--                tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale
--                Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu
--                1000 ms.
-- ===============================================================================
-- 
-- PARAMETER
-- 
-- @SourceTable sysname
--   Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer
--   vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen
--   Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen
--   und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig.
--   Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder
--   Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und
--   Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um
--   identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor
--   nicht reserviert.
-- 
-- @TargetTable sysname
--   Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer
--   vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne
--   führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der
--   SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe
--   ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen
--   nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der
--   Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach
--   einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch
--   sein.
-- 
-- @InsertedRows bigint = NULL OUTPUT
--   Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
--   ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der
--   Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er
--   @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte
--   Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren
--   Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit
--   OUTPUT übergeben; das Argument kann ausgelassen werden.
-- 
-- @StatusCode varchar(40) = NULL OUTPUT
--   Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
--   ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf
--   AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status:
--   AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang;
--   INVALID_PARAMETER bezeichnet ungültige Parameter;
--   LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür
--   vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten;
--   SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare
--   Quell- beziehungsweise Zieltabelle;
--   METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile
--   nicht sichtbar war;
--   UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten
--   oder mit nicht unterstützter Spaltenstruktur;
--   TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch
--   angepasst werden kann;
--   TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen Fehler bei
--   Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT
--   wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss
--   ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das
--   Argument kann ausgelassen werden.
-- 
-- @ErrorNumber int = NULL OUTPUT
--   Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
--   ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL
--   initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen
--   Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt
--   er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der
--   anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen
--   Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine
--   int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden.
-- 
-- @ErrorMessage nvarchar(2048) = NULL OUTPUT
--   Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird
--   ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL
--   initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder
--   Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener
--   Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann
--   ausgelassen werden.
-- 
-- @ThrowOnError bit = 0
--   Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer
--   Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte
--   Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen
--   behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als
--   INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus.
--   Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010
--   umgewandelt.
-- 
-- VERARBEITUNG UND GRENZEN
-- 
-- Die vier OUTPUT-Parameter werden erst nach der eigenen Temp-DDL initialisiert.
-- Schlägt diese DDL fehl, werden ihre neuen Werte nicht zugesichert. Bei dieser
-- Anlage bleiben positive oder unbegrenzte eingehende LOCK_TIMEOUT-Werte erhalten;
-- nach erfolgreicher Anlage setzt der Baustein LOCK_TIMEOUT 0.
-- 
-- Die Quelle darf keine berechneten Spalten, benutzerdefinierten oder
-- Assembly-Datentypen, typisiertes XML sowie timestamp-/rowversion-Spalten
-- enthalten. Bei einer Identitätsspalte der Quelle werden die Werte in eine
-- gewöhnliche Zielspalte kopiert; das Ziel erhält dadurch keine
-- Identitätseigenschaft.
-- 
-- Eine bereits passende Zielstruktur muss in Spaltenanzahl und -reihenfolge,
-- Spaltennamen, vergleichbarem Datentyp, Länge, Genauigkeit, Skala, Sortierung
-- und NULL-Zulässigkeit übereinstimmen. Sie darf keine Identitäts- oder
-- berechneten Spalten, benutzerdefinierten oder Assembly-Datentypen oder
-- typisiertes XML enthalten. Eine abweichende Zieltabelle kann nur angepasst
-- werden, wenn sie leer ist und genau eine beliebige Dummy-Spalte besitzt.
-- Passende vorhandene Ziele dürfen bereits Zeilen enthalten; die neuen Zeilen
-- werden angehängt.
-- 
-- Die interne Auflösung fügt Quell- und Zieltabellen vorübergehend
-- Markierungsspalten hinzu und entfernt sie wieder. Die Schemaanpassung verwendet
-- einen Brücken- und ALTER-TABLE-Batch. Diese DDL kann sichtbare Tabellenänderungen
-- hinterlassen, wenn ein späterer Schritt fehlschlägt. Die Procedure garantiert
-- weder eine Transaktion noch atomaren Rollback oder Bereinigung nach Fehlern.
-- Die interne Schnittstelle ist an den versiongleichen Framework-Aufrufer
-- gebunden.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalWriteResultTable
CREATE OR ALTER PROCEDURE [monitor].[InternalWriteResultTable]
      @SourceTable  sysname
    , @TargetTable  sysname
    , @InsertedRows bigint         = NULL OUTPUT
    , @StatusCode   varchar(40)    = NULL OUTPUT
    , @ErrorNumber  int            = NULL OUTPUT
    , @ErrorMessage nvarchar(2048) = NULL OUTPUT
    , @ThrowOnError bit            = 0
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalWriteResultTable
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalWriteResultTable') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalWriteResultTable"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalWriteResultTable"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/095_USP_InternalWriteResultTable.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalWriteResultTable'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kopiert die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers. Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann an die Quellstruktur angepasst werden; eine passende Tabelle erhält die Zeilen als Anhang.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalWriteResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[columns]`, `[sys].[tables]`, `[sys].[types]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @SourceTable | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @TargetTable | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @InsertedRows | bigint OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorNumber | int OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ThrowOnError | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceTable:** @SourceTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor nicht reserviert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TargetTable:** @TargetTable sysname Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch sein.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@InsertedRows:** @InsertedRows bigint = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** @StatusCode varchar(40) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status: AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang; INVALID_PARAMETER bezeichnet ungültige Parameter; LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten; SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare Quell- beziehungsweise Zieltabelle; METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile nicht sichtbar war; UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten oder mit nicht unterstützter Spaltenstruktur; TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch angepasst werden kann; TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen '
            + N'Fehler bei Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumber:** @ErrorNumber int = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** @ErrorMessage nvarchar(2048) = NULL OUTPUT Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ThrowOnError:** @ThrowOnError bit = 0 Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus. Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010 umgewandelt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Im Normalpfad gibt die interne Procedure kein fachliches Resultset aus. Sie kopiert Zeilen aus der vorhandenen lokalen #Temp-Quelle in das lokale #Temp-Ziel; ein Dummy-Ziel kann an die Quellstruktur angepasst werden. `@InsertedRows` (bigint OUTPUT) zählt nach dem finalen INSERT dessen `@@ROWCOUNT`, nicht die gesamte Zielhistorie und keine atomar gesicherte Änderung. `@StatusCode` (varchar(40) OUTPUT) meldet AVAILABLE, INVALID_PARAMETER, LOCK_TIMEOUT, SOURCE_NOT_FOUND, TARGET_NOT_FOUND, METADATA_NOT_VISIBLE, UNSUPPORTED_SOURCE_SCHEMA, TARGET_SCHEMA_MISMATCH oder TABLE_WRITE_ERROR. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) enthalten einen abgefangenen nativen Fehler beziehungsweise eine Diagnose oder bleiben NULL. Die vier Ausgaben werden erst nach eigener Temp-DDL initialisiert; native Fehler außerhalb dieses Rahmens können entweichen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalWriteResultTable'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalWriteResultTable] @SourceTable=NULL, @TargetTable=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + N'Objekt       : monitor.InternalWriteResultTable'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-19'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten'
            + NCHAR(10)
            + N'               Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.'
            + NCHAR(10)
            + N'               Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann'
            + NCHAR(10)
            + N'               an die Quellstruktur angepasst werden; eine passende Tabelle'
            + NCHAR(10)
            + N'               erhält die Zeilen als Anhang.'
            + NCHAR(10)
            + N'Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.'
            + NCHAR(10)
            + N'               Globale ##Temp-Tabellen, permanente Tabellen und das reservierte'
            + NCHAR(10)
            + N'               Zielpräfix #Monitor sind nicht zugelassen.'
            + NCHAR(10)
            + N'Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die'
            + NCHAR(10)
            + N'               tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale'
            + NCHAR(10)
            + N'               Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu'
            + NCHAR(10)
            + N'               1000 ms.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.InternalWriteResultTable'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-19'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Kopiert die Spaltenwerte eines bereits materialisierten'
            + NCHAR(10)
            + N'               Analyseergebnisses in eine lokale Temp-Tabelle des Aufrufers.'
            + NCHAR(10)
            + N'               Eine leere Tabelle mit genau einer beliebigen Dummy-Spalte kann'
            + NCHAR(10)
            + N'               an die Quellstruktur angepasst werden; eine passende Tabelle'
            + NCHAR(10)
            + N'               erhält die Zeilen als Anhang.'
            + NCHAR(10)
            + N'Sicherheit   : Quelle und Ziel müssen vorhandene lokale #Temp-Tabellen sein.'
            + NCHAR(10)
            + N'               Globale ##Temp-Tabellen, permanente Tabellen und das reservierte'
            + NCHAR(10)
            + N'               Zielpräfix #Monitor sind nicht zugelassen.'
            + NCHAR(10)
            + N'Locking      : Fremde Tabellenoperationen verwenden LOCK_TIMEOUT 0 und die'
            + NCHAR(10)
            + N'               tempdb-Katalogauflösung verwendet WITH (NOLOCK). Eigene lokale'
            + NCHAR(10)
            + N'               Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu'
            + NCHAR(10)
            + N'               1000 ms.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'PARAMETER'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceTable sysname'
            + NCHAR(10)
            + N'  Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer'
            + NCHAR(10)
            + N'  vorhandenen lokalen #Temp-Quelltabelle, etwa in Form eines einzelnen'
            + NCHAR(10)
            + N'  Tabellennamens. NULL, der Leerwert, Namen ohne führendes #, globale ##Namen'
            + NCHAR(10)
            + N'  und Namen mit LEN größer als 116 nach der SQL-Server-Bindung sind ungültig.'
            + NCHAR(10)
            + N'  Der Wert wird nicht getrimmt. Die Eingabe ist kein Schema- oder'
            + NCHAR(10)
            + N'  Klammerausdruck; die Procedure quotiert den Namen nativ. Die Quell- und'
            + NCHAR(10)
            + N'  Zielnamen werden ohne Beachtung der Groß-/Kleinschreibung verglichen, um'
            + NCHAR(10)
            + N'  identische Namen zurückzuweisen. Für die Quelle ist das Präfix #Monitor'
            + NCHAR(10)
            + N'  nicht reserviert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@TargetTable sysname'
            + NCHAR(10)
            + N'  Default: kein Default (Pflichtparameter). Erwartet den unqualifizierten Namen einer'
            + NCHAR(10)
            + N'  vorhandenen lokalen #Temp-Zieltabelle. NULL, der Leerwert, Namen ohne'
            + NCHAR(10)
            + N'  führendes #, globale ##Namen und Namen mit LEN größer als 116 nach der'
            + NCHAR(10)
            + N'  SQL-Server-Bindung sind ungültig. Der Wert wird nicht getrimmt. Die Eingabe'
            + NCHAR(10)
            + N'  ist kein Schema- oder Klammerausdruck; die Procedure quotiert den Namen'
            + NCHAR(10)
            + N'  nativ. Namen mit dem Präfix #Monitor sind ohne Beachtung der'
            + NCHAR(10)
            + N'  Groß-/Kleinschreibung reserviert und ungültig. Quelle und Ziel dürfen nach'
            + NCHAR(10)
            + N'  einem Vergleich ohne Beachtung der Groß-/Kleinschreibung nicht identisch'
            + NCHAR(10)
            + N'  sein.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@InsertedRows bigint = NULL OUTPUT'
            + NCHAR(10)
            + N'  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird'
            + NCHAR(10)
            + N'  ignoriert. Nach erfolgreicher Anlage der internen Temp-Tabellen wird der'
            + NCHAR(10)
            + N'  Parameter auf 0 initialisiert. Nach dem finalen INSERT SELECT enthält er'
            + NCHAR(10)
            + N'  @@ROWCOUNT dieses INSERTs. Der Wert zählt nicht unabhängig davon die gesamte'
            + NCHAR(10)
            + N'  Historie der Zieltabelle und garantiert keine Rücknahme bei einem späteren'
            + NCHAR(10)
            + N'  Fehler. Zum Empfang muss ein gebundener Aufruf eine bigint-Variable mit'
            + NCHAR(10)
            + N'  OUTPUT übergeben; das Argument kann ausgelassen werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@StatusCode varchar(40) = NULL OUTPUT'
            + NCHAR(10)
            + N'  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird'
            + NCHAR(10)
            + N'  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf'
            + NCHAR(10)
            + N'  AVAILABLE initialisiert. Der Parameter liefert genau einen dieser Status:'
            + NCHAR(10)
            + N'  AVAILABLE bezeichnet einen erfolgreichen Schreibvorgang;'
            + NCHAR(10)
            + N'  INVALID_PARAMETER bezeichnet ungültige Parameter;'
            + NCHAR(10)
            + N'  LOCK_TIMEOUT bezeichnet den abgefangenen Sperrtimeout in den dafür'
            + NCHAR(10)
            + N'  vorgesehenen Markierungs-, Leerheitsprüfungs- oder Schemaanpassungsschritten;'
            + NCHAR(10)
            + N'  SOURCE_NOT_FOUND und TARGET_NOT_FOUND bezeichnen eine nicht auflösbare'
            + NCHAR(10)
            + N'  Quell- beziehungsweise Zieltabelle;'
            + NCHAR(10)
            + N'  METADATA_NOT_VISIBLE bezeichnet eine vorhandene Tabelle, deren Katalogzeile'
            + NCHAR(10)
            + N'  nicht sichtbar war;'
            + NCHAR(10)
            + N'  UNSUPPORTED_SOURCE_SCHEMA bezeichnet eine Quelle ohne exportierbare Spalten'
            + NCHAR(10)
            + N'  oder mit nicht unterstützter Spaltenstruktur;'
            + NCHAR(10)
            + N'  TARGET_SCHEMA_MISMATCH bezeichnet ein Ziel, das weder exakt passt noch'
            + NCHAR(10)
            + N'  angepasst werden kann;'
            + NCHAR(10)
            + N'  TABLE_WRITE_ERROR bezeichnet einen sonstigen abgefangenen Fehler bei'
            + NCHAR(10)
            + N'  Tabellenänderungen oder beim finalen INSERT SELECT. Der finale INSERT SELECT'
            + NCHAR(10)
            + N'  wird auch bei Fehler 1222 als TABLE_WRITE_ERROR gemeldet. Zum Empfang muss'
            + NCHAR(10)
            + N'  ein gebundener Aufruf eine varchar(40)-Variable mit OUTPUT übergeben; das'
            + NCHAR(10)
            + N'  Argument kann ausgelassen werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorNumber int = NULL OUTPUT'
            + NCHAR(10)
            + N'  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird'
            + NCHAR(10)
            + N'  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL'
            + NCHAR(10)
            + N'  initialisiert. Bei einem abgefangenen nativen Fehler enthält er dessen'
            + NCHAR(10)
            + N'  Fehlernummer; bei Validierungsfehlern ohne abgefangenen nativen Fehler bleibt'
            + NCHAR(10)
            + N'  er NULL. Fehler, die nicht abgefangen werden, etwa ein Fehler bei der'
            + NCHAR(10)
            + N'  anfänglichen Anlage der internen Temp-Tabellen, werden nicht durch diesen'
            + NCHAR(10)
            + N'  Parameter zugesichert. Zum Empfang muss ein gebundener Aufruf eine'
            + NCHAR(10)
            + N'  int-Variable mit OUTPUT übergeben; das Argument kann ausgelassen werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorMessage nvarchar(2048) = NULL OUTPUT'
            + NCHAR(10)
            + N'  Optionaler OUTPUT-Parameter mit Default NULL. Der eingehende Wert wird'
            + NCHAR(10)
            + N'  ignoriert und nach erfolgreicher Anlage der internen Temp-Tabellen auf NULL'
            + NCHAR(10)
            + N'  initialisiert. Bei einem behandelten Fehler enthält er Validierungs- oder'
            + NCHAR(10)
            + N'  Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang muss ein gebundener'
            + NCHAR(10)
            + N'  Aufruf eine nvarchar(2048)-Variable mit OUTPUT übergeben; das Argument kann'
            + NCHAR(10)
            + N'  ausgelassen werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ThrowOnError bit = 0'
            + NCHAR(10)
            + N'  Optionaler Eingabeparameter mit Default 0; beim Auslassen gilt 0. Leerer'
            + NCHAR(10)
            + N'  Text ist keine unterstützte Schalterform. Der Wert 0 gibt behandelte'
            + NCHAR(10)
            + N'  Fehler über die OUTPUT-Parameter zurück. Der Wert 1 löst für einen'
            + NCHAR(10)
            + N'  behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, wird als'
            + NCHAR(10)
            + N'  INVALID_PARAMETER zurückgegeben und löst selbst keinen Fehler 51010 aus.'
            + NCHAR(10)
            + N'  Auch bei 1 werden nicht alle nativen Fehler abgefangen und in Fehler 51010'
            + NCHAR(10)
            + N'  umgewandelt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'VERARBEITUNG UND GRENZEN'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die vier OUTPUT-Parameter werden erst nach der eigenen Temp-DDL initialisiert.'
            + NCHAR(10)
            + N'Schlägt diese DDL fehl, werden ihre neuen Werte nicht zugesichert. Bei dieser'
            + NCHAR(10)
            + N'Anlage bleiben positive oder unbegrenzte eingehende LOCK_TIMEOUT-Werte erhalten;'
            + NCHAR(10)
            + N'nach erfolgreicher Anlage setzt der Baustein LOCK_TIMEOUT 0.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Quelle darf keine berechneten Spalten, benutzerdefinierten oder'
            + NCHAR(10)
            + N'Assembly-Datentypen, typisiertes XML sowie timestamp-/rowversion-Spalten'
            + NCHAR(10)
            + N'enthalten. Bei einer Identitätsspalte der Quelle werden die Werte in eine'
            + NCHAR(10)
            + N'gewöhnliche Zielspalte kopiert; das Ziel erhält dadurch keine'
            + NCHAR(10)
            + N'Identitätseigenschaft.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Eine bereits passende Zielstruktur muss in Spaltenanzahl und -reihenfolge,'
            + NCHAR(10)
            + N'Spaltennamen, vergleichbarem Datentyp, Länge, Genauigkeit, Skala, Sortierung'
            + NCHAR(10)
            + N'und NULL-Zulässigkeit übereinstimmen. Sie darf keine Identitäts- oder'
            + NCHAR(10)
            + N'berechneten Spalten, benutzerdefinierten oder Assembly-Datentypen oder'
            + NCHAR(10)
            + N'typisiertes XML enthalten. Eine abweichende Zieltabelle kann nur angepasst'
            + NCHAR(10)
            + N'werden, wenn sie leer ist und genau eine beliebige Dummy-Spalte besitzt.'
            + NCHAR(10)
            + N'Passende vorhandene Ziele dürfen bereits Zeilen enthalten; die neuen Zeilen'
            + NCHAR(10)
            + N'werden angehängt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die interne Auflösung fügt Quell- und Zieltabellen vorübergehend'
            + NCHAR(10)
            + N'Markierungsspalten hinzu und entfernt sie wieder. Die Schemaanpassung verwendet'
            + NCHAR(10)
            + N'einen Brücken- und ALTER-TABLE-Batch. Diese DDL kann sichtbare Tabellenänderungen'
            + NCHAR(10)
            + N'hinterlassen, wenn ein späterer Schritt fehlschlägt. Die Procedure garantiert'
            + NCHAR(10)
            + N'weder eine Transaktion noch atomaren Rollback oder Bereinigung nach Fehlern.'
            + NCHAR(10)
            + N'Die interne Schnittstelle ist an den versiongleichen Framework-Aufrufer'
            + NCHAR(10)
            + N'gebunden.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalWriteResultTable
        RETURN;
    END;


    -- Ein geerbter NOWAIT-Wert darf die eigene TempDB-Metadatenanlage
    -- nicht wegen einer kurzzeitigen Kollision abbrechen. Nur diese lokale
    -- Anlage erhält bei eingehendem Timeout 0 ein Zeitbudget von 1000 ms.
    DECLARE @OwnDdlOriginalLockTimeout int=@@LOCK_TIMEOUT;
    BEGIN TRY
        IF @OwnDdlOriginalLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#InternalWriteResultTable_SourceSchema]
        (
              [ColumnId] int NOT NULL
            , [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [TypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [SystemTypeId] tinyint NOT NULL
            , [MaxLength] smallint NOT NULL
            , [Precision] tinyint NOT NULL
            , [Scale] tinyint NOT NULL
            , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
            , [IsNullable] bit NOT NULL
            , [IsIdentity] bit NOT NULL
            , [IsComputed] bit NOT NULL
            , [IsUserDefined] bit NOT NULL
            , [IsAssemblyType] bit NOT NULL
            , [XmlCollectionId] int NOT NULL
        );

        CREATE TABLE [#InternalWriteResultTable_TargetSchema]
        (
              [ColumnId] int NOT NULL
            , [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [TypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [SystemTypeId] tinyint NOT NULL
            , [MaxLength] smallint NOT NULL
            , [Precision] tinyint NOT NULL
            , [Scale] tinyint NOT NULL
            , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
            , [IsNullable] bit NOT NULL
            , [IsIdentity] bit NOT NULL
            , [IsComputed] bit NOT NULL
            , [IsUserDefined] bit NOT NULL
            , [IsAssemblyType] bit NOT NULL
            , [XmlCollectionId] int NOT NULL
        );
    END TRY
    BEGIN CATCH
        DECLARE @OwnDdlRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlOriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @OwnDdlRestoreSql;
        THROW;
    END CATCH;

    SET LOCK_TIMEOUT 0;

    DECLARE @TableThrowMessage nvarchar(2048);
    DECLARE @TableWriteStep varchar(32);

    SELECT
          @InsertedRows = 0
        , @StatusCode = 'AVAILABLE'
        , @ErrorNumber = NULL
        , @ErrorMessage = NULL;

    IF @ThrowOnError IS NULL OR @ThrowOnError NOT IN (0,1)
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@ThrowOnError muss 0 oder 1 enthalten.';
        GOTO TableWriteFailed;
    END;

    IF @SourceTable IS NULL
       OR LEFT(@SourceTable, 1) <> N'#'
       OR LEFT(@SourceTable, 2) = N'##'
       OR @TargetTable IS NULL
       OR LEFT(@TargetTable, 1) <> N'#'
       OR LEFT(@TargetTable, 2) = N'##'
       OR LEN(@SourceTable) > 116
       OR LEN(@TargetTable) > 116
       OR @TargetTable LIKE N'#Monitor%' COLLATE Latin1_General_100_CI_AS
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'@SourceTable und @TargetTable müssen lokale #Temp-Tabellen bezeichnen; ##Temp-, permanente Tabellen und das reservierte Präfix #Monitor sind nicht zulässig.';
        GOTO TableWriteFailed;
    END;

    IF @SourceTable = @TargetTable COLLATE Latin1_General_100_CI_AS
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @ErrorMessage = N'Quell- und Zieltabelle dürfen nicht identisch sein.';
        GOTO TableWriteFailed;
    END;

    DECLARE @SourceObjectId int = NULL;
    DECLARE @TargetObjectId int = NULL;
    DECLARE @SourceMarker sysname = N'__MonitorResolveSource_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
    DECLARE @TargetMarker sysname = N'__MonitorResolveTarget_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
    DECLARE @ResolveSql nvarchar(max);

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@SourceTable)
                        + N' ADD ' + QUOTENAME(@SourceMarker) + N' bit NULL;';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'SOURCE_NOT_FOUND' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die interne Quelltabelle des ausgewählten Resultsets konnte nicht aufgelöst werden: ' + ERROR_MESSAGE()
            , @TableWriteStep = 'SOURCE_MARKER_ADD';
        GOTO TableWriteFailed;
    END CATCH;

    SELECT @SourceObjectId = [c].[object_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [c].[object_id]
    WHERE [c].[name] = @SourceMarker;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@SourceTable)
                        + N' DROP COLUMN ' + QUOTENAME(@SourceMarker) + N';';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die temporäre Quellmarkierung konnte nicht entfernt werden: ' + ERROR_MESSAGE()
            , @TableWriteStep = 'SOURCE_MARKER_DROP';
        GOTO TableWriteFailed;
    END CATCH;

    IF @SourceObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'METADATA_NOT_VISIBLE'
            , @ErrorMessage = N'Die interne Quelltabelle ist vorhanden, ihre Katalogzeile war jedoch ohne Warten nicht sichtbar.';
        GOTO TableWriteFailed;
    END;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@TargetTable)
                        + N' ADD ' + QUOTENAME(@TargetMarker) + N' bit NULL;';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TARGET_NOT_FOUND' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'@TargetTable konnte nicht aufgelöst werden: ' + ERROR_MESSAGE()
            , @TableWriteStep = 'TARGET_MARKER_ADD';
        GOTO TableWriteFailed;
    END CATCH;

    SELECT @TargetObjectId = [c].[object_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [c].[object_id]
    WHERE [c].[name] = @TargetMarker;

    BEGIN TRY
        SET @ResolveSql = N'ALTER TABLE ' + QUOTENAME(@TargetTable)
                        + N' DROP COLUMN ' + QUOTENAME(@TargetMarker) + N';';
        EXEC [sys].[sp_executesql] @ResolveSql;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = N'Die temporäre Zielmarkierung konnte nicht entfernt werden: ' + ERROR_MESSAGE()
            , @TableWriteStep = 'TARGET_MARKER_DROP';
        GOTO TableWriteFailed;
    END CATCH;

    IF @TargetObjectId IS NULL
    BEGIN
        SELECT
              @StatusCode = 'METADATA_NOT_VISIBLE'
            , @ErrorMessage = N'@TargetTable ist vorhanden, ihre Katalogzeile war jedoch ohne Warten nicht sichtbar.';
        GOTO TableWriteFailed;
    END;

    INSERT [#InternalWriteResultTable_SourceSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @SourceObjectId;

    IF NOT EXISTS (SELECT 1 FROM [#InternalWriteResultTable_SourceSchema])
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset besitzt keine exportierbaren Spalten.';
        GOTO TableWriteFailed;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_SourceSchema]
        WHERE [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
           OR [TypeName] IN (N'timestamp', N'rowversion')
    )
    BEGIN
        SELECT
              @StatusCode = 'UNSUPPORTED_SOURCE_SCHEMA'
            , @ErrorMessage = N'Das ausgewählte Resultset enthält einen nicht sicher reproduzierbaren Datentyp oder eine berechnete Spalte.';
        GOTO TableWriteFailed;
    END;

    INSERT [#InternalWriteResultTable_TargetSchema]
    (
          [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
        , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
        , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
    )
    SELECT
          CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
        , [c].[name]
        , [t].[name]
        , [c].[system_type_id]
        , [c].[max_length]
        , [c].[precision]
        , [c].[scale]
        , [c].[collation_name]
        , [c].[is_nullable]
        , [c].[is_identity]
        , [c].[is_computed]
        , [t].[is_user_defined]
        , [t].[is_assembly_type]
        , [c].[xml_collection_id]
    FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
      ON [t].[user_type_id] = [c].[user_type_id]
    WHERE [c].[object_id] = @TargetObjectId;

    DECLARE @TargetColumnCount int;
    DECLARE @TargetHasRows bit = 0;
    DECLARE @DummyColumnName sysname;
    DECLARE @TargetNeedsAdaptation bit = 0;

    SELECT
          @TargetColumnCount = COUNT(*)
        , @DummyColumnName = MAX([ColumnName])
    FROM [#InternalWriteResultTable_TargetSchema];

    IF EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
    )
    OR EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
    )
    OR EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_TargetSchema]
        WHERE [IsIdentity] = 1
           OR [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
    )
        SET @TargetNeedsAdaptation = 1;

    IF @TargetNeedsAdaptation = 1
    BEGIN
        IF @TargetColumnCount <> 1
        BEGIN
            SELECT
                  @StatusCode = 'TARGET_SCHEMA_MISMATCH'
                , @ErrorMessage = N'Eine abweichende Zieltabelle wird nur dann automatisch angepasst, wenn sie leer ist und genau eine beliebige Dummy-Spalte besitzt.';
            GOTO TableWriteFailed;
        END;

        DECLARE @HasRowsSql nvarchar(max) =
            N'SELECT @HasRows = CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM '
            + QUOTENAME(@TargetTable)
            + N') THEN 1 ELSE 0 END);';

        BEGIN TRY
            EXEC [sys].[sp_executesql]
                  @HasRowsSql
                , N'@HasRows bit OUTPUT'
                , @HasRows = @TargetHasRows OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT
                  @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
                , @ErrorNumber = ERROR_NUMBER()
                , @ErrorMessage = ERROR_MESSAGE()
                , @TableWriteStep = 'TARGET_EMPTY_CHECK';
            GOTO TableWriteFailed;
        END CATCH;

        IF @TargetHasRows = 1
        BEGIN
            SELECT
                  @StatusCode = 'TARGET_SCHEMA_MISMATCH'
                , @ErrorMessage = N'Die Zieltabelle muss leer sein, bevor ihre einzelne Dummy-Spalte ersetzt werden kann.';
            GOTO TableWriteFailed;
        END;

        DECLARE @ColumnDefinitions nvarchar(max);

        SELECT @ColumnDefinitions = STUFF
        (
            (
                SELECT
                      N', '
                    + QUOTENAME([s].[ColumnName])
                    + N' '
                    + CASE
                          WHEN [s].[TypeName] IN (N'varchar', N'char', N'varbinary', N'binary')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength]) END + N')'
                          WHEN [s].[TypeName] IN (N'nvarchar', N'nchar')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CASE WHEN [s].[MaxLength] = -1 THEN N'MAX' ELSE CONVERT(nvarchar(10), [s].[MaxLength] / 2) END + N')'
                          WHEN [s].[TypeName] IN (N'decimal', N'numeric')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N',' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] IN (N'datetime2', N'datetimeoffset', N'time')
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Scale]) + N')'
                          WHEN [s].[TypeName] = N'float'
                              THEN QUOTENAME([s].[TypeName]) + N'(' + CONVERT(nvarchar(10), [s].[Precision]) + N')'
                          ELSE QUOTENAME([s].[TypeName])
                      END
                    + CASE WHEN [s].[CollationName] IS NULL THEN N'' ELSE N' COLLATE ' + [s].[CollationName] END
                    + CASE WHEN [s].[IsNullable] = 1 THEN N' NULL' ELSE N' NOT NULL' END
                FROM [#InternalWriteResultTable_SourceSchema] AS [s]
                ORDER BY [s].[ColumnId]
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'nvarchar(max)')
            , 1
            , 2
            , N''
        );

        DECLARE @BridgeColumnName sysname = N'__MonitorBridge_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
        WHILE EXISTS (SELECT 1 FROM [#InternalWriteResultTable_SourceSchema] WHERE [ColumnName] = @BridgeColumnName)
           OR EXISTS (SELECT 1 FROM [#InternalWriteResultTable_TargetSchema] WHERE [ColumnName] = @BridgeColumnName)
            SET @BridgeColumnName = N'__MonitorBridge_' + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');

        BEGIN TRY
            DECLARE @AlterSql nvarchar(max) =
                  N'ALTER TABLE ' + QUOTENAME(@TargetTable) + N' ADD ' + QUOTENAME(@BridgeColumnName) + N' bit NULL;'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' DROP COLUMN ' + QUOTENAME(@DummyColumnName) + N';'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' ADD ' + @ColumnDefinitions + N';'
                + N' ALTER TABLE ' + QUOTENAME(@TargetTable) + N' DROP COLUMN ' + QUOTENAME(@BridgeColumnName) + N';';

            EXEC [sys].[sp_executesql] @AlterSql;
        END TRY
        BEGIN CATCH
            SELECT
                  @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'TABLE_WRITE_ERROR' END
                , @ErrorNumber = ERROR_NUMBER()
                , @ErrorMessage = ERROR_MESSAGE()
                , @TableWriteStep = 'TARGET_SCHEMA_ADAPT';
            GOTO TableWriteFailed;
        END CATCH;

        DELETE FROM [#InternalWriteResultTable_TargetSchema];

        INSERT [#InternalWriteResultTable_TargetSchema]
        (
              [ColumnId], [ColumnName], [TypeName], [SystemTypeId], [MaxLength]
            , [Precision], [Scale], [CollationName], [IsNullable], [IsIdentity]
            , [IsComputed], [IsUserDefined], [IsAssemblyType], [XmlCollectionId]
        )
        SELECT
              CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id]))
            , [c].[name]
            , [t].[name]
            , [c].[system_type_id]
            , [c].[max_length]
            , [c].[precision]
            , [c].[scale]
            , [c].[collation_name]
            , [c].[is_nullable]
            , [c].[is_identity]
            , [c].[is_computed]
            , [t].[is_user_defined]
            , [t].[is_assembly_type]
            , [c].[xml_collection_id]
        FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
        JOIN [tempdb].[sys].[types] AS [t] WITH (NOLOCK)
          ON [t].[user_type_id] = [c].[user_type_id]
        WHERE [c].[object_id] = @TargetObjectId;
    END;

    IF EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
    )
    OR EXISTS
    (
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_TargetSchema]
        EXCEPT
        SELECT
              [ColumnId], [ColumnName], [SystemTypeId], [MaxLength], [Precision]
            , [Scale], [CollationName], [IsNullable]
        FROM [#InternalWriteResultTable_SourceSchema]
    )
    OR EXISTS
    (
        SELECT 1
        FROM [#InternalWriteResultTable_TargetSchema]
        WHERE [IsIdentity] = 1
           OR [IsComputed] = 1
           OR [IsUserDefined] = 1
           OR [IsAssemblyType] = 1
           OR [XmlCollectionId] <> 0
    )
    BEGIN
        SELECT
              @StatusCode = 'TARGET_SCHEMA_MISMATCH'
            , @ErrorMessage = N'Die vorhandene Struktur von @TargetTable stimmt nicht exakt mit dem ausgewählten Resultset überein.';
        GOTO TableWriteFailed;
    END;

    DECLARE @ColumnList nvarchar(max);

    SELECT @ColumnList = STUFF
    (
        (
            SELECT N', ' + QUOTENAME([s].[ColumnName])
            FROM [#InternalWriteResultTable_SourceSchema] AS [s]
            ORDER BY [s].[ColumnId]
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'nvarchar(max)')
        , 1
        , 2
        , N''
    );

    BEGIN TRY
        DECLARE @InsertSql nvarchar(max) =
              N'INSERT ' + QUOTENAME(@TargetTable) + N' (' + @ColumnList + N')'
            + N' SELECT ' + @ColumnList + N' FROM ' + QUOTENAME(@SourceTable) + N';'
            + N' SET @Rows = @@ROWCOUNT;';

        EXEC [sys].[sp_executesql]
              @InsertSql
            , N'@Rows bigint OUTPUT'
            , @Rows = @InsertedRows OUTPUT;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'TABLE_WRITE_ERROR'
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();
    END CATCH;

    IF @StatusCode <> 'AVAILABLE'
        GOTO TableWriteFailed;

    RETURN;

TableWriteFailed:
    IF @StatusCode = 'LOCK_TIMEOUT' AND @ErrorNumber = 1222
        SET @ErrorMessage = CONCAT
        (
              N'TargetTable="', REPLACE(STRING_ESCAPE(@TargetTable, 'json'), N'%', N'\u0025')
            , N'"; SqlStep=', @TableWriteStep, N'; ', @ErrorMessage
        );

    IF @ThrowOnError = 1
    BEGIN
        SET @TableThrowMessage = CONCAT
        (
              N'TABLE-Ausgabe fehlgeschlagen ('
            , COALESCE(@StatusCode, N'UNKNOWN')
            , N'): '
            , COALESCE(@ErrorMessage, N'Unbekannter Fehler.')
        );
        THROW 51010, @TableThrowMessage, 1;
    END;
END;
GO
