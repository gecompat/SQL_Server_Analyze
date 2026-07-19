# [monitor].[USP_FullTextAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen
**Zweck:** Bewertet sichtbare Full-Text-Kataloge, -Indizes und aggregierte Laufzeitmetadaten ohne indizierte Inhalte, Suchbegriffe, Crawl-Logs, Pfade oder Zustandsänderung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FullTextAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, Katalog, Full-Text-Index, einer aktuell laufenden Population, einer aggregierten Batchgruppe, einer semantischen Population, einem Speicherpool oder einer FDHost-Typgruppe.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach Index-/Schlüsselindexschalter, Crawl-Kontext, aktuelle Populationen und Batches gemeinsam lesen. Fragmentanzahl und logische Größe sind Heuristik- beziehungsweise Kapazitätskontext; Memory Pools und FDHosts sind serverweit und keiner einzelnen Datenbank exklusiv zurechenbar.

## Warum kann das problematisch sein?

Deaktivierte Indizes, abgebrochene Populationen, Batchfehler oder fehlgeschlagene Dokumente können Suchaktualität und Auffindbarkeit begrenzen. Viele querybare Fragmente können die Abfrageleistung verschlechtern. Ein langer Lauf oder eine große Batchzahl beweist jedoch keinen Stillstand.

## Wann ist es kein Problem?

`MANUAL` oder `OFF` beim Change Tracking kann bewusst gewählt sein. Ein initialer Full Crawl kann durch `NO POPULATION` absichtlich ausstehen. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Status 7 kann während eines automatischen Merge auftreten. Es existiert kein universeller Fragment- oder Laufzeitgrenzwert.

## Beispiel und Folgeschritt

Eine Population über dem Altersgrenzwert mit weiter steigendem Fortschritt ist eher ein Kapazitäts- als ein Stillstandsfall. Erst bei wiederholt fehlendem Fortschritt zusätzlich Batches, I/O, Log und geschützte Full-Text-/Crawl-Logs in der Laufzeitumgebung korrelieren. Reale Logdaten oder interne Strukturen nicht in Repositoryartefakte übernehmen.

## Leere oder partielle Ausgabe

Eine leere Population-DMV ist weder Abschlussnachweis noch Historie. Fehlende DMV-Rechte lassen zugängliche Katalog- und Fragmentevidenz gültig; die Procedure kennzeichnet die Lücke über `IsPartial` und `SourceStatus`. `NOT_APPLICABLE_VISIBLE_SCOPE` beweist bei eingeschränkter Metadatensichtbarkeit keine vollständige Abwesenheit.

## Eigenlast

MEDIUM: sichtbare Kataloge, Fragmente und aggregierte Full-Text-DMVs. Es werden keine Tabellenzeilen, Keywords, Stopwords, Parser-Eingaben, Schlüsselwerte, Crawl-Logs oder Pfade gelesen und kein `ALTER FULLTEXT` ausgeführt.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Full-Text Catalogs/Indexes konfiguriert, und laufen Population/Change Tracking ohne sichtbare Fehler oder Rückstand?

### Technischer Hintergrund

Full-Text Engine tokenisiert sprachabhängig, speichert invertierte Indizes in Catalogs und aktualisiert sie über Full/Incremental/Auto Population. Stoplists, Search Properties und Change Tracking beeinflussen Inhalt. Population DMVs zeigen aktive Crawls/Phasen.

### Datenkette

`sys.dm_fts_fdhosts`, `sys.dm_fts_index_population`, `sys.dm_fts_memory_pools`, `sys.dm_fts_outstanding_batches`, `sys.dm_fts_semantic_similarity_population`, `sys.fulltext_catalogs`, `sys.fulltext_index_columns`, `sys.fulltext_index_fragments`, `sys.fulltext_indexes`, `sys.indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Metadaten-/Populationzustand plus begrenzte Crawl-/Errorhistorie.

### Bewertung und Gegenprobe

Catalog/Index, Change Tracking State, Population Type/Status, Start/End, Items processed/failed, Fragmentcount, Language/Stoplist und Base-Table-Änderung korrelieren. Querybedarf bestimmt Dringlichkeit.

### Typische Fehlinterpretation

`IDLE` kann erfolgreich fertig oder nie gestartet bedeuten. Ein vorhandener Full-Text-Index garantiert keine aktuelle Vollständigkeit oder semantisch passende Wordbreaker.

### Folgeanalyse

Full-Text Crawl Logs/Errorlog, Job/Populationstart und konkrete CONTAINS-Query.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#6-monitorusp_fulltextanalysis)
