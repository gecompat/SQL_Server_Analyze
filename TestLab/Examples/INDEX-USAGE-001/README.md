# INDEX-USAGE-001

Das Beispiel verwendet `LAB-IDX-003`. Wiederholte synthetische Abfragen erzeugen nach Möglichkeit eine Missing-Index-DMV-Zeile; wenn der Optimizer diese flüchtige Zeile nicht erzeugt, gilt das nachgewiesene indexfreie synthetische Objekt als ausdrückliche Alternativvorbedingung. Anschließend wird `[monitor].[USP_MissingIndexes]` aufgerufen.

Im Interactive-Modus vergleichen Sie Missing-Index-Evidenz mit vorhandenen Indizes, Query Store und Objektkontext. Das Beispiel erzeugt keine DDL-Empfehlung und behauptet keinen universellen Nutzen eines Indexes. Cleanup und Sessionbehandlung bleiben auf den Run-Marker begrenzt.
