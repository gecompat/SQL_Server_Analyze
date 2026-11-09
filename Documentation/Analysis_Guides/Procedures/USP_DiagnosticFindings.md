# [monitor].[USP_DiagnosticFindings]

**Bereich:** Server Health<br>
**Zweck:** Konsolidiert normalisierte Findings mit Priorität, Konfidenz, Evidenz und Aussagegrenze.<br>
**Beobachtungsart:** nicht atomarer Mix aus Child-Snapshots, Stichproben und Historien<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurAbPrioritaet = 'INFO',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter einteiliger SQL-Namen für die datenbankbezogenen Empfänger. NULL, Leertext und Leerzeichen lassen die exakte Auswahl aus. Liste und Muster schließen sich aus. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Systemdatenbanken bei den datenbankbezogenen Empfängern aus. 1 bezieht sie nach deren Regeln ein. NULL wird als Argument weitergereicht und kann bei der Kandidatenprüfung abgelehnt werden. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Der DiagnosticFindings-Parent normalisiert oder validiert das Pattern nicht und reicht es bei tatsächlichem Aufruf des jeweiligen Kindmoduls an DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weiter. Ein nicht-NULL Pattern ist im erreichten Kandidatenhelfer mit einer wirksamen expliziten Namensliste unzulässig; NULL, leerer oder nur aus U+0020 bestehender Listenwert ist keine wirksame Liste. ParentIntegrityJson- und ParentCapacityJson-Wiederverwendung überspringt den jeweiligen Kindmodulaufruf; das Pattern filtert übernommenes JSON nicht nachträglich. Frühe Fehler und übersprungene Aufrufe können die jeweilige Parserprüfung verhindern. |
| `@HighImpactConfirmed` | `bit` | `0` | Der Wert wird an Empfänger mit Kandidaten- oder Klassenprüfung weitergereicht. 1 bestätigt einen tatsächlich aktivierten geschützten Pfad. 0 bestätigt ihn nicht. NULL kann von diesen Prüfungen abgelehnt werden. |
| `@MitIntegritaet` | `bit` | `1` | 1 aktiviert DatabaseIntegrityAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitKapazitaet` | `bit` | `1` | 1 aktiviert DatabaseCapacityAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitSpeicher` | `bit` | `1` | 1 aktiviert BufferPoolAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitBackupketten` | `bit` | `1` | 1 aktiviert BackupChainAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitAvailability` | `bit` | `1` | 1 aktiviert AvailabilityDeepAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitAgentMonitoring` | `bit` | `1` | 1 aktiviert AgentMonitoringAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitSchemaDesign` | `bit` | `0` | 1 aktiviert SchemaDesignAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitStatistikverteilung` | `bit` | `0` | 1 aktiviert StatisticsDistributionAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitIQP` | `bit` | `0` | 1 aktiviert IntelligentQueryProcessingAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@MitContention` | `bit` | `0` | 1 aktiviert InternalContentionAnalysis. 0 oder NULL lässt diesen Aufruf aus. |
| `@ContentionSampleSeconds` | `tinyint` | `5` | Sekunden für das aktivierte Contention-Modul. 1 bis 60 fordert ein Intervalldelta an. 0 überspringt WAITFOR und liefert positive kumulative Zähler seit Serverstart. Werte über 60 sind ungültig. NULL überspringt die Wartezeit und liefert keine Latch- oder Spinlock-Deltazeilen. Raten bleiben unbekannt. |
| `@ContentionMinWaitMs` | `bigint` | `1000` | Nichtnegative Mindestwartezeit in Millisekunden für Latch-Findings aus der Contention-Auswertung. Ein Wert ab der Grenze erfüllt den Vergleich. Bei NULL entstehen aus diesem Vergleich keine Latch-Findings. Negative Werte sind ungültig. |
| `@ParentIntegrityJson` | `nvarchar(max)` | `NULL` | Laufinternes JSON zur Wiederverwendung von DatabaseIntegrityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseIntegrityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs. |
| `@ParentCapacityJson` | `nvarchar(max)` | `NULL` | Laufinternes JSON zur Wiederverwendung von DatabaseCapacityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseCapacityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs. |
| `@ParentBufferPoolJson` | `nvarchar(max)` | `NULL` | Laufinternes JSON zur Wiederverwendung von BufferPoolAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=BufferPoolAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs. |
| `@NurAbPrioritaet` | `varchar(16)` | `'INFO'` | INFO umfasst alle Prioritätsstufen. LOW lässt INFO aus. MEDIUM umfasst MEDIUM und HIGH. HIGH lässt nur HIGH zu. Die Filterung erfolgt nach der Erhebung. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig. |
| `@MaxZeilen` | `int` | `1000` | Eine positive ganze Zahl begrenzt die finale Findingmenge nach Prioritätsfilterung und wird an die Empfänger weitergereicht. NULL oder 0 hebt die Grenze auf. Negative Werte sind ungültig. Die Grenze begrenzt den gesamten Quellenaufwand nicht. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | CONSOLE zeigt beschriftete Findings. RAW liefert technische Ergebnis- und Statusmengen. TABLE schreibt ausschließlich findings. NONE unterdrückt die fachlichen Resultsets. Die Empfänger laufen mit NONE. JSON ist separat wählbar. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel findings erforderlich. Der Wert benennt eine vorhandene leere lokale #Temp-Tabelle mit einer Seed-Spalte. Erlaubt sind maximal 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Wird beim Eintritt auf NULL gesetzt und bei aktivierter JSON-Erzeugung gefüllt. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. |
| `@PrintMeldungen` | `bit` | `1` | 1 aktiviert Meldungen der aufgerufenen Module. 0 und NULL unterdrücken sie. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe nach der TABLE-Vorprüfung und beendet vor der fachlichen Analyse. 0 und NULL führen die Analyse aus. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Empfängt den Laufstatus. Binden Sie eine varchar(40)-Variable mit OUTPUT. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Empfängt das Partialitätsflag für die erreichbare Evidenz. Binden Sie eine bit-Variable mit OUTPUT. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Empfängt eine erfasste Fehlernummer oder NULL. Binden Sie eine int-Variable mit OUTPUT. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Empfängt eine erfasste Fehlermeldung oder NULL. Binden Sie eine nvarchar(2048)-Variable mit OUTPUT. |

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_DiagnosticFindings] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='RAW';
```

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

