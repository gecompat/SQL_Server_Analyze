# [monitor].[USP_CurrentTempDB]

**Bereich:** Current State<br>
**Zweck:** Zeigt aktuelle TempDB-Belegung nach Session, Verbrauchsart und Datei.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Session verbraucht TempDB-Platz, und wie stehen Dateien und Workload Groups dazu?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTempDB]
      @MitDateien = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Das Limit gilt für die Sessionrangliste; die kleine Dateisicht wird separat
erhoben. Setzen Sie bei vielen Sessions über `@MinNettoMb` einen fachlich
sinnvollen Mindestverbrauch.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `sessions` und
`tempdbGovernance`. Status, Scope und Warnings sind vor den Fachergebnissen zu
lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den
technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen
Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen
nicht ungeprüft vereinigt oder summiert werden.

Im Overview werden Sessions, Sessionverbrauch und die Workload-Group-Governance
aus dem gemeinsamen Snapshot übernommen. Die optionale Dateisicht wird auch dort
frisch gelesen. Taskverbrauch und Version Store sind keine Ausgabe dieser Procedure.
Ein direkter Aufruf erhebt Sessions, Governance und gegebenenfalls Dateien frisch. Auf SQL Server 2019/2022 liefert
`tempdbGovernance` einen expliziten `UNAVAILABLE_VERSION`-Status.

`sessions` besitzt zwölf Felder, `tempdbGovernance` 21. Die beiden benannten
TABLE-Ziele übernehmen dieselben ausgewählten Mengen wie RAW, JSON und CONSOLE.
Nach Sammlung, Bewertung und N+1-Zählung begrenzt `@MaxZeilen` die Sessions
nach `TotalNetMb DESC, SessionId`. Der Direktpfad behält seine frühe
Governance-Vorauswahl nach `GroupId`; die Statusbewertung bezieht sich dort
auf diese Vorauswahl. Im Parentpfad folgt die Begrenzung nach `GroupId` erst
nach vollständiger Snapshotübernahme und Statusbewertung. Die abschließende
gemeinsame Begrenzung gilt für beide Pfade. `NULL` und
`0` lassen beide Mengen unbegrenzt. Die Dateisicht bleibt davon unabhängig.
Die Auswahlordnung ist keine ORDER-BY-Zusage für die TABLE- oder CONSOLE-Helper.
`returnedRows` und `hasMoreRows` beziehen sich ausschließlich auf Sessions.
Ungültige Parameter und TABLE-Zuordnungen behalten den Fehlervertrag
`THROW 51011`; sie erzeugen keine kontrollierte INVALID_PARAMETER-JSON-Ausgabe.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile die kumulativen Allokationszähler einer Session,
eine TempDB-Datei oder eine Workload Group. Sessionzähler und
Workload-Group-Zähler besitzen unterschiedliche Granularität und dürfen nicht
addiert werden.

## So lesen

Unterscheiden Sie Dateiauslastung, User Objects, Internal Objects und die
zugeordneten Sessions. Version Store verlangt eine gesonderte Gegenprobe. Auf SQL Server 2025
lesen Sie anschließend `tempdbGovernance`: gespeichertes Limit, tatsächlich
wirksames Limit, aktuelle Nutzung, Peak, Verletzungszähler und
`StatisticsStartTime` getrennt.

## Warum kann das problematisch sein?

Wachsende Internal Objects können Sorts, Hashes oder Spills anzeigen. Version Store deutet eher auf lange Snapshot-/RCSI-Transaktionen.

## Wann ist es kein Problem?

Kurzzeitige Spitzen während kontrollierter ETL- oder Indexoperationen sind akzeptabel, wenn Dateien vorallokiert sind und kein Autogrowth-Sturm entsteht.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Auslastung von 90 % erklärt die Ursache nicht. Ein Anteil von 80 % Version Store verlangt eine Transaktionsprüfung; 80 % Internal Objects einer Session verlangen eine Request- und Plananalyse. Prüfen Sie das Dateidesign mit `USP_TempDBConfiguration`.

