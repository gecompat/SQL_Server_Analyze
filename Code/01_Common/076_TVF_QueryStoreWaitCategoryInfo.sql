USE [DeineDatenbank];
GO

/*
    Ordnet eine Query-Store-Wait-Kategorie einer normalisierten WaitGroup zu und
    liefert Beschreibungstexte zu typischem Auftreten, Auswirkungen und
    empfohlenen Prüfschritten. Die Inline-Tabellenwertfunktion liefert genau
    eine Zeile, verwendet nur @WaitCategoryDesc und liest keine Query-Store-
    Kataloge, Tabellen oder DMVs. Sie erstellt kein Gesundheitsurteil und ist
    kein vollständiger Katalog aller Kategorien. Der Eingabewert ist eine
    Kategoriebezeichnung, kein Wait Type.

    Eingabe:
      @WaitCategoryDesc nvarchar(128); Default: keiner. Das Argument ist beim
      Funktionsaufruf anzugeben, etwa als N'Buffer IO' oder NULL. Die
      Parameterbindung erfolgt an nvarchar(128), also höchstens 128 UTF-16-
      Codeeinheiten; längere Textwerte können dabei vor dem Funktionskörper
      gekürzt werden. NULL, N'' und unbekannte Bezeichnungen sind zulässig.
      NULL wird für WaitGroup wie N'Unknown' behandelt. Bei N'' bleibt
      WaitGroup leer. Andere unbekannte Bezeichnungen durchlaufen dieselbe
      WaitGroup-Transformation und erhalten allgemeine Beschreibungstexte.

    Ausgabe:
      WaitGroup nvarchar(64) – Eingabetext in Großschreibung, Leerzeichen werden
      durch Unterstriche ersetzt. Es gibt kein Trimming; längere Werte werden
      auf 64 Zeichen begrenzt.
      Meaning nvarchar(1000) – Bedeutung einer bekannten Kategorie oder
      allgemeiner Hinweis auf eine interne/externe Ressource.
      TypicalOccurrence nvarchar(1200) – spezialisierte Ursache für CPU, Lock,
      Buffer IO, Tran Log IO und Memory; sonst allgemeiner Hinweis zu Plan,
      Workload und Ressource.
      HighWaitImpact nvarchar(1200) – spezifischer Effekt für CPU, Worker Thread,
      Lock, Buffer IO und Tran Log IO; sonst allgemeiner Hinweis, hohe Werte mit
      Laufzeitstatistik und Ausführungsplan zu korrelieren.
      RecommendedChecks nvarchar(1500) – spezifische Prüfhinweise für CPU, Lock,
      Buffer IO, Tran Log IO und Memory; sonst Query-Store-Laufzeitstatistik,
      Planwechsel und betroffene Query-/Plan-Kombination prüfen.

    Erkannte CASE-Bezeichnungen und ihre Meaning-Texte:
      CPU: CPU-Verbrauch oder Schedulerzeit während der Queryausführung.
      Worker Thread: Warten auf verfügbare Workerthreads.
      Lock: Warten auf inkompatible Locks.
      Latch: Interne Synchronisationslatches.
      Buffer Latch: Latches auf Seiten im Buffer Pool, häufig Hot-Page-Contention.
      Buffer IO: Warten auf Daten-I/O für Seiten.
      Tran Log IO: Warten auf Transaktionslog-I/O.
      Network IO: Warten auf Netzwerk oder Clientabnahme.
      Parallelism: Synchronisation paralleler Ausführungszweige.
      Memory: Warten auf Query- oder interne Speicherressourcen.
      Other Disk IO: Sonstiger persistenter I/O außerhalb Buffer- und Log-I/O.

    Diese Bezeichnungen sind keine geschlossene Eingabewertemenge.
    Meaning-Texte sind für CPU, Worker Thread, Lock, Latch, Buffer Latch,
    Buffer IO, Tran Log IO, Network IO, Parallelism, Memory und Other Disk IO
    spezialisiert. Die anderen Spalten verwenden jeweils nur die oben
    genannten Teilmengen; übrige Kategorien erhalten den Fallbacktext der
    jeweiligen Spalte. Die CASE-Vergleiche folgen der aktuellen
    Datenbankcollation und den SQL-Server-Zeichenvergleichsregeln. Es findet
    kein explizites TRIM oder eine sonstige Eingabenormalisierung für diese
    Vergleiche statt.

    Beispielaufrufe:
      SELECT * FROM [monitor].[TVF_QueryStoreWaitCategoryInfo](N'Buffer IO');
      SELECT * FROM [monitor].[TVF_QueryStoreWaitCategoryInfo](NULL);

      Bei einem unter der aktuellen Datenbankcollation passenden Wert
      N'Buffer IO' ergibt WaitGroup N'BUFFER_IO' und die spezialisierten
      Hinweise zu Seiten-I/O, Storage und Reads. Bei NULL ergibt WaitGroup
      N'UNKNOWN'; die übrigen Spalten liefern ihre allgemeinen Fallbacktexte.
*/

