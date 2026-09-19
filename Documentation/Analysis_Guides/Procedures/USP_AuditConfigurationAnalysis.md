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

`@DatabaseNames` begrenzt die Datenbankspezifikationen auf eine bracket-aware Pipe-Liste. Ohne Datenbankfilter werden sichtbare Online-Benutzerdatenbanken ausgewählt. `@AuditNames` begrenzt die Server- und Datenbankspezifikationen auf sichtbare Auditnamen. `@NurProblematisch = 1` unterdrückt Zeilen mit `INFO`-Priorität.

## Resultsets und Leserichtung

`RAW` liefert zunächst den Modulstatus und danach `audits`, `serverSpecifications`, `databaseSpecifications`, `sourceStatus` und `warnings`. `TABLE` schreibt ausschließlich die in `@ResultTablesJson` benannten Resultsets. JSON verwendet dieselben benannten Arrays. `CONSOLE` zeigt die interaktive Zusammenfassung; bei keiner sichtbaren Auditkonfiguration erscheint eine verständliche Leerzeile.

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
  ON [r].[audit_id] = [a].[audit_guid];
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

Ein kontrollierter Laufzeitnachweis für eine Leerinventur mit einem nicht vorhandenen Auditnamen liegt vor. Nachweise für deaktivierte, partielle und verweigerte Quellen sowie für Runtimezustände stehen für diesen Slice noch aus. Der Produktstatus ist deshalb `PARTIAL_PRODUCT_FUNCTION`.

## Primärquellen

- [SQL Server Audit](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine?view=sql-server-ver17)
- [sys.server_audits](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-audits-transact-sql?view=sql-server-ver17)
- [sys.dm_server_audit_status](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-server-audit-status-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#audit-configuration-analysis)
