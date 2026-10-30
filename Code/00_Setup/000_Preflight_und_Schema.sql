USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt/Datei : 000_Preflight_und_Schema.sql
Version      : 2.1.0
Zweck        : Das Skript bereitet die ausgewählte Installationsdatenbank für die folgenden
               Setup-Skripte vor. Das Skript hat keine Prozedurparameter. Ersetzen
               Sie den USE-Platzhalter vor der Ausführung durch den tatsächlichen
               Datenbanknamen; das Skript wählt keine Datenbank automatisch aus.
Voraussetzung: SQL Server 2019 oder höher sowie die für die Schemaanlage nötigen
               DDL-Rechte. Die erste Batch prüft SERVERPROPERTY('ProductMajorVersion');
               NULL oder ein Wert unter 15 löst dort THROW 50001 aus. Die Prüfung
               umfasst keine vollständige Feature- oder Berechtigungsqualifikation.
Seiteneffekte: Das Skript setzt NOCOUNT und XACT_ABORT für die Sitzung auf ON.
               Vorherige Werte werden weder gesichert noch wiederhergestellt.
               GO trennt Baseline-/Collation-Prüfung und Schemaanlage. Abweichungen
               der Server-, tempdb- oder Zieldatenbank-Collation erzeugen Meldungen
               mit Severity 10 und blockieren die Fortsetzung nicht. SQL_Latin1_General_CP1_CS_AS ist die getestete Collation; die Warnung ist keine
               Qualifikation beliebiger Collations oder aller Vergleichspfade.
               Das Schema monitor wird nur angelegt, wenn es fehlt, dann mit dbo-
               Autorisierung. Ein vorhandenes Schema wird weder validiert noch in
               Ownership oder Berechtigungen korrigiert. Fehler sind vom Aufrufer
               anhand der Meldungen zu behandeln; Batches versprechen keinen
               atomaren Abbruch oder Rollback des gesamten Installationspakets.
Prüfbeispiel: Ein synthetischer Schema-Check kann nach dem Skript lesend erfolgen:
               SELECT [name], [principal_id]
               FROM [sys].[schemas] WITH (NOLOCK)
               WHERE [name] = N'monitor';
               Das Beispiel prüft Sichtbarkeit und Namen, nicht die Ownership.
Änderungen   : 2.1.0 - Collation-Prüfung von Abbruch auf Warnung geändert;
                         das Framework arbeitet collation-agnostisch durch
                         explizite COLLATE-Klauseln in allen Vergleichen.
               2.0.0 - Erstfassung mit harter Collation-Prüfung.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProductMajorVersion int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
IF @ProductMajorVersion IS NULL OR @ProductMajorVersion < 15
    THROW 50001, N'Das Analyseframework unterstützt mindestens SQL Server 2019 (Major Version 15).', 1;

DECLARE @ExpectedCollation sysname = N'SQL_Latin1_General_CP1_CS_AS';
DECLARE @ServerCollation sysname = CONVERT(sysname, SERVERPROPERTY(N'Collation'));
DECLARE @TempDbCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [name]=N'tempdb');
DECLARE @TargetDatabaseCollation sysname = (SELECT [collation_name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID());
DECLARE @CollationWarningIssued bit = 0;

IF @ServerCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    RAISERROR(N'[monitor] WARNUNG: Server-Collation ist %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Das Framework verwendet explizite COLLATE-Klauseln und arbeitet grundsätzlich collation-agnostisch. Getestet ist ausschließlich SQL_Latin1_General_CP1_CS_AS; abweichendes Verhalten bei Filterlisten und Objektnamenvergleichen ist möglich.', 10, 1, @ServerCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @TempDbCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    RAISERROR(N'[monitor] WARNUNG: tempdb-Collation ist %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Temporäre Tabellen verwenden explizite COLLATE-Klauseln; Konflikte sind nicht zu erwarten.', 10, 1, @TempDbCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @TargetDatabaseCollation COLLATE Latin1_General_100_BIN2 <> @ExpectedCollation COLLATE Latin1_General_100_BIN2
BEGIN
    DECLARE @TargetDbName sysname = (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());
    RAISERROR(N'[monitor] WARNUNG: Installationsdatenbank %s hat Collation %s (erwartet: SQL_Latin1_General_CP1_CS_AS). Das Framework funktioniert, jedoch ohne Garantie für ungetestete Collations.', 10, 1, @TargetDbName, @TargetDatabaseCollation) WITH NOWAIT;
    SET @CollationWarningIssued = 1;
END;
IF @CollationWarningIssued = 1
    RAISERROR(N'[monitor] HINWEIS: Die Installation wird fortgesetzt. Das Framework verwendet durchgängig explizite COLLATE SQL_Latin1_General_CP1_CS_AS in Vergleichen, Temp-Tabellen und Rückgabewerten. Bei Problemen prüfen Sie bitte zuerst Filterlisten mit bracket-quotierten Objektnamen.', 10, 1) WITH NOWAIT;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[schemas] AS [s] WITH (NOLOCK) WHERE [s].[name] = N'monitor')
BEGIN
    EXEC [sys].[sp_executesql] N'CREATE SCHEMA [monitor] AUTHORIZATION [dbo];';
END;
GO
