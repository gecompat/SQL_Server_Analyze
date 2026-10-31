# [monitor].[USP_DatabaseIntegrityAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Korrelierte Integritätsindikatoren aus Datenbankstatus, suspect pages, Backupmetadaten und HADR mit ausdrücklich unbekannter CHECKDB-Zeit.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche sichtbaren Metadaten weisen auf suspect pages, beschädigte Backups oder offene HADR-Seitenreparatur hin und welche Integritätsevidenz bleibt unbekannt?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPageDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

Für vollständige serverweite Evidenz ist auf SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE` erforderlich. Fehlt dieses Recht, bleibt zulässige Teilevidenz sichtbar, der Status lautet jedoch ausdrücklich `AVAILABLE_LIMITED` mit `IsPartial=1`.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: &#124; trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze. |
| `@HighImpactConfirmed` | `bit` | `0` | Bit-Bestätigung der fest verdrahteten Analyseklasse; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy. |
| `@CheckdbWarnHours` | `int` | `168` | Ganzzahl Stunden, zulässig ab 1; ausgelassen = 168. NULL wird von &lt; 1 nicht zurückgewiesen. Im aktuellen Pfad wird der Wert nur validiert: LastGoodCheckDbTime und CheckdbAgeHours bleiben NULL, ein CHECKDB-Alter wird nicht damit verglichen. |
| `@BackupHistoryDays` | `int` | `35` | Ganzzahl Tage, 1 bis 3650; ausgelassen = 35. NULL wird nicht ausdrücklich zurückgewiesen. Begrenzt nur Backupmetadaten mit backup_finish_date &gt;= DATEADD(DAY,-@BackupHistoryDays,GETDATE()); Basis ist lokale Serverzeit via GETDATE(), nicht UTC. DATEADD setzt einen Kalenderzeitpunkt, keine garantierte Anzahl verstrichener 24-Stunden-Intervalle. Bei NULL wird der DATEADD-Stichtag NULL; der Vergleich backup_finish_date &gt;= NULL trifft auf keine Backupzeile zu. Dies belegt keinen Erfolg der Backups. |
| `@MitPageDetails` | `bit` | `0` | 0 oder NULL überspringt Seitenauflösung; 1 fordert sie nur bei bisherigem Status AVAILABLE an. sys.dm_db_page_info(...,LIMITED) löst höchstens @MaxZeilen suspect_pages-Zeilen der ausgewählten Kandidaten auf; NULL/0 bei @MaxZeilen bedeutet unbegrenzt. Die begrenzte Kandidatenauswahl ordnet LastUpdateDate DESC, DatabaseId, FileId, PageId. RAW ordnet die Details danach nach LastUpdateDate DESC, DatabaseName, FileId, PageId; JSON ordnet nur nach LastUpdateDate DESC. Ein Auflösungsfehler setzt IsPartial=1. Details erscheinen ausschließlich als RAW-Seitendetailresultset beziehungsweise in JSON.pageDetails bei @JsonErzeugen=1; CONSOLE und TABLE enthalten nur integrity-Zeilen, NONE gibt keine normalen Resultsets aus. Es erfolgt kein DBCC CHECKDB. Numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. |
| `@MaxZeilen` | `int` | `1000` | Ganzzahlig; negative Werte ungültig, NULL/0 wird auf den größten bigint-Wert abgebildet (praktisch unbegrenzt), ausgelassen = 1000. Integritätszeilen nach Quellenaggregation: Findings vor NO_INDICATOR_FOUND, dann DatabaseName und DatabaseId. PageDetails hat zusätzlich ein eigenes TOP-Limit in gleicher Höhe. Keine Vorabbegrenzung der Kandidaten/Quellen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare integrity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel integrity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N'{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, integrity, pageDetails und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten. |
| `@PrintMeldungen` | `bit` | `1` | Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate. |
| `@Hilfe` | `bit` | `0` | Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = bei vorherigem AVAILABLE ohne Teilstatus mindestens eine integrity-Zeile mit FindingCode ungleich NO_INDICATOR_FOUND; dazu zählt CHECKDB_EVIDENCE_UNAVAILABLE. Der aktuelle INSERT-CASE erzeugt NO_INDICATOR_FOUND nicht, daher reicht eine normale nichtleere Integrity-Menge für diesen Status; er bestätigt keinen Schaden; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung. |

```sql
DECLARE @IntegrityJson nvarchar(max)=NULL;
EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';

EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@IntegrityJson OUTPUT;
SELECT @IntegrityJson AS [DatabaseIntegrityAnalysisJson];

CREATE TABLE [#DatabaseIntegrityAnalysis_HelpExample] ([Seed] bit NULL);
DECLARE @Tables nvarchar(max)=N'{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=@Tables;
    DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#DatabaseIntegrityAnalysis_HelpExample') IS NOT NULL DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample];
    THROW;
END CATCH;

EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `integrity`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die 15 Textspalten der lokalen Kandidaten-, Warnungs-, Integritäts- und
Seitendetailtabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.
Der TABLE-Export übernimmt diese Frameworkcollation für seine fünf Textspalten
auch bei abweichender Server- oder `tempdb`-Collation. `@MaxZeilen` begrenzt
die gemeinsame Integritätsausgabe in RAW, TABLE und JSON; die Seitendetails
besitzen weiterhin ihr eigenes Limit. Die Quellenaggregation erfolgt vor
der Ausgabebegrenzung.

`LastGoodCheckDbTime` und `CheckdbAgeHours` bleiben ausdrücklich unbekannt.
Die Procedure liest keine CHECKDB-Historie über `DATABASEPROPERTYEX` zurück
und führt keinen DBCC-Lauf aus. Das Backupzeitfenster begrenzt ausschließlich
Backupmetadaten.

Die optionale Seitenauflösung verwendet `sys.dm_db_page_info` im Modus
`LIMITED`. Dessen Beschreibungsspalten bleiben laut [Microsoft-Dokumentation](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-page-info-transact-sql?view=sql-server-ver17)
`NULL`; dies gilt deshalb auch für `PageTypeDesc`. Numerische Headerfelder
können weiterhin native Objekt-, Index- und Zuordnungsmetadaten liefern.

## Eine Zeile bedeutet

Eine Zeile in `integrity` entspricht einer ausgewählten Datenbank mit aggregierten Indikatoren. Eine Zeile in `pageDetails` entspricht einer verdächtigen Seite mit optional auflösbaren Metadaten; eine Warnungszeile betrifft einen Datenbankkandidaten.

## So lesen

Berücksichtigen Sie Datenbankstatus, PAGE_VERIFY, suspect pages, Backupchecksums und HADR-Reparaturen gemeinsam. Die letzte erfolgreiche Integritätsprüfung bleibt in dieser Procedure unbekannt.

## Warum kann das problematisch sein?

Suspect Pages oder beschädigte Backupevidenz sind konkrete negative Indikatoren möglicher physischer oder inhaltlicher Schäden.

## Wann ist es kein Problem?

Keine negativen Indikatoren beweisen keine Integrität; die Procedure führt keinen vollständigen CHECKDB aus.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `SuspectPageCount=0` heißt nur „Quelle meldet nichts“. `SuspectPageCount=3` ist konkrete negative Evidenz und verlangt Eskalation, CHECKDB-Strategie, Backupkette und Restore-Test.

**Ähnlich aussehender Gegenfall:** Keine negativen Indikatoren beweisen keine Integrität; die Procedure führt keinen vollständigen CHECKDB aus. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DatabaseIntegrityAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Sichtbare Online-Benutzerdatenbanken, 35 Tage Backupmetadaten, suspect pages und HADR-Auto-Page-Repair ohne Seitenauflösung. Kein DBCC-Lauf. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, langer Backup-Lookback, `@MitPageDetails = 1` und unbegrenzte Ausgabe bei vielen suspect/repair-Seiten; jede sichtbare Seite wird gezielt über `sys.dm_db_page_info` aufgelöst. |
| Haupttreiber | Zahl gewählter Datenbanken, Backupmetadaten im Lookback sowie suspect- und HADR-Auto-Page-Repair-Zeilen. `@MitPageDetails = 1` fügt für jede sichtbare Seite einen eigenen `sys.dm_db_page_info`-Aufruf hinzu. |
| Skalierung | Metadatenpfad wächst mit Datenbanken und relevanter msdb-Retention. Der optionale Seitenpfad wächst mit suspect-/repair-Seiten und kann zusätzliche Buffer-/Storage-I/O verursachen. |
| Ressourcen | CPU und Katalog-/msdb-I/O für Status, Backupset und suspect pages; optional gezielte Page-Metadaten-I/O über `sys.dm_db_page_info`; kleine temporäre Evidenztabellen. |
| Begrenzungswirkung | Datenbankscope und `@BackupHistoryDays` begrenzen relevante Quellen. `@MaxZeilen` wirkt auf fertige Evidenz; es schützt nicht sicher vor allen Backupaggregationen oder jedem bereits ausgewählten Seitenprobe. `@MitPageDetails = 0` ist die wichtigste Lastgrenze. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | `HA_DR_CURRENT` verlangt laut Klassenkatalog keine High-Impact-Bestätigung; `@HighImpactConfirmed` schaltet die Seitenauflösung nicht. Diese wird ausschließlich durch `@MitPageDetails` opt-in aktiviert. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Seitenauflösung aus und begrenzter Lookback. Page Details erst für eine kleine bereits sichtbare suspect-/repair-Menge und außerhalb der I/O-Spitze aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + retentionbegrenzte Metadatenhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Metadaten weisen auf suspect pages, beschädigte Backups oder offene HADR-Seitenreparatur hin und welche Integritätsevidenz bleibt unbekannt?

### Technischer Hintergrund

Page Verify CHECKSUM erkennt bestimmte Pageänderungen bei Read; `suspect_pages` speichert erkannte Pageereignisse; DBINFO/Property kann Last Good CHECKDB liefern; Backupsets enthalten checksum/damage flags; HADR Auto Page Repair dokumentiert Reparaturversuche.

### Datenkette

`master.sys.databases`, `msdb.dbo.backupset`, `msdb.dbo.suspect_pages`, `sys.dm_db_page_info`, `sys.dm_hadr_auto_page_repair`.

### Source Select

Der historische Kern verbindet verdächtige Seiten mit Datenbank und optionaler AG-Auto-Repair-Evidenz:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , [sp].[file_id]
    , [sp].[page_id]
    , [sp].[event_type]
    , [sp].[last_update_date]
    , [apr].[page_status]
    , [apr].[modification_time]
FROM [msdb].[dbo].[suspect_pages] AS [sp] WITH (NOLOCK)
JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [sp].[database_id]
LEFT JOIN [sys].[dm_hadr_auto_page_repair] AS [apr] WITH (NOLOCK)
  ON [apr].[database_id] = [sp].[database_id]
 AND [apr].[file_id] = [sp].[file_id]
 AND [apr].[page_id] = [sp].[page_id]
WHERE [d].[name] = N'ExampleDatabase'
  AND [sp].[last_update_date] >= DATEADD(DAY, -30, GETDATE());
```

**Wichtig für die Eigenlast:** Setzen Sie Datenbank und Zeitfenster vor `dm_db_page_info`. Rufen Sie die Seitenmetadaten-DMF nur für die kleine verbleibende Seitenmenge auf; sie ist keine Ersatzprüfung für `DBCC CHECKDB`.

### Zeit- und Scope-Modell

Die Auswertung verbindet historische und aktuelle Metadaten mit unterschiedlicher Retention; sie führt keinen Live-CHECKDB aus.

### Bewertung und Gegenprobe

Priorisieren Sie jede Suspect Page, jedes beschädigte Backup und jede Pending Page Repair hoch. Prüfen Sie Last Good CHECKDB gegen die Policy, die Datenbankgröße und die Backup- und Restorestrategie. Berücksichtigen Sie dabei immer EvidenceLimit.

### Typische Fehlinterpretation

`0` negative Einträge beweist keine Integrität. `RESTORE VERIFYONLY` prüft nicht alle Daten und ersetzt weder CHECKDB noch echten Restore.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Geplanter CHECKDB, Backup Chain, echter Restoretest und Storage-/Errorlog/XE-Korrelation.

## Primärquellen

- [DBCC CHECKDB](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: SQL Server Integrity Check – betriebliche CHECKDB-Praxis](https://ola.hallengren.com/sql-server-integrity-check.html)

[Technische Detailbeschreibung](../08_Server_Health.md#11-monitorusp_databaseintegrityanalysis)
