# Common: Navigation, Zugriff, Capabilities und Auswahlverträge

**Procedures:** 5
**Primäre Kostenklasse:** LOW bis MEDIUM

## 1. [monitor].[USP_AnalysisNavigator]

### Zweck

Der Analysis Navigator findet geeignete öffentliche Procedures nach Symptom, Ziel, technischem Begriff, Themenbereich, Scope oder Navigationsrolle. Er verbindet drei statische Metadatenebenen:

- `VW_AnalysisCatalog`: genau eine fachliche Hauptzeile je öffentlicher Procedure,
- `VW_AnalysisSearchTerm`: deutsche und englische Suchbegriffe mit Gewicht und Begründung,
- `VW_AnalysisRelation`: gerichtete Vertiefungs-, Gegenproben-, Alternativ- und Vorbereitungspfade.

Die Procedure führt keinen Treffer aus. Sie liest nur Frameworkmetadaten und `sys.schemas`/`sys.procedures` zur lokalen Installationsprüfung.

### Wann einsetzen?

- als ersten Kontakt mit dem Framework,
- wenn nur ein Symptom wie Blocking, CPU, TempDB, Log, I/O, Deadlock oder AG-Lag bekannt ist,
- wenn eine Procedure nach Rolle, Scope oder Fachbereich gesucht wird,
- um sichere Erstaufrufe, Kostenband, Paketstatus und Folgeanalysen zu vergleichen,
- um optionale, lokal noch nicht installierte Paketfunktionen vollständig zu sehen.

### Wann nicht einsetzen?

- nicht zur Diagnose eines aktuellen Serverzustands,
- nicht als Capability- oder Berechtigungsnachweis,
- nicht als automatische Ausführungskette,
- nicht als Schwere- oder Root-Cause-Scoring.

### Aufrufe

```sql
EXEC [monitor].[USP_AnalysisNavigator];
```

```sql
EXEC [monitor].[USP_AnalysisNavigator]
      @Suchbegriff = N'Query plötzlich langsamer',
      @MaxZeilen = 8,
      @ResultSetArt = 'CONSOLE';
```

```sql
EXEC [monitor].[USP_AnalysisNavigator]
      @Bereich = 'PLAN',
      @Navigationsrolle = 'TARGETED',
      @NurInstallierte = 1,
      @ResultSetArt = 'RAW';
```

### RAW-Resultsets

#### Resultset 1: Modulstatus

`StatusCode`, `IsPartial`, Fehlerkontext und die normalisierten Such-, Bereichs-, Scope- und Rollenfilter. `NO_MATCH` ist eine gültige leere Suche; `INVALID_PARAMETER` kennzeichnet einen fehlerhaften Filtervertrag.

#### Resultset 2: navigation

| Spaltengruppe | Bedeutung |
|---|---|
| `Rank`, `RelevanceScore` | Rang in diesem Aufruf; keine fachliche Schwere |
| `ProcedureName`, `DisplayName`, `WhyMatched` | technischer Name, verständlicher Name und Treffergrund |
| `NavigationRole`, `PrimaryAreaCode`, `ScopeCode` | Einstiegstyp und benötigter Untersuchungsscope |
| `EvidenceType`, `CostRangeCode` | Zeit-/Quellenmodell und dokumentierte Kostenspannweite |
| `RepresentativeAnalysisClass`, `AnalysisLevel`, `RequiresGroupGate` | repräsentativer Ressourcen- und Policykontext |
| `RequiresKnownTarget`, `RequiresHighImpactForSafeStart`, `HighImpactPathAvailable` | Ziel- und Schutzanforderungen |
| `PackageCode`, `IsInstalled` | Paketgrenze und lokale Existenz |
| `SafeCall`, `PrerequisiteSummary` | begrenzter Einstieg und vorher zu prüfende Voraussetzung |
| `NextProcedureName`, `RelationType`, `NextStep` | priorisierte Vertiefung oder unabhängige Gegenprobe |
| `RunbookPath`, `DocumentationPath` | vertiefende Dokumentation |

### Suchsemantik

Der Vergleich ist unabhängig von der Datenbankcollation case- und accent-insensitiv. Exakte Procedure-, Anzeigenamen- und Phrasentreffer stehen vor Tokenüberschneidungen. `ENTRY` erhält nur einen kleinen Bonus und verdrängt keinen deutlich besseren Targettreffer. Ohne Suchtext und Filter erscheint die kuratierte Startliste; mit Filtern die passende Katalogmenge.

