# [monitor].[USP_ReplicationStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Publikationen, Subscriptions, Agents, Latenz, Backlog und Fehler.<br>
**Beobachtungsart:** verteilter Snapshot + retentionbegrenzte Agenthistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ReplicationStatus]
      @MitDistributionDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MitDistributionDetails` | `bit` | Default: `0` | Default 0. 0 liest nur sichtbare Replikationsrollen; 1 aktiviert Details aus der online erkannten lokalen Distribution-Datenbank (Publikationen, Subscriptions samt letzter Agent-Historyzeile, Fehler). Fehlt sie, entsteht ein Partialstatus bzw. ohne Basiszeilen UNAVAILABLE_FEATURE. NULL wird nicht geprüft und aktiviert den Pfad nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `5000` | Default 5000 je Datenbank-, Publikations-, Subscription- und Fehlerresultset getrennt, ohne gemeinsames Gesamtbudget. Positive Werte begrenzen je Menge; 0 oder NULL bedeutet unbegrenzt. Negative Werte setzen INVALID_PARAMETER/Partial und verhindern die Facherhebung, sofern kein früherer Gate-Status den Status bereits geändert hat. Bei @Hilfe=1 wird der Wert nicht validiert, weil die Hilfe vorher zurückkehrt. Die Grenze verhindert nicht die Latest-History-Auflösung je Subscription. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | Nur bei MitDistributionDetails=1 prüft die Procedure die Klasse ENTERPRISE_TOPOLOGY_DEEP. Der gebundene Wert 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED. Nach Bestätigung mit 1 kann die aktuelle Zugriffspolicy DENIED_GROUP ergeben. Der Detailpfad setzt Bestätigung und aktuelle Berechtigung voraus. NULL ergibt bei aktiviertem Detailpfad INVALID_PARAMETER. Bei deaktiviertem Detailpfad wird der Wert nicht geprüft. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE (nur Datenbankrollenansicht über Console-Helper), RAW (Modulstatus plus vier Fachergebnissets), TABLE (nur databases in Zieltemp-Tabelle) und NONE (keine Resultsets). NULL/Leerwert/anderer Wert ergibt INVALID_PARAMETER. CONSOLE und TABLE unterdrücken den normalen Status-/RAW-Pfad. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Default NULL. Nur mit TABLE zulässig; sonst wird nichtleeres JSON mit Fehler 51011 abgewiesen. Erwartet ein Objekt mit einzigem Resultnamen databases und Ziel als Wert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, maximal 116 Zeichen und genau eine Seed-Spalte. NULL/leeres JSON ist ungültig. Der Preflight läuft vor HELP und Fachdatenzugriff. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Default 0. 1 erzeugt zusätzlich JSON in Json mit meta, databases, publications, subscriptions und errors; 0 nicht. JSON-Erzeugung ist unabhängig von ResultSetArt. NULL aktiviert den IF-Zweig nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT, Default NULL. Wird am Anfang auf NULL gesetzt und bei JsonErzeugen=1 mit dem JSON-Objekt aus meta und vier Ergebnisarrays gebunden. Andernfalls bleibt NULL. Der Aufrufer bindet eine nvarchar(max)-OUTPUT-Variable. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@PrintMeldungen` | `bit` | Default: `1` | Default 1. Bei 1 wird eine behandelte Catch-Fehlermeldung mit Severity 10 ausgegeben; 0 unterdrückt sie. NULL wirkt nicht wie 1. Steuert keine Resultsets. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Default 0. 1 druckt kurze Hilfe und kehrt zurück, 0 fährt fort; NULL wirkt wie 0. TABLE-Kombinationsprüfung und Preflight laufen vor der Hilfeprüfung. Bei ausgelassenem Argument gilt der angegebene Default. |

## Aufrufbeispiele zu den Parameterverträgen

Das TABLE-Beispiel erwartet einen freien lokalen Tabellennamen. Es legt das leere Ziel mit einer Seed-Spalte an und entfernt es nach dem Aufruf oder bei einem Aufruffehler.

