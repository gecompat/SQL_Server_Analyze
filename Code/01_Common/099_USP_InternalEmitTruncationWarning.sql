USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalEmitTruncationWarning
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Gibt höchstens eine technische Severity-10-Warning für alle im
               Aufruf sichtbar gekürzten Werte aus.
Resultsets   : Keine.
Nebenwirkung : Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die
               Ausgabe aktiviert und mindestens ein Wert gekürzt ist.
Parameter    : @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit die Anzahl gekürzter Werte; der Helper
               ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab.
               NULL, 0 und negative Werte unterdrücken die Meldung.
               @ParameterName sysname, Default: keiner; Pflichtargument und
               ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu
               <unbekannter Parameter> und im Vorschlag zu den begrenzenden
               Parameter; ein leerer Wert bleibt leer.
               @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich
               Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.
               @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit den größten benötigten Zeichenbedarf; der
               Helper berechnet oder prüft diesen Wert nicht. NULL wird im
               Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.
               @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken
               die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale
               SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare
               Zahlen auf 1 abbilden.
               Keine Parameter sind OUTPUT-Parameter.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalEmitTruncationWarning]
      @TruncatedValueCount       bigint
    , @ParameterName             sysname
    , @ParameterValue            int
    , @LargestRequiredCharacters bigint
    , @PrintMeldungen            bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    IF COALESCE(@PrintMeldungen,0) <> 1
       OR COALESCE(@TruncatedValueCount,0) <= 0
        RETURN;

    DECLARE @Message nvarchar(2048) = LEFT
    (
        CONCAT
        (
              N'OUTPUT_VALUE_TRUNCATED: '
            , CONVERT(nvarchar(30),@TruncatedValueCount)
            , N' Wert(e) wurden durch '
            , COALESCE(@ParameterName,N'<unbekannter Parameter>')
            , N'='
            , COALESCE(CONVERT(nvarchar(30),@ParameterValue),N'NULL')
            , N' gekürzt. Der größte Wert benötigt '
            , COALESCE(CONVERT(nvarchar(30),@LargestRequiredCharacters),N'NULL')
            , N' Zeichen. Verwenden Sie '
            , COALESCE(@ParameterName,N'den begrenzenden Parameter')
            , N'='
            , COALESCE(CONVERT(nvarchar(30),@LargestRequiredCharacters),N'0')
            , N' oder 0 für eine vollständige Ausgabe.'
        ),
        2048
    );

    RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
END;
GO
