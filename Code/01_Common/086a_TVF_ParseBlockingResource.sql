USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseBlockingResource
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Multi-statement Table-valued Function
Zweck        : Die Funktion zerlegt einen Blocking-Ressourcenwert in syntaktisch
               erkannte IDs und bewahrt den Eingabewert. Sie greift weder auf
               Kataloge noch auf DMVs zu.
Eingabe      : @WaitResource nvarchar(3072) ohne Defaultwert. Jeder Aufruf liefert
               genau eine Ergebniszeile, auch bei NULL oder leerem Eingabewert.
Ausgabe      : Die zwölf Spalten, Datentypen, NULL-Zulässigkeit und Kollationen
               entsprechen der RETURNS-Tabelle:
                 RawResource       nvarchar(3072), NULL, SQL_Latin1_General_CP1_CS_AS
                 ResourceType      nvarchar(60),   NULL, SQL_Latin1_General_CP1_CS_AS
                 FormatCode        varchar(40),    NOT NULL, SQL_Latin1_General_CP1_CS_AS
                 DatabaseId        int,            NULL
                 EntityId          bigint,         NULL
                 SubEntityId       bigint,         NULL
                 FileId            int,            NULL
                 PageId            bigint,         NULL
                 RowId             int,            NULL
                 MetadataSubtype   nvarchar(60),   NULL, SQL_Latin1_General_CP1_CS_AS
                 ResourceQualifier nvarchar(512),  NULL, SQL_Latin1_General_CP1_CS_AS
                 ParseStatus       varchar(40),    NOT NULL, SQL_Latin1_General_CP1_CS_AS
               IDs ohne explizite Kollation verwenden die Datenbankstandardkollation.
Verarbeitung : Bei NULL oder nach LTRIM/RTRIM leerem Wert ist RawResource der
               unveränderte Eingabewert; FormatCode und ParseStatus sind EMPTY.
               Sonst enthält RawResource den an den Rändern mit LTRIM/RTRIM
               bereinigten Wert. METADATA wird großgeschrieben und von gewöhnlichen
               Leerzeichen befreit. Der Subtyp wird in der Reihenfolge STATS,
               SCHEMA, AUDIT, SECURITY_CACHE, METADATA_CACHE,
               QDS_STATEMENT_STABILITY und OTHER erkannt. Zahlenfelder werden aus
               den jeweiligen Schlüsseltexten gelesen; je Zahlenfeld wird höchstens
               ein 128 Zeichen langer Abschnitt untersucht.
Formate      : EMPTY kennzeichnet NULL oder leere Eingabe. METADATA wird für Werte
               mit dem Präfix METADATA: gewählt. NUMERIC_PAGE gilt, wenn das erste
               Zeichen in eine int-Zahl konvertierbar ist. PREFIXED gilt bei einem
               Doppelpunkt und verwendet den davorstehenden Text als ResourceType.
               NAMED_RESOURCE gilt ohne Doppelpunkt und verwendet den ersten Namen
               bis Leerzeichen oder öffnender Klammer. Weitere Formate werden nicht
               als vollständige SQL-Server-Grammatik beansprucht.
Zuordnung    : Bei Präfixformaten werden DatabaseId aus Teil 1 und EntityId aus
               Teil 2 für OBJECT, KEY, HOBT, OIB und ALLOCATION_UNIT gelesen;
               SubEntityId kommt bei OBJECT aus Teil 3. Für FILE, PAGE, RID und
               EXTENT stammen FileId aus Teil 2 und PageId bei PAGE, RID und EXTENT
               aus Teil 3. RowId stammt bei RID aus Teil 4. DATABASE verwendet nur
               DatabaseId. APPLICATION und XACT übernehmen den Text nach dem
               Doppelpunkt als ResourceQualifier. Unbekannte Präfixe bleiben
               RAW_ONLY. Die Zerlegung liest höchstens vier Teile; weitere Teile
               werden nicht validiert.
