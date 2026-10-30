# [monitor].[USP_CurrentMemoryGrants]

**Bereich:** Current State<br>
**Zweck:** Zeigt angeforderte, gewährte und genutzte Query Execution Memory Grants.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Queries besitzen oder erwarten Workspace Memory für Sorts, Hashes und ähnliche Operatoren?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

`EXEC [monitor].[USP_CurrentMemoryGrants] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_CurrentMemoryGrants]
      @NurWartende = 1,
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

So beginnt die Triage bei tatsächlich wartenden Grants und vermeidet zunächst
SQL-Textmaterialisierung. Für eine Kapazitätssicht auf bereits gewährte Grants
Setzen Sie `@NurWartende` anschließend bewusst auf `0`.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parametervertrag

Die folgenden Verträge beschreiben jeden Parameter einzeln. Vor der Hilfe werden nichtleere Zuordnungen außerhalb von TABLE und bei TABLE das Zielmapping geprüft. Ungültige Zuordnungen können deshalb auch bei `@Hilfe = 1` den Fehler 51011 auslösen.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@SessionIds` | Typ nvarchar(max); Default=NULL. NULL oder ausgelassen deaktiviert den Sessionfilter. Nicht-NULL wird durch TVF_ParseBigintList verarbeitet: Komma und Semikolon werden zuerst global in Pipe umgewandelt; Pipe trennt danach außerhalb eckiger Klammern, innerhalb maskiert ]] eine schließende Klammer. Außenleerzeichen je Segment werden getrimmt. Leerer String ergibt EMPTY_LIST; nur Leerzeichen oder leere Segmente EMPTY_ITEM; fehlerhafte Klammern INVALID_BRACKET_SYNTAX; Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Klammerquotierung wird nicht entfernt: IDs in [...] sind keine gültige Zahl. TRY_CONVERT(bigint) muss erfolgreich sein und jede ID muss 1 bis 32767 sein; andernfalls Status INVALID_PARAMETER. Gültige doppelte IDs werden gruppiert. Pipe, Komma und Semikolon sind einzeln oder gemischt zulässig. |
| `@AktuelleSessionEinbeziehen` | Typ bit; Default=0. Ausgelassen entspricht 0. 0 schließt @@SPID aus; 1 erlaubt die aufrufende Session. NULL ist nicht als ungültig markiert und schließt die eigene Session durch das SQL-Prädikat ebenfalls aus; andere Session-IDs bleiben davon unberührt. Eingaben werden vor Eintritt nach bit konvertiert (numerisch 0→0, jeder numerische Nichtnullwert→1). |
| `@NurWartende` | Typ bit; Default=0. Ausgelassen entspricht 0. 0 lässt gewährte und wartende Grants passieren; 1 filtert auf grant_time IS NULL. NULL ist nicht als ungültig markiert; das Prädikat lässt dadurch wartende Zeilen passieren, während gewährte Zeilen ausgeschlossen werden. Numerische Eingaben werden nach bit konvertiert (0→0, Nichtnull→1). |
| `@MinRequestedMb` | Typ decimal(19,2), Einheit MB; Default=NULL. NULL oder ausgelassen deaktiviert diese Untergrenze. Ein nichtnegativer Wert n filtert mit requested_memory_kb &gt;= n * 1024.0, also einschließlich Gleichheit. Negative Werte führen zu INVALID_PARAMETER. Der Eingabebereich ist der SQL-Datentyp decimal(19,2); die Konvertierung in diesen Typ erfolgt vor Ausführung. |
| `@MinGrantedMb` | Typ decimal(19,2), Einheit MB; Default=NULL. NULL oder ausgelassen deaktiviert diese Untergrenze. Ein nichtnegativer Wert n filtert mit granted_memory_kb &gt;= n * 1024.0, also einschließlich Gleichheit. Die Bedingung wird auch auf wartende Grants angewendet; deren gewährte Speichergröße kann NULL sein, sodass sie bei gesetztem Grenzwert nicht passieren. Negative Werte führen zu INVALID_PARAMETER. Der Eingabebereich ist decimal(19,2). |
| `@MitSqlText` | Typ bit; Default=1. Ausgelassen entspricht 1. 1 löst Statementtext über den vorhandenen SQL-Text-/Snapshotkontext auf und projiziert ihn; 0 lässt die SQL-Textquelle aus und CurrentStatement bleibt NULL. NULL ist nicht ungültig, aber IF-Wirkungen wie bei 0 (Text wird nicht eingelesen). Numerische Eingaben werden nach bit konvertiert: 0→0, Nichtnull→1. |
| `@MaxSqlTextZeichen` | Typ int; Default=3000 Zeichen. Ein positiver Wert begrenzt jeden ausgegebenen Statementtext auf höchstens diese Zahl Unicode-Zeichen (SC-Zeichen zählen gemäß SC-Collation); der Helper liefert zusätzlich Originalzeichen, Originalbytes und Kürzungskennzeichen. NULL oder 0 bedeutet unbegrenzte Textlänge; negativ ergibt INVALID_PARAMETER. Ausgelassen verwendet 3000. int-Grenzen gelten nach SQL-Konvertierung; bei @MitSqlText=0 ist keine Textprojektion betroffen. |
| `@MaxZeilen` | Typ int; Default=1000 Datenzeilen. Positives n wählt höchstens n Zeilen und materialisiert regulär bis zu n+1 Kandidaten, um HasMoreRows/ResultLimited vor dem Zuschnitt zu bestimmen. Bei int-Maximum 2147483647 wird n+1 nicht berechnet; die Kandidatenobergrenze bleibt dann n. NULL oder 0 bedeutet unbegrenzt und setzt die effektive Obergrenze auf bigint-Maximum; negativ ergibt INVALID_PARAMETER. Die ausgewählte Fachmenge gilt für RAW, CONSOLE, TABLE-Export und JSON; NONE unterdrückt Resultsets. |
| `@ResultSetArt` | Typ varchar(16); Default='CONSOLE'. Eingabe wird mit LTRIM/RTRIM außen getrimmt, COALESCE(NULL, leer) und UPPER normalisiert. Exakt CONSOLE (lesbare Ansicht, einschließlich Leerfallansicht), RAW (Modulstatus- und Datenresultset), TABLE (benanntes Resultset memoryGrants in das konfigurierte Ziel) und NONE (keine fachlichen Resultsets) sind zulässig. Die Schreibweise ist dadurch case-insensitiv; leere oder andere Werte liefern INVALID_PARAMETER. Bei NULL entsteht leer und somit INVALID_PARAMETER. Ein nichtleeres @ResultTablesJson außerhalb TABLE löst davor Fehler 51011 aus. |
| `@ResultTablesJson` | Typ nvarchar(max); Default=NULL. Bei @ResultSetArt=TABLE muss das JSON ein Objekt mit genau dem erlaubten Schlüssel memoryGrants und einem JSON-String als Ziel enthalten; JSON-Schlüssel und erlaubter Ergebnisname werden nach Konvertierung zu sysname byte-/case-sensitiv verglichen. Exakte doppelte Schlüssel sind ungültig; doppelte Zielnamen werden unter Latin1_General_100_CI_AS erkannt. NULL/ausgelassen, ein leeres Objekt, unbekannte oder anders geschriebene Schlüssel, Nicht-Stringwerte sowie nach LTRIM/RTRIM leere Schlüssel/Zielwerte führen zum TABLE-Preflightfehler. LTRIM/RTRIM entfernt hier gewöhnliche U+0020-Leerzeichen; Tabs und andere Whitespacezeichen werden dadurch nicht als leer behandelt. Das Ziel muss mit # beginnen, darf nicht ## beginnen, höchstens 116 nach LEN gemessene Zeichen lang sein und darf nicht mit #Monitor beginnen (case-insensitive). Es muss im aktuellen Sessionkontext existieren, leer sein und genau eine Seed-Platzhalterspalte besitzen; der Preflight prüft dies durch temporäres Hinzufügen/Entfernen einer Spalte. Außerhalb TABLE sind NULL, ausgelassen, leerer String und nur U+0020-Leerzeichen erlaubt; ein nach LTRIM/RTRIM nichtleerer Wert (auch Tabs) löst vor Hilfe/Analyse Fehler 51011 aus. Die TABLE-Zuordnungswache und der Preflight laufen vor Hilfe und vor fachlichen Quellenzugriffen. |
| `@JsonErzeugen` | Typ bit; Default=0. Ausgelassen entspricht 0. 0 unterdrückt die JSON-Erzeugung; 1 erzeugt unabhängig von ResultSetArt ein JSON-Envelope in @Json. NULL ist nicht ungültig und wirkt wegen IF (@JsonErzeugen=1) wie deaktiviert. Numerische Eingaben werden vor Eintritt nach bit konvertiert (0→0, Nichtnull→1). |
| `@Json` | Typ nvarchar(max), OUTPUT; Default=NULL. Als OUTPUT-Variable zu binden; beim Eintritt setzt die Procedure den Ausgabewert zunächst auf NULL. Bei @JsonErzeugen=1 erhält die Variable das JSON-Envelope mit meta, memoryGrants und warnings, einschließlich NULL-Properties; bei 0 oder NULL in @JsonErzeugen bleibt sie NULL. Der Eingabewert ist kein Filter und wird überschrieben. |
| `@PrintMeldungen` | Typ bit; Default=1. Ausgelassen entspricht 1. 1 lässt Statusmeldungen bei Status ungleich AVAILABLE und Textkürzungswarnungen ausgeben; beide Wege verwenden RAISERROR mit Severity 10 und WITH NOWAIT (der Textkürzungshelper übernimmt denselben Schalter), keine PRINT-Ausgabe. 0 und NULL unterdrücken diese Meldungen, nicht Resultsets oder strukturierte Status-/Warningdaten. Numerische Eingaben werden vor Eintritt nach bit konvertiert (0→0, Nichtnull→1). |
| `@Hilfe` | Typ bit; Default=0. Ausgelassen entspricht 0. 1 druckt die Hilfe und kehrt vor Analyse und Datenquellenzugriff zurück; zuvor ausgeführte TABLE-Zuordnungswache und TABLE-Preflight bleiben wirksam, ebenso die Wache für nichtleeres Mapping außerhalb TABLE. 0 führt die Analyse aus. NULL wirkt wie 0. Numerische Eingaben werden nach bit konvertiert (0→0, Nichtnull→1). |
| `@ParentCurrentStateSnapshotId` | Typ uniqueidentifier; Default=NULL. NULL oder ausgelassen liest die Live-DMVs eigenständig und erzeugt eine eigene Snapshot-ID. Eine UUID bindet an den materialisierten Snapshot des aktuellen USP_CurrentOverview-Aufrufs: erforderliche lokale Snapshot-Temp-Tabellen müssen mit kompatiblem Schema vorhanden sein; Context muss die UUID, @@SPID als OwnerSessionId und ContractVersion=2 enthalten. Daten werden aus MemoryGrants, ResourceSemaphores, Sessions, Requests, WorkloadGroups und ResourcePools geladen; SqlText-Daten werden nur bei @MitSqlText=1 geladen. Für Zeitbezug und Partialität werden die SourceStatus von MEMORY_GRANTS, RESOURCE_SEMAPHORES, SESSIONS, REQUESTS, WORKLOAD_GROUPS, RESOURCE_POOLS und SQL_TEXT stets berücksichtigt. Der SQL_TEXT-Status kann daher auch bei @MitSqlText=0 Zeitbezug und Partialität beeinflussen, obwohl die Textdaten nicht geladen werden. Eine fehlende, fremde oder inkompatible Bindung führt zu INVALID_PARENT_SNAPSHOT beziehungsweise strukturiertem Fehler. Es gibt in diesem Pfad keine Ablaufprüfung oder garantierte Frischegrenze. Erfordert die Berechtigung der Parent-Materialisierung sowie die erforderliche DMV-Berechtigung; Sichtbarkeit und Vollständigkeit richten sich nach Quellstatus und Berechtigungen. Parent-Zeitbezug ist die früheste CapturedAtUtc-Quellzeit, daher kann er älter sein als der Child-Aufruf. |

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `memoryGrants` mit 63 Feldern, neun expliziten Frameworktextcollations und ohne Identity. Nur `IsWaiting` und `CurrentStatementIsTruncated` sind NOT NULL. RAW liefert einen zwölfspaltigen Modulstatus und dieselben 63 Fachfelder; aktive CONSOLE ergänzt die Fachfelder um `Ergebnis` und besitzt damit 64 Felder. Eine leere CONSOLE liefert `Ergebnis`, `Status` und `Hinweis`. JSON enthält `meta` mit 15 Feldern, `memoryGrants` und `warnings`; NULL-Properties bleiben erhalten. Status und Warnungen sind im RAW-Modulstatus beziehungsweise JSON zu prüfen.

