# [monitor].[USP_AuditConfigurationAnalysis]

**Bereich:** Security<br>
**Zweck:** Inventarisiert sichtbare SQL-Audits, Server- und Datenbank-Auditspezifikationen sowie den verfügbaren Runtimezustand.<br>
**Beobachtungsart:** Katalog- und Runtime-Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Frage, welche SQL-Audits und Auditspezifikationen im sichtbaren Scope konfiguriert, aktiviert oder mit einem auffälligen Runtimezustand gemeldet sind. Sie dient der Konfigurationsprüfung und ersetzt weder eine Auswertung der Auditereignisse noch ein Berechtigungs- oder Compliance-Audit.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AuditConfigurationAnalysis]
      @ResultSetArt = 'CONSOLE';
```

`@DatabaseNames` begrenzt lokale Spezifikationen auf exakte Datenbanknamen; alternativ filtert `@DatabaseNamePattern`. Systemdatenbanken werden nur mit `@SystemdatenbankenEinbeziehen = 1` einbezogen. `@AuditNames` filtert Audits und beide Spezifikationsscopes nach exakten Namen. `@AuditNamePattern` filtert ausschließlich `audits` mit LIKE; Spezifikationen werden dadurch nicht eingeschränkt. Eine aktive, nichtleere Datenbankliste ist mit einem Datenbankpattern unvereinbar; bei Auditnamen sind bereits zwei nicht-NULL-Filter unvereinbar. Regex wird für Auditnamen zurückgewiesen. `@NurProblematisch = 1` und `NULL` entfernen INFO aus den drei Fachresultaten.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Filter für lokale Spezifikationen. NULL, Leertext oder nur U+0020-Leerzeichen: sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Datenbanksnapshots; Systemdatenbanken nur mit Opt-in. Sonst bracket-aware Pipe-Liste exakter SQL-Namen; Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere/ungültige Segmente oder Namen sind ungültig. Nur eine aktive, nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Fehlende, offline oder nicht zugängliche Namen erzeugen interne Kandidatenwarnungen, die diese Procedure nicht ausgibt und nicht allein in ihre Partialitätsbewertung übernimmt. Eine leere Spezifikationsmenge belegt deshalb keine vollständige Auswahl. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER. Explizit angeforderte Systemdatenbanken ohne Opt-in erzeugen intern SYSTEM_DATABASE_EXCLUDED; diese Auswahlwarnung wird nicht ausgegeben. Weitergabe an den Kandidatenhelper. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Alternativer Datenbankfilter, unvereinbar mit einer aktiven nichtleeren Datenbankliste. NULL: kein Pattern. Helper trimmt außen; erkennt LIKE:, REGEX:, REGEXI: ohne Beachtung der Großschreibung, sonst LIKE. Rest wird nicht erneut getrimmt. REGEX arbeitet case-sensitiv (Flag c), REGEXI ohne Beachtung der Groß-/Kleinschreibung (Flag i); leerer Rest ungültig. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorab geprüft. Eine fehlerhafte Regex kann bei REGEXP_LIKE im Kandidatenhelper einen nicht abgefangenen Fehler auslösen und den normalen Modulabschluss umgehen. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 und 1 sind gültige Bestätigungswerte, werden in diesem Aufruf aber keinem Analyseklassen-/Gruppengate vorgelegt: AnalysisClass ist fest NULL. Beide Werte aktivieren dasselbe lesende Inventar. NULL ist im Kandidatenhelper ungültig und setzt INVALID_PARAMETER; der Wert ist keine Berechtigungserteilung. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@AuditNames` | `nvarchar(max)` | `NULL` | Exakte Auditnamen für audits und beide Spezifikationsscopes als bracket-aware Pipe-Liste; NULL: kein Filter. Pipes in [Klammern] trennen nicht, ]] maskiert ]. Leere Segmente und ungültige SQL-Namen sind ungültig; gültige Werte werden dedupliziert. Exklusiv mit @AuditNamePattern. Vergleich ist SQL_Latin1_General_CP1_CS_AS (case-sensitive); kein Treffer erzeugt keinen eigenen Fehlerstatus. |
| `@AuditNamePattern` | `nvarchar(4000)` | `NULL` | Alternativer Auditnamenfilter mit LIKE, exklusiv mit @AuditNames. NULL: kein Filter. Parser trimmt außen, entfernt optional LIKE: ohne Groß-/Kleinschreibung und trimmt danach nicht erneut. REGEX:/REGEXI: werden erkannt, aber von dieser Procedure als INVALID_PARAMETER zurückgewiesen. Leerwert/Leerrest ungültig. Vergleich case-sensitive. Dieses Pattern begrenzt ausschließlich audits; serverSpecifications und databaseSpecifications werden dadurch nicht gefiltert. Für einen Namensfilter in allen drei Fachmengen ist stattdessen @AuditNames zu verwenden. |
| `@NurProblematisch` | `bit` | `0` | 0 lässt INFO und MEDIUM in den drei Fachresultaten zu. 1 entfernt INFO; NULL entfernt INFO ebenfalls und wirkt wie 1. Quellenstatus und Warnings bleiben ungefiltert; Warnings entstehen vor diesem INFO-Filter. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@MaxZeilen` | `int` | `1000` | Obergrenze je Fachresultat einzeln. Reihenfolge: AuditName/AuditId, SpecificationName/SpecificationId, DatabaseName/SpecificationName/DatabaseId/SpecificationId. NULL oder 0 unbegrenzt; negative Werte INVALID_PARAMETER. Quellenstatus, Warnings und Statusresultat bleiben ungekürzt. |
| `@LockTimeoutMs` | `int` | `0` | Wird nur auf negative Werte geprüft; im Body aber nicht zum Setzen eines Timeouts genutzt. NULL besteht den Negativtest und wird nicht angewendet. Die Procedure setzt danach LOCK_TIMEOUT 0; SET-Werte werden bei Rückkehr aus der Procedure zurückgenommen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Entfernen äußerer U+0020-Leerzeichen und Großschreibung sind genau RAW, CONSOLE, TABLE und NONE erlaubt. RAW liefert Modulstatus und danach audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. CONSOLE wird intern auf NONE normalisiert und zeigt ausschließlich die beschriftete audits-Ansicht, ohne separates Modulstatusresultset. TABLE schreibt nur zugeordnete Gruppen, NONE liefert keine regulären Resultsets. JSON wird unabhängig gesteuert. NULL, Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE; gültiges JSON-Objekt mit mindestens einer Zuordnung aus exakt audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings zu einem Ziel. Keys binär exakt, keine doppelten Keys/Ziele. Ziel: vorhandene leere lokale #Temp mit genau einer Seed-Spalte, max. 116 Zeichen, kein ##- oder reserviertes #Monitor-Präfix. Mapping wird vor fachlichem Zugriff validiert; Bei einem ungültigen Ziel kann der Helper mit Fehler 51011 abbrechen; dann ist die abschließende Zuweisung der Modul-OUTPUTs nicht garantiert. audits bedeutet Auditkonfigurationen, serverSpecifications Serverspezifikationen, databaseSpecifications Datenbankspezifikationen, sourceStatus Quellenstatus und warnings Warnungen. In TABLE sind NULL, Leertext und ein leeres Objekt ungültig. Außerhalb von TABLE bleiben NULL, Leertext und nur U+0020-Leerzeichen unbeachtet; ein anderer nichtleerer Wert kann vor der Analyse Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erstellt JSON in @Json; 0 oder NULL erzeugt keines. Unabhängig von Resultsetart; für JSON ohne Resultsets NONE verwenden. Dokument enthält meta und fünf Arrays audits, serverSpecifications, databaseSpecifications, sourceStatus, warnings. meta: resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, crossDatabaseRequested. Facharrays wenden Filter und Limit an; Status/Warnungen bleiben vollständig. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Empfänger. Zu Beginn NULL; bei JsonErzeugen=1 Dokument, sonst NULL. OUTPUT-Variable nvarchar(max) mit OUTPUT im EXEC binden. Hilfe kehrt vorher zurück und lässt den Wert NULL. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll. |
| `@PrintMeldungen` | `bit` | `1` | Der Parameter wird im Procedure-Body nicht gelesen und beeinflusst weder PRINT-Meldungen noch Resultsets. Der Hilfezweig gibt seine PRINT-Zeilen unabhängig von diesem Eingabewert aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 1 gibt PRINT-Hilfe aus und kehrt ohne Analyse und abschließende OUTPUT-Zuweisung zurück. Die Hilfe erklärt Zweck, Parameterverträge und Beispielaufrufe. 0 führt aus; NULL löst Früh-Rückkehr nicht aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Bei regulärem Abschluss: AVAILABLE ohne gemeldeten Befund, AVAILABLE_WITH_FINDING bei MEDIUM-Warnungen ohne Partialität, AVAILABLE_LIMITED bei partiellen Quellen, INVALID_PARAMETER bei ungültigen Modul-/Kandidatenparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlender Regex-Voraussetzung. Behandelte Quellenfehler stehen in Quellenstatus/Warnungen; Partialität setzt AVAILABLE_LIMITED. Zuweisung erfolgt am normalen Ende. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT-Bit der Partialität: 0 ohne partielle Quellenlesung, 1 bei behandelten unvollständigen Lesungen. Normale Endzuweisung; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. Interne Kandidatenwarnungen über fehlende oder ausgeschlossene Namen werden hierbei nicht ausgewertet; 0 belegt keine vollständige Datenbanksicht. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT int der zuerst gespeicherten behandelten Serverquellen-Fehlernummer. Zweiter Server-CATCH setzt nur bei noch NULL. Datenbank-CATCHes setzen Partialität und schreiben interne, nicht ausgegebene Warnungen, aber keine Modulnummer. Parameterfehler haben keine Fehlernummer; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT nvarchar(2048) zur zuerst gespeicherten Serverquellenstörung; spätere Serverfehler überschreiben sie nicht. Datenbankfehler setzen Partialität und schreiben interne, nicht ausgegebene Warnungen statt einer Modulmeldung. Ungültige Parameter liefern Validierungstext; Hilfe weist nicht zu. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Im Hilfezweig bleibt ein anfänglicher NULL- oder anderer Empfängerwert erhalten. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON-Ausgabe

```sql
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#AuditConfigurationAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"audits":"#AuditConfigurationAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_AuditConfigurationAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#AuditConfigurationAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#AuditConfigurationAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_AuditConfigurationAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

