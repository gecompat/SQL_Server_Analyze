# [monitor].[USP_DatabaseIntegrityAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Korrelierte Integritätsevidenz aus Datenbankstatus, CHECKDB-Historie, suspect pages, Backups und HADR.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Metadaten weisen auf Integritätsrisiko, veralteten CHECKDB-Nachweis, suspect pages, beschädigte Backups oder offene HADR-Seitenreparatur hin?** Der dokumentierte Zweck ist: Korrelierte Integritätsevidenz aus Datenbankstatus, CHECKDB-Historie, suspect pages, Backups und HADR. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Historische/aktuelle Metadaten mit unterschiedlicher Retention; kein Live-CHECKDB. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPageDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

Für vollständige serverweite Evidenz ist auf SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE` erforderlich. Fehlt dieses Recht, bleibt zulässige Teilevidenz sichtbar, der Status lautet jedoch ausdrücklich `AVAILABLE_LIMITED` mit `IsPartial=1`.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `integrity` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbank, einer suspect page, Backup-/CHECKDB-Evidenz, HADR-Reparatur oder einem Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Datenbankstatus, PAGE_VERIFY, Alter letzter Integritätsprüfung, suspect pages, Backupchecksums und HADR-Reparaturen gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Suspect Pages oder beschädigte Backupevidenz sind konkrete negative Indikatoren möglicher physischer oder inhaltlicher Schäden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Keine negativen Indikatoren beweisen keine Integrität; die Procedure führt keinen vollständigen CHECKDB aus.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `SuspectPageCount=0` heißt nur „Quelle meldet nichts“. `SuspectPageCount=3` ist konkrete negative Evidenz und verlangt Eskalation, CHECKDB-Strategie, Backupkette und Restore-Test.

**Ähnlich aussehender Gegenfall:** Keine negativen Indikatoren beweisen keine Integrität; die Procedure führt keinen vollständigen CHECKDB aus. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DatabaseIntegrityAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`, 35 Tage Backup-/CHECKDB-Metadaten, suspect pages und HADR-Auto-Page-Repair ohne Seitenauflösung. Kein DBCC-Lauf. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, langer Backup-Lookback, `@MitPageDetails = 1` und unbegrenzte Ausgabe bei vielen suspect/repair-Seiten; jede sichtbare Seite wird gezielt über `sys.dm_db_page_info` aufgelöst. |
| Haupttreiber | Zahl gewählter Datenbanken, Backup-/CHECKDB-Metadaten im Lookback sowie suspect- und HADR-Auto-Page-Repair-Zeilen. `@MitPageDetails = 1` fügt für jede sichtbare Seite einen eigenen `sys.dm_db_page_info`-Aufruf hinzu. |
| Skalierung | Metadatenpfad wächst mit Datenbanken und relevanter msdb-Retention. Der optionale Seitenpfad wächst mit suspect-/repair-Seiten und kann zusätzliche Buffer-/Storage-I/O verursachen. |
| Ressourcen | CPU und Katalog-/msdb-I/O für Status, Backupset und suspect pages; optional gezielte Page-Metadaten-I/O über `sys.dm_db_page_info`; kleine temporäre Evidenztabellen. |
| Begrenzungswirkung | Datenbankscope und `@BackupHistoryDays` begrenzen relevante Quellen. `@MaxZeilen` wirkt auf fertige Evidenz; es schützt nicht sicher vor allen Backupaggregationen oder jedem bereits ausgewählten Seitenprobe. `@MitPageDetails = 0` ist die wichtigste Lastgrenze. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | `HA_DR_CURRENT` verlangt laut Klassenkatalog keine High-Impact-Bestätigung; `@HighImpactConfirmed` schaltet die Seitenauflösung nicht. Diese wird ausschließlich durch `@MitPageDetails` opt-in aktiviert. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Seitenauflösung aus und begrenzter Lookback. Page Details erst für eine kleine bereits sichtbare suspect-/repair-Menge und außerhalb der I/O-Spitze aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + retentionbegrenzte Metadatenhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Metadaten weisen auf Integritätsrisiko, veralteten CHECKDB-Nachweis, suspect pages, beschädigte Backups oder offene HADR-Seitenreparatur hin?

### Technischer Hintergrund

Page Verify CHECKSUM erkennt bestimmte Pageänderungen bei Read; `suspect_pages` speichert erkannte Pageereignisse; DBINFO/Property kann Last Good CHECKDB liefern; Backupsets enthalten checksum/damage flags; HADR Auto Page Repair dokumentiert Reparaturversuche.

### Datenkette

`master.sys.databases`, `msdb.dbo.backupset`, `msdb.dbo.suspect_pages`, `sys.dm_db_page_info`, `sys.dm_hadr_auto_page_repair`.

### Zeit- und Scope-Modell

Historische/aktuelle Metadaten mit unterschiedlicher Retention; kein Live-CHECKDB.

### Bewertung und Gegenprobe

Jede Suspect Page, damaged backup oder pending page repair hoch priorisieren. Last Good CHECKDB gegen Policy, Datenbankgröße und Backup/Restorestrategie prüfen. EvidenceLimit immer mitlesen.

### Typische Fehlinterpretation

`0` negative Einträge beweist keine Integrität. `RESTORE VERIFYONLY` prüft nicht alle Daten und ersetzt weder CHECKDB noch echten Restore.

### Folgeanalyse

Geplanter CHECKDB, Backup Chain, echter Restoretest und Storage-/Errorlog/XE-Korrelation.

## Primärquellen

- [DBCC CHECKDB](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Integrity Check – betriebliche CHECKDB-Praxis](https://ola.hallengren.com/sql-server-integrity-check.html)

[Technische Detailbeschreibung](../08_Server_Health.md#11-monitorusp_databaseintegrityanalysis)