NULL oder 0 als `@MaxZeilen` liefert die vollständige gefilterte Menge. Ein positives Limit begrenzt RAW, CONSOLE, TABLE und JSON gemeinsam. Die Auswahl erfolgt nach `IsWaiting DESC`, `RequestedMemoryMb DESC`, `WaitTimeMs DESC`, `SessionId` und `RequestId`; RAW und JSON sortieren die ausgewählte Menge ausdrücklich. TABLE und der CONSOLE-Helper garantieren keine Darstellungsreihenfolge. `HasMoreRows`, `ResultLimited` und die Textwarnung werden vor dem gemeinsamen Zuschnitt aus den N+1-Kandidaten bestimmt. Ungültige negative Zeilen- oder Textgrenzen liefern weiterhin kontrolliert `INVALID_PARAMETER`.

Im Overview stammen Grants, Resource Semaphores, Sessions, Requests,
Workload-Gruppen, Resource Pools und deduplizierter SQL-Text aus derselben
Snapshot-ID. Der Einzelaufruf behält seinen frischen, eigenständigen
Materialisierungspfad.

## Eine Zeile bedeutet

Eine Zeile entspricht einem sichtbaren Memory-Grant-Vorgang einer Query beziehungsweise eines Requests.

## So lesen

Vergleichen Sie `RequestedMemoryMb`, `GrantedMemoryMb`, `UsedMemoryMb`, Wartezeit, Queryzustand und konkurrierende Grants.