`RAW` liefert Status, danach `audits`, `serverSpecifications`, `databaseSpecifications`, `sourceStatus` und `warnings`. `TABLE` schreibt benannte Resultate in vorhandene, leere lokale #Temp-Ziele mit je einer Seed-Spalte. JSON enthält dieselben Arrays und `meta`; `@JsonErzeugen = 1` erstellt es, `@ResultSetArt = 'NONE'` unterdrückt Resultsets. `CONSOLE` zeigt ausschließlich die beschriftete Auditansicht, ohne eigenes Statusresultset; ein leerer Auditbestand erhält eine verständliche Leerzeile.

Die bisher nicht collatierten 32 Textspalten der lokalen Zuordnungs-, Kandidaten-, Ergebnis- und
Statustabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Die fünf
TABLE-Exporte übernehmen diese Frameworkcollation auch bei abweichender
Server- oder `tempdb`-Collation. `SpecificationId` ist in beiden
Spezifikationsresultsets ein `int`; `AuditId` bleibt ein `uniqueidentifier`.

Die drei Fachresultate in RAW, TABLE und JSON wenden `@NurProblematisch` und `@MaxZeilen` je Resultat an. `sourceStatus` und `warnings` bleiben ungefiltert und ungekürzt und beziehen sich auf die erfasste Konfiguration vor dem INFO-Filter.