**Ähnlich aussehender Gegenfall:** Kurzzeitige Spitzen während kontrollierter ETL- oder Indexoperationen sind akzeptabel, wenn Dateien vorallokiert sind und kein Autogrowth-Sturm entsteht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentTempDB` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Bis zu 1000 User-Sessions aus `sys.dm_db_session_space_usage` plus das kleine TempDB-Dateiresultset. Es werden weder SQL-Texte noch Allokationsseiten gelesen. |
| Teuerster Pfad | `@MaxZeilen = 0`, System-Sessions eingeschlossen und `@MitDateien = 1` auf einer Instanz mit sehr vielen Sessions und zahlreichen TempDB-Dateien. |
| Haupttreiber | Zahl sichtbarer Sessions in `dm_db_session_space_usage` und – falls angefordert – reale TempDB-Dateizahl. Mindestbelegung/Sessionfilter reduzieren Kandidaten; Allokationsseiten, Tasks und SQL-Texte werden nicht gelesen. |
| Skalierung | Sessionpfad wächst mit sichtbaren Sessions; der optionale Dateipfad wächst mit TempDB-Dateien. Sortiert wird nach Nettobelegung, die Ergebniszeilen bleiben schmal. |
| Ressourcen | Geringe CPU-/Speicherlast für Live-DMV-Join und Sortierung; optional Katalog-/Dateispace-DMV-Zugriff in TempDB. Kein Benutzertabellen- oder Textzugriff. |
| Begrenzungswirkung | Session-ID, Systemscope und Mindest-Nettobelegung wirken in der Quellabfrage. Bei positivem endlichem Limit werden höchstens `@MaxZeilen + 1` Sessionkandidaten übernommen; anschließend erhalten alle Ausgabeformen dieselbe begrenzte Menge. Der Direktpfad behält seine frühe Governance-Vorauswahl; die späte gemeinsame Begrenzung folgt zusätzlich. Im Parentpfad wird Governance nach vollständiger Snapshotübernahme und Statusbewertung begrenzt. `@MaxZeilen` begrenzt das separate Dateiresultset nicht, weil dieses bereits durch die reale Dateizahl begrenzt ist. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Kein High-Impact-Gate. Wirksam sind `@SessionIds`, `@MinNettoMb`, der Ausschluss von System-/aktueller Session und das endliche Sessionlimit; `@MitDateien = 0` lässt die separate Dateisicht aus. Keiner dieser Schalter begrenzt die bereits kleine Dateiliste, wenn sie aktiviert ist. |
| Sicherer Einsatz | User-Sessions, endliches Limit und bei reiner Verbrauchersuche zunächst `@MitDateien = 0`; Dateisicht anschließend einmalig zur Kapazitätseinschätzung ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Sessionzähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Session verbraucht TempDB-Platz, und wie stehen Dateien und Workload Groups dazu?

### Technischer Hintergrund

TempDB speichert User Objects, Internal Objects für Sort/Hash/Spool/Worktables, Version Store sowie freie/ungeordnete Bereiche. Datei-Space-DMVs und Session-/Task-Space-Usage besitzen unterschiedliche Aggregation. Version Store wird durch zeilenversionsbasierte Isolation und weitere Enginefeatures erzeugt.

### Datenkette

`sys.database_files`, `sys.dm_db_session_space_usage`, `sys.dm_exec_sessions`,
`sys.resource_governor_workload_groups`,
`sys.dm_resource_governor_workload_groups`,
`sys.resource_governor_configuration`,
`sys.dm_resource_governor_configuration`, bedingt `master.sys.master_files`
und `sys.sp_executesql`.

### Source Select

Der Sessionverbrauch entsteht aus Allokations- und Deallokationszählern und wird mit dem aktuellen Sessionzustand verbunden:

```sql
SELECT
      [u].[session_id]
    , [s].[status]
    , [u].[user_objects_alloc_page_count]
      - [u].[user_objects_dealloc_page_count] AS [UserObjectPages]
    , [u].[internal_objects_alloc_page_count]
      - [u].[internal_objects_dealloc_page_count] AS [InternalObjectPages]
FROM [sys].[dm_db_session_space_usage] AS [u] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [u].[session_id]
WHERE [u].[session_id] <> @@SPID
  AND
  (
      [u].[user_objects_alloc_page_count] - [u].[user_objects_dealloc_page_count]
      + [u].[internal_objects_alloc_page_count] - [u].[internal_objects_dealloc_page_count]
  ) * 8.0 / 1024.0 >= @MinNettoMb;
```

**Wichtig für die Eigenlast:** Ein positiver Mindestwert begrenzt den Sessionverbrauchsscope. Der Default `@MinNettoMb=0` lässt auch Nullverbrauch zu. Die Dateisicht aus `tempdb.sys.database_files` ist klein und getrennt; sie darf nicht fälschlich einer einzelnen Session zugerechnet werden.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Dateizustand; Sessionzähler gelten
seit der jeweiligen Sessionaktivität. Der
Version Store kann nach dem Transaktionsende verzögert bereinigt werden.
Workload-Group-Peak und Verletzungszähler gelten seit
`StatisticsStartTime`, also seit Serverstart oder dem letzten
`ALTER RESOURCE GOVERNOR RESET STATISTICS`.

### Bewertung und Gegenprobe

Trennen Sie zuerst die Belegungsarten und prüfen Sie danach Verbraucher und Wachstum. Internal Objects zusammen mit einer Spillwarnung führen zur Plananalyse, Version Store zusammen mit einer alten Snapshottransaktion zur Transaktionsanalyse und User Objects zur Analyse der temporären Objekte.

### Typische Fehlinterpretation

Hohe Gesamtbelegung oder eine große Datei nennt keine Ursache. Freier Platz innerhalb TempDB und freier Volumeplatz sind verschiedene Größen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentRequests`, `USP_CurrentTransactions`, `USP_TempDBConfiguration`, Showplan.

## Primärquellen

- [sys.dm_db_session_space_usage](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-session-space-usage-transact-sql?view=sql-server-ver17)
- [TempDB space resource governance](https://learn.microsoft.com/en-us/sql/relational-databases/resource-governor/tempdb-space-resource-governance?view=sql-server-ver17)
- [sys.dm_resource_governor_workload_groups](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-resource-governor-workload-groups-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#7-monitorusp_currenttempdb)