### Kosten und Grenzen

LOW. Die Kataloge sind konstant, die Ergebnismenge ist auf 100 Zeilen begrenzt. `IsInstalled` beweist keine Quellberechtigung oder Featureaktivierung. `SafeCall` muss an den realen Scope angepasst werden. Der vollständige Vertrag steht unter [Analysis Navigator](../Reference/Analysis_Navigator.md).

---

## 2. [monitor].[USP_CheckAnalyseAccess]

### Zweck

Die Procedure prüft den Framework-Gruppengate für Analyseklassen im aktuellen Login- und Execution-Kontext. Sie führt keine Fachanalyse aus und vergibt keine SQL-Rechte. Die Momentaufnahme verwendet Katalog, aktuelle Framework-Views, sys.login_token, IS_MEMBER und SYSUTCDATETIME(); sie ist kein Live-AD- oder Objektberechtigungsnachweis.

### Wann einsetzen?

- vor einer ressourcenintensiven Cross-Database-, Plan-, Histogramm- oder Tiefenanalyse,
- wenn eine Procedure DENIED_GROUP meldet,
- zur Prüfung der für den aktuellen Login sichtbaren Analyseklassen.

### Aufrufe und Parameterhilfe

CONSOLE ist die Standardausgabe. Die vollständige Parameterhilfe erscheint mit @Hilfe=1 unabhängig von @PrintMeldungen; @Json wird vorher zurückgesetzt. TABLE-Preflight liegt vor der Hilfe und kann lokale TempDB-Metadaten per DDL ändern oder bei ungültiger Zuordnung abbrechen.

| Parameter | Typ und Standard | Wirkung |
|---|---|---|
| @AnalyseKlasse | varchar(64), NULL | NULL wählt alle Klassen; sonst vorhandener Katalogcode exakt und case-sensitiv. Leer oder unbekannt ergibt INVALID_PARAMETER. |
| @NurGesperrte | bit, 0 | 1 oder NULL filtert nur Accesszeilen auf IsAllowed=0; Policies bleiben ungefiltert. |
| @ResultSetArt | varchar(16), CONSOLE | CONSOLE, RAW, TABLE oder NONE; case-insensitiv mit getrimmten äußeren Leerzeichen. NULL/ungültig ergibt INVALID_PARAMETER. |
| @ResultTablesJson | nvarchar(max), NULL | Für TABLE JSON-Objekt access auf ein vorhandenes, leeres lokales #temp-Ziel mit genau einer Seed-Spalte bit NULL abbilden. Außerhalb TABLE führt eine nichtleere Zuordnung zu THROW 51011. |
| @JsonErzeugen | bit, 0 | 1 erzeugt JSON; NULL aktiviert es nicht. |
| @Json | nvarchar(max), NULL OUTPUT | Ausgabeparameter; wird zu Beginn auf NULL gesetzt. JSON enthält meta und die arrays access, policies, warnings. |
| @PrintMeldungen | bit, 1 | Steuert nur die zusätzliche Severity-10-Meldung für behandelte Fehler. NULL/0 deaktiviert sie, nicht Hilfe, Resultsets oder JSON. |
| @Hilfe | bit, 0 | 1 gibt Hilfe aus und beendet die fachliche Auswertung; NULL aktiviert sie nicht. |

CONSOLE rendert Access und zeigt bei leerer Accessmenge „Keine fachlichen Ergebnisse“. RAW liefert Meta, Access, Policies und Warnings als vier Resultsets. TABLE schreibt ausschließlich access mit zwölf typisierten Feldern. NONE liefert keine fachlichen Resultsets; Meldungen und JSON bleiben unabhängig.

~~~sql
-- Hilfe
EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;
-- Standard
EXEC [monitor].[USP_CheckAnalyseAccess];
-- Scope und RAW
EXEC [monitor].[USP_CheckAnalyseAccess] @AnalyseKlasse='PLAN_CACHE_DEEP', @ResultSetArt='RAW';
-- Nur gesperrte Klassen
EXEC [monitor].[USP_CheckAnalyseAccess] @NurGesperrte=1, @ResultSetArt='RAW';
-- JSON
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckAnalyseAccess] @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
-- Keine fachlichen Resultsets
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='NONE', @JsonErzeugen=1;
-- TABLE
CREATE TABLE #Access_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"access":"#Access_HelpExample"}';
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #Access_HelpExample;
~~~

