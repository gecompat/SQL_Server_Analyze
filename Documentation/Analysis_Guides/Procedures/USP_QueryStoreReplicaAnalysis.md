# [monitor].[USP_QueryStoreReplicaAnalysis]

`USP_QueryStoreReplicaAnalysis` trennt Query-Store-Runtime-, Wait- und
Plan-Forcing-Evidenz nach `replica_group_id` und ordnet sie den in
`sys.query_store_replicas` sichtbaren Rollen zu. Die Procedure ist auf SQL
Server 2019 und 2022 installierbar, referenziert dort aber keine
SQL-Server-2025-Kataloge und liefert kontrolliert `UNAVAILABLE_VERSION`.

**Bereich:** Query Store und SQL Server 2025
**Zweck:** Trennt Query-Store-Runtime-, Wait- und Forcingevidenz nach beobachteter Replica-Gruppe und Rollenmetadaten.
**Beobachtungsart:** versionsadaptiver historischer Query-Store-Aggregationssnapshot
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn Query-Store-Messwerte eines begrenzten Zeitfensters nicht über Primary-, Secondary- und andere beobachtete Rollen vermischt werden sollen. Sie liefert die Rollenabbildung als eigene Evidenz und eignet sich vor einem Vergleich von Runtime- oder Waitaggregaten zwischen Replicas.

## Nicht beantwortete Fragen

