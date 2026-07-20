# [monitor].[USP_CurrentOverview]

**Bereich:** Current State, Orchestrator<br>
**Zweck:** Führt mehrere leichte Live-Analysen in definierter Reihenfolge aus.<br>
**Beobachtungsart:** nicht atomare Folge aus Snapshots und optionalen Stichproben<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Current-State-Symptome verdienen als Erstes eine spezialisierte Analyse?** Der dokumentierte Zweck ist: Führt mehrere leichte Live-Analysen in definierter Reihenfolge aus. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Nahe beieinanderliegende, aber nicht atomare Momentaufnahmen; Samplingchildren können den Aufruf verlängern. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentOverview]
      @MitSqlText = 0,
      @SampleSeconds = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Default `@Detailgrad = 'SUMMARY'` liefert genau ein konsolidiertes
Modul-Summary. `RELEVANT` ergänzt nicht leere diagnostisch relevante Details;
`ALL` ergänzt alle nicht leeren aktivierten Childdetails. Sampling und
vollständige SQL-Texte nur gezielt aktivieren.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus`, `sessions`, `requests`, `blocking`, `waits`, `transactions`, `memoryGrants`, `tempdbSessions`, `io`, `logs`, `warnings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Im Summary entspricht eine Zeile einem Childmodul. Status, Partialität,
Zeilenanzahl und Dauer stammen aus dem expliziten Childvertrag. In den bewusst
aktivierten Detailgraden entspricht eine Detailzeile weiterhin Session, Request,
Blockingkante, Wait, Transaktion, Grant, TempDB-Verbrauch, Datei-I/O oder
Logzustand.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Modulstatus, dann vom konkreten Symptom zum passenden Child wechseln. Resultsets nicht ungeprüft miteinander addieren.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Überblick verdichtet unterschiedliche Evidenzarten. Ein auffälliger Einzelwert ohne Childkontext kann zu einer falschen Ursache führen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Blocking und hohe Logauslastung können dieselbe alte Transaktion als Ursache haben. Mit Blocking- und Transaktionsprocedure fokussiert nachprüfen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Children fehlen absichtlich. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentOverview` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Der Default ruft alle neun Current-State-Children einmal auf, materialisiert deren TABLE-Ergebnisse und erzeugt Childstatus/JSON. `@Detailgrad = 'SUMMARY'` verkürzt nur die sichtbare Ausgabe; er spart die Erhebung nicht ein. Mit `@SampleSeconds = 0` gibt es kein WAITFOR. |
| Teuerster Pfad | Breiter Datenbank- und Sessionscope, SQL-Text an und `@SampleSeconds = 60`: `USP_CurrentWaits` und `USP_CurrentIO` sampeln nacheinander, sodass allein die beiden WAITFOR-Intervalle den Parent um ungefähr 120 Sekunden verlängern können. |
| Haupttreiber | Zahl sichtbarer Sessions, Requests, Blockingkanten, Transaktionen, Grants und TempDB-Verbraucher sowie Datenbanken/Dateien für I/O und Log. SQL-Text verbreitert mehrere Childresultate. |
| Skalierung | Jedes Child liest seinen eigenen Zeitpunkt und schreibt in eine Parent-Temp-Tabelle. Kosten addieren sich sequenziell; derselbe Request kann in mehreren Children erneut gelesen werden. Mehr Detailausgabe erhöht Transfer, ändert aber nicht die bereits angefallene Childarbeit. |
| Ressourcen | Live-DMV- und Datenbankmetadatenzugriffe, Temp-Tabellen/JSON und optional zwei wartende Samplephasen. Es gibt in diesem Parent keinen XEL-, Plan-XML-, `msdb`- oder Benutzerdatenscan. |
| Begrenzungswirkung | `@MaxZeilen` wird je Child weitergereicht und ist kein globales Budget. Einige Children nutzen ein frühes Kandidatenlimit, andere begrenzen erst sortierte/aggregierte Resultate; die Quellen für Instanzwaits und Datei-I/O werden dadurch nicht vollständig vermieden. `SUMMARY` ist ausdrücklich kein Kostenlimit. |
| Locking und Nebenwirkungen | Read-only ohne absichtlich gehaltene Nutzdatenlocks. Sampling hält die aufrufende Session während jedes WAITFOR; die Children laufen nacheinander und bilden daher keinen atomaren Zustand. |
| Schutzmechanismus | `@HighImpactConfirmed` wird an datenbankbezogene Children weitergereicht und wirkt nur, wenn deren konkrete Analyseklasse ein Gate verlangt. Der Parent aktiviert keine VLF-, Datei-, XML- oder sonstige Deep-Option; der Schalter begrenzt weder Laufzeit noch Ergebnisgröße. |
| Sicherer Einsatz | SQL-Text und Sampling zunächst aus, `@MaxZeilen = 100`, nicht benötigte Children abschalten und Datenbanken/Sessions eingrenzen. Nach dem Summary genau das Child separat wiederholen, das zum Symptom passt. |
| Aussagegrenze | Ein Child kann zwischen den sequenziellen Abfragen verschwinden oder neu entstehen. Ein Parentlimit kann Ranglisten abschneiden, und ein erfolgreicher Summarystatus macht die unterschiedlichen Messzeitpunkte nicht konsistent; „leer“ bedeutet nur im jeweiligen Childmoment nicht sichtbar. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Current-State-Symptome verdienen als Erstes eine spezialisierte Analyse?

### Technischer Hintergrund

Der Orchestrator ruft jedes aktivierte Child genau einmal und niemals mit
CONSOLE auf. Der eine Childaufruf materialisiert das Primärergebnis und erzeugt
den JSON-/Statusvertrag. Summary, optionale Details, JSON und TABLE-Export nutzen
diese Materialisierung weiter. Das Ausbleiben eines SQL-Fehlers wird nicht als
`AVAILABLE` interpretiert; ein fehlender oder unvollständiger Statusvertrag wird
als `STATUS_UNAVAILABLE` partiell ausgewiesen.

TABLE verwendet ausschließlich `@ResultTablesJson`. Exportierbar sind
`moduleStatus`, `sessions`, `requests`, `blocking`, `waits`, `transactions`,
`memoryGrants`, `tempdbSessions`, `io`, `logs` und `warnings`.

### Datenkette

Frameworkinterne Orchestrierung/Filterlogik; keine eigenständige Systemquelle.

### Zeit- und Scope-Modell

Nahe beieinanderliegende, aber nicht atomare Momentaufnahmen; Samplingchildren können den Aufruf verlängern.

### Bewertung und Gegenprobe

Zuerst Modulstatus und Partialflags, dann nur auffällige Children vertiefen. Korrelation ist möglich, wenn dieselbe Session/DB/Datei in mehreren Children erscheint.

### Typische Fehlinterpretation

Ein unauffälliger Overview beweist nicht, dass zwischen Childaufrufen kein kurzer Vorfall auftrat. Resultsets dürfen nicht so behandelt werden, als stammten sie aus einer gemeinsamen Transaktion.

### Folgeanalyse

Betroffenes Childmodul mit engeren Filtern erneut ausführen.

## Primärquellen

- [Dynamic Management Views](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#10-monitorusp_currentoverview)
