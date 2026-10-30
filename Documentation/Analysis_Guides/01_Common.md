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

### Hilfe, JSON und TABLE

Die Hilfe zeigt alle zwölf Parameterverträge; ihre Defaults sind ausdrücklich gekennzeichnet. Bei bit-Parametern bedeuten 0 und 1 die jeweiligen logischen Werte; andere in bit konvertierbare Nicht-NULL-Werte werden von T-SQL zu 1 konvertiert. @Json wird beim Eintritt auf NULL gesetzt. Bei TABLE erfolgt der Zieltabellen-Preflight vor der Hilfe und prüft das lokale leere Ziel mit kurzzeitigem Marker-DDL in tempdb.

| Parameter | Typ; Default | Eingabe und Wirkung |
|---|---|---|
| @Suchbegriff | nvarchar(4000); Default=NULL | Freier Unicode-Text. NULL/leer deaktiviert die Textsuche; ohne Bereichs-, Scope- und Rollenfilter erscheint die kuratierte Startliste, mit solchen Filtern die passende Katalogmenge. Getrimmt max. 400 Zeichen, sonst INVALID_PARAMETER. Case-/accent-insensitiv; technische Namenssuche entfernt eckige Klammern und führendes monitor. Tokens an Leerzeichen, unter 3 Zeichen/Stoppwörter entfallen, je Token max. 200 Zeichen. |
| @Bereich | varchar(40); Default=NULL | NULL/leer deaktiviert den Filter; sonst trimmen, uppercase, case-/accent-insensitiver Vergleich. Alle Codes: NAVIGATION=Einstieg/Orientierung; FRAMEWORK=Framework/Zugriff; LIVE=akute Störung/laufende Requests sowie aktuelle Aktivität, Blocking und Ressourcen; OBJECT=Objekte/Indizes/Statistiken; PLAN=langsame Query/Ausführungsplan; QUERY_STORE=Query Store/Laufzeithistorie und Regressionen; EXTENDED_EVENTS=Extended Events/Forensik; OPERATIONS=Backup/Agent/HA-DR/Betrieb; SERVER=CPU/Memory/Worker, Serverzustand/Ressourcen, Server Health, Konfiguration und Sicherheit; SPECIAL_FEATURE=Konfiguration/Sicherheit/Spezialfeatures; SNAPSHOT=optionales Snapshot-/Baseline-Paket. Andere Codes ergeben INVALID_PARAMETER. |
| @Scope | varchar(40); Default=NULL | NULL/leer deaktiviert den Filter; sonst trimmen, uppercase, case-/accent-insensitiv. Alle ScopeCodes: DATABASE=eine Datenbank; EVENT_HISTORY=persistierte Ereignishistorie; EVENT_SESSION=Ereignissitzung; FRAMEWORK=Frameworkmetadaten; INFRASTRUCTURE=Infrastruktur; MULTI_DATABASE=mehrere Datenbanken; OBJECT=Objekt; PLAN_XML=Ausführungsplan-XML; QUERY=Query; SERVER=Instanz; SESSION_REQUEST=Session/Request; SNAPSHOT_TARGET=Snapshotziel. Andere Codes ergeben INVALID_PARAMETER. Das ist die dokumentierte Scope-Einheit, keine Verfügbarkeits- oder Berechtigungsaussage. |
| @Navigationsrolle | varchar(24); Default=NULL | NULL/leer deaktiviert den Filter; sonst trimmen und uppercase. ENTRY=allgemeiner Einstieg; FOLLOW_UP=Folgepfad bei beobachtetem Signal; TARGETED=bekanntes Ziel; SETUP=Setup/Betrieb; SUPPORT=interner Unterstützungs-/Aufrufvertrag. Andere Werte ergeben INVALID_PARAMETER. |
| @NurInstallierte | bit; Default=0 | 0 zeigt alle Katalogzeilen; 1 verlangt lokal vorhandene Procedure im Schema monitor in sys.procedures. NULL ergibt INVALID_PARAMETER. Kein Rechte- oder Featurefähigkeitsnachweis. |
| @MaxZeilen | int; Default=12 | NULL oder 0 hebt das Limit auf; 1 bis 100 begrenzt Treffer auf die Zeilenzahl. Negative Werte und Werte über 100 ergeben INVALID_PARAMETER. |
| @ResultSetArt | varchar(16); Default=CONSOLE | Getrimmt und uppercase. CONSOLE rendert navigation; RAW liefert Status und navigation; TABLE schreibt navigation ins Ziel; NONE unterdrückt Resultsets. NULL/leer/andere Werte ergeben INVALID_PARAMETER, kein Fallback. Ein ungültiger Ausgabewert liefert Status und navigation. |
| @ResultTablesJson | nvarchar(max); Default=NULL | Bei TABLE ist ein JSON-Objekt mit genau einem Schlüssel navigation und einem JSON-String als Wert erforderlich. Der String benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. NULL, leer oder nur Leerzeichen ist bei TABLE ungültig; außerhalb TABLE darf nur NULL, leerer Text oder ein Text nur aus Leerzeichen stehen. Eine nichtleere Zuordnung außerhalb TABLE löst THROW 51011 aus. Zielprüfung mit Marker-DDL läuft vor Hilfe. |
| @JsonErzeugen | bit; Default=0 | 1 erstellt JSON mit meta und navigation, unabhängig von ResultSetArt. 0 oder NULL deaktiviert JSON. |
| @Json | nvarchar(max); Default=NULL OUTPUT | Optionale Bindung einer nvarchar(max)-Variablen mit OUTPUT zum Empfang; Default=NULL bedeutet keinen Eingabewert. Wird beim Eintritt auf NULL gesetzt; bei JsonErzeugen=1 enthält die gebundene Variable meta und navigation. Bei Hilfe bleibt sie NULL. |
| @PrintMeldungen | bit; Default=1 | 1 zeigt nur zusätzliche Severity-10-Meldungen aus dem CATCH; 0 oder NULL unterdrückt sie, ohne Hilfe/Resultsets/JSON zu ändern. |
| @Hilfe | bit; Default=0 | Nur 1 druckt Hilfe und beendet vor Suche/Rendering; 0 oder NULL deaktiviert sie. TABLE-Preflight läuft vorher. |