Die Analyse prüft keine aktuelle AG-Synchronität, kein Routing und keine Hardwaregleichheit. Sie liest keine Querytexte, Plan-XMLs oder Hint-Payloads. Unterschiedliche Rollenaggregate beweisen deshalb weder Regression noch fehlerhafte Lastverteilung. Fehlende Replica-Metadaten machen eine Messung nicht wertlos, begrenzen aber ihre Rollenzuschreibung.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen/0: keine High-Impact-Bestätigung. NULL ist im normalen Analysepfad INVALID_PARAMETER. Der Auswahlhelfer prüft QUERY_STORE_CURRENT, derzeit ohne Gruppengate; dieses Modul ruft QUERY_STORE_DEEP auch bei breitem Zeitfenster oder unbegrenztem Limit nicht auf. 1 verändert weder Scope noch Rechte und vergibt keine Gruppenmitgliedschaft. |
| `@ReplicaGroupIds` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL: kein Replica-Gruppenfilter. Sonst Textliste ganzer bigint-Werte von -9223372036854775808 bis 9223372036854775807; &#124;, Beistrich und Strichpunkt dürfen gemischt werden, zum Beispiel N'1&#124;2,3;2'. U+0020-Randleerzeichen werden entfernt. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Kein zusätzlicher Positivitätsfilter: auch 0 und negative Werte werden exakt verglichen. Leerwert, leere Elemente, ungültige Klammerstruktur, Rohsegmente über 4000 UTF-16-Codeeinheiten und nicht zu bigint konvertierbare Werte machen den normalen Aufruf ungültig. Beistrich/Strichpunkt werden vor der bracket-aware Pipe-Zerlegung überall ersetzt; Klammern werden für die Zahlenkonvertierung nicht entfernt, deshalb keine Zahlen in eckigen Klammern übergeben. Filtert alle vier Fachmengen, nicht die Quelldatenbankauswahl. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Ausgelassen/NULL: nach dem Hilfezweig eine Stunde vor dem effektiven @BisUtc. Als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Muss vor @BisUtc liegen, sonst INVALID_PARAMETER. Runtime und Waits berücksichtigen vollständige Intervalle mit end_time &gt; @VonUtc und start_time &lt; @BisUtc, ohne anteilige Kürzung. Replica-Katalog und Forcing-Locations bleiben zeitlich ungefiltert. Der Default DATEADD(HOUR,-1,@BisUtc) benötigt eine darstellbare Stunde vor dem Ende; bei einem zu frühen datetime2-Endwert (etwa 0001-01-01T00:00:00) kann die Berechnung vor der normalen Validierung ungefangen überlaufen. |
| `@BisUtc` | `datetime2(7)` | `NULL` | Ausgelassen/NULL: nach dem Hilfezweig SYSUTCDATETIME(); zugleich NULLer Beginn ergibt die letzte Stunde. Als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T13:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Muss nach @VonUtc liegen. Nur Runtime/Waits werden über vollständige überlappende Intervalle gefiltert, Replica-Katalog und Forcing-Locations nicht. |
| `@MaxZeilen` | `int` | `200` | Ausgelassen: 200. NULL/0: unbegrenzt. Positive ganze int-Werte bis 2147483647 begrenzen jede der vier Fachmengen getrennt: replicas nach DatabaseId/ReplicaGroupId/RoleType aufsteigend; runtimeByReplica nach TotalCpuMs und LastExecutionTimeUtc absteigend, danach DatabaseId/ReplicaGroupId; waitsByReplica nach TotalQueryWaitTimeMs und LastIntervalEndUtc absteigend, danach DatabaseId/ReplicaGroupId; forcingByReplica nach ForcingLocationCount absteigend, danach DatabaseId/ReplicaGroupId. moduleStatus, sourceStatus und warnings sind nicht begrenzt. Nur der Wait-Quellpfad materialisiert je Quelldatenbank höchstens N+1 bereits aggregierte Waitgruppen, bei int-Maximum N; die zugrunde liegenden Quellzeilen werden vor diesem TOP aggregiert; die anderen Fachmengen werden vollständig gesammelt und danach global gekürzt. Modulzähler zählen die Ausgabe, sourceStatus.ReturnedRowCount die Sammlung vor globaler Kürzung. Negative Werte ergeben INVALID_PARAMETER mit Partialität, vier leere Fachmengen und vier false-HasMore-Flags. Das Limit löst keinen Deep-Check aus. Sortties garantieren keine zusätzliche eindeutige Auswahl; TABLE/CONSOLE keine physische Reihenfolge. |
| `@LockTimeoutMs` | `int` | `0` | Ausgelassen/0: kein Warten auf gesperrte Ressourcen beim Quellzugriff. Positive ganze Millisekunden von 1 bis 60000 setzen den Lock-Timeout für die Sammlung; andere nicht-NULL Werte sind INVALID_PARAMETER. Kein Gesamtzeitbudget. Nach regulärer Sammlung und behandelten Quellenfehlern wird der zuvor erfasste @@LOCK_TIMEOUT wiederhergestellt; ungefangene Fehler sind davon nicht pauschal abgedeckt. NULL wird durch NOT BETWEEN nicht explizit abgewiesen und nicht auf 0 normalisiert: der dynamische SET-Text wird NULL, also keine ausdrückliche Timeoutzuweisung. Für einen definierten Wert 0 bis 60000 übergeben. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung genau vier Optionen: CONSOLE zeigt nur den Modulstatus mit Ergebnislabel; RAW liefert sieben Resultsets in der Reihenfolge moduleStatus, replicas, runtimeByReplica, waitsByReplica, forcingByReplica, sourceStatus, warnings; TABLE schreibt nur die gemappte nichtleere Teilmenge dieser sieben; NONE unterdrückt normale Resultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen oder andere Werte sind im normalen Analysepfad INVALID_PARAMETER. Der an varchar(16) gebundene Wert ist maßgeblich. Hilfe kehrt vor dieser Validierung zurück. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL sowie leer/U+0020 sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt ist dort INVALID_PARAMETER. Bei TABLE ist ein nichtleeres JSON-Objekt mit ein bis sieben binär exakten, eindeutigen Schlüsseln erforderlich: moduleStatus (Gesamtstatus/Zähler), replicas (beobachtete Rollen), runtimeByReplica (Runtimeaggregate), waitsByReplica (Waitaggregate), forcingByReplica (Forcing-Locations), sourceStatus (Quellenstatus/Zähler), warnings (Warnungen). Jeder Wert ist der Name einer eigenen vorhandenen, leeren lokalen #Temp-Tabelle mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, höchstens LEN 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, case-insensitiv doppelte Ziele, Nicht-Stringwerte oder ungültige Ziele scheitern im ThrowOnError-Preflight vor Fachvalidierung, aber nach Hilfe. Der Writer ersetzt die Seed-Struktur durch das Ergebnisschema; nicht angeforderte Ziele bleiben unberührt. Gültige Zuordnungen erhalten auch bei ungültigen Fachparametern ihre Schemas und gegebenenfalls den Ablehnungsstatus. |
| `@JsonErzeugen` | `bit` | `0` | Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen/0: kein JSON, @Json bleibt NULL. 1 erzeugt unabhängig vom Ausgabemodus ein Objekt mit meta sowie den sieben Arrays moduleStatus, replicas, runtimeByReplica, waitsByReplica, forcingByReplica, sourceStatus und warnings. NULL ist im normalen Analysepfad INVALID_PARAMETER; es aktiviert JSON nicht. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter für das JSON-Dokument; beim Eintritt stets NULL, ein Eingabewert wird überschrieben. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Nur @JsonErzeugen=1 befüllt den Wert; bei Hilfe bleibt NULL. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Ein ungefangener THROW garantiert keine OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen: 1. NULL ist im normalen Analysepfad INVALID_PARAMETER. Der aktuelle Modulkörper nutzt den Parameter nur für diese NULL-Prüfung; 0 und 1 verändern weder Warnungsdaten noch die Meldungsausgabe. Hilfe-PRINTs erfolgen unabhängig davon vor der Prüfung. |
| `@Hilfe` | `bit` | `0` | Ausgelassen/0 oder NULL: normaler Analysepfad. 1 druckt Hilfe und Beispiele und kehrt vor Zeitdefaults, TABLE-Zielprüfung, fachlicher Validierung und Sammlung zurück. SQL-Typbindung bleibt vorher erforderlich. Nur @Json wurde bereits NULL; die vier Status-/Fehler-OUTPUTs behalten im Hilfezweig ihre Eingabewerte. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT des abschließenden Modulstatus im normalen Ablauf; kein Eingabefilter. Zum Empfang varchar(40)-Variable mit OUTPUT binden. AVAILABLE: nutzbare Evidenz; AVAILABLE_LIMITED: partielle Sammlung/Zuordnung; NOT_APPLICABLE: keine Fachmenge bei sonst nutzbarer Prüfung; UNAVAILABLE_VERSION: Replica-Auswertung vor SQL Server 2025 nicht unterstützt; INVALID_PARAMETER: ungültiger Aufruf. Vorbereitungsfehler werden unverändert übernommen, insbesondere INTERNAL_ERROR (interner Helfer-/Tabellenfehler), UNAVAILABLE_FEATURE (nicht unterstützter Quellregex), sowie je Analyseklassenregel HIGH_IMPACT_CONFIRMATION_REQUIRED (fehlende Bestätigung) oder DENIED_GROUP (fehlende Gruppenfreigabe); die aktuell verwendete Klasse QUERY_STORE_CURRENT verlangt kein Gruppengate. Bei Hilfe bleibt der Eingabewert unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT des abschließenden Partialitätsbits, kein Eingabeschalter. Eine bit-Variable mit OUTPUT binden. Im normalen Ablauf 0: keine festgestellte Partialität, 1: unvollständige Sammlung/Zuordnung oder ungültige Fachparameter. Ein Limit allein setzt dieses Bit nicht. Bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT der Modulfehlernummer, kein Eingabefilter. Eine int-Variable mit OUTPUT binden. Die interne Nummer wird NULL initialisiert und im aktuellen Modulkörper nicht gesetzt; Quellenfehlernummern stehen getrennt in sourceStatus/warnings und werden nicht automatisch übernommen. Bei Hilfe bleibt der Eingabewert unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT des Modulfehlertexts, kein Eingabefilter. Eine nvarchar(2048)-Variable mit OUTPUT binden. Im normalen Ablauf NULL, sofern keine Modulvalidierung oder Datenbankvorbereitung einen Fehlertext setzt; Quellenmeldungen werden nicht automatisch als erste Fehlermeldung übernommen, sondern stehen in sourceStatus/warnings. Bei Hilfe bleibt der Eingabewert unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung. |

