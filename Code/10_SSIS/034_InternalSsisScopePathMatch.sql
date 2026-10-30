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
