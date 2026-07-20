# Common: Zugriff, Capabilities und interne Auswahlverträge

**Procedures:** 4  
**Primäre Kostenklasse:** LOW bis MEDIUM

## 1. [monitor].[USP_CheckAnalyseAccess]

### Zweck

Prüft die effektive Analyseklassen- und Gruppenpolicy für den aktuellen Sicherheitskontext. Die Procedure beantwortet nicht, ob jede technische DMV lesbar ist; sie beantwortet, ob der Framework-Gate eine Analyseklasse grundsätzlich erlaubt.

### Wann einsetzen?

- vor einer ressourcenintensiven Cross-Database-, Plan-, Histogramm- oder Tiefenanalyse,
- wenn eine Procedure `DENIED_GROUP` meldet,
- zur Dokumentation, welche Analyseklassen für den aktuellen Login freigegeben sind,
- bei Abweichungen zwischen `sysadmin`, direktem Login-Token und `IS_MEMBER`.

### Wann nicht einsetzen?

- nicht als vollständige Berechtigungsprüfung der SQL-Server-Systemquellen,
- nicht als Beweis, dass ein Feature technisch aktiviert ist,
- nicht zur Änderung von Policies.

### Aufrufe

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @ResultSetArt = 'CONSOLE';
```

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @AnalyseKlasse = 'CROSS_DATABASE_DEEP',
      @ResultSetArt = 'RAW';
```

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @NurGesperrte = 1,
      @ResultSetArt = 'RAW';
```

### RAW-Resultsets

#### Resultset 1: Meta

| Spalte | Bedeutung |
|---|---|
| `ContractVersion` | Version des Resultset-Vertrags |
| `CollectionTimeUtc` | Erfassungszeitpunkt |
| `ModuleName` | Procedure-Name |
| `StatusCode` | Gesamtstatus, etwa `AVAILABLE`, `AVAILABLE_LIMITED`, `INVALID_PARAMETER` oder `ERROR_HANDLED` |
| `IsPartial` | 1, wenn nicht vollständig `AVAILABLE` |
| `ErrorNumber` | technische Fehlernummer |
| `ErrorMessage` | begrenzte technische Meldung |

#### Resultset 2: Access

| Spalte | Bedeutung und Interpretation |
|---|---|
| `AnalysisClass` | stabiler Code der Analyseklasse |
| `AnalysisLevel` | relative Stufe, etwa leichter oder tiefer Pfad |
| `RequiresGroupGate` | 1 bedeutet, dass eine aktive Policy relevant sein kann |
| `OriginalLoginName` | ursprünglicher Login; bei Impersonation wichtig |
| `EffectiveLoginName` | aktueller Ausführungskontext |
| `IsSysadmin` | sysadmin-Bypass, sofern die Frameworkpolicy dies vorsieht |
| `ActivePolicyCount` | Zahl aller aktuell aktiven Policies |
| `RelevantPolicyCount` | Policies, die für diese Klasse oder Wildcard gelten |
| `IsAllowed` | effektives Ergebnis |
| `AccessReason` | Begründung, etwa offen, sysadmin, Gruppenmatch oder Sperre |
| `MatchedGroupCount` | Zahl passender Gruppen |
| `StatusCode` | `AVAILABLE` oder `DENIED_GROUP` je Klasse |

#### Resultset 3: Policies

| Spalte | Bedeutung |
|---|---|
| `AnalysisClass` | Zielklasse oder Wildcard |
| `ADGroupName` | konfigurierte Gruppe |
| `Priority` | Reihenfolge der Policy |
| `ValidFromUtc`, `ValidToUtc` | Gültigkeitsfenster |
| `MatchesLoginToken` | Gruppe ist direkt im Login-Token sichtbar |
| `MatchesIsMember` | `IS_MEMBER` meldet Mitgliedschaft |
| `Comment` | dokumentierter Policyhinweis |

#### Resultset 4: Warnings

`WarningCode` und `WarningMessage` erklären Sperren oder behandelte Fehler.

### Beispiele

| Konstellation | Bewertung |
|---|---|
| `RequiresGroupGate=0`, `IsAllowed=1`, `AccessReason=OPEN` | normaler offener Pfad |
| `RequiresGroupGate=1`, `RelevantPolicyCount=0`, `IsAllowed=1` | gemäß Projektvertrag offen, solange keine Policy definiert ist |
| `RelevantPolicyCount>0`, `MatchedGroupCount=0`, `IsAllowed=0` | erwartete Gate-Sperre |
| `MatchesLoginToken=0`, `MatchesIsMember=1` | grenzwertig; Token-/Domänenkontext und Fallback verstehen |
| `IsSysadmin=1`, `IsAllowed=0` | unerwartet; Policy-/View-Implementierung prüfen |

### Folgeanalyse

- technische Verfügbarkeit: `USP_CheckFrameworkCapabilities`,
- konkrete Procedure anschließend mit `@ResultSetArt='RAW'`,
- keine Rechte automatisch vergeben.

### Kosten und Grenzen

LOW. Login-Token, Policies und Views werden gelesen. Das Resultset darf in der Runtime reale Identitäten anzeigen; Repositorybeispiele bleiben synthetisch.

---

## 2. [monitor].[USP_CheckFrameworkCapabilities]

### Zweck

Prüft pro Feature server- oder datenbankweit:

- Mindestversion,
- Gruppenfreigabe,
- erforderlichen Permission-Scope,
- tatsächliche Abfragbarkeit,
- optionalen Enablement-Zustand,
- daraus abgeleitete Nutzbarkeit.

Dies ist der wichtigste Vorabcheck, wenn ein späteres leeres Resultset nicht eindeutig interpretierbar wäre.

### Wann einsetzen?

- nach Installation oder Upgrade,
- vor einer Testmatrix,
- bei `UNAVAILABLE_FEATURE`, `PERMISSION_DENIED` oder partiellen Resultsets,
- bei SQL Server 2019/2022/2025-Unterschieden,
- vor Cross-Database-Analysen.

### Aufrufe

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @ResultSetArt = 'CONSOLE';
```

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @DatabaseNames = NULL,
      @NurNichtVerfuegbar = 1,
      @ResultSetArt = 'RAW';