```sql
EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreReplicaAnalysis_HelpStatus]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#QueryStoreReplicaAnalysis_HelpStatus"}';
 SELECT * FROM [#QueryStoreReplicaAnalysis_HelpStatus];
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

RAW, TABLE und JSON trennen `moduleStatus`, `replicas`, `runtimeByReplica`, `waitsByReplica`, `forcingByReplica`, `sourceStatus` und `warnings`. CONSOLE zeigt ausschließlich `moduleStatus` mit einem Ergebnislabel. Lesen Sie Datenbank-, Versions- und Query-Store-Status vor Rollen und Aggregaten. Vergleichen Sie nur identische Zeitfenster und berücksichtigen Sie `MappingStatusCode`.

Die sieben Resultsets besitzen zusammen 105 Felder, darunter 45 explizit mit `SQL_Latin1_General_CP1_CS_AS` collatierte Textfelder. Die vier fachlichen Mengen werden vor allen Ausgaben gemeinsam begrenzt. `moduleStatus` zählt die zurückgegebenen Zeilen; `sourceStatus.ReturnedRowCount` beschreibt die Sammlung vor dieser globalen Begrenzung. Status, Quellen und Warnungen erhalten kein Zeilenlimit. TABLE schreibt nur angeforderte Resultsets und lässt andere Ziele einschließlich vorhandener Zeilen unverändert. `SourceOrdinal` und `WarningOrdinal` behalten ihre Werte; die TABLE-Ziele besitzen keine Identity-Eigenschaft.

Ein negatives `@MaxZeilen` liefert `INVALID_PARAMETER` mit Partialität und vier leeren fachlichen Mengen; alle vier `HasMore*`-Flags stehen dabei auf `false`. Gültige TABLE-Zuordnungen werden auch bei ungültigen fachlichen Parametern vorbereitet. Angeforderte Ziele erhalten ihr vollständiges Schema und `moduleStatus` den Ablehnungsstatus. Ungültige Zuordnungen werden weiterhin vor der Datensammlung abgewiesen.

## Eine Zeile bedeutet

Eine Zeile in `replicas` beschreibt eine vom Query Store beobachtete Rolle einer
Datenbank. Eine Zeile in `runtimeByReplica` beschreibt die über das gewählte
Zeitfenster aggregierten Runtimeintervalle einer `replica_group_id`.
`waitsByReplica` ergänzt Ausführungstyp und Waitkategorie.
`forcingByReplica` inventarisiert nur sichtbare Plan-Forcing-Locations.

## So lesen

1. Zuerst `moduleStatus` auf Version, Partialität und Ausgabegrenzen prüfen.
2. Danach `sourceStatus` je Datenbank und Quelle lesen.
3. `replicas` trennt beobachtete Rolle und aktuelle Verbindungsrolle.
4. `runtimeByReplica` und `waitsByReplica` nur innerhalb desselben Zeitfensters vergleichen.
5. `MappingStatusCode` prüfen, bevor eine Messung einer Rolle zugeschrieben wird.
6. `EvidenceLimit` bei jeder Interpretation mitlesen.

Mehrere beobachtete Rollen können nach Failover korrekt sein. Die aktuelle
Verbindungsrolle und die historische Query-Store-Rolle sind bewusst getrennt.

## Beispiele und Gegenbeispiele

Ein geeigneter Example-Fall verwendet ein synthetisches Query-Store-Workloadfenster und prüft auf SQL Server 2025, ob Runtimezeilen eine explizite oder als fehlend markierte Rollenzuordnung besitzen. Ein Gegenbeispiel ist die pauschale Zuordnung jeder nicht gemappten Zeile zum Primary. Ebenso ist ein höherer Mittelwert auf einer Secondary ohne Ausführungszahl, Zeitraum und Hardwarekontext keine Regression.

## Leere oder partielle Ausgabe

`UNAVAILABLE_VERSION` ist auf SQL Server 2019 und 2022 der vorgesehene Fallback. Ein deaktivierter oder leerer Query Store erzeugt keine künstlichen Runtimezeilen. Fehlt eine einzelne 2025-Quelle oder Berechtigung, bleiben andere Quellen erhalten und `sourceStatus` beschreibt die Partialität. `NOT_RECORDED` und fehlende Metadaten sind keine erfundene Rollenidentität.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` |
| Standardpfad | Letzte Stunde in allen sichtbaren, online verfügbaren Benutzerdatenbanken; das Beispiel wählt ausdrücklich eine Datenbank |
| Teuerster Pfad | Breites Zeitfenster und mehrere Query-Store-Datenbanken |
| Haupttreiber | Runtimeintervalle, Pläne, Waitzeilen und Replica-Gruppen |
| Skalierung | Sequenziell je Datenbank; Aggregation innerhalb des Zeitfensters |
| Ressourcen | Query-Store-Katalog-I/O, CPU für gewichtete Aggregate und lokale Sortierung |
| Begrenzungswirkung | Datenbank-, Zeit-, Replica- und Zeilengrenzen |
| Locking und Nebenwirkungen | Read-only; kein Planforcing, Hint oder Query-Store-Flush |
| Schutzmechanismus | Versions-/Spaltenprobes und getrennte Quellenstatus |
| Sicherer Einsatz | Kleine Datenbankmenge und enges UTC-Zeitfenster |
| Aussagegrenze | Rollenaggregate sind keine AG-Health- oder Regressionsentscheidung |

