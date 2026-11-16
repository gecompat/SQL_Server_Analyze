/*
Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.

Schnittstelle und Parameter
---------------------------
`@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne
Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt
null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile
darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und
ist nicht gleich NULL.

`@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,
auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit
nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.

`@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,
1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;
keine Konsistenzprüfung mit StatusCode.

`@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.
NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung
gespeichert und nicht als SQL-Fehler ausgelöst.

`@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für
Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;
Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.

Verhalten und Grenzen
---------------------
Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf
SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage
übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den
zugehörigen Tabellen ermittelt. Keine Quellerfassung.

Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null
Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile
gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion
und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren
ist nicht gesperrt oder als einmalig abgesichert.
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalFinalizeCollectionCycle]
      @CaptureRunId    bigint
    , @StatusCode      varchar(40)
    , @IsPartial       bit
    , @ErrorNumber     int
    , @ErrorMessage    nvarchar(2048)
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    UPDATE [snapshot].[CaptureRun]
    SET [EndedAtUtc]=SYSUTCDATETIME(),
        [StatusCode]=@StatusCode,
        [IsPartial]=@IsPartial,
        [ErrorNumber]=@ErrorNumber,
        [ErrorMessage]=@ErrorMessage,
        [MetricSampleCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId),
        [PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
    WHERE [CaptureRunId]=@CaptureRunId;
END;
GO
