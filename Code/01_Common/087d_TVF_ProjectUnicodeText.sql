USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ProjectUnicodeText
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Inline Table-Valued Function
Zweck        : Projiziert einen bereits materialisierten nvarchar(max)-Wert
               mit messbarer, aufhebbarer und Surrogate-sicherer Begrenzung.
Parameter    : @Value nvarchar(max) und @MaxCharacters int sind Pflichtparameter
               ohne Defaults. Die Funktion liest keine System- oder
               Benutzerdaten und verändert keine Daten.
Ausgaben     : OriginalCharacters (bigint), OriginalBytes (bigint),
               IsTruncated (bit) und ProjectedValue (nvarchar(max)).
               OriginalCharacters zählt unter Latin1_General_100_CI_AS_SC
               via LEN mit angehängtem NCHAR(1), damit abschließende
               Leerzeichen mitgezählt werden. OriginalBytes ist
               DATALENGTH(@Value).
NULL/Grenze  : Bei NULL-Wert sind Text und beide Zählwerte NULL sowie
               IsTruncated = 0. NULL oder 0 als Grenze bedeutet unbegrenzt.
               Eine positive Grenze schneidet nur bei Überschreitung mit LEFT
               unter Latin1_General_100_CI_AS_SC; diese Collation zählt
               Surrogate-Paare als ein Zeichen und schneidet sie nicht
               innerhalb des Paars.
Aufrufer     : Negative Grenzen validiert die aufrufende Procedure; die
               Funktion erzeugt dafür keinen eigenen Status. LEFT kann bei
               negativem Limit fehlschlagen.
Grenzen      : Zeichen sind keine Grapheme. Es erfolgen keine Reparatur und
               keine Anonymisierung des Werts.
Beispiele    : Synthetische Aufrufe ohne Hostdaten:
               SELECT * FROM monitor.TVF_ProjectUnicodeText(N'Beispiel  ', 4);
               SELECT * FROM monitor.TVF_ProjectUnicodeText(N'Beispiel', 0);
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ProjectUnicodeText 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ProjectUnicodeText"
-- schema_name: "monitor"
-- object_name: "TVF_ProjectUnicodeText"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Projiziert einen bereits materialisierten nvarchar(max)-Wert mit messbarer, aufhebbarer und Surrogate-sicherer Begrenzung."
-- source_path: "Code/01_Common/087d_TVF_ProjectUnicodeText.sql"
-- ---
-- 
-- # monitor.TVF_ProjectUnicodeText
-- 
-- ## Zweck und Einsatz
-- 
-- Projiziert einen bereits materialisierten nvarchar(max)-Wert mit messbarer, aufhebbarer und Surrogate-sicherer Begrenzung.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ProjectUnicodeText]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @Value | nvarchar(max) | ja | kein Default |
-- | @MaxCharacters | int | ja | kein Default |
-- 
-- **@Value:** Pflichtwert nvarchar(max), kein Default. NULL liefert NULL für projizierten Text und beide Längen, IsTruncated=0. Der Wert wird nicht aus System- oder Benutzerdaten gelesen und nicht anonymisiert.
-- 
-- **@MaxCharacters:** Pflichtwert int, kein Default. NULL oder 0 bedeutet unbegrenzt; positiv begrenzt mit LEFT unter einer SC-Collation und trennt kein Surrogate-Paar. Negative Grenzen validiert der Aufrufer; LEFT kann bei negativem Wert fehlschlagen.
-- 
-- ## Resultate und Ausgabe
-- 
-- OriginalCharacters (bigint), OriginalBytes (bigint), IsTruncated (bit) und ProjectedValue (nvarchar(max)). OriginalCharacters zählt unter Latin1_General_100_CI_AS_SC via LEN mit angehängtem NCHAR(1), damit abschließende Leerzeichen mitgezählt werden. OriginalBytes ist DATALENGTH(@Value).
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM monitor.TVF_ProjectUnicodeText(N'Beispiel  ', 4);
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Zeichen sind keine Grapheme. Es erfolgen keine Reparatur und keine Anonymisierung des Werts.
-- 
-- USAGE_SKILL_END monitor.TVF_ProjectUnicodeText
CREATE OR ALTER FUNCTION [monitor].[TVF_ProjectUnicodeText]
(
      @Value         nvarchar(max)
    , @MaxCharacters int
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          [OriginalCharacters] =
              CASE WHEN @Value IS NULL THEN CONVERT(bigint,NULL)
                   ELSE [m].[CharacterCount] END
        , [OriginalBytes] = CONVERT(bigint,DATALENGTH(@Value))
        , [IsTruncated] = CONVERT
          (
              bit,
              CASE WHEN @Value IS NOT NULL
                         AND @MaxCharacters IS NOT NULL
                         AND @MaxCharacters > 0
                         AND [m].[CharacterCount] > @MaxCharacters
                   THEN 1 ELSE 0 END
          )
        , [ProjectedValue] = CONVERT
          (
              nvarchar(max),
              CASE WHEN @Value IS NULL THEN NULL
                   WHEN @MaxCharacters IS NULL OR @MaxCharacters = 0 THEN @Value
                   WHEN [m].[CharacterCount] <= @MaxCharacters THEN @Value
                   ELSE LEFT(@Value COLLATE Latin1_General_100_CI_AS_SC,@MaxCharacters)
              END
          )
    FROM
    (
        SELECT [CharacterCount] = CONVERT
        (
            bigint,
            LEN((@Value + NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC) - 1
        )
    ) AS [m]
);
GO