Lesen Sie zuerst `sourceStatus` und `warnings`. Ein deaktiviertes Audit oder eine deaktivierte Spezifikation ist ein Reviewhinweis, aber kein Nachweis für eine fehlerhafte fachliche Vorgabe. Ein fehlender Runtimezustand kann durch Berechtigungen, Metadatensichtbarkeit oder einen nicht verfügbaren DMV-Zugriff bedingt sein.

## Eine Zeile bedeutet

Eine Zeile in `audits` entspricht einem sichtbaren Serveraudit. Eine Zeile in den Spezifikationsresultsets entspricht einer sichtbaren Server- oder Datenbankspezifikation; `ActionCount` ist eine aggregierte Anzahl und enthält keine Aktions- oder Ereignispayload.

## So lesen

Prüfen Sie Aktivierungszustand, Runtimezustand, Quellenstatus und Evidenzgrenze gemeinsam. `AUDIT_DISABLED`, `*_SPECIFICATION_DISABLED` und `*_WITHOUT_ACTION` sind prüfbare Konfigurationshinweise, keine automatische Compliance-Bewertung.

## Warum kann das problematisch sein?

Ein deaktiviertes Audit oder eine Spezifikation ohne sichtbare Aktionen kann von einer vorgesehenen Nachweisstrategie abweichen. Ein nicht gestarteter Runtimezustand kann die erwartete Erfassung beeinträchtigen, wenn das Audit nach der fachlichen Vorgabe aktiv sein soll.

## Wann ist es kein Problem?

