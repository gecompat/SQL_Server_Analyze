# [monitor].[USP_CurrentTempDB]

**Bereich:** Current State<br>
**Zweck:** Zeigt aktuelle TempDB-Belegung nach Session, Verbrauchsart und Datei.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Hilfe der Procedure grenzt Sessionfilter, Datei-, Governance- und Version-Store-Sichten samt ihrer Zeit- und Berechtigungsgrenzen ab.

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

## Parametervertrag

Die folgenden Verträge beschreiben jeden Parameter einzeln. Bei dieser Procedure kehrt `@Hilfe = 1` vor der Parameterprüfung und vor der TABLE-Zuordnungsprüfung zurück. Im normalen Pfad folgen auf die Parameterprüfung der bedingte TABLE-Preflight und anschließend erst die fachlichen Quellenzugriffe.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | Typ nvarchar(max); Default=NULL. NULL deaktiviert den ID-Filter. Sonst Liste von Ganzzahlen; 085 ersetzt zuerst Komma und Semikolon durch Pipe und zerlegt anschließend Pipe bracket-aware: Pipe innerhalb [...] bleibt Bestandteil; zuvor dort ersetzte Kommas/Semikolons bleiben daher als Pipe im Segment. ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen werden entfernt; Klammern werden nicht entquotet, daher ist [12] keine gültige ID. N'' ergibt EMPTY_LIST, nur Leerzeichen oder leere Segmente EMPTY_ITEM; Fehlerhafte oder nicht geschlossene Klammerstruktur ergibt INVALID_BRACKET_SYNTAX, Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Diese Parserfehler, ungültige bigint-Zahlen, Werte außerhalb 0..32767 und Duplikate führen im normalen Pfad zu INVALID_PARAMETER und THROW 51011. Gültige IDs wählen Sessions; Filter wirken zusätzlich zu den Session-Schaltern. Ausgelassen entspricht NULL. |
| `@AktuelleSessionEinbeziehen` | Typ bit; Default=0. 0 schließt @@SPID aus, 1 lässt die aufrufende Session zu; Session-ID- und Systemsessionfilter gelten zusätzlich. NULL ist INVALID_PARAMETER/THROW 51011. Numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1); nicht konvertierbare Eingaben scheitern bei SQL-Typkonvertierung. Ausgelassen=0. |
| `@MinNettoMb` | Typ decimal(19,2); Default=0. Zahl in der ausgegebenen MB-Skalierung (Nettoseiten * 8 / 1024); Grenzwert für Netto-User-Object- plus Netto-Internal-Object-Seiten. 0 schließt Nullverbrauch ein; positive Werte verlangen mindestens diesen Verbrauch. Negative Werte lösen INVALID_PARAMETER und THROW 51011 aus. NULL wird nicht explizit abgelehnt, aber der Vergleich &gt;= NULL lässt keine Sessionzeile passieren. Datentypbereich: -99999999999999999.99 bis 99999999999999999.99 mit zwei Nachkommastellen; negative Werte werden fachlich abgewiesen. Ausgelassen=0. |
| `@SystemSessionsEinbeziehen` | Typ bit; Default=0. 0 schließt anhand is_user_process bekannte interne/System-Sessions aus; 1 nimmt sie auf. Wirkt zusätzlich zu aktueller Session und @SessionIds. Bei fehlender Sessionidentität behandelt COALESCE(is_user_process,1) die Zeile wie eine User-Session. NULL ist INVALID_PARAMETER/THROW 51011. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=0. |
| `@MitDateien` | Typ bit; Default=1. 1 liest TempDB-Dateien frisch aus tempdb.sys.database_files einschließlich FILEPROPERTY(SpaceUsed) und gibt sie in RAW/CONSOLE sowie im JSON-Array tempdbFiles aus; 0 überspringt die Quelle, unterdrückt das Dateiresultset und lässt tempdbFiles als leeres Array erscheinen. TABLE kann Dateien nicht exportieren; es gibt keinen Datei-Key. Unabhängig von Parent-Snapshot und @MaxZeilen. NULL ist INVALID_PARAMETER/THROW 51011; numerisch 0→0, Nichtnull→1. Ausgelassen=1. |
| `@MaxZeilen` | Typ int; Default=1000. Nichtnegative Ganzzahl; negative Werte lösen INVALID_PARAMETER/THROW 51011 aus, NULL oder 0 bedeutet unbegrenzt. Positive N begrenzt Sessions und Governance-Gruppen separat, nicht als Gesamtbudget. Sessions verwenden im Direkt- und Parentpfad höchstens N+1 Kandidaten für hasMoreRows, falls N&lt;2147483647; bei int-Maximum ist keine N+1-Erhöhung möglich. Parent-Snapshotzeilen werden zuvor vollständig übernommen. Danach werden Sessions auf N begrenzt. Governance wird direkt vor Statusauswertung nach GroupId auf N vorselektiert; im Parentpfad erst nach Übernahme und Statusbewertung. Dateien, Version-Store-Zeilen und Warnings sind unbeschränkt. returnedRows/hasMoreRows beziehen sich nur auf Sessions. Ausgelassen=1000. |
| `@ResultSetArt` | Typ varchar(16); Default=CONSOLE. Einzelner Modus; LTRIM/RTRIM entfernt Rand-U+0020-Leerzeichen, UPPER normalisiert Groß-/Kleinschreibung. Geschlossene Werte: CONSOLE gibt Sessions, optionale Dateien, Governance und Version Store lesbar aus; RAW gibt Statusmetadaten, Sessions, optionale Dateien, Governance, Version Store und Warnings als Resultsets aus; TABLE schreibt nur die benannten Mengen sessions, tempdbGovernance und versionStore in lokale Ziele; NONE unterdrückt Fachdaten-Resultsets, nicht angeforderte JSON-OUTPUT-Ausgabe. NULL/leer/Leerraum wird zu leerem Modus und löst INVALID_PARAMETER/THROW 51011 aus; andere Werte sind ungültig. Ausgelassen=CONSOLE. |
| `@ResultTablesJson` | Typ nvarchar(max); Default=NULL. Bei TABLE nichtleeres JSON-Objekt mit mindestens einem Key. Exakte case-sensitive Keys und Bedeutungen: sessions = Sessionverbrauchszeilen; tempdbGovernance = Workload-Group-Governance; versionStore = traditionelle und persistente Version-Store-Zeilen je Datenbank. Nichtleere Teilmenge zulässig; kein Datei-Key. Jeder Wert muss ein JSON-String mit Name einer vorhandenen lokalen #Temp-Tabelle sein. Ziele müssen leer und mit genau einer Seed-Spalte angelegt sein; Resultnamen und Ziele eindeutig. Keine ##-/permanenten Tabellen, Zielname höchstens 116 Zeichen, kein reserviertes #Monitor-Präfix (case-insensitive). Resultnamen werden binär/case-sensitiv verglichen, Zieldubletten case-insensitiv. Ungültige Form, Keys, Werte oder Ziele führen beim normalen TABLE-Preflight zu THROW 51011. Außerhalb TABLE sind NULL, leer oder nur U+0020 erlaubt; nichtleerer Wert ist INVALID_PARAMETER/THROW 51011. @Hilfe=1 umgeht Guard und Preflight; normal erfolgt der Preflight nach dem Parameter-Guard und vor Quellenzugriff. |
| `@JsonErzeugen` | Typ bit; Default=0. 0 deaktiviert JSON; 1 erzeugt zusätzlich zur ResultSetArt ein JSON-Dokument über @Json, auch bei NONE. Envelope enthält meta sowie sessions, tempdbFiles, tempdbGovernance, versionStore und warnings. Bei @MitDateien=0 ist tempdbFiles leer. NULL ist INVALID_PARAMETER/THROW 51011; numerisch 0→0, Nichtnull→1. Ausgelassen=0. |
| `@Json` | Typ nvarchar(max) OUTPUT; Default=NULL. Empfangsvariable gleichen Typs muss mit OUTPUT gebunden werden. Wird bei Procedure-Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 mit JSON befüllt, sonst bleibt NULL. Ohne OUTPUT-Bindung wird der Wert nicht empfangen. Ausgelassen=Default NULL. |
| `@PrintMeldungen` | Typ bit; Default=1. Bei 1 wird für Status ungleich AVAILABLE eine Severity-10-Warnmeldung mit Status und Fehlermeldung ausgegeben; 0 unterdrückt nur die Meldung, nicht Statusfelder, Resultsets oder JSON. NULL wird nicht geprüft und wirkt wegen IF=1 wie nicht aktiviert, also Meldung unterdrückt. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=1. |
| `@Hilfe` | Typ bit; Default=0. 1 druckt die Hilfe und kehrt vor Parameterprüfung, TABLE-Guard/-Preflight und Quellenzugriff zurück; normale Parameter und TABLE-Zuordnung werden dabei nicht validiert. 0 führt Diagnose aus. NULL wird nicht als Hilfe erkannt und führt in den normalen Pfad, ist nicht selbst ungültig. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=0. |
| `@ParentCurrentStateSnapshotId` | Typ uniqueidentifier; Default=NULL. NULL erhebt Sessions, Sessionzähler, traditionellen und persistenten Version Store sowie Governance direkt. Eine GUID übernimmt diese Daten aus dem aktuellen USP_CurrentOverview-Aufruf, wenn SnapshotId, OwnerSessionId=@@SPID und ContractVersion=2 passen. Fehlende Parent-Temp-Tabellen, fremde/abgelaufene ID oder falscher Aufrufkontext werden als INVALID_PARENT_SNAPSHOT mit partieller Status-/Warning-Ausgabe erfasst. Parentquellen werden nacheinander erhoben, nicht atomar; SourceStatus trägt Quellstatus, Partialität, Erfassungs-/Abschlusszeit, Zeilenzahl und Fehlerfelder. TempDB-Dateien sind keine Parent-Snapshotquelle und werden bei @MitDateien=1 immer frisch gelesen; Task-Space-Usage wird nicht ausgegeben. Ausgelassen=NULL. |

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `sessions`, `tempdbGovernance` und
`versionStore`. Status, Scope und Warnings sind vor den Fachergebnissen zu
lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den
technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen
Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen
nicht ungeprüft vereinigt oder summiert werden.

Im Overview werden Sessions, Sessionverbrauch und die Workload-Group-Governance
aus dem gemeinsamen Snapshot übernommen. Der traditionelle Version Store und
der ADR Persistent Version Store werden ebenfalls aus diesem Snapshot übernommen.
Die optionale Dateisicht wird auch dort frisch gelesen. Taskverbrauch bleibt keine
Ausgabe dieser Procedure.
Ein direkter Aufruf erhebt Sessions, Governance und gegebenenfalls Dateien frisch. Auf SQL Server 2019/2022 liefert
`tempdbGovernance` einen expliziten `UNAVAILABLE_VERSION`-Status.

`sessions` besitzt zwölf Felder, `tempdbGovernance` 21 und `versionStore` zehn.
Die drei benannten TABLE-Ziele übernehmen dieselben ausgewählten Mengen wie RAW,
JSON und CONSOLE.
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