```sql
EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;

EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];

CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#ReplicationStatus_HelpExample"}'; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag exportiert ausschließlich `databases`. RAW stellt den Modulstatus vor die vier Fachergebnissets; JSON enthält den Status in `meta`. CONSOLE gibt über den Console-Helper nur die Datenbankrollenansicht aus und enthält dabei keinen separaten Modulstatus. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Publikation, Subscription, einen Agent oder eine Distributor-/Backlogmetrik.

## So lesen

Berücksichtigen Sie Agentstatus, letzte Aktion, Latenz, Pending Commands, Fehler und Trend über mehrere Messungen.

## Warum kann das problematisch sein?

Wachsender Backlog bedeutet, dass Änderungen schneller entstehen als verteilt werden oder ein Agent/Distributor blockiert ist.

## Wann ist es kein Problem?

Kurzzeitiger Backlog während Lastspitzen ist akzeptabel, wenn er anschließend sichtbar abgebaut wird.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Pending Commands steigen in drei Messungen kontinuierlich und Latenz wächst: systematischer Rückstand. Prüfen Sie Agentjob, Distributor, Blocking und Netzwerk.

**Ähnlich aussehender Gegenfall:** Kurzzeitiger Backlog während Lastspitzen ist akzeptabel, wenn er anschließend sichtbar abgebaut wird. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_ReplicationStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist mittel; die Auswertung der Distribution-Datenbank ist optional.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Lokaler Instanzsnapshot der als Publisher, Subscriber, Merge-Publisher oder Distributor markierten Datenbanken; `@MitDistributionDetails = 0`. |
| Teuerster Pfad | `@MitDistributionDetails = 1`, unbegrenzte Ausgabe und eine große lokale Distribution-Datenbank mit vielen Publikationen, Subscriptions, Agents, History- und Fehlerzeilen. AG-/HADR-Quellen werden nicht gelesen. |
| Haupttreiber | Ohne Details die kleine `sys.databases`-Menge; mit Details Publikationen, Subscriptions und insbesondere Latest-History-Suche je Agent sowie `MSrepl_errors` in der lokal erkannten Distribution-Datenbank. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_ReplicationStatus ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und lokales Katalog-/Distribution-DB-I/O; dynamisches SQL für die erkannte Distribution-Datenbank und temporäre Resultate. Keine Remote-Distributorabfrage. |
| Begrenzungswirkung | `@MaxZeilen` wird getrennt auf Datenbanken, Publikationen, Subscriptions und Fehler angewandt. Es begrenzt nicht als gemeinsames Budget und verhindert die Latest-History-Suche je ausgewählter Subscription nicht sicher. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `ENTERPRISE_TOPOLOGY_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Zuerst ohne Distributiondetails. Den lokalen Distributionpfad nur bei erkannter Distributorrolle, endlichem Limit und `@HighImpactConfirmed = 1` aktivieren; Fehler-/Historytexte als sensible Laufzeitdaten behandeln. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter Snapshot + retentionbegrenzte Agenthistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?

### Technischer Hintergrund

Transactional Replication nutzt Log Reader und Distribution Agents; Merge Replication eigene Agents/Sessions. Publisher-, Distributor- und Subscriber-Metadaten liegen auf verschiedenen Servern/Datenbanken. History und Commands bilden begrenzte Zustände/Latenz.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Source Select

Der leichte Basispfad erkennt nur Datenbanken mit sichtbaren Replication-Rollen:

```sql
SELECT
      [d].[name]
    , [d].[is_published]
    , [d].[is_subscribed]
    , [d].[is_merge_published]
    , [d].[is_distributor]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[is_published] = 1
   OR [d].[is_subscribed] = 1
   OR [d].[is_merge_published] = 1
   OR [d].[is_distributor] = 1;
```

**Wichtig für die Eigenlast:** Dieser Katalogfilter ist der sichere Einstieg. Distributionstabellen, Agenthistorien und Fehlerdetails nur für erkannte Rollen und im expliziten Tiefenpfad lesen; dort Datenbank und Zeitfenster weiter einschränken.

### Zeit- und Scope-Modell

Die Auswertung kombiniert eine verteilte Momentaufnahme mit der Distributor- und Agenthistorie innerhalb der Retention.

### Bewertung und Gegenprobe

Berücksichtigen Sie Topologierolle, Agentstatus, letzte Aktion/Fehler, undistributed commands, geschätzte Latenz und Zeitmarken gemeinsam. Geben Sie Remote-/Distributorzugriff als Partialstatus aus.

### Typische Fehlinterpretation

`Running` bedeutet nur aktiver Agent, nicht geringe Latenz. Lokale Leere kann fehlende Rolle oder fehlenden Remotezugriff bedeuten.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_DataCaptureDeepAnalysis`, Agent Jobs, Log/Distributor-DB-Kapazität und Replication Monitor.

## Primärquellen

- [SQL Server Replication](https://learn.microsoft.com/en-us/sql/relational-databases/replication/sql-server-replication?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#7-monitorusp_replicationstatus)