## Warum kann das problematisch sein?

Ein großer angeforderter Grant mit `GrantedMemoryMb=0` wartet auf verfügbaren Execution Memory. Viele wartende Requests können einen Stau bilden.

## Wann ist es kein Problem?

Ein großer gewährter und tatsächlich genutzter Grant kann für einen großen Sort oder Hash Join angemessen sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 32 GB angefordert, 0 gewährt, 60 Sekunden `RESOURCE_SEMAPHORE`: Die Query rechnet nicht langsam, sie durfte noch nicht beginnen. Dagegen sind 32 GB gewährt und 28 GB genutzt bei einem geplanten großen Report plausibel.

**Bisher dokumentierter Folgeschritt:** Prüfen Sie Plan, Kardinalität, DOP, Konkurrenz und `USP_ServerMemory`.

**Ähnlich aussehender Gegenfall:** Ein großer gewährter und tatsächlich genutzter Grant kann für einen großen Sort oder Hash Join angemessen sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentMemoryGrants` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist gering; die DMV enthält nur aktuelle Grants und Anforderungen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Ein Snapshot der aktuell vorhandenen Memory Grants mit Defaultlimit 1000. SQL-Text ist standardmäßig aktiv. Im direkten Pfad wird er für alle unterschiedlichen Handles der erfassten Grants gelesen. Höchstens N+1 extrahierte Statements werden materialisiert und anschließend mit dem Unicodehelper projiziert; zusätzliche Extraktionsarbeit während Join, Filter und Sortierung ist damit nicht ausgeschlossen. Das Textbudget beträgt 3000 Zeichen. |
| Teuerster Pfad | `@MaxZeilen = 0`, keine Session-/Größenfilter und ungekürzter SQL-Text während sehr vieler gleichzeitig wartender oder gewährter Grants. Zusätzlich werden Workload-Group-, Pool- und Semaphorekontext je Grant korreliert. |
| Haupttreiber | Zahl gleichzeitig wartender/gewährter Grants und ihrer Request-, Semaphore-, Workload-Group- und Poolkorrelationen. Im direkten Pfad bestimmt die gesamte erfasste Grantmenge die Zahl unterschiedlicher Text-Handles. Filter und N+1-Limit begrenzen die Zahl materialisierter Statements und deren anschließende Unicodeprojektion; zusätzliche Join-, Filter-, Sortier- und Extraktionsarbeit kann weitere Quellzeilen betreffen. Ungekürzter Text verbreitert jeden behaltenen Kandidaten. |
| Skalierung | Die normalerweise kleine DMV-Menge bestimmt die Join- und Sortierarbeit. Breite oder ungekürzte Batchtexte erhöhen Speicher und Transfer; die Procedure liest keine Pläne und keine Benutzertabellen. |
| Ressourcen | CPU und Arbeitsspeicher für Live-DMV-Joins und Sortierung; bei `@MitSqlText = 1` zusätzlicher Plan-Cache-/Textzugriff und Ergebnistransfer. |
| Begrenzungswirkung | Session-, Waiting- und MB-Filter stehen in der Quellabfrage. Intern werden höchstens `@MaxZeilen + 1` Kandidaten materialisiert, um `HasMoreRows` zu bestimmen. Der DMV-/Joinpfad kann für Filter und Sortierung dennoch mehr Quellzeilen untersuchen; `@MaxSqlTextZeichen` begrenzt nur Textbreite. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Kein High-Impact-Gate. Session-, Waiting- und Größenfilter sowie das N+1-Kandidatenlimit begrenzen die materialisierte Statementmenge und deren anschließende Unicodeprojektion; `@MitSqlText = 0` und das Zeichenbudget sparen Breite. Das Sortieren/Filtern der sichtbaren Grantquelle bleibt notwendig. |
| Sicherer Einsatz | Bei akuter Grantwartefrage mit `@NurWartende = 1`, endlichem Limit und zunächst `@MitSqlText = 0` beginnen; Text nur für identifizierte Sessions ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen oder erwarten Workspace Memory für Sorts, Hashes und ähnliche Operatoren?

### Technischer Hintergrund

Der Optimizer schätzt den benötigten Query Execution Memory Grant aus Plan, Kardinalität, Row Size und DOP. Ein Request kann erst starten beziehungsweise bestimmte Operatoren ausführen, wenn der Grant verfügbar ist. `sys.dm_exec_query_memory_grants` zeigt angefordert, gewährt, genutzt und ideal sowie wartende Grants.

### Datenkette

`sys.databases`, `sys.dm_exec_query_memory_grants`, `sys.dm_exec_query_resource_semaphores`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`.