### RAW-Resultsets

Erstes Resultset: Meta mit ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber und ErrorMessage. Das zweite Resultset enthält Access mit zwölf Feldern: AnalysisClass, AnalysisLevel, RequiresGroupGate, OriginalLoginName, EffectiveLoginName, IsSysadmin, ActivePolicyCount, RelevantPolicyCount, IsAllowed, AccessReason, MatchedGroupCount und StatusCode. Das dritte enthält Policies, das vierte Warnings.

### Bewertung

Die Fallauswahl lautet ungeschützte Klasse, sysadmin, keine global aktive Policy, Treffer über Login-Token, IS_MEMBER-Treffer, sonst NO_MATCH. Die AccessReason-Werte dazu sind NOT_REQUIRED, SYSADMIN, OPEN_POLICY, LOGIN_TOKEN, IS_MEMBER und NO_MATCH. Ohne global aktive Policy ist der Gate offen. Gibt es mindestens eine global aktive Policy, kann eine geschützte Klasse ohne spezifische oder '*' Regel gesperrt sein. RelevantPolicyCount=0 allein bedeutet dann keine offene Freigabe.

Aktive Policyzeilen sind aktiviert, innerhalb ihres UTC-Gültigkeitsfensters und haben nichtleere getrimmte Klassen- und Gruppennamen. Priority wird ausgegeben und sortiert, steuert aber keine Auswahl oder Freigabe. MatchedGroupCount summiert Gruppen-Treffer über spezifische und '*' Regeln; dieselbe Gruppe kann mehrfach zählen und die Zahl bezeichnet keine eindeutigen Gruppen.

Accessreason und Policies-JSON verwenden keine identische Filterlogik: Das Policies-Array berücksichtigt Aktivierung, Zeitfenster und Scopeklasse, aber nicht denselben Leernamefilter wie VW_AnalyseAccessCurrent. Arraylänge und ActivePolicyCount sind daher nicht gleichzusetzen.

Keine Accesszeile kann durch @NurGesperrte=1 ohne gesperrte Klasse, ungültige Eingabe oder ERROR_HANDLED entstehen. Leere Ausgabe ist deshalb allein keine Entwarnung. IsPartial ist bei Status ungleich AVAILABLE gesetzt.

~~~sql
-- Partieller Blick auf aktive Policies und Login-Token; kein vollständiger Gate-Nachbau
SELECT [p].[AnalysisClass], [p].[ADGroupName], [lt].[name] AS [MatchedLoginToken]
FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
LEFT JOIN [sys].[login_token] AS [lt] WITH (NOLOCK)
  ON UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
   = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
 AND [lt].[type] = N'WINDOWS GROUP'
WHERE [p].[IsEnabled] = 1
  AND [p].[AnalysisClass] IN ('PLAN_CACHE_DEEP', '*');
~~~

## 3. [monitor].[USP_CheckFrameworkCapabilities]

### Zweck und Einsatz

Die Procedure kombiniert die Framework-Featuredefinitionen mit ausgewählten Datenbankkandidaten und prüft Version, optionale Gruppenfreigabe, Berechtigung, Abfragbarkeit sowie optionalen Enablementzustand. Sie ist eine Momentaufnahme und keine Fachanalyse. Sie vergibt keine Rechte. Ein Probeerfolg oder Metadatenrecht beweist weder vollständige Sichtbarkeit späterer Fachdaten noch externe Gesundheit. Ein Katalogeintrag löst kein Fachmodul aus; die Procedure führt jedoch die im Katalog hinterlegten Probe- und Enablement-SQL-Templates aus. Kosten und Zugriffsumfang sind daher anhand der konkreten Templates zu beurteilen, nicht aus einem TOP (0)-Beispiel abzuleiten.

### Scope und Aufrufe

@DatabaseNames nimmt eine bracket-aware Pipe-Liste exakter Namen an; NULL, leer oder nur Leerzeichen lässt den Kandidatenhelper ohne exakte Einschränkung arbeiten. @DatabaseNamePattern kann stattdessen SQL-LIKE oder regex:/regexi: nutzen. Liste und Pattern sind exklusiv. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. @SystemdatenbankenEinbeziehen steuert die Auswahl von master, tempdb, model und msdb. Explizit angeforderte, aber nicht verfügbare Datenbanken können in Warnings erscheinen.