Status       : Die erreichbaren ParseStatus-Werte sind EMPTY, PARSED, PARTIAL,
               INVALID_FORMAT und RAW_ONLY. Bei METADATA bestimmt allein eine
               gelesene DatabaseId den Status PARSED; fehlende übrige IDs ändern
               ihn nicht. Bei FILE führt eine fehlende FileId zu PARTIAL.
               APPLICATION und XACT liefern PARTIAL. Fehlende EntityId bei den
               Entitytypen oder fehlende FileId/PageId bei PAGE, RID und EXTENT
               führen zu INVALID_FORMAT. OBJECT kann trotz fehlender SubEntityId
               und RID trotz fehlender RowId PARSED sein.
Beispiele    : Synthetische Eingaben; angegeben sind die durch die Zuordnung
               belegten Ergebnisse, nicht eine Laufzeitmessung:
                 PAGE:5:1:123 -> PREFIXED, PAGE, DatabaseId=5, FileId=1,
                                PageId=123, ParseStatus=PARSED
                 RID:5:1:123 -> PREFIXED, RID, DatabaseId=5, FileId=1,
                                PageId=123, RowId=NULL, ParseStatus=PARSED
                 METADATA:STATS(OBJECT_ID=42,STATS_ID=7,DATABASE_ID=5)
                              -> METADATA, METADATA, DatabaseId=5, EntityId=42,
                                 SubEntityId=7, MetadataSubtype=STATS,
                                 ParseStatus=PARSED
                 FUTURE_RESOURCE:abc -> PREFIXED, FUTURE_RESOURCE,
                                       ParseStatus=RAW_ONLY
                 NULL -> RawResource=NULL, FormatCode=EMPTY, ParseStatus=EMPTY;
                         genau eine Ergebniszeile
Aufrufe      : SELECT * FROM [monitor].[TVF_ParseBlockingResource](N'PAGE:5:1:123');
               SELECT * FROM [monitor].[TVF_ParseBlockingResource](
                   N'METADATA:STATS(OBJECT_ID=42,STATS_ID=7,DATABASE_ID=5)');
               SELECT * FROM [monitor].[TVF_ParseBlockingResource](NULL);
Auflösung    : Namen werden erst vom aufrufenden Modul für dessen begrenzte und
               deduplizierte Kandidatenmenge aufgelöst.
Aussagegrenze: Die Funktion liefert syntaktische Werte, keine Katalog- oder DMV-
               Auflösung und keinen Nachweis für Gültigkeit, Positivität, Existenz,
               Berechtigung oder Zustand einer Ressource. Die Beispiele sind keine
               empirischen Ausführungsergebnisse. Die begrenzte Textzerlegung ist
               keine Garantie sicherer Behandlung jeder fehlerhaften Eingabe.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseBlockingResource]
