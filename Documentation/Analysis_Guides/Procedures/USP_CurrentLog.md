# [monitor].[USP_CurrentLog]

**Bereich:** Current State<br>
**Zweck:** Zeigt Logauslastung, Wiederverwendungswartegrund, VLF- und optional PVS-Kontext.<br>
**Beobachtungsart:** Snapshot + Katalog + kumulative Teilwerte<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie voll ist das Transaktionslog, warum kann es nicht wiederverwendet werden und welches Risiko entsteht?** Der dokumentierte Zweck ist: Zeigt Logauslastung, Wiederverwendungswartegrund, VLF- und optional PVS-Kontext. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Space-/Reusezustand; Filegröße und VLFs Metadaten, einzelne Zähler kumulativ. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentLog]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `logs` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, eine Logdatei, einen VLF- oder PVS-Aspekt. Den jeweiligen Scope vor Summenbildung prüfen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Used Percent, absolute Loggröße, `log_reuse_wait_desc`, Growth, VLF und offene Transaktionen gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Hohe Nutzung ist besonders kritisch, wenn Wiederverwendung durch eine alte Transaktion, fehlende Logbackups oder HA-/Replikations-Lag blockiert wird. Reines Vergrößern behebt die Ursache nicht.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 95 % genutzt plus `ACTIVE_TRANSACTION` plus zwei Stunden alte Transaktion: Primärursache ist die offene Transaktion. `USP_CurrentTransactions`, Backupstatus und Kapazität prüfen.

**Ähnlich aussehender Gegenfall:** Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentLog` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Standard moderat; automatische Datenbankauswahl ist durch keine Datenbank-Vorabbegrenzung.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Datenbankweise Logspace-/Reuse-Metadaten ohne breite VLF- oder PVS-Vertiefung. |
| Teuerster Pfad | Cross-Database-VOLL-Lauf mit VLF- und PVS-Vertiefung über große beziehungsweise VLF-reiche Logs. |
| Haupttreiber | Zahl gewählter Datenbanken und – bei aktiviertem Detail – ihrer VLF-Zeilen aus `dm_db_log_info`; Log-Space-/Log-Stats-Summary ist je Datenbank klein. PVS-Kontext fügt Metadaten hinzu, liest aber keine Version-Store-Zeilen. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_CurrentLog ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Katalog-/DMV-CPU und bei VLF-/PVS-Vertiefung zusätzliche datenbankweise Arbeit, TempDB und Ergebnistransfer. |
| Begrenzungswirkung | Datenbankfilter begrenzen den Quellzugriff; ein Zeilenlimit verhindert nicht, dass VLFs oder PVS-Metadaten des gewählten Scopes zunächst gelesen werden. |
| Locking und Nebenwirkungen | Read-only, aber dynamische datenbankweise Katalogzugriffe können kurz mit DDL/Statuswechseln kollidieren. Der Zustand kann sich schon während des Laufs ändern. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `LOG_VLF_DEEP`, `STANDARD_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Zuerst eine ExampleDb ohne VLF-/PVS-Details; LOG_VLF_DEEP nur gezielt und in ruhigerem Betriebsfenster freigeben. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + Katalog + kumulative Teilwerte“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie voll ist das Transaktionslog, warum kann es nicht wiederverwendet werden und welches Risiko entsteht?

### Technischer Hintergrund

Das Log ist eine sequenzielle Recoverystruktur aus VLFs. Log Records müssen für Commit gehärtet und für Recovery/Backup/HADR/Replication je nach Konfiguration erhalten werden. Space-Usage, Filemetadaten, VLF-Kontext und `log_reuse_wait_desc` erklären verschiedene Ebenen.

### Datenkette

`master.sys.databases`, `sys.dm_db_log_info`, `sys.dm_db_log_space_usage`, `sys.dm_db_log_stats`, `sys.dm_tran_persistent_version_store_stats`, `sys.sp_executesql`.

### Source Select

Der datenbanklokale Kern verbindet Logbelegung und Logzustand; die Zieldatenbank muss vor dem DMF-Aufruf feststehen:

```sql
SELECT
      [space].[total_log_size_in_bytes]
    , [space].[used_log_space_in_bytes]
    , [stats].[recovery_model]
    , [stats].[log_truncation_holdup_reason]
    , [stats].[total_vlf_count]
FROM [sys].[dm_db_log_space_usage] AS [space] WITH (NOLOCK)
CROSS APPLY [sys].[dm_db_log_stats](DB_ID()) AS [stats];
```

**Wichtig für die Eigenlast:** Zuerst die Datenbankkandidaten einschränken. `sys.dm_db_log_info` liefert eine Zeile je VLF und ist der wesentliche Vertiefungstreiber; VLF-Details nicht breit über alle Datenbanken lesen.

### Zeit- und Scope-Modell

Aktueller Space-/Reusezustand; Filegröße und VLFs Metadaten, einzelne Zähler kumulativ. Reuse-Wait kann sich nach Backup/Commit rasch ändern.

### Bewertung und Gegenprobe

Used Percent, absolute freie MB, Wachstumsoption, Volumeplatz und Reuse-Wait zusammen lesen. `ACTIVE_TRANSACTION`, `LOG_BACKUP`, `AVAILABILITY_REPLICA` oder `REPLICATION` führen zu unterschiedlichen Maßnahmen.

### Typische Fehlinterpretation

Logvergrößerung beseitigt die Reuse-Ursache nicht. Shrink ist keine dauerhafte Lösung und kann VLF-/Autogrowthprobleme verschärfen.

### Folgeanalyse

`USP_CurrentTransactions`, Backup-/AG-/Replicationmodule, `USP_CurrentIO` für Logfilelatenz.

## Primärquellen

- [sys.dm_db_log_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-log-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#9-monitorusp_currentlog)
