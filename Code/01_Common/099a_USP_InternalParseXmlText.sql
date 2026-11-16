USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalParseXmlText
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne
               vorherige Kürzung in natives xml und klassifiziert Ausfälle.
Resultsets   : Keine; ausschließlich OUTPUT-Parameter.
Grenze       : Die aufrufende Procedure materialisiert den Quelltext genau
               einmal und entscheidet, ob ein Textfallback exportiert wird.
===============================================================================
*/
/*
Parametervertrag:
- @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...)
  nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL
  beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist
  XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020
  einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung
  AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.
- @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL.
  Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei
  einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei
  erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY.
- @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus.
  Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus
  sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener
  Fehler 6335, 6336 oder 6337) und XML_INVALID (jeder andere gefangene Fehler).
  PENDING ist nur der initiale Zwischenwert vor CONVERT und kein normaler
  Endstatus.
- @ErrorNumber int: OUTPUT-Empfänger für ERROR_NUMBER() eines gefangenen
  Fehlers. Default: NULL. Ein bestehender Empfängerwert wird auf NULL gesetzt; ohne
  gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL.
- @ErrorMessage nvarchar(2048): OUTPUT-Empfänger für den nativen
  ERROR_MESSAGE()-Text eines gefangenen Fehlers, begrenzt durch nvarchar(2048). Default: NULL. Der
  bisherige Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei
  SOURCE_NULL, bleibt der Wert NULL.

Jeder OUTPUT-Wert wird durch Bindung als @Parameter=@typisierteVariable
OUTPUT empfangen. Ausgelassene optionale OUTPUT-Argumente empfangen keine
Daten.
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalParseXmlText]
      @XmlText       nvarchar(max)
    , @XmlValue      xml            = NULL OUTPUT
    , @StatusCode    varchar(40)    = NULL OUTPUT
    , @ErrorNumber   int            = NULL OUTPUT
    , @ErrorMessage  nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @XmlValue=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,
           @StatusCode=CASE WHEN @XmlText IS NULL THEN 'SOURCE_NULL' ELSE 'PENDING' END;

    IF @XmlText IS NULL RETURN;

    BEGIN TRY
        SET @XmlValue=CONVERT(xml,@XmlText);
        SET @StatusCode=CASE
            WHEN NULLIF(LTRIM(RTRIM(@XmlText)),N'') IS NULL THEN 'XML_EMPTY'
            ELSE 'AVAILABLE' END;
    END TRY
    BEGIN CATCH
        SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),
               @StatusCode=CASE
                   WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT'
                   ELSE 'XML_INVALID' END;
    END CATCH;
END;
GO
