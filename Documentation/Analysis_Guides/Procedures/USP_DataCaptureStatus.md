# [monitor].[USP_DataCaptureStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt CDC-, Change-Tracking- und weitere Data-Capture-Zustände.<br>
**Beobachtungsart:** Konfigurations- und Runtime-Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureStatus]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

Ersetzen Sie ExampleDatabase in den Aufrufbeispielen durch die beabsichtigte Datenbank. Ein Zeilenlimit begrenzt die Ergebnismengen, während die Datenbankauswahl von den Filtern abhängt.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | Default: `NULL` | Default NULL. NULL oder Leer-/Whitespace-Eingabe bedeutet keine Einschränkung und alle zulässigen sichtbaren Online-Datenbanken. Nichtleere Pipe-Liste einteiliger SQL-Namen; \| trennt außerhalb eckiger Klammern, ]] maskiert eine schließende Klammer; Elementränder werden getrimmt. Leere Segmente, ungültige Klammerung, Rohsegment über 4000 UTF-16-Codeeinheiten, Multipartname oder Name über 128 Zeichen sind INVALID_PARAMETER; Duplikate ebenfalls. Gültige, aber fehlende/offline/unzugängliche Namen werden Warnungen/Partial. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@SystemdatenbankenEinbeziehen` | `bit` | Default: `0` | Default 0. 0 schließt master, tempdb, model und msdb aus; explizite Anforderung erzeugt SYSTEM_DATABASE_EXCLUDED. 1 lässt System-IDs bis 4 zu. NULL oder Werte außer 0/1 sind INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | Default: `NULL` | Default NULL. NULL heißt kein Pattern. Eingabe außen getrimmt; optionale Präfixe ohne Groß-/Kleinschreibung: like: (LIKE), regex: (case-sensitive Regex), regexi: (case-insensitive Regex); ohne Präfix gilt LIKE. Präfix wird entfernt, Rest nicht erneut getrimmt; leerer Inhalt ist ungültig. Exakte Liste und Pattern sind exklusiv. LIKE ist case-sensitive. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@HighImpactConfirmed` | `bit` | Default: `0` | Der Kandidatenhelfer prüft HA_DR_CURRENT. Diese Klasse verlangt keine High-Impact-Bestätigung. 0 genügt für das Bestätigungsbit. Die aktuelle Zugriffspolicy wird weiterhin geprüft und kann DENIED_GROUP ergeben. Auch bei mehreren Datenbanken erfolgt kein zusätzlicher CROSS_DATABASE_DEEP-Check. NULL ergibt INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@MaxZeilen` | `int` | Default: `10000` | Default 10000. NULL/0 unbegrenzt; negativ INVALID_PARAMETER, bevor Datenbankauswahl und Facherhebung beginnen (ein TABLE-Preflight kann vorher bereits erfolgt sein). Positive Grenze gilt global getrennt für databases, CDC-Tabellen, Change-Tracking-Tabellen und Jobs, nicht als Gesamtbudget. Auswahl wird nicht vorab begrenzt; lokal höchstens N+1 je Pfad pro Datenbank, danach globale TOP-N. Warnings bleiben ungekürzt. Datenbankausgabe nach DatabaseName sortiert. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE, RAW, TABLE, NONE. NULL, Leerwert und andere Werte ungültig. RAW liefert Modulstatus, databases, CDC-Tabellen, CT-Tabellen, Jobs und Warnings. CONSOLE wird intern vor der Ausgabe auf NONE normalisiert; der erreichbare Console-Helper gibt anschließend ausschließlich die databases-Ansicht aus, ohne separaten Modulstatus oder Warnings. TABLE schreibt nur databases; NONE keine normalen Resultsets. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Default NULL. Nur TABLE zulässig; sonst wird nichtleeres JSON mit 51011 abgewiesen. Einziges Resultat databases. Erwartet JSON-Objekt mit Resultnamen und Zielwert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, höchstens 116 Zeichen, genau eine Seed-Spalte und eindeutiger Name. Fehlende/ungültige Zuordnung wirft. Preflight vor HELP und Datenbankauswahl. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | Default 0. 1 erzeugt zusätzlich unabhängig von ResultSetArt JSON mit meta, databases, cdcTables, changeTrackingTables, cdcJobs und warnings; 0 nicht. Warnungen bleiben ungekürzt. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT, Default NULL. Anfangs auf NULL gesetzt; bei JsonErzeugen=1 wird JSON mit Status/Partialität und fünf Arrays an gebundene nvarchar(max)-OUTPUT-Variable zurückgegeben. Binden Sie eine Variable des deklarierten Typs mit OUTPUT. |
| `@PrintMeldungen` | `bit` | Default: `1` | Default 1. Bei Status ungleich AVAILABLE zusätzliche Severity-10-Warnung; 0 unterdrückt sie. NULL wirkt nicht wie 1. Status-/Warning-Resultsets bleiben bestehen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | Default 0. 1 druckt kurze Eingabe-, Auswahl- und Ausgabehilfe und kehrt zurück; NULL wirkt wie 0. ResultTablesJson-Kombinationsprüfung und TABLE-Preflight laufen vor HELP. Bei ausgelassenem Argument gilt der angegebene Default. |

## Aufrufbeispiele zu den Parameterverträgen

Das TABLE-Beispiel erwartet einen freien lokalen Tabellennamen. Es legt das leere Ziel mit einer Seed-Spalte an und entfernt es nach dem Aufruf oder bei einem Aufruffehler.

```sql
EXEC [monitor].[USP_DataCaptureStatus] @Hilfe=1;

EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @CaptureJson nvarchar(max); EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@CaptureJson OUTPUT; SELECT @CaptureJson AS [Json];

CREATE TABLE #DataCaptureStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#DataCaptureStatus_HelpExample"}'; SELECT * FROM #DataCaptureStatus_HelpExample; DROP TABLE #DataCaptureStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #DataCaptureStatus_HelpExample; THROW; END CATCH;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag exportiert ausschließlich `databases`. RAW stellt den Modulstatus vor die Fachergebnissets; Warnings folgen danach. JSON enthält den Status in `meta` und Warnings in einem eigenen Array. CONSOLE gibt über den Console-Helper nur die databases-Ansicht aus und enthält dabei weder den Modulstatus noch die Warnings. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, ein Capture-Feature, einen Job oder eine erfasste Tabelle.

## So lesen

Unterscheiden Sie Featurestatus, Capture-/Cleanup-Job, Retention, Datenbankzustand und Logkontext.

## Warum kann das problematisch sein?

Aktiviertes CDC ohne laufenden Capturejob kann Logrückstand erzeugen; Cleanupfehler lassen Capturetabellen wachsen.

## Wann ist es kein Problem?

Deaktiviertes CDC oder Change Tracking ist normal, wenn die Datenbank das Feature nicht benötigt.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** CDC enabled plus Capturejob disabled ist ein konkreter Fehlerzustand. Prüfen Sie Agentjobs, Logstatus und Featurekonfiguration.