@AnalyseKlasse=NULL wählt alle Katalogfeatures; ein anderer Wert muss exakt im Klassenkatalog stehen. @MitGruppenpruefung=1 prüft die Access-View pro Feature; 0 oder NULL überspringt den Gruppencheck. @HighImpactConfirmed wird an den Kandidatenhelper übergeben, aber mit Analyseklasse NULL. Daher löst dieser Capability-Aufruf kein High-Impact-Deep-Gate aus. Obwohl `@AnalysisClass=NULL` den optionalen Klassen-Gate auslässt, verwirft der Helper `@HighImpactConfirmed=NULL` bereits in der Grundvalidierung als `INVALID_PARAMETER`.

~~~sql
-- Hilfe und Standard
EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
EXEC [monitor].[USP_CheckFrameworkCapabilities];
-- Scope und RAW
EXEC [monitor].[USP_CheckFrameworkCapabilities] @DatabaseNames=N'[ExampleDb]', @AnalyseKlasse='STANDARD_CURRENT', @ResultSetArt='RAW';
-- JSON ohne fachliche Resultsets
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
-- TABLE exportiert ausschließlich capabilities
CREATE TABLE #Capabilities_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"capabilities":"#Capabilities_HelpExample"}';
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #Capabilities_HelpExample;
~~~

### Ausgabe und Interpretation

RAW liefert vier Resultsets: Meta, Capabilities, Summary und Datenbank-Warnings. CONSOLE übergibt capabilities an den Console-Renderer. TABLE schreibt nur das benannte Resultset capabilities in das vorbereitete lokale Ziel. NONE unterdrückt fachliche Resultsets; JSON und Severity-10-Meldungen sind davon unabhängig. JSON enthält meta, capabilities, summary und warnings; es enthält kein Datenbankstatus-Array. @Json wird zu Beginn auf NULL gesetzt. TABLE-Preflight läuft vor @Hilfe und kann bei ungültigem Ziel abbrechen.

Die Capabilityzeile hat 27 Felder. Die Kette umfasst VersionSupported, GroupAccessAllowed, HasRequiredPermission, IsQueryable, IsFeatureEnabled und IsUsable; je nach Status werden Prüfungen übersprungen oder bleiben NULL. Eine Versionsunterschreitung ergibt UNAVAILABLE_VERSION. Gruppen-Deny ergibt DENIED_GROUP. Ein Probe-Fehler kann DENIED_PERMISSION, DATABASE_UNAVAILABLE, UNAVAILABLE_OBJECT, TIMEOUT oder ERROR_HANDLED ergeben. Ein Permission-Checkfehler setzt HasRequiredPermission auf NULL; danach kann die Probe dennoch ausgeführt werden. PROBE_ONLY kann bei erfolgreicher Probe AVAILABLE_UNVERIFIED melden.

@NurNichtVerfuegbar=1 filtert die ausgegebenen Capabilityzeilen auf IsUsable=0; NULL bewirkt durch das SQL-Prädikat denselben Filter. Die Prüfungen und Summary bleiben vollständig. AVAILABLE_LIMITED wird gesetzt, wenn bei zuvor AVAILABLE mindestens eine geprüfte Capability IsUsable=0 hat. Eine Auswahlwarning setzt den Status nicht allein auf LIMITED.

IsUsable beschreibt das Ergebnis dieser konkreten Katalogprüfungen. Es garantiert keine Berechtigung auf jede spätere Fachzeile, keine Datenvollständigkeit und keine externe oder fachliche Gesundheit. Katalogtemplates werden tatsächlich ausgeführt; eine SQL-Definition mit TOP (0) ist kein empirischer Kosten- oder Sicherheitstest.

### Aufwand und Grenzen

Der Aufwand hängt von ausgewählten SERVER-Features, der Anzahl der Datenbanken und DATABASE-Features sowie den ausgeführten Probe- und Enablementtemplates ab. @AnalyseKlasse und Datenbankscope reduzieren die ausgewählten Kombinationen. @NurNichtVerfuegbar filtert erst nach den Prüfungen und reduziert die Ausführung nicht. Die High-Impact-Bestätigung für eine spätere Fachanalyse gehört zum jeweiligen Fachaufruf.

---

## 4. [monitor].[USP_PrepareDatabaseCandidates]

### Rolle

Die Procedure implementiert den internen technischen Auswahlvertrag. Sie ist nicht als regulärer Analyseendpunkt vorgesehen.