## Warum kann das problematisch sein?

Ohne Trennung nach Replica-Rolle können Laufzeit- oder Waitaggregate aus
Primary-, Secondary- und Named-Replica-Ausführungen vermischt werden. Dadurch
kann eine Verschiebung des Read-Workloads wie eine allgemeine Queryregression
erscheinen. Eine fehlende Rollenzuordnung kann außerdem zu falschen
Healthaussagen führen, wenn Messwerte stillschweigend dem Primary zugeschrieben
werden.

## Wann ist es kein Problem?

Unterschiedliche Laufzeitwerte zwischen Primary und Secondary sind nicht
automatisch ein Fehler. Hardware, Cachezustand, Parallelität, Datenbewegung,
Read-Intent-Routing und zeitlich unterschiedlicher Workload können die Werte
legitim unterscheiden. Eine beobachtete frühere Rolle nach Failover ist
ebenfalls kein aktueller Störungsnachweis.

## Sicherer Einstieg

```sql
DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = DATEADD(HOUR,-1,SYSUTCDATETIME())
    , @BisUtc = SYSUTCDATETIME()
    , @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;

SELECT @Json AS [QueryStoreReplicaAnalysisJson];
```

`@ReplicaGroupIds` kann eine numerische Pipe-, Beistrich- oder
Strichpunktliste enthalten. `@MaxZeilen = NULL` und `@MaxZeilen = 0` bedeuten
unbegrenzt und sind für den Ersteinstieg nicht empfohlen. Ein positives Limit
gilt getrennt für `replicas`, `runtimeByReplica`, `waitsByReplica` und
`forcingByReplica`. Die Auswahl verwendet die bestehenden Sortschlüssel;
TABLE und CONSOLE garantieren keine Zeilenreihenfolge.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-Store-Evidenz wurde auf welcher beobachteten Replica-Rolle
erfasst, und ist die Zuordnung vollständig genug für einen Rollenvergleich?

