USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.VW_ModuleStatusCatalog
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Zentraler Katalog aller maschinenlesbaren Framework-Statuscodes.
Änderungen   : 1.1.0 - Plattform-, Messkontext- und Resetstatus ergänzt.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_ModuleStatusCatalog]
AS
    SELECT [v].[StatusCode],[v].[SeverityLevel],[v].[IsSuccess],[v].[IsQueryable],[v].[IsTerminal],
           [v].[GermanDescription],[v].[TechnicalMeaning]
    FROM (VALUES
      (CAST('AVAILABLE' AS varchar(40)),CAST(0 AS tinyint),CAST(1 AS bit),CAST(1 AS bit),CAST(0 AS bit),CAST(N'Verfügbar' AS nvarchar(200)),CAST(N'Die Quelle wurde erfolgreich abgefragt.' AS nvarchar(1000))),
      ('AVAILABLE_LIMITED',1,1,1,0,N'Verfügbar, aber eingeschränkt',N'Die Quelle ist abfragbar, die Vollständigkeit kann wegen Rechten oder Featurezustand eingeschränkt sein.'),
      ('AVAILABLE_UNVERIFIED',1,1,1,0,N'Abfragbar, Vollständigkeit nicht verifiziert',N'Die technische Probe war erfolgreich; eine deklarative Vollständigkeitsprüfung war nicht möglich.'),
      ('AVAILABLE_DISABLED',1,0,1,0,N'Quelle verfügbar, Feature deaktiviert',N'Die Metadatenquelle ist erreichbar, das zugehörige Feature ist nicht aktiviert.'),
      ('PARTIAL',1,1,1,0,N'Teilergebnis',N'Mindestens ein Teil wurde erfolgreich erhoben, mindestens ein weiterer Teil wurde übersprungen oder mit Fehlerstatus beendet.'),
      ('CUMULATIVE_CONTEXT',0,1,1,0,N'Kumulativer Messkontext',N'Die Werte gelten seit SQL-Server-Start oder letztem Zählerreset und sind keine aktuelle Delta-Messung.'),
      ('MEASUREMENT_RESET',2,0,0,1,N'Messung durch Reset ungültig',N'Während des Messfensters wurde ein Serverneustart oder ein Zählerreset erkannt; Deltas und Prozentwerte sind nicht belastbar.'),
      ('SKIPPED',1,0,0,0,N'Übersprungen',N'Das Teilmodul wurde aufgrund der Aufrufparameter nicht ausgeführt.'),
      ('NOT_APPLICABLE',0,0,0,0,N'Nicht anwendbar',N'Die Funktion ist für Plattform, Datenbankrolle oder Konfiguration fachlich nicht anwendbar.'),
      ('UNAVAILABLE_VERSION',2,0,0,1,N'Von der Serverversion nicht unterstützt',N'Die notwendige DMV, Spalte, Eigenschaft oder Syntax ist in dieser Version nicht verfügbar.'),
      ('UNAVAILABLE_PLATFORM',2,0,0,1,N'Auf dieser Plattform nicht verfügbar',N'Die Information ist nur auf einer anderen Betriebssystemplattform verfügbar; ein allgemeiner Fallback kann weiterhin nutzbar sein.'),
      ('UNAVAILABLE_FEATURE',2,0,0,1,N'Feature nicht verfügbar',N'Das optionale Feature ist nicht installiert, nicht aktiviert oder für Edition beziehungsweise Rolle nicht nutzbar.'),
      ('UNAVAILABLE_OBJECT',2,0,0,1,N'Objekt nicht verfügbar',N'Das optionale System- oder Frameworkobjekt ist nicht vorhanden.'),
      ('DATABASE_UNAVAILABLE',2,0,0,1,N'Datenbank nicht verfügbar',N'Die Zieldatenbank ist nicht vorhanden, nicht online oder für den Login nicht zugänglich.'),
      ('DENIED_PERMISSION',2,0,0,1,N'Berechtigung fehlt',N'Die Quelle konnte wegen fehlender SQL-Server-Berechtigung nicht abgefragt werden.'),
      ('DENIED_GROUP',2,0,0,1,N'Analyseklasse gesperrt',N'Die Analyseklasse ist durch die konfigurierte Gruppenpolicy nicht freigegeben.'),
      ('TIMEOUT',2,0,0,1,N'Zeitlimit erreicht',N'Das Teilmodul wurde wegen Lock- oder Laufzeitlimit beendet.'),
      ('ERROR_HANDLED',2,0,0,1,N'Fehler abgefangen',N'Ein Teilfehler wurde isoliert und strukturiert zurückgegeben.'),
      ('INVALID_PARAMETER',2,0,0,1,N'Ungültiger Parameter',N'Der Aufruf enthält einen ungültigen oder widersprüchlichen Parameterwert.')
    ) v(StatusCode,SeverityLevel,IsSuccess,IsQueryable,IsTerminal,GermanDescription,TechnicalMeaning);
GO
