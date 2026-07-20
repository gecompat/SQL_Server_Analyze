# [monitor].[USP_BackupRecovery]

**Bereich:** Infrastruktur<br>
**Zweck:** Bewertet Backupalter, Recovery Model, Logbackupbedarf und Restorehistorie.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?** Der dokumentierte Zweck ist: Bewertet Backupalter, Recovery Model, Logbackupbedarf und Restorehistorie. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Historie innerhalb `msdb`-Retention; Datenträger/Dateien werden nicht geöffnet. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupRecovery]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `freshness` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Hauptzeile beschreibt den Backup-/Recoveryzustand einer Datenbank; Historienresultsets enthalten einzelne Backup- oder Restoreereignisse.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Recovery Model, Alter von Full/Diff/Log, letzte erfolgreiche Sicherung, Copy-only und Restorehistorie gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Alte oder fehlende Logbackups vergrößern möglichen Datenverlust und können bei FULL/BULK_LOGGED die Log-Wiederverwendung verhindern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

In SIMPLE Recovery sind Logbackups nicht vorgesehen. Eine fehlende Differential-Sicherung kann durch die Backupstrategie abgedeckt sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** FULL Recovery, letztes Logbackup vor sechs Stunden, RPO 30 Minuten: kritisch. SIMPLE plus kein Logbackup: erwartbar. Backupkette und echten Restore-Test prüfen.

**Ähnlich aussehender Gegenfall:** In SIMPLE Recovery sind Logbackups nicht vorgesehen. Eine fehlende Differential-Sicherung kann durch die Backupstrategie abgedeckt sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_BackupRecovery` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase` mit Freshnessbewertung, bis zu 5000 Backupzeilen und optionaler Restorehistory. Die Warnschwellen sind Bewertungsgrenzen, kein History-Cutoff. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, `@MaxZeilen = 0` und Restorehistory aktiv auf einer msdb mit sehr umfangreicher Backup-/Restorehistorie. |
| Haupttreiber | Zahl ausgewählter Datenbanken sowie Backupset-, Medien- und Restore-Historyzeilen im Lookback. Lange Aufbewahrung und häufige Logbackups vergrößern die msdb-Quellen deutlich stärker als die aktuelle Datenbankzahl allein. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BackupRecovery ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen alle msdb-Joins. `@MitRestoreHistory = 0` lässt diesen Pfad aus. `@MaxZeilen` wird auf Backup- und Restoreausgabe angewandt; die Freshnessaggregation über Backupset kann zuvor mehr Zeilen prüfen. Warnstunden/-minuten verändern nur Klassifikation. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | `@AnalysisClass = NULL`; `@HighImpactConfirmed` schaltet keinen Deep-Pfad frei. Die wirksamen Grenzen sind Datenbankscope, endliches Zeilenlimit und der Restorehistory-Schalter. |
| Sicherer Einsatz | Eine `ExampleDatabase`, endliches Limit und nur benötigte Restorehistory. Auf msdb mit langer Retention zunächst Freshness/Summary lesen, bevor Detailmengen erweitert werden. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?

### Technischer Hintergrund

`msdb` speichert Backup Sets, Medien-/Dateiinformation, Type, LSNs, Start/Finish, Size/Compression/Checksum und Damageindikatoren. Recovery Model bestimmt, ob eine kontinuierliche Logkette erwartet wird.

### Datenkette

`msdb.dbo.backupmediafamily`, `msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Zeit- und Scope-Modell

Historie innerhalb `msdb`-Retention; Datenträger/Dateien werden nicht geöffnet.

### Bewertung und Gegenprobe

Letzte Backupzeiten gegen RPO/Policy, Recovery Model, CopyOnly, Checksum, Damage, Größe/Dauer und Logbackupkontinuität prüfen. SIMPLE benötigt keine Logbackups, FULL ohne regelmäßige Logbackups verhindert Logtruncation.

### Typische Fehlinterpretation

Eine erfolgreiche Backup-Historyzeile beweist weder Dateiexistenz noch erfolgreichen Restore. `RESTORE VERIFYONLY` ist ebenfalls kein vollständiger Restoretest.

### Folgeanalyse

`USP_BackupChainAnalysis`, Database Integrity und regelmäßiger echter Restoretest.

## Primärquellen

- [Backup und Restore](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md#5-monitorusp_backuprecovery)
