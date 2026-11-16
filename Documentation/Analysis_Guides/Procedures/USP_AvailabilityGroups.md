# [monitor].[USP_AvailabilityGroups]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Availability-Group-, Replica-, Datenbank- und Routingzustand.<br>
**Beobachtungsart:** verteilter, nicht atomarer Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityGroups]
      @MitRouting = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MitRouting` | `bit` | Default: `1` | SQL Server konvertiert das Argument vor Aufruf; NULL bleibt NULL. Nur ein Argument, das SQL Server zu bit 1 konvertiert, führt die zusätzliche Read-only-Abfrage der Read-Only-Routinglisten aus. Bei 0 oder NULL bleibt diese Ergebnismenge leer. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `5000` | Der SQL-int-Bereich von -2.147.483.648 bis 2.147.483.647. Ein negativer Wert ergibt INVALID_PARAMETER. NULL oder 0 wird in bigint-Maximalwert umgerechnet und bedeutet damit praktisch unbegrenzt; ein positiver Wert begrenzt jede der vier Ergebnismengen getrennt. Er filtert weder AGs noch Datenbanken vor der Quellabfrage. Nicht konvertierbare Argumente scheitern bereits vor dem Procedure-Body. Einheit: Zeilen je Ergebnismenge. Ein negativer Wert allein lässt IsPartial=0. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | SQL-Konvertierung findet vor dem Body statt; danach werden Leerzeichen an den Rändern entfernt und die Eingabe in Großbuchstaben normalisiert. Vorgesehen sind CONSOLE, RAW, TABLE und NONE. NULL, leerer oder unbekannter Wert ist ungültig. RAW liefert zuerst den Modulstatus und danach vier native Ergebnismengen; NONE unterdrückt Ergebnismengen. CONSOLE wird intern zunächst zu NONE und am Ende über den erreichbaren gemeinsamen Console-Adapter für die Replikamenge ausgegeben. TABLE unterdrückt die nativen Mengen und exportiert nur replicas. Außerhalb von TABLE muss ResultTablesJson NULL oder leer sein. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Nur im TABLE-Modus wird ein JSON-Objekt mit dem exakt erlaubten Schlüssel replicas angenommen; sein Zeichenkettenwert muss auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte zeigen. Globale ##Temp- und permanente Ziele sind unzulässig; der Tabellenname darf höchstens 116 Zeichen lang sein. NULL oder leer wird im TABLE-Modus vom Helper abgelehnt. Außerhalb davon löst nichtleeres JSON nach Trimmen Fehler 51011 aus; Whitespace gilt als leer. Der Helper prüft Schlüssel und Stringtyp, Eindeutigkeit sowie den Zielnamen. Diese Prüfung liegt vor HELP. Das Präfix #Monitor ist unabhängig von Groß- und Kleinschreibung reserviert. Der Preflight kann vor HELP vorübergehend eine Markerspalte hinzufügen und entfernen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Nur der nach SQL-Konvertierung vorliegende Wert 1 aktiviert die JSON-Erzeugung für den OUTPUT-Parameter Json; NULL wirkt wie deaktiviert. JSON-Erzeugung ist unabhängig von ResultSetArt. Der gebundene Wert 0 deaktiviert die JSON-Erzeugung. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | Die Procedure setzt ihn am Eintritt auf NULL; nur bei JsonErzeugen=1 enthält er ein JSON-Objekt mit den Schlüsseln meta, replicas, databases, listeners und routing. Die Arrays enthalten auch NULL-Felder. Die OUTPUT-Bindung ändert die normalen Resultsets nicht. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@PrintMeldungen` | `bit` | Default: `1` | Bei einem abgefangenen Fehler der Erfassung gibt nur der Wert 1 eine Meldung mit Severity 10 und WITH NOWAIT aus. 0 oder NULL unterdrücken nur diese Zusatzmeldung, nicht Status oder Daten. SQL-konvertierte bit-Eingaben werden vor dem Body gebunden. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt vor der Erfassung zurück. 0 und NULL aktivieren die Hilfe nicht. Json wird vorher auf NULL gesetzt; auch die TABLE-Vorprüfung findet bereits statt. Bei ausgelassenem Argument gilt der angegebene Default. |