```sql
CREATE TABLE #DiagnosticFindings_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#DiagnosticFindings_HelpExample"}';
SELECT * FROM #DiagnosticFindings_HelpExample;
DROP TABLE #DiagnosticFindings_HelpExample;
END TRY BEGIN CATCH DROP TABLE #DiagnosticFindings_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die zehn Textspalten der lokalen Befundtabelle und die vier Textspalten der
Modulstatusvariable verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.
Der TABLE-Export behält diese Frameworkcollation auch bei einer abweichenden
Server- oder `tempdb`-Collation. Nach Befunderzeugung und Statusermittlung wird
die gemeinsame Ausgabemenge nach `@NurAbPrioritaet` gefiltert und nach
`@MaxZeilen` begrenzt. RAW, CONSOLE, TABLE und JSON verwenden dieselben Befunde.

Die vorhandenen Zähler werden vor der Ausgabekürzung ermittelt:
`totalFindingCount` sowie die RAW- und CONSOLE-Gesamtzahl zählen alle erzeugten
Befunde. Das bisherige JSON-Feld `returnedFindingCount` zählt die Befunde nach
Prioritätsfilter, aber vor dem Zeilenlimit. Bei vier passenden Befunden und
`@MaxZeilen=1` beträgt dieser Zähler weiterhin vier; das Findingarray und der
TABLE-Export enthalten jeweils eine Zeile.

## Eine Zeile bedeutet

Eine Zeile entspricht einem normalisierten Finding aus einem SourceModule. Modulstatuszeilen sind getrennt zu lesen.

## So lesen

Berücksichtigen Sie Severity **und** Confidence mit SourceModule, Evidence, `EvidenceLimit`, RecommendedNextCheck und Modulstatus.

## Warum kann das problematisch sein?

HIGH/HIGH ist starke priorisierte Evidenz. HIGH/LOW verlangt dringende Verifikation, ist aber noch keine bestätigte Ursache.

## Wann ist es kein Problem?

Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Leeres Findingsresultset plus Integritätsmodul `PERMISSION_DENIED` ist keine Entwarnung. Ein HIGH/HIGH-Suspect-Page-Finding verlangt sofortige Detailprüfung im SourceModule.

**Ähnlich aussehender Gegenfall:** Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DiagnosticFindings` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Sechs Children sind an: Integritäts-, Kapazitäts-, reduzierte Buffer-Pool-, Backupketten-, Availability- und Agent-Evidenz. Die Procedure liest deren JSON-Verträge und erzeugt daraus normalisierte Findings; Schema, Histogramme, IQP und Contention bleiben aus. |
| Teuerster Pfad | Breiter Datenbankscope plus alle vier Opt-ins. Besonders `USP_StatisticsDistributionAnalysis` läuft dann mit `@AnalyseModus = 'VOLL'`; SchemaDesign scannt Datenbankkataloge, und Contention hält für das konfigurierte Sample eine Session. |
| Haupttreiber | Zahl der Datenbanken, Dateien, Backup-/Restorehistorienzeilen und HA-/Agentobjekte sowie bei Opt-in die Anzahl von Schemaobjekten und Statistik-Histogrammen. Das abschließende Mapping der JSON-Evidenz ist meist kleiner als die Childerhebung. |
| Skalierung | Children laufen sequenziell und erzeugen jeweils JSON. Ohne `@ParentIntegrityJson`, `@ParentCapacityJson` und `@ParentBufferPoolJson` werden diese Quellen frisch gelesen; ein übergeordneter Orchestrator kann genau diese drei Ergebnisse wiederverwenden und Doppelarbeit vermeiden. |
| Ressourcen | Datenbank-/Server-DMVs, Kataloge und `msdb`-Historie; optional Histogrammzugriff, TempDB/JSON und ein Contention-WAITFOR. Es gibt in diesem Aggregator keinen Ereignisdatei- oder Plan-XML-Pfad. |
| Begrenzungswirkung | `@MaxZeilen` begrenzt das finale Findingresultset und wird an Children weitergereicht. Es ist kein gemeinsames Quellbudget: Backup- oder Katalogaggregation kann vor dem Childlimit stattfinden, und die VOLL-Histogrammauswahl hat eigene Kandidatenregeln. `@NurAbPrioritaet` filtert Findings erst nach der Erhebung. |
| Locking und Nebenwirkungen | Read-only. Childaufrufe sind nicht atomar; Backup-, HA- oder Agentzustände können zwischen ihnen wechseln. Nur das optionale Contention-Sample verlängert den Aufruf per WAITFOR, ohne absichtlich Nutzdatenlocks zu halten. |
| Schutzmechanismus | `@HighImpactConfirmed` wird an datenbankweite und tiefe Children weitergereicht. Schema-, Statistikverteilungs- und IQP-Pfade bleiben zusätzlich standardmäßig deaktiviert. Freigabe, Childschalter und Mengen-/Zeitrahmen sind drei getrennte Schutzebenen. |
| Sicherer Einsatz | Eine Datenbank, `@MaxZeilen = 100`, die vier Deep-Schalter aus und vollständigen Childstatus lesen. Danach nur das Finding mit hoher Priorität im zuständigen Fachmodul reproduzieren. |
| Aussagegrenze | Ein Finding ist aus normalisierten Childfeldern abgeleitete Triage, keine Root-Cause-Feststellung. Wiederverwendete Parent-JSONs können etwas älter als frisch gelesene Children sein; Limits oder ein fehlgeschlagenes Child können Findingkategorien ganz entfernen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?

