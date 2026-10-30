USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.PlanAnalysisProfileAssignment
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Das Skript legt lokale Zuordnungszeilen an, die Plan- oder
               Workloadkontext mit einem generischen Analyseprofil verbinden
               können. Die DDL enthält keine INSERTs mit realen Zuordnungen.
Voraussetzung: Das Schema [monitor] und [monitor].[PlanAnalysisProfile]
               müssen in der durch USE gewählten Datenbank verfügbar sein.
Spalten      : AssignmentId ist ein bigint-IDENTITY-Schlüssel. Priority ist
               smallint; IsEnabled aktiviert oder deaktiviert die Zeile mit
               bit. ProfileCode verweist als varchar(32) auf ein Profil.
               DatabaseNamePattern, SchemaNamePattern, ObjectNamePattern und
               ProgramNameLikePattern sind optionale nvarchar(256)-Muster.
               QueryHash ist optionales binary(8), QueryStoreQueryId bigint,
               StatementId int, ResourcePoolId int und WorkloadGroupId int.
               IsFrameworkDefault kennzeichnet Frameworkbesitz mit bit.
               Comment enthält optional nvarchar(1000); LastUpdatedUtc speichert
               datetime2(0) in UTC.
Schlüssel    : AssignmentId ist der gruppierte Primärschlüssel. ProfileCode
               besitzt einen Fremdschlüssel auf
               [monitor].[PlanAnalysisProfile]([ProfileCode]). Priority muss
               zwischen 1 und 32767 liegen. Die Scope-Prüfung verlangt, dass
               mindestens eines der neun Filterfelder nicht NULL ist. Der
               nicht gruppierte Index
               [IX_PlanAnalysisProfileAssignment_Resolution] beginnt mit
               IsEnabled, Priority und ProfileCode und enthält die Filterfelder
               als INCLUDE-Spalten.
Verwendung   : Diese Tabelle speichert lokale Konfiguration. Sie enthält keine
               ausgelieferten realen Zuweisungen; ein Profilseed erzeugt keine
               Zeilen in dieser Tabelle. Der Index belegt keine konkrete
               Auflösungsreihenfolge. Die Spalten sind Filterdaten, keine
               Ausführungsanweisung oder Sicherheitsgrenze. Ohne belegten
               Verbraucher werden weder Mustervergleich, NULL-Verhalten,
               Prioritätsauflösung noch Zuordnungskonkurrenz festgelegt.
Datenschutz  : Persistieren Sie nur generische, für das Repository zulässige
               Muster. Reale Datenbank-, Objekt-, Programm- oder
               Umgebungsnamen gehören nicht in ausgelieferte Beispiele.
Beispiel     : Die Abfrage zeigt lokal gespeicherte Zeilen und filtert nicht
               anhand eines angenommenen Matchingvertrags.
===============================================================================
SELECT [AssignmentId],[ProfileCode],[IsEnabled],[Priority],[DatabaseNamePattern]
FROM [monitor].[PlanAnalysisProfileAssignment] WITH (NOLOCK);
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisProfileAssignment'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisProfileAssignment]
    (
          [AssignmentId]          bigint        IDENTITY(1,1) NOT NULL
        , [Priority]              smallint      NOT NULL
        , [IsEnabled]             bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_IsEnabled] DEFAULT (1)
        , [ProfileCode]           varchar(32)   NOT NULL
        , [DatabaseNamePattern]   nvarchar(256) NULL
        , [SchemaNamePattern]     nvarchar(256) NULL
        , [ObjectNamePattern]     nvarchar(256) NULL
        , [QueryHash]             binary(8)     NULL
        , [QueryStoreQueryId]     bigint        NULL
        , [StatementId]           int           NULL
        , [ProgramNameLikePattern] nvarchar(256) NULL
        , [ResourcePoolId]        int           NULL
        , [WorkloadGroupId]       int           NULL
        , [IsFrameworkDefault]    bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_IsFrameworkDefault] DEFAULT (0)
        , [Comment]               nvarchar(1000) NULL
        , [LastUpdatedUtc]        datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfileAssignment_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisProfileAssignment]
            PRIMARY KEY CLUSTERED ([AssignmentId])
        , CONSTRAINT [FK_PlanAnalysisProfileAssignment_Profile]
            FOREIGN KEY ([ProfileCode])
            REFERENCES [monitor].[PlanAnalysisProfile]([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisProfileAssignment_Priority]
            CHECK ([Priority] BETWEEN 1 AND 32767)
        , CONSTRAINT [CK_PlanAnalysisProfileAssignment_Scope]
            CHECK
            (
                   [DatabaseNamePattern] IS NOT NULL
                OR [SchemaNamePattern] IS NOT NULL
                OR [ObjectNamePattern] IS NOT NULL
                OR [QueryHash] IS NOT NULL
                OR [QueryStoreQueryId] IS NOT NULL
                OR [StatementId] IS NOT NULL
                OR [ProgramNameLikePattern] IS NOT NULL
                OR [ResourcePoolId] IS NOT NULL
                OR [WorkloadGroupId] IS NOT NULL
            )
    );

    CREATE INDEX [IX_PlanAnalysisProfileAssignment_Resolution]
        ON [monitor].[PlanAnalysisProfileAssignment]
        ([IsEnabled],[Priority],[ProfileCode])
        INCLUDE
        (
              [DatabaseNamePattern],[SchemaNamePattern],[ObjectNamePattern]
            , [QueryHash],[QueryStoreQueryId],[StatementId]
            , [ProgramNameLikePattern],[ResourcePoolId],[WorkloadGroupId]
        );
END;
GO