**Ähnlich aussehender Gegenfall:** Deaktiviertes CDC oder Change Tracking ist normal, wenn die Datenbank das Feature nicht benötigt. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_DataCaptureStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist mittel; lokale Kandidaten werden je Datenbank auf N+1 begrenzt, anschließend erfolgt ein globales TOP je fachlichem Resultset.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`; CDC-Capture-Instances, Change-Tracking-Tabellen und zugeordnete CDC-Jobs werden als aktueller Konfigurations-/Statussnapshot gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken und unbegrenzte Ausgabe bei vielen erfassten Tabellen. Je CDC-Job wird nur die letzte Outcome-Historyzeile aufgelöst, kein frei wählbares Historyfenster. |
| Haupttreiber | Zahl sichtbarer Datenbanken und aktivierter CDC-/Change-Tracking-Konfigurationen sowie zugehöriger lokaler CDC-Jobs und letzter Historyzeilen. Change-Tabelleninhalte und Replikationsbefehle werden in diesem Statuspfad nicht gelesen. |
| Skalierung | Aufwand wächst mit Datenbanken, CDC-Instances, Change-Tracking-Tabellen und Jobs. Pro Datenbank werden lokal höchstens N+1 Kandidaten je fachlichem Pfad übernommen, anschließend global begrenzt. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Datenbankscope begrenzt den Cursor. `@MaxZeilen` steuert lokale N+1-Kandidaten und das globale TOP je Resultset; es ist keine gemeinsame Gesamtgrenze über CDC, CT und Jobs und verhindert nicht jede Katalog-/letzte-History-Suche. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | `HA_DR_CURRENT` muss freigegeben sein, verlangt laut Klassenkatalog aber keine High-Impact-Bestätigung. `@HighImpactConfirmed` aktiviert hier keinen zusätzlichen Detailpfad. |
| Sicherer Einsatz | Eine `ExampleDatabase` und endliches Limit; Datenbankstatus vor den drei getrennten Fachresultsets lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurations- und Runtime-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?

### Technischer Hintergrund

CDC liest Transaction Log asynchron in Change Tables und räumt per Cleanupjob auf. Change Tracking speichert kompakte Änderungsinformationen mit Retention/Auto Cleanup, keine vollständigen historischen Werte. Replication besitzt eigenen Logreader-/Distributionspfad.

### Datenkette

`master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Collation und Ausgabegrenzen

Die fünf Textspalten des `databases`-TABLE-Exports verwenden die
Frameworkcollation `SQL_Latin1_General_CP1_CS_AS`. TABLE und JSON verwenden
dieselbe materialisierte Datenbankmenge. Alle ausgewählten Datenbanken werden
vor der Ausgabegrenze erhoben; Modulstatus und Warnings berücksichtigen die
vollständige Erhebung. Ein positives `@MaxZeilen` begrenzt die Datenbankausgabe
nach Datenbankname. CDC-Tabellen, CT-Tabellen und Jobs besitzen jeweils eine
separate globale Grenze nach ihren vorhandenen Namenssortierungen. Null und
NULL sind unbegrenzt. Die Ausgabe ist kein atomarer Snapshot verschiedener
Aufrufe und beweist keinen Consumerfortschritt.

### Source Select

Der Basisstatus verbindet die Datenbankoption mit den Change-Tracking-Tabellen der ausgewählten Datenbank:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , [d].[is_cdc_enabled]
    , [ctd].[retention_period]
    , [ctd].[retention_period_units_desc]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
LEFT JOIN [sys].[change_tracking_databases] AS [ctd] WITH (NOLOCK)
  ON [ctd].[database_id] = [d].[database_id]
WHERE [d].[database_id] = DB_ID();

SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [ct].[begin_version]
    , CHANGE_TRACKING_MIN_VALID_VERSION([ct].[object_id]) AS [MinValidVersion]
FROM [sys].[change_tracking_tables] AS [ct] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK)
  ON [t].[object_id] = [ct].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
WHERE [t].[is_ms_shipped] = 0;
```

**Wichtig für die Eigenlast:** Die Datenbankauswahl erfolgt vor dem dynamischen datenbanklokalen Katalogzugriff. Die Procedure sucht passende CDC-Jobnamen für jede ausgewählte Datenbank und liest je Job nur die letzte Outcome-Zeile. Sie bietet keinen Historyzeitfilter und liest keine Change-Zeilen.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Enablement-/Konfigurationszustand mit begrenzten Job-/LSN-/Versionmarken.

### Bewertung und Gegenprobe

Berücksichtigen Sie Technologie, Captureinstanzen, Jobs, Retention, Min/Max LSN oder Change Tracking Versions und Tabellenabdeckung. Prüfen Sie Consumerposition gegen Mindestversion/MinLSN.

### Typische Fehlinterpretation

`Enabled=1` beweist keinen aktuellen Durchsatz, keine lückenlose Retention und keine funktionierenden Consumer.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_DataCaptureDeepAnalysis`, Agent Jobs und Consumercheckpoint.

## Primärquellen

- [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#8-monitorusp_datacapturestatus)
