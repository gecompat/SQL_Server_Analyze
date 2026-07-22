# [monitor].[USP_TraceFlags]

**Bereich:** Server Health<br>
**Zweck:** Inventarisiert aktive globale und sessionbezogene Trace Flags.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche globalen oder sessionbezogenen Trace Flags sind aktiv und welche Engineverhaltensänderung ist damit verbunden?** Der dokumentierte Zweck ist: Inventarisiert aktive globale und sessionbezogene Trace Flags. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Runtimezustand; Sessionflags gelten nur im Kontext, globale bis Deaktivierung/Restart. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TraceFlags]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `traceFlags` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem aktiven Trace Flag und seinem Scope.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Flagnummer, global/session Scope, Aktivierungsquelle, Version und dokumentierte Bedeutung prüfen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Undokumentierte oder veraltete Flags können Optimizer- oder Engineverhalten unerwartet verändern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Dokumentierte Flags können bewusste Workarounds oder Diagnosehilfen sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein altes Kompatibilitätsflag nach Upgrade kann neue Standardverbesserungen überdecken. Startup Parameters, Microsoft-Dokumentation und Changehistorie prüfen.

**Ähnlich aussehender Gegenfall:** Dokumentierte Flags können bewusste Workarounds oder Diagnosehilfen sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_TraceFlags` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Führt genau einmal `DBCC TRACESTATUS(-1) WITH NO_INFOMSGS` aus und gibt die aktiven globalen/sessionbezogenen Flags aus. CONSOLE, RAW, TABLE und JSON projizieren dieselbe materialisierte kleine Quelle. |
| Teuerster Pfad | Gegenüber dem Standard gibt es keinen tieferen Quellpfad; zusätzliche Ausgabeformate erhöhen nur Serialisierung und Transfer der bereits ermittelten Flagzeilen. |
| Haupttreiber | Anzahl aktuell aktiver Trace Flags. Es werden weder Konfigurationskataloge noch Scheduler-DMVs, Startupdateien oder Datenbankobjekte gescannt. |
| Skalierung | Die DBCC-Ausgabe ist instanzweit und gewöhnlich sehr klein. Sortierung nach Flagnummer und JSON-/TABLE-Ausgabe wachsen linear mit den aktiven Flags. |
| Ressourcen | Geringe CPU und eine kleine Temp-Tabelle für die vier DBCC-Spalten `TraceFlag`, `Status`, `GlobalFlag`, `SessionFlag`. |
| Begrenzungswirkung | Die Procedure besitzt weder Scopefilter noch `@MaxZeilen`; es wird absichtlich die vollständige aktive Flagliste ausgegeben. `@ResultSetArt = 'NONE'` unterdrückt Ausgabe, spart aber den DBCC-Aufruf nicht. |
| Locking und Nebenwirkungen | `DBCC TRACESTATUS` liest nur Zustand und aktiviert/deaktiviert kein Flag. Es werden keine Nutzdatenlocks absichtlich gehalten; die Flagkonfiguration kann sich unmittelbar nach dem Snapshot ändern. |
| Schutzmechanismus | Kein Gate und kein Limit. Der Quellvertrag ist konstruktiv auf genau einen read-only `DBCC TRACESTATUS(-1)`-Aufruf begrenzt; die Procedure setzt oder löscht keine Trace Flags. Ausgabeunterdrückung ist kein Quellkostenschutz. |
| Sicherer Einsatz | CONSOLE im Standardpfad und Status zuerst lesen. Die Ausgabe enthält Flagnummer und Scope, aber keine Pfade, SQL-Texte oder Konfigurationswerte. |
| Aussagegrenze | Der Snapshot zeigt nur aktive Flags und erklärt weder ihren Zweck noch, ob sie per Startup, globalem DBCC oder Session gesetzt wurden. Für Supportstatus und Wirkung sind SQL-Version, Scope und separate Startparameter-/Konfigurationsquellen nötig. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche globalen oder sessionbezogenen Trace Flags sind aktiv und welche Engineverhaltensänderung ist damit verbunden?

### Technischer Hintergrund

Trace Flags aktivieren Diagnose- oder Verhaltenspfade auf globaler/sessionbezogener Scope. Manche wurden durch Database Scoped Configurations oder neuere Defaults ersetzt; Supportstatus ist versionsabhängig. Startupparameter können globale Flags früh setzen.

### Datenkette

`DBCC TRACESTATUS(-1)` → Temp-Tabelle → nach Flagnummer sortierte
CONSOLE-/RAW-/TABLE-/JSON-Projektion. Es gibt keine Childmodule.

### Source Select

Kein `SELECT` auf eine DMV: Die Engine stellt aktive Trace Flags über einen DBCC-Befehl bereit. Der direkte Quellaufruf lautet:

```sql
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;
```

Die Procedure fängt dieses Resultset in einer lokalen Temp-Tabelle ab und projiziert es sortiert in die Ausgabeformate.

**Wichtig für die Eigenlast:** Der Befehl liefert nur aktive globale und sessionbezogene Flags und ändert keinen Zustand. Es existiert kein serverseitiger Flagfilter; Filterung erfolgt erst nach der kleinen DBCC-Ausgabe.

### Zeit- und Scope-Modell

Aktueller Runtimezustand; Sessionflags gelten nur im Kontext, globale bis Deaktivierung/Restart.

### Bewertung und Gegenprobe

Flagnummer, Scope, Startupbezug, dokumentierter Zweck, Version und aktuelle Notwendigkeit prüfen. Undokumentierte Flags besonders vorsichtig behandeln.

### Typische Fehlinterpretation

Aktiv heißt nicht, dass jeder Workloadpfad betroffen ist. Ein früher notwendiges Flag kann nach Upgrade redundant oder schädlich sein.

### Folgeanalyse

`USP_StartupParameters`, Server Configuration und offizielle versionsspezifische Dokumentation.

## Primärquellen

- [DBCC TRACESTATUS](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-tracestatus-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#6-monitorusp_traceflags)