### Source Select

Das Grundselect verbindet Grants mit Session, Request und Datenbank; der Wartestatus kann bereits an der Grantquelle gefiltert werden:

```sql
SELECT
      [mg].[session_id]
    , [mg].[request_id]
    , [mg].[requested_memory_kb]
    , [mg].[granted_memory_kb]
    , [mg].[wait_time_ms]
    , [r].[wait_type]
    , [d].[name] AS [DatabaseName]
FROM [sys].[dm_exec_query_memory_grants] AS [mg] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [mg].[session_id]
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[session_id] = [mg].[session_id]
 AND [r].[request_id] = [mg].[request_id]
LEFT JOIN [sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [r].[database_id]
WHERE [mg].[grant_time] IS NULL;
```

**Wichtig für die Eigenlast:** `NurWartende`, Sessionfilter und TOP begrenzen die materialisierte Statementmenge. Die TVF-Extraktion steht im SELECT-/OUTER-APPLY-Pfad; daraus folgt ohne Ausführungsplannachweis keine entsprechende Grenze für ihre physische Auswertung. Der direkte Pfad materialisiert Grants, Sessions, Requests und Resource-Governor-Kontext vorher getrennt; bei `@MitSqlText = 1` liest er Text für alle unterschiedlichen Grant-Handles. `@MitSqlText = 0` vermeidet diesen zusätzlichen Textzugriff.

### Zeit- und Scope-Modell

Die Auswertung beschreibt einen flüchtigen Zustand. Wartende Grants verschwinden bei Zuteilung oder Abbruch; die Nutzung verändert sich während der Ausführung.

### Bewertung und Gegenprobe

Berücksichtigen Sie Wartedauer, Requested, Granted, Used und Ideal, DOP, Konkurrenz und Planoperatoren gemeinsam. Große tatsächlich genutzte Grants können korrekt sein; ein großer ungenutzter Anteil spricht eher für einen Übergrant oder einen Schätzfehler.

### Typische Fehlinterpretation

`GrantedMemory=0` kann vor Start normal kurz sichtbar sein; ein einzelner großer Grant beweist keinen Servermemorymangel. Server Memory und Query Execution Memory sind verwandte, aber nicht identische Ebenen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentRequests`, `USP_ServerMemory`, Showplan/Statistics und Query Store Runtime.

## Primärquellen

- [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#6-monitorusp_currentmemorygrants)
