USE [DeineDatenbank];
GO

-- Ordinaler Laufzeitvergleich auf bereits klassifizierten Toolbelt-Schritten.
-- Kein DTSX-Zugriff und keine Erkennung von SSIS-Komponentenklassen.
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
