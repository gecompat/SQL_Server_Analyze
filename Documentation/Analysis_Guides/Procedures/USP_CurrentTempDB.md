# [monitor].[USP_CurrentTempDB]

**Bereich:** Current State<br>
**Zweck:** Zeigt aktuelle TempDB-Belegung nach Session, Verbrauchsart und Datei.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche TempDB-Komponente verbraucht Platz, und welche Session/Task treibt den Verbrauch?** Der dokumentierte Zweck ist: Zeigt aktuelle TempDB-Belegung nach Session, Verbrauchsart und Datei. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Datei-/Datenbankzustand; Session-/Taskzähler seit Request/Sessionaktivität. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTempDB]
      @MitDateien = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Das Limit gilt für die Sessionrangliste; die kleine Dateisicht wird separat
erhoben. Bei vielen Sessions zuerst über `@MinNettoMb` einen fachlich sinnvollen
Mindestverbrauch setzen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `sessions` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Sessionallokation, eine Verbrauchsart oder eine TempDB-Datei. Diese Granularitäten dürfen nicht addiert werden, ohne das Resultset zu beachten.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Gesamt- und Dateiauslastung, danach User Objects, Internal Objects, Version Store und verursachende Sessions unterscheiden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wachsende Internal Objects können Sorts, Hashes oder Spills anzeigen. Version Store deutet eher auf lange Snapshot-/RCSI-Transaktionen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Kurzzeitige Spitzen während kontrollierter ETL- oder Indexoperationen sind akzeptabel, wenn Dateien vorallokiert sind und kein Autogrowth-Sturm entsteht.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 90 % voll erklärt die Ursache nicht. 80 % Version Store verlangt Transaktionsprüfung; 80 % Internal Objects einer Session verlangt Request- und Plananalyse. Dateidesign über `USP_TempDBConfiguration` prüfen.

**Ähnlich aussehender Gegenfall:** Kurzzeitige Spitzen während kontrollierter ETL- oder Indexoperationen sind akzeptabel, wenn Dateien vorallokiert sind und kein Autogrowth-Sturm entsteht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentTempDB` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Bis zu 1000 User-Sessions aus `sys.dm_db_session_space_usage` plus das kleine TempDB-Dateiresultset. Es werden weder SQL-Texte noch Allokationsseiten gelesen. |
| Teuerster Pfad | `@MaxZeilen = 0`, System-Sessions eingeschlossen und `@MitDateien = 1` auf einer Instanz mit sehr vielen Sessions und zahlreichen TempDB-Dateien. |
| Haupttreiber | Zahl sichtbarer Sessions in `dm_db_session_space_usage` und – falls angefordert – reale TempDB-Dateizahl. Mindestbelegung/Sessionfilter reduzieren Kandidaten; Allokationsseiten, Tasks und SQL-Texte werden nicht gelesen. |
| Skalierung | Sessionpfad wächst mit sichtbaren Sessions; der optionale Dateipfad wächst mit TempDB-Dateien. Sortiert wird nach Nettobelegung, die Ergebniszeilen bleiben schmal. |
| Ressourcen | Geringe CPU-/Speicherlast für Live-DMV-Join und Sortierung; optional Katalog-/Dateispace-DMV-Zugriff in TempDB. Kein Benutzertabellen- oder Textzugriff. |
| Begrenzungswirkung | Session-ID, Systemscope und Mindest-Nettobelegung wirken in der Quellabfrage. Intern werden höchstens `@MaxZeilen + 1` Sessionkandidaten übernommen. `@MaxZeilen` begrenzt das separate Dateiresultset nicht, weil dieses bereits durch die reale Dateizahl begrenzt ist. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Kein High-Impact-Gate. Wirksam sind `@SessionIds`, `@MinNettoMb`, der Ausschluss von System-/aktueller Session und das endliche Sessionlimit; `@MitDateien = 0` lässt die separate Dateisicht aus. Keiner dieser Schalter begrenzt die bereits kleine Dateiliste, wenn sie aktiviert ist. |
| Sicherer Einsatz | User-Sessions, endliches Limit und bei reiner Verbrauchersuche zunächst `@MitDateien = 0`; Dateisicht anschließend einmalig zur Kapazitätseinschätzung ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Sessionzähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche TempDB-Komponente verbraucht Platz, und welche Session/Task treibt den Verbrauch?

### Technischer Hintergrund

TempDB speichert User Objects, Internal Objects für Sort/Hash/Spool/Worktables, Version Store sowie freie/ungeordnete Bereiche. Datei-Space-DMVs und Session-/Task-Space-Usage besitzen unterschiedliche Aggregation. Version Store wird durch zeilenversionsbasierte Isolation und weitere Enginefeatures erzeugt.

### Datenkette

`sys.database_files`, `sys.dm_db_session_space_usage`, `sys.dm_exec_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Datei-/Datenbankzustand; Session-/Taskzähler seit Request/Sessionaktivität. Version Store kann nach Transaktionsende verzögert bereinigt werden.

### Bewertung und Gegenprobe

Zuerst Belegungsart trennen, dann Verbraucher und Wachstum prüfen. Internal Objects plus Spillwarnung führt zum Plan; Version Store plus alte Snapshottransaktion zur Transaktionsanalyse; User Objects zu Tempobjekten.

### Typische Fehlinterpretation

Hohe Gesamtbelegung oder eine große Datei nennt keine Ursache. Freier Platz innerhalb TempDB und freier Volumeplatz sind verschiedene Größen.

### Folgeanalyse

`USP_CurrentRequests`, `USP_CurrentTransactions`, `USP_TempDBConfiguration`, Showplan.

## Primärquellen

- [sys.dm_db_session_space_usage](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-session-space-usage-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#7-monitorusp_currenttempdb)