## Aufrufbeispiele zu den Parameterverträgen

Das TABLE-Beispiel erwartet einen freien lokalen Tabellennamen. Es legt das leere Ziel mit einer Seed-Spalte an und entfernt es nach dem Aufruf oder bei einem Aufruffehler.

```sql
EXEC [monitor].[USP_AvailabilityGroups] @Hilfe=1;

EXEC [monitor].[USP_AvailabilityGroups] @MitRouting=0, @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @AgJson nvarchar(max); EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgJson OUTPUT; SELECT @AgJson AS [Json];

CREATE TABLE #AvailabilityGroups_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"replicas":"#AvailabilityGroups_HelpExample"}'; SELECT * FROM #AvailabilityGroups_HelpExample; DROP TABLE #AvailabilityGroups_HelpExample; END TRY BEGIN CATCH DROP TABLE #AvailabilityGroups_HelpExample; THROW; END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `replicas`. RAW beginnt mit dem Modulstatus und liefert danach Replikate, Datenbanken, Listener und Routing. CONSOLE verwendet den erreichbaren gemeinsamen Console-Adapter für die Replikamenge; TABLE schreibt nur diese Replikamenge. JSON ist unabhängig davon optional und enthält Metadaten sowie die Arrays `replicas`, `databases`, `listeners` und `routing`. Ein nicht aktiviertes HADR-Feature wird als `UNAVAILABLE_FEATURE` ausgegeben; Erfassungsfehler werden als `ERROR_HANDLED` mit Partial Result gemeldet. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden. AVAILABLE bezeichnet die reguläre Erfassung. INVALID_PARAMETER meldet ein negatives Zeilenlimit (IsPartial=0, sofern der Ausgabemodus gültig ist) oder einen ungültigen Ausgabemodus (IsPartial=1). UNAVAILABLE_FEATURE bedeutet, dass IsHadrEnabled ungleich 1 ist. ERROR_HANDLED meldet einen abgefangenen Erfassungsfehler mit IsPartial=1, Fehlernummer und Fehlermeldung. Ungültige TABLE-Zuordnungen können bereits vor der Statusermittlung eine Ausnahme auslösen.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine AG, Replica, Availability Database oder Routingkonfiguration.

## So lesen

Berücksichtigen Sie Replica-Rolle, Connected State, Synchronization State, Health, Availability Mode, Failover Mode und Routing gemeinsam.

## Warum kann das problematisch sein?

Disconnected oder not synchronizing kann RPO-/Failoverrisiko erhöhen; fehlerhaftes Routing kann Read-Only-Workload falsch lenken.

## Wann ist es kein Problem?

Asynchrone Replicas dürfen Lag besitzen. Entscheidend sind vereinbartes RPO, Trend und geplanter Einsatzzweck.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 30 Sekunden Lag bei asynchroner DR-Replica kann policykonform sein; vor synchronem Failover ist derselbe Zustand kritisch. Verwenden Sie danach `USP_AvailabilityDeepAnalysis`.

**Ähnlich aussehender Gegenfall:** Asynchrone Replicas dürfen Lag besitzen. Entscheidend sind vereinbartes RPO, Trend und geplanter Einsatzzweck. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine leere AG- oder Replica-Sicht kann bedeuten, dass Always On nicht konfiguriert ist, der lokale Knoten keine sichtbare Replica besitzt oder Berechtigung beziehungsweise Rolle einzelne Runtime-DMVs ausblendet. Unterscheiden Sie deshalb zuerst Katalog- und Quellenstatus.

Für `USP_AvailabilityGroups` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist mittel; die Procedure wertet ausschließlich HADR-Kataloge und -DMVs aus.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Lokaler HADR-Katalog-/DMV-Snapshot mit Standardlimit; Routingdetails nur soweit konfiguriert und angefordert. |
| Teuerster Pfad | Unbegrenzte RAW-Ausgabe aller AGs, Replicas, Datenbanken, Listener und Routinglisten auf einer großen Instanz. |
| Haupttreiber | Anzahl lokaler AGs, Replicas, Availability-Datenbanken, Listener/IPs und – falls angefordert – Routinglisteneinträge. Es gibt keinen AG-/Datenbankfilter; `@MaxZeilen` reduziert erst die einzelnen Resultsets. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AvailabilityGroups ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Geringe bis mittlere CPU für lokale HADR-Kataloge/DMVs und Zusammenführung; kein Remotequery und kein Nutzdaten- oder Logscan. |
| Begrenzungswirkung | MaxZeilen begrenzt die einzelnen Ausgaben, nicht die davor gelesenen HADR-Katalog-/DMV-Zeilen und nicht die zeitliche Nicht-Atomarität. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Kein High-Impact-Gate und kein AG-/Datenbankfilter. `@MitRouting = 0` lässt Routingdetails aus, und `@MaxZeilen` begrenzt die einzelnen Ausgaben; die lokalen HADR-Kataloge/DMVs werden davor dennoch instanzweit gelesen. |
| Sicherer Einsatz | CONSOLE mit Standardlimit; lokale Rolle und Erfassungszeit notieren, anschließend nur die betroffene ExampleAG beziehungsweise ExampleDb korrelieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter, nicht atomarer Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?

### Technischer Hintergrund

Primär erzeugt Log Records, sendet Logblöcke an Secondaries, diese harden und redoen. Synchroner Commit wartet je Konfiguration auf Bestätigung. Replica-/Database-DMVs liefern Role, Connection, Synchronization State/Health, Send/Redo Queue, Rate und Last Hardened/Redone.

### Datenkette

`sys.availability_group_listener_ip_addresses`, `sys.availability_group_listeners`, `sys.availability_groups`, `sys.availability_read_only_routing_lists`, `sys.availability_replicas`, `sys.dm_hadr_`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_database_replica_states`, `sys.fn_hadr_is_primary_replica`.

