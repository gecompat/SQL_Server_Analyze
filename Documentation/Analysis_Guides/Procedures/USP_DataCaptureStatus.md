# [monitor].[USP_DataCaptureStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt CDC-, Change-Tracking- und weitere Data-Capture-Zustände.<br>
**Beobachtungsart:** Konfigurations- und Runtime-Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?** Der dokumentierte Zweck ist: Zeigt CDC-, Change-Tracking- und weitere Data-Capture-Zustände. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Enablement-/Konfigurationszustand mit begrenzten Job-/LSN-/Versionmarken. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureStatus]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `databases` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, ein Capture-Feature, einen Job oder eine erfasste Tabelle.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Featurestatus, Capture-/Cleanup-Job, Retention, Datenbankzustand und Logkontext unterscheiden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Aktiviertes CDC ohne laufenden Capturejob kann Logrückstand erzeugen; Cleanupfehler lassen Capturetabellen wachsen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Deaktiviertes CDC oder Change Tracking ist normal, wenn die Datenbank das Feature nicht benötigt.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** CDC enabled plus Capturejob disabled ist ein konkreter Fehlerzustand. Agentjobs, Logstatus und Featurekonfiguration prüfen.

**Ähnlich aussehender Gegenfall:** Deaktiviertes CDC oder Change Tracking ist normal, wenn die Datenbank das Feature nicht benötigt. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_DataCaptureStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Mittel; lokale Kandidaten werden je Datenbank auf N+1 begrenzt, anschließend erfolgt ein globales TOP je fachlichem Resultset.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`; CDC-Capture-Instances, Change-Tracking-Tabellen und zugeordnete CDC-Jobs werden als aktueller Konfigurations-/Statussnapshot gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken und unbegrenzte Ausgabe bei vielen erfassten Tabellen. Je CDC-Job wird nur die letzte Outcome-Historyzeile aufgelöst, kein frei wählbares Historyfenster. |
| Haupttreiber | Zahl sichtbarer Datenbanken und aktivierter CDC-/Change-Tracking-Konfigurationen sowie zugehöriger lokaler CDC-Jobs und letzter Historyzeilen. Change-Tabelleninhalte und Replikationsbefehle werden in diesem Statuspfad nicht gelesen. |
| Skalierung | Aufwand wächst mit Datenbanken, CDC-Instances, Change-Tracking-Tabellen und Jobs. Pro Datenbank werden lokal höchstens N+1 Kandidaten je fachlichem Pfad übernommen, anschließend global begrenzt. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankscope begrenzt den Cursor. `@MaxZeilen` steuert lokale N+1-Kandidaten und das globale TOP je Resultset; es ist keine gemeinsame Gesamtgrenze über CDC, CT und Jobs und verhindert nicht jede Katalog-/letzte-History-Suche. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | `HA_DR_CURRENT` muss freigegeben sein, verlangt laut Klassenkatalog aber keine High-Impact-Bestätigung. `@HighImpactConfirmed` aktiviert hier keinen zusätzlichen Detailpfad. |
| Sicherer Einsatz | Eine `ExampleDatabase` und endliches Limit; Datenbankstatus vor den drei getrennten Fachresultsets lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurations- und Runtime-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?

### Technischer Hintergrund

CDC liest Transaction Log asynchron in Change Tables und räumt per Cleanupjob auf. Change Tracking speichert kompakte Änderungsinformationen mit Retention/Auto Cleanup, keine vollständigen historischen Werte. Replication besitzt eigenen Logreader-/Distributionspfad.

### Datenkette

`master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Der Basisstatus verbindet die Datenbankoption mit den Change-Tracking-Tabellen der ausgewählten Datenbank:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , [d].[is_cdc_enabled]
    , [ctd].[retention_period]
    , [ctd].[retention_period_units_desc]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
LEFT JOIN [sys].[change_tracking_databases] AS [ctd] WITH (NOLOCK)
  ON [ctd].[database_id] = [d].[database_id]
WHERE [d].[database_id] = DB_ID();

SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [ct].[begin_version]
    , CHANGE_TRACKING_MIN_VALID_VERSION([ct].[object_id]) AS [MinValidVersion]
FROM [sys].[change_tracking_tables] AS [ct] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK)
  ON [t].[object_id] = [ct].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
WHERE [t].[is_ms_shipped] = 0;
```

**Wichtig für die Eigenlast:** Die Datenbankauswahl erfolgt vor dem dynamischen datenbanklokalen Katalogzugriff. Jobhistorie nur für tatsächlich aktivierte CDC-Datenbanken und mit Zeitfenster ergänzen.

### Zeit- und Scope-Modell

Aktueller Enablement-/Konfigurationszustand mit begrenzten Job-/LSN-/Versionmarken.

### Bewertung und Gegenprobe

Technologie, Captureinstanzen, Jobs, Retention, Min/Max LSN oder Change Tracking Versions und Tabellenabdeckung lesen. Consumerposition gegen Mindestversion/MinLSN prüfen.

### Typische Fehlinterpretation

`Enabled=1` beweist keinen aktuellen Durchsatz, keine lückenlose Retention und keine funktionierenden Consumer.

### Folgeanalyse

`USP_DataCaptureDeepAnalysis`, Agent Jobs und Consumercheckpoint.

## Primärquellen

- [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#8-monitorusp_datacapturestatus)
