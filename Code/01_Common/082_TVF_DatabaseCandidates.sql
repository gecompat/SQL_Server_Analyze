USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_DatabaseCandidates
Version      : 3.0.0
Stand        : 2026-07-20
Typ          : Inline Table-valued Function
Zweck        : Liefert sichtbare, online befindliche, zugreifbare Datenbanken,
               die den optionalen exakten Namen und das Pattern erfüllen.
SQL-Version  : SQL Server 2019 oder neuer. Regex-Ausführung übernimmt der
               Aufrufer versionsadaptiv; REGEX und REGEXI werden hier nicht
               abgeglichen.
Parameter    : @DatabaseNames nvarchar(max) = NULL; @SystemdatenbankenEinbeziehen
               bit = 0; @DatabaseNamePattern nvarchar(4000) = NULL. NULL,
               leerer Text oder Leerzeichen in der Namensliste bedeuten keine
               Einschränkung. Der bit-Wert 1 schließt System-IDs bis 4 ein;
               sonst werden nur IDs größer 4 berücksichtigt.
Datenquellen : master.sys.databases mit NOLOCK, monitor.TVF_ParseSqlNameList
               und monitor.TVF_ParsePattern. Snapshots (source_database_id
               nicht NULL) werden ausgeschlossen. Erforderlich sind ONLINE-
               Status und HAS_DBACCESS=1.
Filter       : Gültige exakte Namen werden zusätzlich zum Pattern angewandt;
               ungültige Listenelemente werden still ignoriert. Doppelte
               gültige Namen können Zeilen vervielfachen. LIKE wird hier
               case-sensitive ausgewertet. NONE, REGEX und REGEXI passieren
               ohne Patternabgleich. Ein ungültiges Parser-Pattern liefert
               null Kandidaten; die Funktion erzeugt keine Fehlerausgabe.
Ergebnis     : Zehn Spalten einschließlich RequestedOrdinal, das bei nicht
               eingeschränkter Namensliste NULL ist. Die Funktion garantiert
               weder eine Vorabmenge noch einen atomaren Katalogsnapshot,
               einen Datenbankstatus oder vollständige Erreichbarkeit. Ohne
               ORDER BY ist keine physische Reihenfolge zugesichert.
