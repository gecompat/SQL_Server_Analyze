# [monitor].[USP_BackupChainAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Prüft Full-/Diff-/Log-Beziehungen, LSN-Folgen und optionale Restoreevidenz.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?** Der dokumentierte Zweck ist: Prüft Full-/Diff-/Log-Beziehungen, LSN-Folgen und optionale Restoreevidenz. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: `msdb`-Metadaten im gewählten Fenster; ein zu kurzes Fenster kann die notwendige Basis ausblenden. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupChainAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HistoryDays = 35,
      @MitRestoreEvidence = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `summary` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile ein Backup, eine Kettenbeziehung, ein LSN-Segment, Restoreevidenz oder ein Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Full-Basis, Differential Base, Log-LSN-Folge und Gaps in zeitlicher Reihenfolge lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Eine unterbrochene LSN-Kette kann Point-in-Time-Restore verhindern. Vorhandene Dateien garantieren keine wiederherstellbare Folge.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Copy-only Full verändert die Differential Base nicht und darf nicht als Kettenbruch bewertet werden.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Full und viele Logbackups vorhanden, aber ein LSN-Segment fehlt: Restore bis zum Ende nicht möglich. Medien und echten Restore testen.

**Ähnlich aussehender Gegenfall:** Copy-only Full verändert die Differential Base nicht und darf nicht als Kettenbruch bewertet werden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_BackupChainAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`, 35 Tage Backuphistorie, Restoreevidenz aktiv und endliches Limit; der letzte nicht-copy-only Full vor dem Fenster wird als Kettenanker zusätzlich gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, `@HistoryDays = 3650`, Restoreevidenz und unbegrenzte Ausgabe auf einer msdb mit sehr langer Backup-/Restore-Retention. |
| Haupttreiber | Zahl ausgewählter Datenbanken sowie Full-/Diff-/Log-Backupsets und optionaler Restore-Historyzeilen im Lookback. Häufige Logbackups vergrößern LSN-Sortierung und Kettenkorrelation besonders stark. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BackupChainAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankscope und `@HistoryDays` begrenzen Backupquellen, wobei der letzte Full vor dem Fenster bewusst zusätzlich gesucht wird. `@MitRestoreEvidence = 0` lässt Restorehistory aus. `@MaxZeilen` wirkt erst je fertigem Summary-/Backupresultset. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Der Datenbankkandidatenpfad verwendet `@AnalysisClass = NULL`; `@HighImpactConfirmed` aktiviert hier keinen Deep-Pfad. Schutz bieten explizite Datenbank, Historyfenster und optional ausgelassene Restoreevidenz. |
| Sicherer Einsatz | Eine `ExampleDatabase`, 35 Tage und endliches Limit; Restoreevidenz nur auslassen, wenn die Entscheidung sie nachweislich nicht benötigt. Lange Retentionen datenbankweise prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?

### Technischer Hintergrund

Fullbackups definieren Database Backup LSN/Checkpoint; Differentials basieren auf Differential Base; Logbackups decken First/Last LSN und Recovery Forks ab. CopyOnly beeinflusst Differential Base beziehungsweise Logkette unterschiedlich. Restorefolge muss LSN- und Forkkonsistenz wahren.

### Datenkette

`msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Zeit- und Scope-Modell

`msdb`-Metadaten im gewählten Fenster; ein zu kurzes Fenster kann die notwendige Basis ausblenden.

### Bewertung und Gegenprobe

Recovery Fork, Fullbasis, Differential Base, Log First/Last LSN, Gap-/Overlapindikatoren, CopyOnly und Backupzeiten prüfen. Kette je gewünschtem Restorezeitpunkt bewerten.

### Typische Fehlinterpretation

Metadatenkonsistenz beweist nicht, dass Medien vorhanden, unbeschädigt, entschlüsselbar oder zugreifbar sind. Ein vermeintliches Gap kann durch außerhalb des Fensters liegende Sets entstehen.

### Folgeanalyse

Echter Restoretest, `USP_BackupRecovery`, Encryption-/Certificate-Governance.

## Primärquellen

- [Backup history and header information](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-history-and-header-information-sql-server?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md#9-monitorusp_backupchainanalysis)