```

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @AnalyseKlasse = 'PLAN_CACHE_DEEP',
      @MitGruppenpruefung = 1,
      @ResultSetArt = 'RAW';
```

### Hauptresultset `Capabilities`

| Spalte | Bedeutung |
|---|---|
| `FeatureOrdinal` | definierte Sortierung |
| `FeatureCode` | stabiler technischer Featurecode |
| `FeatureName` | lesbare Bezeichnung |
| `ScopeType` | `SERVER` oder `DATABASE` |
| `AnalysisClass` | zugehörige Frameworkklasse |
| `AnalysisLevel` | relative Tiefe |
| `IsResourceIntensive` | Hinweis auf teuren Pfad |
| `DatabaseName` | Ziel-DB bei Database-Scope |
| `ServerMajorVersion`, `ServerProductVersion` | erkannte Version |
| `MinimumMajorVersion` | Mindestversion der Quelle |
| `VersionSupported` | Versionsgate erfüllt |
| `GroupCheckApplied` | Gruppenpolicy wurde berücksichtigt |
| `GroupAccessAllowed` | Gate-Ergebnis |
| `AccessReason` | Gate-Begründung |
| `RequiredPermissionScope` | Server- oder Database-Permission |
| `PermissionCheckType` | verwendete Prüfmethode |
| `RequiredPermission` | technische Permission |
| `PermissionDisplayText` | anwenderfreundlicher Text |
| `HasRequiredPermission` | Ergebnis der Permission-Prüfung; `NULL` kann nicht prüfbar bedeuten |
| `IsQueryable` | technische Probe war lesbar |
| `IsFeatureEnabled` | Featurezustand, sofern ermittelbar |
| `IsUsable` | kombinierte Nutzbarkeit |
| `StatusCode` | normalisierter Grund für verfügbar oder nicht verfügbar |
| `ErrorNumber`, `ErrorMessage` | behandelte technische Details |
| `Description` | fachliche Kurzbeschreibung |

Weitere RAW-Resultsets enthalten eine Zusammenfassung, Datenbankstatus und Warnungen. Die Zusammenfassung ist zur Triage geeignet; für Ursachen immer die Capabilities-Zeile verwenden.

### Entscheidende Kombinationen

| Kombination | Interpretation |
|---|---|
| `VersionSupported=0` | auf dieser Version unmöglich; keine Rechteanalyse nötig |
| `VersionSupported=1`, `GroupAccessAllowed=0` | Frameworkpolicy sperrt den Pfad |
| `HasRequiredPermission=0` | Berechtigung fehlt oder ist nicht effektiv |
| `HasRequiredPermission=1`, `IsQueryable=0` | Quelle scheitert trotz formaler Permission; Kontext, DB-Status oder Plattform prüfen |
| `IsQueryable=1`, `IsFeatureEnabled=0` | Quelle lesbar, Feature aber deaktiviert |
| `IsUsable=1` | technischer Pfad ist nach aktueller Probe nutzbar; kein Qualitätsurteil über Daten |

### Grenzfälle

- Eine sekundäre Replica kann Kataloge lesen, aber andere Runtimequellen nicht.
- `VIEW SERVER STATE` wurde ab SQL Server 2022 für viele Performance-DMVs durch `VIEW SERVER PERFORMANCE STATE` ersetzt.
- Ein Database-Scope-Feature kann in einer DB verfügbar und in einer anderen deaktiviert sein.
- `IsFeatureEnabled=NULL` bedeutet nicht automatisch aktiviert; Enablement war möglicherweise nicht anwendbar oder nicht bestimmbar.

### Folgeanalyse

Die konkrete Procedure nur für Zeilen mit `IsUsable=1` ausführen. Bei Teilverfügbarkeit den Zielscope enger setzen.

### Kosten

LOW bis MEDIUM. Viele kleine Probes können bei zahlreichen Datenbanken
kumulieren. Für tatsächlich aktivierte ressourcenintensive Pfade ist deshalb
`@HighImpactConfirmed=1` erforderlich; die Kandidatenmenge selbst wird nicht
willkürlich vorab gekürzt.

---

## 3. [monitor].[USP_PrepareDatabaseCandidates]

### Rolle

Technischer interner Auswahlvertrag. Nicht als normale Analyse-Procedure verwenden.

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

## 4. [monitor].[USP_PrepareNameFilters]

### Rolle

Interne Procedure für bracket-aware, case-sensitive Namensfilter. Kein normaler Direktaufruf und keine Resultsets.

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