Ein Audit kann absichtlich deaktiviert sein, beispielsweise während einer geplanten Umstellung oder weil eine andere Instanz- oder Datenbankspezifikation den benötigten Scope abdeckt. Die Procedure kennt die fachliche Sollvorgabe nicht und bewertet diesen Kontext nicht selbst.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbare SQL-Auditkonfiguration ist aktiviert, welche Spezifikationen verweisen auf sie und welcher Runtimezustand ist verfügbar?

### Technischer Hintergrund

Ein SQL Server Audit ist ein Serverobjekt mit einem Ziel und kann durch Server- oder Datenbankspezifikationen mit Auditaktionen verbunden sein. Der Runtime-DMV liefert nur einen momentanen Status. Die Auswertung trennt diese Konfigurations- und Runtimeebenen von Auditereignissen.

### Datenkette

`sys.server_audits` und `sys.dm_server_audit_status` liefern die Auditkonfiguration und den sichtbaren Runtimezustand. Die Server- und Datenbankspezifikationskataloge ergänzen Namen, Aktivierungszustand und aggregierte Aktionsanzahlen.

### Source Select

```sql
SELECT
      [a].[name]
    , [a].[type_desc]
    , [a].[is_state_enabled]
    , [r].[status_desc]
FROM [sys].[server_audits] AS [a] WITH (NOLOCK)
LEFT JOIN [sys].[dm_server_audit_status] AS [r] WITH (NOLOCK)
  ON [r].[audit_id] = [a].[audit_id];
```

Der Select liest keine Auditdatei, keinen Zielpfad und keine Auditereignisse.

**Wichtig für die Eigenlast:** Die Abfrage liest kleine Katalog- und Runtime-Metadaten. Datenbankspezifikationen werden je ausgewählter Online-Datenbank isoliert und ohne Auditdatei- oder Ereigniszugriff gelesen.

### Zeit- und Scope-Modell

Die Ausgabe ist ein Snapshot zum Aufrufzeitpunkt. Der Serverteil umfasst sichtbare Serveraudits und Serverspezifikationen; Datenbankspezifikationen werden nur für die ausgewählten sichtbaren Online-Datenbanken gelesen.

### Bewertung und Gegenprobe

Vergleichen Sie einen Hinweis mit der freigegebenen Auditpolicy, dem verantwortlichen Owner und dem vorgesehenen Zielbetrieb. Eine erforderliche Ereignis- oder Aufbewahrungsprüfung muss in einem getrennt autorisierten Nachweis erfolgen.

### Typische Fehlinterpretation

Eine leere Ausgabe beweist nicht, dass keine Auditkonfiguration existiert. Ein gestarteter Runtimezustand beweist nicht, dass die fachlich erwarteten Ereignisse erfasst, zugestellt oder aufbewahrt werden.

### Folgeanalyse

Stimmen Sie auffällige Konfigurationen mit dem Security- oder Complianceprozess ab. Auditpayloads und Zielinhalte sind kein Bestandteil dieser Procedure.

## Datenquellen, Datenschutz und Nebenwirkungen

Die Procedure liest `sys.server_audits`, die Server- und Datenbank-Auditspezifikationen samt deren Detailkatalogen sowie, soweit sichtbar, `sys.dm_server_audit_status`. Sie gibt nur Konfigurationsmetadaten, aggregierte Aktionsanzahlen und Scopehinweise aus. Auditdateien, Dateipfade, Auditlog-Payloads, Ereignisinhalte und überwachte Nutzdaten werden weder gelesen noch ausgegeben.

Die Procedure ist read-only. Sie erstellt, startet, stoppt, ändert und löscht keine Auditobjekte.

## Grenzen und Gegenprüfung

Eine sichtbare Konfiguration beweist weder die Vollständigkeit der Auditabdeckung noch die Zustellung, Aufbewahrung oder Auswertbarkeit von Auditereignissen. Eine nicht sichtbare Zeile beweist nicht, dass ein Audit oder eine Spezifikation fehlt. Prüfen Sie auffällige Befunde mit dem verantwortlichen Security- oder Complianceprozess und, falls autorisiert, getrennt mit den zugelassenen Auditbetriebsnachweisen.

Kontrollierte Laufzeitnachweise für eine Leerinventur mit einem nicht vorhandenen Auditnamen, für verweigerte Servermetadaten, für eine deaktivierte Auditkonfiguration und für einen aktiven Runtimezustand liegen vor. Der Produktstatus ist `IMPLEMENTED_ACTIONS_GATE`.

## Primärquellen

- [SQL Server Audit](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine?view=sql-server-ver17)
- [sys.server_audits](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-audits-transact-sql?view=sql-server-ver17)
- [sys.dm_server_audit_status](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-server-audit-status-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#audit-configuration-analysis)