Bereichs- und Scopecodes sind durch den statischen Katalog bestimmt und lassen sich gezielt abfragen:

```sql
SELECT DISTINCT [PrimaryAreaCode]
FROM [monitor].[VW_AnalysisCatalog] WITH (NOLOCK)
ORDER BY [PrimaryAreaCode];

SELECT DISTINCT [ScopeCode]
FROM [monitor].[VW_AnalysisCatalog] WITH (NOLOCK)
ORDER BY [ScopeCode];
```

JSON bleibt unabhängig von `@ResultSetArt` und enthält `meta` sowie das Array `navigation`:

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_AnalysisNavigator]
      @Suchbegriff = N'Benutzer warten',
      @JsonErzeugen = 1,
      @Json = @Json OUTPUT;
SELECT @Json;
```

TABLE exportiert nur `navigation`. Das Ziel muss vor dem Aufruf leer und lokal sein; eine einzelne Seed-Spalte genügt, weil der Exporthelper das leere Ziel auf das native Resultsetschema erweitert.

```sql
CREATE TABLE #AnalysisNavigator_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max) = N'{"navigation":"#AnalysisNavigator_HelpExample"}';
EXEC [monitor].[USP_AnalysisNavigator]
      @ResultSetArt = 'TABLE',
      @ResultTablesJson = @Map;
