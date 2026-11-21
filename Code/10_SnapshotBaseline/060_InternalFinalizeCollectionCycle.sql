/*
Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.

Schnittstelle und Parameter
---------------------------
`@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne
Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt
null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile
darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und
ist nicht gleich NULL.

`@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,
auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit
nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.

`@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,
1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;
keine Konsistenzprüfung mit StatusCode.

`@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.
NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung
gespeichert und nicht als SQL-Fehler ausgelöst.

`@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für
Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;
Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.

Verhalten und Grenzen
---------------------
Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf
SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage
übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den
zugehörigen Tabellen ermittelt. Keine Quellerfassung.

Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null
Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile
gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion
und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren
ist nicht gesperrt oder als einmalig abgesichert.
*/
-- USAGE_SKILL_BEGIN snapshot.InternalFinalizeCollectionCycle 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "snapshot.InternalFinalizeCollectionCycle"
-- schema_name: "snapshot"
-- object_name: "InternalFinalizeCollectionCycle"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "snapshot_target"
-- is_internal: true
-- description: "Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen."
-- source_path: "Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql"
-- ---
-- 
-- # snapshot.InternalFinalizeCollectionCycle
-- 
-- ## Zweck und Einsatz
-- 
-- Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalFinalizeCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @CaptureRunId | bigint | ja | kein Default |
-- | @StatusCode | varchar(40) | ja | kein Default |
-- | @IsPartial | bit | ja | kein Default |
-- | @ErrorNumber | int | ja | kein Default |
-- | @ErrorMessage | nvarchar(2048) | ja | kein Default |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@CaptureRunId:** `@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und ist nicht gleich NULL.
-- 
-- **@StatusCode:** `@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text, auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.
-- 
-- **@IsPartial:** `@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell, 1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL; keine Konsistenzprüfung mit StatusCode.
-- 
-- **@ErrorNumber:** `@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl. NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung gespeichert und nicht als SQL-Fehler ausgelöst.
-- 
-- **@ErrorMessage:** `@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert; Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Weder Fach-Resultset noch OUTPUT-Parameter. Die Procedure aktualisiert die vorhandene CaptureRun-Zeile mit StatusCode, IsPartial, ErrorNumber, ErrorMessage und Endzeit; fehlt der CaptureRun, werden null Zeilen aktualisiert und kein eigener Resultsetstatus geliefert. Die übergebenen Statuswerte werden nicht zu einer geschlossenen Fach-Wertemenge umgedeutet.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalFinalizeCollectionCycle';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [snapshot].[InternalFinalizeCollectionCycle] @CaptureRunId=NULL, @StatusCode=NULL, @IsPartial=NULL, @ErrorNumber=NULL, @ErrorMessage=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.
-- 
-- Schnittstelle und Parameter
-- ---------------------------
-- `@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne
-- Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt
-- null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile
-- darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und
-- ist nicht gleich NULL.
-- 
-- `@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,
-- auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit
-- nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.
-- 
-- `@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,
-- 1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;
-- keine Konsistenzprüfung mit StatusCode.
-- 
-- `@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.
-- NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung
-- gespeichert und nicht als SQL-Fehler ausgelöst.
-- 
-- `@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für
-- Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;
-- Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.
-- 
-- Verhalten und Grenzen
-- ---------------------
-- Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf
-- SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage
-- übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den
-- zugehörigen Tabellen ermittelt. Keine Quellerfassung.
-- 
-- Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null
-- Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile
-- gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion
-- und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren
-- ist nicht gesperrt oder als einmalig abgesichert.
-- ```
-- 
-- USAGE_SKILL_END snapshot.InternalFinalizeCollectionCycle
CREATE OR ALTER PROCEDURE [snapshot].[InternalFinalizeCollectionCycle]
      @CaptureRunId    bigint
    , @StatusCode      varchar(40)
    , @IsPartial       bit
    , @ErrorNumber     int
    , @ErrorMessage    nvarchar(2048)
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN snapshot.InternalFinalizeCollectionCycle
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalFinalizeCollectionCycle') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalFinalizeCollectionCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalFinalizeCollectionCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalFinalizeCollectionCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalFinalizeCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartial | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumber | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunId:** `@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und ist nicht gleich NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** `@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text, auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartial:** `@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell, 1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL; keine Konsistenzprüfung mit StatusCode.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumber:** `@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl. NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung gespeichert und nicht als SQL-Fehler ausgelöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** `@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert; Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Weder Fach-Resultset noch OUTPUT-Parameter. Die Procedure aktualisiert die vorhandene CaptureRun-Zeile mit StatusCode, IsPartial, ErrorNumber, ErrorMessage und Endzeit; fehlt der CaptureRun, werden null Zeilen aktualisiert und kein eigener Resultsetstatus geliefert. Die übergebenen Statuswerte werden nicht zu einer geschlossenen Fach-Wertemenge umgedeutet.'
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
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalFinalizeCollectionCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalFinalizeCollectionCycle] @CaptureRunId=NULL, @StatusCode=NULL, @IsPartial=NULL, @ErrorNumber=NULL, @ErrorMessage=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
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
            + N'Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Schnittstelle und Parameter'
            + NCHAR(10)
            + N'---------------------------'
            + NCHAR(10)
            + N'`@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne'
            + NCHAR(10)
            + N'Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt'
            + NCHAR(10)
            + N'null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile'
            + NCHAR(10)
            + N'darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und'
            + NCHAR(10)
            + N'ist nicht gleich NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,'
            + NCHAR(10)
            + N'auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit'
            + NCHAR(10)
            + N'nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,'
            + NCHAR(10)
            + N'1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;'
            + NCHAR(10)
            + N'keine Konsistenzprüfung mit StatusCode.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.'
            + NCHAR(10)
            + N'NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung'
            + NCHAR(10)
            + N'gespeichert und nicht als SQL-Fehler ausgelöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'`@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für'
            + NCHAR(10)
            + N'Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;'
            + NCHAR(10)
            + N'Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Verhalten und Grenzen'
            + NCHAR(10)
            + N'---------------------'
            + NCHAR(10)
            + N'Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf'
            + NCHAR(10)
            + N'SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage'
            + NCHAR(10)
            + N'übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den'
            + NCHAR(10)
            + N'zugehörigen Tabellen ermittelt. Keine Quellerfassung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null'
            + NCHAR(10)
            + N'Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile'
            + NCHAR(10)
            + N'gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion'
            + NCHAR(10)
            + N'und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren'
            + NCHAR(10)
            + N'ist nicht gesperrt oder als einmalig abgesichert.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END snapshot.InternalFinalizeCollectionCycle
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    UPDATE [snapshot].[CaptureRun]
    SET [EndedAtUtc]=SYSUTCDATETIME(),
        [StatusCode]=@StatusCode,
        [IsPartial]=@IsPartial,
        [ErrorNumber]=@ErrorNumber,
        [ErrorMessage]=@ErrorMessage,
        [MetricSampleCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId),
        [PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
    WHERE [CaptureRunId]=@CaptureRunId;
END;
GO