### Source Select

Die wesentliche Beziehung verbindet AG-Konfiguration, Replikate und deren aktuellen Laufzeitzustand:

```sql
SELECT
      [ag].[name] AS [AvailabilityGroupName]
    , [ar].[replica_server_name]
    , [ar].[availability_mode_desc]
    , [ar].[failover_mode_desc]
    , [ars].[role_desc]
    , [ars].[connected_state_desc]
FROM [sys].[availability_groups] AS [ag] WITH (NOLOCK)
JOIN [sys].[availability_replicas] AS [ar] WITH (NOLOCK)
  ON [ar].[group_id] = [ag].[group_id]
LEFT JOIN [sys].[dm_hadr_availability_replica_states] AS [ars] WITH (NOLOCK)
  ON [ars].[replica_id] = [ar].[replica_id]
WHERE [ag].[name] = N'ExampleAvailabilityGroup';
```

**Wichtig für die Eigenlast:** Der AG-Name ist der wirksamste frühe Scope. Listener, IP-Adressen, Routinglisten und Datenbankzustände werden erst für die verbleibenden Gruppen ergänzt.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen lokalen Snapshot; Ratewerte können intern über begrenzte Intervalle berechnet werden und schwanken.

### Bewertung und Gegenprobe

Berücksichtigen Sie Role, Availability Mode, Failover Mode, Connected State, Sync State, Queue MB, Rate und Zeitmarken gemeinsam. Das Verhältnis von Queue und Rate liefert nur bei einer stabilen Rate eine grobe Abarbeitungszeit.

### Typische Fehlinterpretation

`SYNCHRONIZED` bedeutet nicht null Latenz oder lesbare Secondary. Queuegröße allein ohne Trend und Workloadrate ist keine Prognose.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_AvailabilityDeepAnalysis`, Current Log/I/O und externe Cluster-/Netzwerktelemetrie.

## Primärquellen

- [Always On Availability Groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/overview-of-always-on-availability-groups-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#4-monitorusp_availabilitygroups)