DROP TABLE #AnalysisNavigator_HelpExample;
```
### RAW-Resultsets

Ein ungültiger Wert für `@ResultSetArt` ergibt `INVALID_PARAMETER` und liefert Status plus `navigation`; die Ausgabe fällt nicht auf `CONSOLE` zurück.

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

LOW. Die Kataloge sind konstant. Positive Werte von `@MaxZeilen` begrenzen Treffer auf höchstens 100 Zeilen; `NULL` oder `0` hebt diese Grenze auf. `IsInstalled` beweist keine Quellberechtigung oder Featureaktivierung. `SafeCall` muss an den realen Scope angepasst werden. Der vollständige Vertrag steht unter [Analysis Navigator](../Reference/Analysis_Navigator.md).

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
CREATE TABLE #CheckAnalyseAccess_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"access":"#CheckAnalyseAccess_HelpExample"}';
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #CheckAnalyseAccess_HelpExample;
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
CREATE TABLE #CheckFrameworkCapabilities_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"capabilities":"#CheckFrameworkCapabilities_HelpExample"}';
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #CheckFrameworkCapabilities_HelpExample;
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

### Rolle und Zieltabellen

Die öffentliche Helper-Procedure bereitet Datenbankkandidaten für aufrufende Module vor. Sie liefert keine Resultsets. Der Aufrufer legt die lokale Tabelle unter dem Namen aus `@CandidateTable` an. Erforderlich sind DatabaseId int, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS, IsReadOnly bit, CompatibilityLevel tinyint, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS, IsSystemDatabase bit und RequestedOrdinal int. Optional nimmt `@WarningTable` RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS und ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS auf.

Die Procedure hängt Kandidaten und Warnungen an vorhandene Tabellen an; sie leert die Ziele nicht. Verwenden Sie für einen isolierten Aufruf frische Tabellen. Die Kandidatentabellenprüfung bindet nur DatabaseId und DatabaseName mit TOP (0), nicht das vollständige Schema. Spätere Insertfehler können entkommen. Die Warnungstabelle wird separat geprüft; eine fehlende oder nicht passende Tabelle wird still übersprungen. Vorhandene Kandidatenzeilen beeinflussen die Erkennung angeforderter, fehlender Namen. Es gibt keine allgemeine atomare Rücknahme späterer Änderungen.

### Parameter und Auswahl

- `@DatabaseNames` ist eine optionale bracket-aware Pipe-Liste einteiliger Namen. NULL, leer oder Leerzeichen bedeutet keine exakte Einschränkung. Doppelte gültige Werte sind ungültig.
- `@DatabaseNamePattern` unterstützt SQL LIKE oder die Präfixe regex: und regexi:. Eine Namensliste und ein Pattern sind exklusiv. Regex erfordert SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank.
- `@SystemdatenbankenEinbeziehen=0` schließt master, tempdb, model und msdb aus. NULL wird als INVALID_PARAMETER abgelehnt.
- `@AnalysisClass=NULL` überspringt die optionale Analysepfadprüfung. Nur eine angegebene, tatsächlich aktive Klasse kann das delegierte High-Impact- oder Gruppengate auslösen.
- `@CrossDatabaseRequested` beschreibt die Form der Anfrage, nicht ob alle Namen ausgewählt wurden.
- Statuswerte sind AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR und UNAVAILABLE_FEATURE. Die delegierte Pfadprüfung kann INVALID_PARAMETER, HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP zurückgeben.

### Interpretation

Ein Kandidat ist im Ermittlungszeitpunkt sichtbar, online und filterkonform. Das belegt keine spätere CONNECT- oder Objektberechtigung. Explizit angeforderte, aber fehlende Datenbanken können als DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED in die passende Warnungstabelle geschrieben werden. AVAILABLE allein bestätigt nicht, dass alle angeforderten Namen Kandidaten wurden.

Die Pattern- und Namensparser prüfen syntaktische Struktur; PARSENAME-basierte Prüfungen sind keine vollständige SQL-Bezeichnergrammatik. Die Kandidatenauswahl liest master.sys.databases und öffnet die ausgewählten Datenbanken nicht. Regex filtert Namen nach der Kandidatenermittlung und darf nicht als frühe Quellbegrenzung verstanden werden.

## 5. [monitor].[USP_PrepareNameFilters]

### Rolle und Zieltabelle

Die öffentliche Helper-Procedure validiert Listen für Schema-, Objekt-, Index-, Statistik-, Spalten- und vollständige Objektnamen. Der Aufrufer legt die lokale Tabelle unter dem Namen aus `@FilterTable` an. Das Schema umfasst FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS, ItemOrdinal int, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL und ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL. Die Procedure liefert keine Resultsets.

Sie leert das Ziel nicht. Validierte Zeilen werden angehängt. Bei einem Fehler vor dem abschließenden Insert bleiben vorhandene Zeilen bestehen. Der abschließende Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und liefert AVAILABLE.

### Filtertypen und Regeln

| FilterType | Befüllte Felder |
|---|---|
| `SCHEMA`, `OBJECT`, `INDEX`, `STATISTICS`, `COLUMN` | `NameValue` |
| `FULL_OBJECT` | `DatabaseName`, `SchemaName`, `ObjectName` |

`@FullObjectNames` ist exklusiv mit `@SchemaNames` und `@ObjectNames`. Pipe trennt nur außerhalb geklammerter Werte; innerhalb von [...] maskiert ]] eine schließende Klammer. Einzelne Listen akzeptieren einen von PARSENAME strukturell erkannten Namen. Vollständige Objektbezüge enthalten ein, zwei oder drei Teile; bei drei Teilen ist das Schema erforderlich, vier Teile sind ungültig. Doppelte Werte innerhalb desselben Filtertyps werden unter SQL_Latin1_General_CP1_CS_AS abgelehnt.

Diese strukturellen Prüfungen sind keine vollständige SQL-Bezeichnergrammatik. Die Procedure prüft nicht, ob Datenbank, Schema, Objekt, Index, Statistik oder Spalte im Katalog existiert oder für den Aufrufer sichtbar ist. Eine leere Tabelle kann bei frischer Tabelle sowohl einen erfolgreichen Aufruf mit ausschließlich NULL-Listen als auch einen vorherigen Fehler anzeigen; Status und Tabelleninhalt sind gemeinsam auszuwerten.

## Quellen

- [SQL Server permissions](https://learn.microsoft.com/sql/relational-databases/security/permissions-database-engine)
- [HAS_PERMS_BY_NAME](https://learn.microsoft.com/sql/t-sql/functions/has-perms-by-name-transact-sql)
- [IS_MEMBER](https://learn.microsoft.com/sql/t-sql/functions/is-member-transact-sql)
- [sys.databases](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-databases-transact-sql)
- [Regular expressions in SQL Server 2025](https://learn.microsoft.com/sql/relational-databases/regular-expressions/overview)