(
    @WaitResource nvarchar(3072)
)
RETURNS @Result TABLE
(
      [RawResource]       nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ResourceType]      nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS   NULL
    , [FormatCode]        varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
    , [DatabaseId]        int            NULL
    , [EntityId]          bigint         NULL
    , [SubEntityId]       bigint         NULL
    , [FileId]            int            NULL
    , [PageId]            bigint         NULL
    , [RowId]             int            NULL
    , [MetadataSubtype]   nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS   NULL
    , [ResourceQualifier] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
    , [ParseStatus]       varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
)
AS
BEGIN
    DECLARE @Raw nvarchar(3072) = NULLIF(LTRIM(RTRIM(@WaitResource)), N'');

    IF @Raw IS NULL
    BEGIN
        INSERT @Result ([RawResource], [FormatCode], [ParseStatus])
        VALUES (@WaitResource, 'EMPTY', 'EMPTY');
        RETURN;
    END;

    DECLARE @Upper nvarchar(3072) = UPPER(@Raw);
    DECLARE @Compact nvarchar(3072) = REPLACE(@Upper, N' ', N'');
    DECLARE @ResourceType nvarchar(60) = NULL;
    DECLARE @FormatCode varchar(40) = 'PREFIXED';
    DECLARE @DatabaseId int = NULL;
    DECLARE @EntityId bigint = NULL;
    DECLARE @SubEntityId bigint = NULL;
    DECLARE @FileId int = NULL;
    DECLARE @PageId bigint = NULL;
    DECLARE @RowId int = NULL;
    DECLARE @MetadataSubtype nvarchar(60) = NULL;
    DECLARE @Qualifier nvarchar(512) = NULL;
    DECLARE @ParseStatus varchar(40) = 'UNRECOGNIZED';
    DECLARE @Start int;
    DECLARE @NumericSegment nvarchar(128);
    DECLARE @NumericSegmentLength int;

    IF LEFT(@Compact, 9) = N'METADATA:'
    BEGIN
        SET @ResourceType = N'METADATA';
        SET @FormatCode = 'METADATA';
        SET @MetadataSubtype =
            CASE WHEN CHARINDEX(N'STATS(', @Compact) > 0 THEN N'STATS'
                 WHEN CHARINDEX(N'SCHEMA(', @Compact) > 0 THEN N'SCHEMA'
                 WHEN CHARINDEX(N'AUDIT(', @Compact) > 0 THEN N'AUDIT'
                 WHEN CHARINDEX(N'SECURITY_CACHE(', @Compact) > 0 THEN N'SECURITY_CACHE'
                 WHEN CHARINDEX(N'METADATA_CACHE(', @Compact) > 0 THEN N'METADATA_CACHE'
                 WHEN CHARINDEX(N'QDS_STATEMENT_STABILITY(', @Compact) > 0 THEN N'QDS_STATEMENT_STABILITY'
                 ELSE N'OTHER' END;

        SET @Start = CHARINDEX(N'DATABASE_ID=', @Compact);
        IF @Start > 0
        BEGIN
            SET @NumericSegment = SUBSTRING(@Compact, @Start + LEN(N'DATABASE_ID='), 128);
            SET @NumericSegmentLength = PATINDEX(N'%[^0-9]%', @NumericSegment + N'X') - 1;
            SET @DatabaseId = TRY_CONVERT(int, LEFT(@NumericSegment, @NumericSegmentLength));
        END;

        IF @MetadataSubtype = N'STATS'
        BEGIN
            SET @Start = CHARINDEX(N'OBJECT_ID=', @Compact);
            IF @Start > 0
            BEGIN
                SET @NumericSegment = SUBSTRING(@Compact, @Start + LEN(N'OBJECT_ID='), 128);
                SET @NumericSegmentLength = PATINDEX(N'%[^0-9]%', @NumericSegment + N'X') - 1;
                SET @EntityId = TRY_CONVERT(bigint, LEFT(@NumericSegment, @NumericSegmentLength));
            END;

            SET @Start = CHARINDEX(N'STATS_ID=', @Compact);
            IF @Start > 0
            BEGIN
                SET @NumericSegment = SUBSTRING(@Compact, @Start + LEN(N'STATS_ID='), 128);
                SET @NumericSegmentLength = PATINDEX(N'%[^0-9]%', @NumericSegment + N'X') - 1;
                SET @SubEntityId = TRY_CONVERT(bigint, LEFT(@NumericSegment, @NumericSegmentLength));
            END;
        END;
        ELSE IF @MetadataSubtype = N'SCHEMA'
        BEGIN
            SET @Start = CHARINDEX(N'SCHEMA_ID=', @Compact);
            IF @Start > 0
            BEGIN
                SET @NumericSegment = SUBSTRING(@Compact, @Start + LEN(N'SCHEMA_ID='), 128);
                SET @NumericSegmentLength = PATINDEX(N'%[^0-9]%', @NumericSegment + N'X') - 1;
                SET @EntityId = TRY_CONVERT(bigint, LEFT(@NumericSegment, @NumericSegmentLength));
            END;
        END;
        ELSE IF @MetadataSubtype = N'AUDIT'
        BEGIN
            SET @Start = CHARINDEX(N'AUDIT_ID=', @Compact);
            IF @Start > 0
            BEGIN
                SET @NumericSegment = SUBSTRING(@Compact, @Start + LEN(N'AUDIT_ID='), 128);
                SET @NumericSegmentLength = PATINDEX(N'%[^0-9]%', @NumericSegment + N'X') - 1;
                SET @EntityId = TRY_CONVERT(bigint, LEFT(@NumericSegment, @NumericSegmentLength));
            END;
        END;

        SET @Qualifier = LEFT(@Raw, 512);
        SET @ParseStatus = CASE WHEN @DatabaseId IS NULL THEN 'PARTIAL' ELSE 'PARSED' END;
    END;
    ELSE
    BEGIN
        DECLARE @Payload nvarchar(3072);
        DECLARE @FirstColon int = CHARINDEX(N':', @Raw);

        IF TRY_CONVERT(int, LEFT(@Raw, 1)) IS NOT NULL
        BEGIN
            SET @ResourceType = N'PAGE';
            SET @FormatCode = 'NUMERIC_PAGE';
            SET @Payload = @Raw;
        END;
        ELSE IF @FirstColon > 0
        BEGIN
            SET @ResourceType = LEFT(UPPER(LTRIM(RTRIM(LEFT(@Raw, @FirstColon - 1)))), 60);
            SET @Payload = LTRIM(SUBSTRING(@Raw, @FirstColon + 1, 3072));
        END;
        ELSE
        BEGIN
            DECLARE @NameEnd int = NULLIF(CHARINDEX(N' ', @Raw + N' '), 0);
            DECLARE @Paren int = NULLIF(CHARINDEX(N'(', @Raw), 0);
            IF @Paren IS NOT NULL AND (@NameEnd IS NULL OR @Paren < @NameEnd)
                SET @NameEnd = @Paren;

            SET @ResourceType = LEFT(UPPER(LEFT(@Raw, COALESCE(@NameEnd - 1, LEN(@Raw)))), 60);
            SET @FormatCode = 'NAMED_RESOURCE';
            SET @Qualifier = LEFT(@Raw, 512);
            SET @ParseStatus = 'RAW_ONLY';
        END;

        IF @Payload IS NOT NULL
        BEGIN
            DECLARE @Parts TABLE
            (
                  [Ordinal] int NOT NULL PRIMARY KEY
                , [Value] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
            );
            DECLARE @Ordinal int = 1;
            DECLARE @Colon int;
            DECLARE @Space int;
            DECLARE @OpenParen int;
            DECLARE @OpenBracket int;
            DECLARE @End int;

            WHILE @Ordinal <= 4 AND NULLIF(LTRIM(@Payload), N'') IS NOT NULL
            BEGIN
                SET @Payload = LTRIM(@Payload);
                SET @Colon = NULLIF(CHARINDEX(N':', @Payload), 0);
                SET @Space = NULLIF(CHARINDEX(N' ', @Payload), 0);
                SET @OpenParen = NULLIF(CHARINDEX(N'(', @Payload), 0);
                SET @OpenBracket = NULLIF(CHARINDEX(N'[', @Payload), 0);

                SELECT @End = MIN([Position])
                FROM (VALUES (@Colon), (@Space), (@OpenParen), (@OpenBracket)) AS [d]([Position])
                WHERE [Position] IS NOT NULL;

                INSERT @Parts ([Ordinal], [Value])
                VALUES
                (
                      @Ordinal
                    , NULLIF(LTRIM(RTRIM(CASE WHEN @End IS NULL THEN @Payload
                                               ELSE LEFT(@Payload, @End - 1) END)), N'')
                );

                IF @End IS NULL
                    SET @Payload = N'';
                ELSE IF @Colon = @End
                    SET @Payload = SUBSTRING(@Payload, @End + 1, 3072);
                ELSE
                BEGIN
                    SET @Qualifier = LEFT(LTRIM(SUBSTRING(@Payload, @End, 3072)), 512);
                    SET @Payload = N'';
                END;

                SET @Ordinal += 1;
            END;

            DECLARE @Part1 nvarchar(128) = (SELECT [Value] FROM @Parts WHERE [Ordinal] = 1);
            DECLARE @Part2 nvarchar(128) = (SELECT [Value] FROM @Parts WHERE [Ordinal] = 2);
            DECLARE @Part3 nvarchar(128) = (SELECT [Value] FROM @Parts WHERE [Ordinal] = 3);
            DECLARE @Part4 nvarchar(128) = (SELECT [Value] FROM @Parts WHERE [Ordinal] = 4);

            IF @ResourceType IN
               (
                   N'OBJECT', N'KEY', N'HOBT', N'OIB', N'ALLOCATION_UNIT',
                   N'DATABASE', N'FILE', N'PAGE', N'RID', N'EXTENT',
                   N'APPLICATION', N'XACT'
               )
            BEGIN
                SET @DatabaseId = TRY_CONVERT(int, @Part1);
                SET @EntityId = CASE WHEN @ResourceType IN (N'OBJECT', N'KEY', N'HOBT', N'OIB', N'ALLOCATION_UNIT')
                                     THEN TRY_CONVERT(bigint, @Part2) END;
                SET @SubEntityId = CASE WHEN @ResourceType = N'OBJECT'
                                        THEN TRY_CONVERT(bigint, @Part3) END;
                SET @FileId = CASE WHEN @ResourceType IN (N'FILE', N'PAGE', N'RID', N'EXTENT')
                                   THEN TRY_CONVERT(int, @Part2) END;
                SET @PageId = CASE WHEN @ResourceType IN (N'PAGE', N'RID', N'EXTENT')
                                   THEN TRY_CONVERT(bigint, @Part3) END;
                SET @RowId = CASE WHEN @ResourceType = N'RID'
                                  THEN TRY_CONVERT(int, @Part4) END;
                IF @ResourceType IN (N'APPLICATION', N'XACT')
                    SET @Qualifier = LEFT(LTRIM(SUBSTRING(@Raw, CHARINDEX(N':', @Raw) + 1, 3072)), 512);
                SET @ParseStatus =
                    CASE WHEN @DatabaseId IS NULL THEN 'INVALID_FORMAT'
                         WHEN @ResourceType IN (N'OBJECT', N'KEY', N'HOBT', N'OIB', N'ALLOCATION_UNIT')
                              AND @EntityId IS NULL THEN 'INVALID_FORMAT'
                         WHEN @ResourceType IN (N'PAGE', N'RID', N'EXTENT')
                              AND (@FileId IS NULL OR @PageId IS NULL) THEN 'INVALID_FORMAT'
                         WHEN @ResourceType = N'FILE' AND @FileId IS NULL THEN 'PARTIAL'
                         WHEN @ResourceType IN (N'APPLICATION', N'XACT') THEN 'PARTIAL'
                         ELSE 'PARSED' END;
            END;
            ELSE
            BEGIN
                SET @Qualifier = LEFT(COALESCE(@Qualifier, @Raw), 512);
                SET @ParseStatus = 'RAW_ONLY';
            END;
        END;
    END;

    INSERT @Result
    (
          [RawResource], [ResourceType], [FormatCode], [DatabaseId]
        , [EntityId], [SubEntityId], [FileId], [PageId], [RowId]
        , [MetadataSubtype], [ResourceQualifier], [ParseStatus]
    )
    VALUES
    (
          @Raw, @ResourceType, @FormatCode, @DatabaseId
        , @EntityId, @SubEntityId, @FileId, @PageId, @RowId
        , @MetadataSubtype, @Qualifier, @ParseStatus
    );

    RETURN;
END;
GO