### Technischer Hintergrund

SQL Server 2025 ergänzt die Query-Store-Runtime- und Waitquellen um
`replica_group_id`. `sys.query_store_replicas` ordnet diese Gruppen beobachteten
Rollen zu. `sys.query_store_plan_forcing_locations` hält replica-spezifische
Forcing-Locations. Die Procedure liest keine Querytexte, Plan-XMLs oder
Hint-Payloads.

### Datenkette

Je Zieldatenbank werden zuerst Product Major Version, Query-Store-Zustand,
Systemobjekte und Pflichtspalten geprüft. Erst danach werden die
versionsspezifischen Quellen dynamisch referenziert. Die fachlichen Mengen
werden lokal materialisiert und vor den Verbrauchern begrenzt. Runtimewerte werden mit
`count_executions` gewichtet; Waitwerte bleiben nach Ausführungstyp und
Waitkategorie getrennt.

### Source Select

```sql
SELECT
      [rs].[replica_group_id]
    , SUM([rs].[count_executions]) AS [ExecutionCount]
    , SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions]) AS [CpuWeighted]
FROM [sys].[query_store_runtime_stats] AS [rs]
JOIN [sys].[query_store_runtime_stats_interval] AS [i]
  ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id]
WHERE [i].[end_time]>@VonUtc
  AND [i].[start_time]<@BisUtc
GROUP BY [rs].[replica_group_id];
```

