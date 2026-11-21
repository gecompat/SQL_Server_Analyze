USE [DeineDatenbank];
GO

/*
    Zweck: Die Funktion vergleicht einen Pfad ordinal mit einem Root-Präfix und einer geordneten Folge bereits klassifizierter Toolbelt-Schritte.

    @Root und @Path sind nvarchar(4000). @Steps ist ein JSON-Array mit Schrittobjekten, deren text- und counter-Werte der Toolbelt bereits klassifiziert hat. Die Funktion liest keine DTSX-Datei, analysiert keine Lineage und erkennt keine SSIS-Komponentenklassen. Sie verwendet weder CLR noch eine Komponentenklassifikation.

    Die Funktion liefert eine Tabellenzeile mit IsMatch=1 nur, wenn Root und alle Schritte passen und der Pfad genau dort endet. Der Root-Vergleich und die Schrittvergleiche verwenden Latin1_General_100_BIN2 sowie DATALENGTH-basierte UTF-16-Längen; es gibt keine Wildcard- oder Vorfahrensuche. Mehr als 32 Schritte ergeben IsMatch=0.

    Ein Schritt benötigt einen nichtleeren text-Wert. counter wird mit TRY_CONVERT(bit, ...) umgewandelt und ist daher keine strikte JSON-Boolean-Validierung. Bei counter=1 wird ein unmittelbar folgender optionaler Index in eckigen Klammern akzeptiert, wenn er 1 bis 19 Ziffern, keine führende Null und einen bigint-Wert im gültigen Bereich enthält. Ist kein Index vorhanden, wird der Schritttext ohne Index verglichen. JSON_VALUE begrenzt die ausgelesenen Skalare auf nvarchar(4000).

    NULL in @Root oder @Path ergibt IsMatch=0. Ein leeres Array passt, wenn @Root und @Path identisch sind. Bei NULL in @Steps kann die äußere IF-Bedingung UNKNOWN bleiben; OPENJSON liefert dann null Zeilen, sodass ein identischer Root und Pfad als leere Schrittfolge passen kann. Die äußere JSON-Prüfung validiert nicht das vollständige Schrittschema. Ungültige Elemente oder JSON_VALUE-Auswertungen können Fehler auslösen; die Funktion fängt solche Fehler nicht allgemein ab.

    Beispiele mit ausschließlich synthetischen Werten:
    SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT\NODE[12]',N'[{"text":"\\NODE","counter":1}]'); -- IsMatch=1; optionaler Index
    SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT\OTHER',N'[{"text":"\\NODE","counter":0}]'); -- IsMatch=0
    SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT',N'[]'); -- IsMatch=1; leere Schrittfolge

    Das Ergebnis ist ausschließlich ein synthetischer Metadaten-Pfadvergleich. Es belegt weder Ausführung noch Scope-Hierarchie-Vollständigkeit oder den Zustand einer SSIS-Umgebung.
*/
-- USAGE_SKILL_BEGIN monitor.InternalSsisScopePathMatch 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalSsisScopePathMatch"
-- schema_name: "monitor"
-- object_name: "InternalSsisScopePathMatch"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Funktion vergleicht einen Pfad ordinal mit einem Root-Präfix und einer geordneten Folge bereits klassifizierter Toolbelt-Schritte."
-- source_path: "Code/10_SSIS/034_InternalSsisScopePathMatch.sql"
-- ---
-- 
-- # monitor.InternalSsisScopePathMatch
-- 
-- ## Zweck und Einsatz
-- 
-- Interne SSIS-Hilfsfunktion für vorab klassifizierte Toolbelt-Pfade; für die fachliche Diagnose ist der öffentliche SSIS-Bericht zu verwenden.
-- 
-- Die Funktion vergleicht einen Pfad ordinal mit einem Root-Präfix und einer geordneten Folge bereits klassifizierter Toolbelt-Schritte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[InternalSsisScopePathMatch]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien. Sie ist ein interner SSIS-Helfer; Fachaufrufe verwenden die öffentliche SSIS-Analyse.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @Root | nvarchar(4000) | ja | kein Default |
-- | @Path | nvarchar(4000) | ja | kein Default |
-- | @Steps | nvarchar(max) | ja | kein Default |
-- 
-- **@Root:** Pflichtwert nvarchar(4000), kein Default. Ordinaler Root-Präfix ohne Wildcard; NULL ergibt IsMatch=0. Der Vergleich verwendet Latin1_General_100_BIN2 und UTF-16-Längen.
-- 
-- **@Path:** Pflichtwert nvarchar(4000), kein Default. Bereits klassifizierter Pfad; er muss genau am Ende der Root-/Schrittfolge enden. NULL ergibt IsMatch=0; es erfolgt kein DTSX-Read.
-- 
-- **@Steps:** Pflichtwert nvarchar(max), kein Default. JSON-Array mit höchstens 32 Schrittobjekten. Jeder Schritt benötigt einen nicht leeren `text`-Wert; `counter` wird mit TRY_CONVERT(bit, ...) umgewandelt und ist keine strikte JSON-Boolean-Prüfung. Bei `counter=1` ist ein nachfolgender Index in eckigen Klammern optional: 1 bis 19 Ziffern, keine führende Null und gültiger bigint-Bereich. JSON_VALUE liest Skalare nur bis nvarchar(4000). NULL kann als leere Folge wirken; das gesamte JSON-Schrittschema wird nicht validiert und ungültige Werte können ungefangene Fehler auslösen.
-- 
-- ## Resultate und Ausgabe
-- 
-- Rückgabetyp und Spaltendeklarationen der Funktion:
-- 
-- ```sql
-- RETURNS @Result TABLE([IsMatch] bit NOT NULL)
-- ```
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT\NODE[12]',N'[{"text":"\\NODE","counter":1}]');
-- SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT',N'[]');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.InternalSsisScopePathMatch
CREATE OR ALTER FUNCTION [monitor].[InternalSsisScopePathMatch]
(@Root nvarchar(4000),@Path nvarchar(4000),@Steps nvarchar(max)) RETURNS @Result TABLE([IsMatch] bit NOT NULL)
AS
BEGIN
    IF @Root IS NULL OR @Path IS NULL OR ISJSON(@Steps)<>1 OR LEFT(LTRIM(@Steps),1)<>N'[' BEGIN INSERT @Result VALUES(0);RETURN;END;
    DECLARE @position int=DATALENGTH(@Root)/2+1,@i int=0,@count int=(SELECT COUNT(*) FROM OPENJSON(@Steps)),@text nvarchar(4000),@counter bit,@after int,@close int,@digits nvarchar(32);
    IF @count>32 OR DATALENGTH(@Path)<DATALENGTH(@Root) OR LEFT(@Path COLLATE Latin1_General_100_BIN2,@position-1) COLLATE Latin1_General_100_BIN2<>@Root COLLATE Latin1_General_100_BIN2 BEGIN INSERT @Result VALUES(0);RETURN;END;
    WHILE @i<@count
    BEGIN
        SELECT @text=NULL,@counter=NULL;
        SELECT @text=JSON_VALUE([value],'$.text'),@counter=TRY_CONVERT(bit,JSON_VALUE([value],'$.counter')) FROM OPENJSON(@Steps) WHERE TRY_CONVERT(int,[key])=@i;
        IF @text IS NULL OR DATALENGTH(@text)=0 OR @counter IS NULL OR SUBSTRING(@Path COLLATE Latin1_General_100_BIN2,@position,DATALENGTH(@text)/2) COLLATE Latin1_General_100_BIN2<>@text COLLATE Latin1_General_100_BIN2
            OR DATALENGTH(SUBSTRING(@Path COLLATE Latin1_General_100_BIN2,@position,DATALENGTH(@text)/2))<>DATALENGTH(@text) BEGIN INSERT @Result VALUES(0);RETURN;END;
        SET @after=@position+DATALENGTH(@text)/2;
        IF @counter=1 AND SUBSTRING(@Path COLLATE Latin1_General_100_BIN2,@after,1)=N'['
        BEGIN
            SET @close=CHARINDEX(N']',@Path COLLATE Latin1_General_100_BIN2,@after+1);
            IF @close<=@after+1 OR @close-@after-1>19 BEGIN INSERT @Result VALUES(0);RETURN;END;
            SET @digits=SUBSTRING(@Path COLLATE Latin1_General_100_BIN2,@after+1,@close-@after-1);
            IF LEFT(@digits,1) COLLATE Latin1_General_100_BIN2 NOT BETWEEN N'1' AND N'9' OR @digits COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%' OR TRY_CONVERT(bigint,@digits) IS NULL BEGIN INSERT @Result VALUES(0);RETURN;END;
            SET @after=@close+1;
        END;
        SET @position=@after;SET @i+=1;
    END;
    INSERT @Result VALUES(CASE WHEN @position=DATALENGTH(@Path)/2+1 THEN 1 ELSE 0 END);
    RETURN;
END;
GO