### Technischer Hintergrund

Aggregator ruft Children über definierte JSON-/RAW-Verträge auf und normalisiert Category, Severity, Confidence, Scope, Evidence, EvidenceLimit und Next Check. Innerhalb von `USP_ServerHealthAnalysis` werden bereits kontextgleich erhobene Integritäts-, Kapazitäts- und Buffer-Pool-Ergebnisse wiederverwendet; `InvocationStatus=REUSED_PARENT_RESULT` macht dies sichtbar. Ein direkter Aufruf ohne Parent-Ergebnis liest die aktivierten Quellen frisch.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure ruft die ausgewählten Diagnosemodule auf, übernimmt deren strukturierte Ergebnisse und normalisiert sie zu Findings. Direkte Quellen liegen unter anderem in `USP_DatabaseIntegrityAnalysis`, `USP_DatabaseCapacityAnalysis`, `USP_BufferPoolAnalysis`, `USP_BackupChainAnalysis`, `USP_AvailabilityDeepAnalysis`, `USP_AgentMonitoringAnalysis`, `USP_SchemaDesignAnalysis`, `USP_StatisticsDistributionAnalysis`, `USP_IntelligentQueryProcessingAnalysis` und `USP_InternalContentionAnalysis`.

**Wichtig für die Eigenlast:** Aktivieren Sie nur benötigte Finding-Gruppen und reichen Sie den Datenbankscope früh weiter. Das spätere `@MaxZeilen` begrenzt die Findingausgabe, nicht automatisch die Quellarbeit jedes Childmoduls.

### Zeit- und Scope-Modell

Die Auswertung kombiniert Child-Snapshots, Samples und Historien im selben Lauf. Die Wiederverwendung gilt nur innerhalb desselben Parent-Laufs; es gibt keinen sitzungs- oder aufrufübergreifenden Cache.

### Bewertung und Gegenprobe

Lesen Sie Severity und Confidence gemeinsam, verfolgen Sie SourceModule und Scope zum Detail zurück und blenden Sie `EvidenceLimit` nicht aus. Die Kombination HIGH und LOW verlangt eine schnelle Validierung, aber keine automatische Aktion.

### Typische Fehlinterpretation

Keine Findings bedeutet nur dann wenig Auffälliges, wenn alle relevanten Children vollständig erfolgreich waren. Normalisierung kann Details bewusst weglassen.

### Folgeanalyse

Rufen Sie SourceModule direkt mit engem Scope auf.

## Primärquellen

- [sp_server_diagnostics](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-server-diagnostics-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../08_Server_Health.md#17-monitorusp_diagnosticfindings)