Beispiele   : SELECT * FROM [monitor].[TVF_DatabaseCandidates](NULL, 0, NULL);
               SELECT * FROM [monitor].[TVF_DatabaseCandidates](N'AppDb', 0, N'App%');
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_DatabaseCandidates 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_DatabaseCandidates"
-- schema_name: "monitor"
-- object_name: "TVF_DatabaseCandidates"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Liefert sichtbare, online befindliche, zugreifbare Datenbanken, die den optionalen exakten Namen und das Pattern erfüllen."
-- source_path: "Code/01_Common/082_TVF_DatabaseCandidates.sql"
-- ---
-- 
-- # monitor.TVF_DatabaseCandidates
-- 
-- ## Zweck und Einsatz
-- 
-- Liefert sichtbare, online befindliche, zugreifbare Datenbanken, die den optionalen exakten Namen und das Pattern erfüllen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht SELECT auf [monitor].[TVF_DatabaseCandidates] im vorgesehenen Datenbankkontext. Die Funktion nutzt `master.sys.databases`, HAS_DBACCESS und die beiden Namens-/Patternparser unter dem aktuellen Caller. Metadatensicht, ONLINE-Status und Zugang begrenzen die Zeilen; eine ausgeblendete Datenbank ist kein Existenzbeweis.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @DatabaseNames | nvarchar(max) | nein | NULL |
-- | @SystemdatenbankenEinbeziehen | bit | nein | 0 |
-- | @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
-- 
-- **@DatabaseNames:** Optionaler nvarchar(max)-Filter. NULL, leer oder nur U+0020 bedeutet keine Namenseinschränkung. Sonst verwendet die Funktion TVF_ParseSqlNameList; ungültige Elemente werden still ignoriert, doppelte gültige Namen können Zeilen vervielfachen.
-- 
-- **@SystemdatenbankenEinbeziehen:** bit, Default 0. Nur gebundenes 1 bezieht Datenbanken mit ID bis 4 ein; sonst bleiben sie ausgeschlossen. Die Funktion prüft die Sichtbarkeit, ONLINE und HAS_DBACCESS.
-- 
-- **@DatabaseNamePattern:** Optionales nvarchar(4000)-Pattern. NULL deaktiviert es. TVF_ParsePattern klassifiziert LIKE-/Regex-Form, diese Funktion selbst wertet REGEX/REGEXI nicht aus; der versionsadaptive Aufrufer trägt diese Verantwortung.
-- 
-- ## Resultate und Ausgabe
-- 
-- Null bis mehrere sichtbare ONLINE-Datenbanken nach Filter. Spalten: `DatabaseId int`, `DatabaseName sysname`, `StateDesc nvarchar(60)`, `UserAccessDesc nvarchar(60)`, `IsReadOnly bit`, `CompatibilityLevel tinyint`, `CollationName sysname`, `RecoveryModelDesc nvarchar(60)`, `IsSystemDatabase bit`, `RequestedOrdinal int` (NULL ohne expliziten Namensfilter). Die Zeile beschreibt Katalogsicht und Zugriff des aktuellen Callers, keine garantierte spätere Erreichbarkeit.
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_DatabaseCandidates](NULL, 0, NULL); SELECT * FROM [monitor].[TVF_DatabaseCandidates](N'AppDb', 0, N'App%');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_DatabaseCandidates
CREATE OR ALTER FUNCTION [monitor].[TVF_DatabaseCandidates]
(
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH [Parameters] AS
    (
        SELECT [EffectiveDatabaseNames] = CONVERT
        (
            nvarchar(max),
            CASE
                WHEN NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames, N''))), N'') IS NULL
                    THEN NULL
                ELSE @DatabaseNames
            END
        )
    ),
    [ExactNames] AS
    (
        SELECT
              [l].[ItemOrdinal]
            , [DatabaseName] = CONVERT(sysname, [l].[NameValue])
        FROM [Parameters] AS [p]
        CROSS APPLY [monitor].[TVF_ParseSqlNameList]([p].[EffectiveDatabaseNames]) AS [l]
        WHERE [l].[IsValid] = 1
    ),
    [Pattern] AS
    (
        SELECT [PatternMode], [PatternValue], [IsValid]
        FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern)
    )
    SELECT
          [d].[database_id] AS [DatabaseId]
        , [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [DatabaseName]
        , [d].[state_desc] AS [StateDesc]
        , [d].[user_access_desc] AS [UserAccessDesc]
        , [d].[is_read_only] AS [IsReadOnly]
        , [d].[compatibility_level] AS [CompatibilityLevel]
        , [d].[collation_name] AS [CollationName]
        , [d].[recovery_model_desc] AS [RecoveryModelDesc]
        , CONVERT(bit, CASE WHEN [d].[database_id] <= 4 THEN 1 ELSE 0 END) AS [IsSystemDatabase]
        , [e].[ItemOrdinal] AS [RequestedOrdinal]
    FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
    CROSS JOIN [Parameters] AS [p]
    CROSS JOIN [Pattern] AS [pt]
    LEFT JOIN [ExactNames] AS [e]
      ON [e].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
       = [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
    WHERE [pt].[IsValid] = 1
      AND [d].[source_database_id] IS NULL
      AND [d].[state] = 0
      AND HAS_DBACCESS([d].[name]) = 1
      AND (@SystemdatenbankenEinbeziehen = 1 OR [d].[database_id] > 4)
      AND ([p].[EffectiveDatabaseNames] IS NULL OR [e].[DatabaseName] IS NOT NULL)
      AND
      (
          [pt].[PatternMode] IN ('NONE', 'REGEX', 'REGEXI')
          OR [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
             LIKE [pt].[PatternValue] COLLATE SQL_Latin1_General_CP1_CS_AS
      )
);
GO
