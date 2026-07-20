# [monitor].[USP_CheckFrameworkCapabilities]

**Bereich:** Common<br>
**Zweck:** Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?** Der dokumentierte Zweck ist: Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Umgebungszustand; Ergebnisse können sich nach Konfigurationsänderung, Failover, Datenbankstatuswechsel oder Berechtigungsänderung ändern. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @NurNichtVerfuegbar = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `capabilities` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Capability-Zeile bewertet ein Feature in einem Server- oder Datenbank-Scope. Dieselbe Fähigkeit kann deshalb je Datenbank unterschiedlich ausfallen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

In dieser Reihenfolge lesen: `VersionSupported` → `GroupAccessAllowed` → `HasRequiredPermission` → `IsQueryable` → `IsFeatureEnabled` → `IsUsable`.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

`HasRequiredPermission=1`, aber `IsQueryable=0` zeigt, dass eine formale Permission nicht genügt. Datenbankstatus, Plattform, Replica-Rolle oder Laufzeitfehler begrenzen den Pfad.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Query Store kann versionsseitig unterstützt und lesbar, aber deaktiviert sein. Ein leeres Query-Store-Resultset sagt dann nichts über die Queryqualität. Nur Scopes mit `IsUsable=1` fachlich auswerten.

**Ähnlich aussehender Gegenfall:** Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Hilfsprocedures kann eine leere interne Zieltabelle aus bewusst leerem Filter, ungültiger Eingabe oder fehlender Policy entstehen; diese Fälle dürfen nicht zu einem ungefilterten Parentlauf zusammenfallen.

Für `USP_CheckFrameworkCapabilities` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Fehlende Capability-Zeilen können durch eine explizite Datenbankauswahl, Rechte
oder nicht verfügbare Datenbanken entstehen. Status und Warnings gehören
zwingend zur Bewertung.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Ohne Scope werden alle sichtbaren Online-Benutzerdatenbanken mit allen Katalogfeatures kombiniert. Für jede Serverfeaturezeile und jede `(Datenbank, Feature)`-Zeile prüft der Code Version, Gruppe, Berechtigung, Abfragbarkeit und optional Enablement. |
| Teuerster Pfad | Viele Datenbanken × viele Datenbankfeatures mit `@MitGruppenpruefung = 1`; jede Kombination führt kleine dynamische Permission-/Probe-/Enablementstatements aus. Es sind Metadatenprobes, keine Fachanalyse- oder Nutzdatenscans. |
| Haupttreiber | Produkt aus Zahl der ausgewählten Datenbanken und DATABASE-Features plus konstante SERVER-Features. Dynamisches SQL wird je Kombination kompiliert/ausgeführt. |
| Skalierung | Annähernd linear mit den Featurekombinationen. Eine einzelne Analyseklasse reduziert den Featurekatalog früh; Datenbankscope reduziert DATABASE-Kombinationen. JSON/Sortierung sind nachgeordnet. |
| Ressourcen | Frameworkkatalogviews, `master`-Datenbankkandidaten, Login-/Permissionchecks und kurze Metadatenprobes per `sp_executesql`; Temp-Tabellen für Capability- und Warningzeilen. |
| Begrenzungswirkung | `@DatabaseNames` und `@AnalyseKlasse` begrenzen tatsächliche Probeanzahl. `@NurNichtVerfuegbar` filtert erst die Ausgabe und spart keine Probes. Es gibt kein `@MaxZeilen`. |
| Locking und Nebenwirkungen | Read-only; Probe- und Enablementtemplates werden nur abgefragt, nicht konfiguriert. Datenbankstatus/Berechtigung kann sich während der Schleife ändern, daher sind Capabilityzeilen kein atomarer Snapshot. |
| Schutzmechanismus | Der Aufruf an `USP_PrepareDatabaseCandidates` verwendet bewusst `@AnalysisClass = NULL`; damit löst `@HighImpactConfirmed` hier kein Deep-Gate aus. Schutz sind Feature-/Datenbankscope und ausschließlich leichte Capabilityprobes. |
| Sicherer Einsatz | Eine `ExampleDatabase` und eine konkrete Analyseklasse prüfen; die vollständige Matrix nur für Inventar-/Upgradeaudits ausführen. `@NurNichtVerfuegbar` dient Lesbarkeit, nicht Lastreduktion. |
| Aussagegrenze | `IsUsable` beweist, dass der kleine Capabilityprobe im aktuellen Kontext funktioniert. Es garantiert weder Berechtigung auf jede spätere Fachzeile noch geringe Kosten, Datenvollständigkeit oder erfolgreiche Ausführung des eigentlichen Analysemoduls. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?

### Technischer Hintergrund

Version, Edition, Featurekonfiguration und formale Permission sind verschiedene Ebenen. Die Procedure führt capability-orientierte Prüfungen aus und kann geschützte Testabfragen dynamisch ausführen. Dadurch wird zwischen `supported`, `enabled`, `permitted`, `queryable` und `usable` unterschieden.

### Datenkette

`sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Umgebungszustand; Ergebnisse können sich nach Konfigurationsänderung, Failover, Datenbankstatuswechsel oder Berechtigungsänderung ändern.

### Bewertung und Gegenprobe

Die Prüfkette in der dokumentierten Reihenfolge lesen. `HasRequiredPermission=1` bei `IsQueryable=0` weist auf eine zusätzliche Laufzeitgrenze hin. `IsFeatureEnabled=0` kann bei bewusst ungenutztem Feature normal sein.

### Typische Fehlinterpretation

Capability ist kein Nachweis, dass relevante Daten vorhanden sind. Query Store kann nutzbar, aber leer sein; XE kann abfragbar, aber ohne passende Session sein.

### Folgeanalyse

Nur Fachmodule starten, deren benötigte Quelle nutzbar ist; bei Partialstatus die jeweilige Datenbank/Quelle gezielt prüfen.

## Primärquellen

- [sys.sp_executesql](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#2-monitorusp_checkframeworkcapabilities)