**Wichtig für die Eigenlast:** Datenbank- und Zeitfilter werden vor der
Aggregation angewendet. `@MaxZeilen` begrenzt die Ausgabe; breite Zeitfenster
und viele Datenbanken erhöhen CPU und I/O des Query-Store-Katalogzugriffs.

### Zeit- und Scope-Modell

`CapturedAtUtc` ist der aufrufweite Erfassungszeitpunkt. Runtime- und Waitwerte
stammen aus vollständigen Query-Store-Intervallen, die `@VonUtc` bis `@BisUtc`
überlappen. Der Zeitfilter schneidet keine einzelnen Messwerte aus einem
Intervall. `replicas` und `forcingByReplica` sind sichtbarer Katalogzustand ohne
Zeitfensterfilter. Die Quellen bilden
keine transaktional atomare Momentaufnahme.

### Bewertung und Gegenprobe

Rollenunterschiede zuerst mit Ausführungszahl, Zeitraum, Routing und
`USP_QueryStoreRuntimeStats` gegenprüfen. Bei Planwechseln oder Regressionen
anschließend `USP_QueryStorePlanChanges` beziehungsweise
`USP_QueryStoreRegressions` verwenden. Aktuelle AG-Synchronität und Routing
werden separat über die Availability-Group-Analysen geprüft.

### Typische Fehlinterpretation

`SECONDARY` bedeutet nicht, dass die aktuelle Verbindung gerade auf einer
Secondary läuft. Es ist die beobachtete Rolle der gespeicherten
Query-Store-Evidenz. `REPLICA_METADATA_MISSING` bedeutet ebenfalls nicht, dass
die Messung ungültig ist; nur die Rollenzuschreibung bleibt unvollständig.

### Folgeanalyse

`USP_QueryStoreRuntimeStats` liefert Query- und Plandetails im gleichen
Zeitfenster. `USP_QueryStoreWaitStats` vertieft Waitkategorien.
`USP_AvailabilityGroups` und `USP_AvailabilityDeepAnalysis` ergänzen aktuelle
Replica-, Routing- und Datenbewegungsevidenz.

## Primärquellen

- [sys.query_store_replicas](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-replicas?view=sql-server-ver17)
- [Query Store for secondary replicas](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-for-secondary-replicas?view=sql-server-ver17)
- [sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_plan_forcing_locations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-plan-forcing-locations-transact-sql?view=sql-server-ver17)


[Technische Detailbeschreibung](../05_Query_Store.md)