CREATE OR ALTER FUNCTION [monitor].[TVF_QueryStoreWaitCategoryInfo](@WaitCategoryDesc nvarchar(128))
RETURNS TABLE
AS
RETURN
(
    SELECT
          CONVERT(nvarchar(64), UPPER(REPLACE(COALESCE(@WaitCategoryDesc, N'Unknown'), N' ', N'_'))) AS [WaitGroup]
        , CONVERT
          (
              nvarchar(1000)
            , CASE @WaitCategoryDesc
                  WHEN N'CPU' THEN N'CPU-Verbrauch oder Schedulerzeit während der Queryausführung.'
                  WHEN N'Worker Thread' THEN N'Warten auf verfügbare Workerthreads.'
                  WHEN N'Lock' THEN N'Warten auf inkompatible Locks.'
                  WHEN N'Latch' THEN N'Interne Synchronisationslatches.'
                  WHEN N'Buffer Latch' THEN N'Latches auf Seiten im Buffer Pool, häufig Hot-Page-Contention.'
                  WHEN N'Buffer IO' THEN N'Warten auf Daten-I/O für Seiten.'
                  WHEN N'Tran Log IO' THEN N'Warten auf Transaktionslog-I/O.'
                  WHEN N'Network IO' THEN N'Warten auf Netzwerk oder Clientabnahme.'
                  WHEN N'Parallelism' THEN N'Synchronisation paralleler Ausführungszweige.'
                  WHEN N'Memory' THEN N'Warten auf Query- oder interne Speicherressourcen.'
                  WHEN N'Other Disk IO' THEN N'Sonstiger persistenter I/O außerhalb Buffer- und Log-I/O.'
                  ELSE N'Query-Store-Wait-Kategorie für eine interne oder externe Ressource.'
              END
          ) AS [Meaning]
        , CONVERT
          (
              nvarchar(1200)
            , CASE @WaitCategoryDesc
                  WHEN N'CPU' THEN N'CPU-intensive Pläne, Scans, Sorts, Hashes oder hohe Parallelität.'
                  WHEN N'Lock' THEN N'Konkurrierende oder lange Transaktionen.'
                  WHEN N'Buffer IO' THEN N'Cache Misses, große Reads oder langsamer Storage.'
                  WHEN N'Tran Log IO' THEN N'Commit-intensive Workloads oder langsames Log-I/O.'
                  WHEN N'Memory' THEN N'Große Memory Grants oder viele konkurrierende Queries.'
                  ELSE N'Abhängig von Plan, Workload und betroffener Ressource.'
              END
          ) AS [TypicalOccurrence]
        , CONVERT
          (
              nvarchar(1200)
            , CASE @WaitCategoryDesc
                  WHEN N'CPU' THEN N'Durchsatz und Antwortzeit werden durch CPU limitiert.'
                  WHEN N'Worker Thread' THEN N'Queries können verzögert starten oder die Instanz wirkt blockiert.'
                  WHEN N'Lock' THEN N'Blocking, Timeouts und lange Antwortzeiten.'
                  WHEN N'Buffer IO' THEN N'Queries warten auf Seiten vom Storage.'
                  WHEN N'Tran Log IO' THEN N'Commit-Latenz und Schreibdurchsatz verschlechtern sich.'
                  ELSE N'Hohe Werte zeigen einen relevanten Stall-Punkt der Queryausführung; mit Runtime Stats und Plan korrelieren.'
              END
          ) AS [HighWaitImpact]
        , CONVERT
          (
              nvarchar(1500)
            , CASE @WaitCategoryDesc
                  WHEN N'CPU' THEN N'Top CPU Queries, Pläne, Scheduler und Parallelität prüfen.'
                  WHEN N'Lock' THEN N'Blocking, offene Transaktionen, Indizes und Isolation prüfen.'
                  WHEN N'Buffer IO' THEN N'File-Latenz, Reads, Scans, Buffer Pool und Indizes prüfen.'
                  WHEN N'Tran Log IO' THEN N'Log-Latenz, Growth, Commit-Rate und AG-Pfad prüfen.'
                  WHEN N'Memory' THEN N'Memory Grants, Cardinality und Sort-/Hash-Operatoren prüfen.'
                  ELSE N'Query Store Runtime Stats, Planwechsel und betroffene Query/Plan-Kombination prüfen.'
              END
          ) AS [RecommendedChecks]
);
GO
