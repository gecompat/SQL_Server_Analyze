USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalProjectUnicodeTextColumn
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Projiziert eine bereits materialisierte nvarchar(max)-Spalte
               Unicode-sicher und befüllt deren Längen-/Kürzungsmetadaten.
Grenze       : Liest ausschließlich die übergebene lokale Temp-Tabelle; kein
               erneuter Zugriff auf die fachliche Systemquelle.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne # und ##Name lösen Guard-Fehler 51021 aus. Keine Liste oder SQL-Ausdruck. Der Projektor prüft keine eigene 116-Zeichen-Grenze und validiert Existenz/Schema nicht vorab.
@TextColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus. QUOTENAME wird angewandt; Listen und SQL-Ausdrücke sind keine Eingabeform. Muss auf die bereits materialisierte nvarchar(max)-Textspalte zeigen, die IN PLACE überschrieben wird.
@CharactersColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalCharacters als bigint: Anzahl der Originalzeichen nach TVF_ProjectUnicodeText unter Latin1_General_100_CI_AS_SC, einschließlich nachgestellter Leerzeichen; Surrogatpaare zählen als ein Zeichen.
@BytesColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile OriginalBytes als bigint, entsprechend DATALENGTH des Originalwerts.
@IsTruncatedColumn sysname. Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL löst 51021 aus; QUOTENAME wird angewandt. Empfängt für jede Zeile IsTruncated als bit aus der TVF-Kürzungsentscheidung.
@MaxCharacters int. Default: keiner; Pflichtargument. Negativ löst 51021 aus. NULL passiert den Guard und wird unverändert an die TVF übergeben; diese behandelt NULL ebenso wie 0 als unbegrenzt; positive Werte begrenzen auf diese Anzahl SC-Zeichen. Die TVF zählt Surrogatpaare als ein Zeichen und schneidet nicht innerhalb des Paars; Zeichen sind keine Grapheme.
@TruncatedValueCount bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @TruncatedValueCount=@bigintVariable OUTPUT binden. Nach erfolgreicher Parameterprüfung und vor der dynamischen Ausführung 0; nach Verarbeitung COUNT_BIG ausschließlich der gekürzten Zeilen, bei keiner Kürzung 0.
@LargestRequiredCharacters bigint OUTPUT. Default: keiner; Pflichtargument. An eine bigint-Variable mit @LargestRequiredCharacters=@bigintVariable OUTPUT binden. Nach erfolgreicher Guard-Initialisierung NULL; nach Verarbeitung MAX der OriginalCharacters ausschließlich gekürzter Zeilen, bei keiner Kürzung NULL.
Abhängigkeit: monitor.TVF_ProjectUnicodeText bestimmt Zeichen-, Byte- und Kürzungssemantik. Surrogatpaare zählen als ein SC-Zeichen, nachgestellte Leerzeichen werden gezählt, Bytes entsprechen DATALENGTH; es gibt keine Graphemgarantie.
Die vollständige fachliche Quelle muss der interne Caller vorab materialisieren. Alle drei Metadatenspalten werden für jede Zeile aktualisiert. Nicht vorhandene, leere oder typinkompatible Spalten werden nicht vorab geprüft; dynamisches SQL kann normale native Fehler auslösen. Es gibt keine eigene Transaktion oder CATCH-Behandlung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalProjectUnicodeTextColumn]
      @SourceTable               sysname
    , @TextColumn                sysname
    , @CharactersColumn          sysname
    , @BytesColumn               sysname
    , @IsTruncatedColumn         sysname
    , @MaxCharacters             int
    , @TruncatedValueCount       bigint OUTPUT
    , @LargestRequiredCharacters bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    IF @SourceTable IS NULL OR LEFT(@SourceTable,1)<>N'#'
       OR LEFT(@SourceTable,2)=N'##'
       OR @TextColumn IS NULL OR @CharactersColumn IS NULL
       OR @BytesColumn IS NULL OR @IsTruncatedColumn IS NULL
       OR @MaxCharacters<0
        THROW 51021,N'InternalProjectUnicodeTextColumn benötigt eine lokale Temp-Tabelle, gültige Spalten und einen nichtnegativen Grenzwert.',1;

    DECLARE @Sql nvarchar(max)=N'
UPDATE [source]
SET '+QUOTENAME(@CharactersColumn)+N'=[projection].[OriginalCharacters],
    '+QUOTENAME(@BytesColumn)+N'=[projection].[OriginalBytes],
    '+QUOTENAME(@IsTruncatedColumn)+N'=[projection].[IsTruncated],
    '+QUOTENAME(@TextColumn)+N'=[projection].[ProjectedValue]
FROM '+QUOTENAME(@SourceTable)+N' AS [source]
CROSS APPLY [monitor].[TVF_ProjectUnicodeText]([source].'+QUOTENAME(@TextColumn)+N',@Limit) AS [projection];

SELECT @Count=COUNT_BIG(*),@Largest=MAX('+QUOTENAME(@CharactersColumn)+N')
FROM '+QUOTENAME(@SourceTable)+N'
WHERE '+QUOTENAME(@IsTruncatedColumn)+N'=1;';

    SET @TruncatedValueCount=0;
    SET @LargestRequiredCharacters=NULL;
    EXEC [sys].[sp_executesql]
          @Sql
        , N'@Limit int,@Count bigint OUTPUT,@Largest bigint OUTPUT'
        , @Limit=@MaxCharacters
        , @Count=@TruncatedValueCount OUTPUT
        , @Largest=@LargestRequiredCharacters OUTPUT;
END;
GO