Die Procedure erwartet, dass der Aufrufer lokale Temp-Tabellen mit exakt definiertem Schema anlegt und deren eindeutige Namen über `@CandidateTable` sowie optional `@WarningTable` übergibt. Sie liefert keine Resultsets.

### Befüllte Temp-Tabelle `@CandidateTable`

| Spalte | Bedeutung |
|---|---|
| `DatabaseId` | Datenbank-ID |
| `DatabaseName` | sichtbarer Datenbankname |
| `StateDesc` | Status, typischerweise ONLINE erforderlich |
| `UserAccessDesc` | Zugriffsmodus |
| `IsReadOnly` | Read-only-Status |
| `CompatibilityLevel` | Compatibility Level |
| `CollationName` | Collation |
| `RecoveryModelDesc` | Recovery Model |
| `IsSystemDatabase` | Systemdatenbankkennzeichen |
| `RequestedOrdinal` | Reihenfolge einer expliziten Liste |

Optional wird `@WarningTable(RequestedName, StatusCode, ErrorMessage)` befüllt.

### OUTPUT-Parameter

| Parameter | Bedeutung |
|---|---|
| `@StatusCode` | `AVAILABLE`, `INVALID_PARAMETER`, `DENIED_GROUP`, `UNAVAILABLE_FEATURE` oder interner Fehler |
| `@ErrorMessage` | begrenzte Erklärung |
| `@CrossDatabaseRequested` | 1 bei `NULL` oder mehr als einer expliziten Datenbank |

### Auswahlsemantik

- `@DatabaseNames=N''` oder `NULL`: alle sichtbaren Online-Benutzerdatenbanken.
- Eine nicht leere Liste oder ein Pattern schränkt explizit ein.
- Systemdatenbanken benötigen ein ausdrückliches Opt-in.
- Liste und Pattern sind exklusiv.
- Doppelte Namen werden case-sensitiv abgelehnt.
- Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.
- Cross-Database-Modus kann einem Gruppen-Gate unterliegen.

### Fehlinterpretation

Die Kandidatenmenge wird vollständig ermittelt. Ausdrücklich angeforderte, aber
nicht verfügbare Datenbanken werden als Warning ausgewiesen; sie verschwinden
nicht still aus dem Auftrag.

---

## 5. [monitor].[USP_PrepareNameFilters]

### Rolle

Die interne Procedure verarbeitet bracket-aware und case-sensitive Namensfilter. Sie ist nicht als regulärer Direktaufruf vorgesehen und liefert keine fachlichen Resultsets.

### Erwartete Temp-Tabelle

Die über `@FilterTable` eindeutig benannte lokale Tabelle mit dem Schema `(FilterType, ItemOrdinal, NameValue, DatabaseName, SchemaName, ObjectName)`.

### Filtertypen

| FilterType | Befüllte Werte |
|---|---|
| `SCHEMA` | `NameValue` |
| `OBJECT` | `NameValue` |
| `INDEX` | `NameValue` |
| `STATISTICS` | `NameValue` |
| `COLUMN` | `NameValue` |
| `FULL_OBJECT` | `DatabaseName`, `SchemaName`, `ObjectName` |

### Regeln

- `@FullObjectNames` ist mit `@SchemaNames` und `@ObjectNames` exklusiv.
- Jede Liste wird syntaktisch validiert.
- Duplikate werden unter `SQL_Latin1_General_CP1_CS_AS` erkannt.
- Bei Fehlern wird die Temp-Tabelle geleert.

### Grenzbeispiele

| Eingabe | Ergebnis |
|---|---|
| `N'[ExampleSchema]|[exampleschema]'` | zwei verschiedene Werte unter CS-Collation |
| `N'[ExampleSchema]|[ExampleSchema]'` | `INVALID_PARAMETER` wegen Duplikat |
| `@FullObjectNames` plus `@ObjectNames` | `INVALID_PARAMETER` |
| Name mit Pipe innerhalb korrekt geklammerter Identifier | wird nicht fälschlich getrennt |

## Quellen

- [SQL Server permissions](https://learn.microsoft.com/sql/relational-databases/security/permissions-database-engine)
- [HAS_PERMS_BY_NAME](https://learn.microsoft.com/sql/t-sql/functions/has-perms-by-name-transact-sql)
- [IS_MEMBER](https://learn.microsoft.com/sql/t-sql/functions/is-member-transact-sql)
- [sys.databases](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-databases-transact-sql)
- [Regular expressions in SQL Server 2025](https://learn.microsoft.com/sql/relational-databases/regular-expressions/overview)
