# [monitor].[USP_DatabaseConfigurationAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Inventarisiert Datenbankoptionen und trennt lokale Variation von expliziter Profilabweichung.<br>
**Beobachtungsart:** aktueller Cross-Database-Katalogsnapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet: **Welche sichtbaren Datenbank-, Database-Scoped- und Query-Store-Einstellungen unterscheiden sich lokal oder von einem ausdrücklich gelieferten Sollprofil?** Ohne Profil berechnet sie nur lokale Variation. Der häufigste sichtbare Wert ist dabei eine Vergleichsreferenz, kein Sollwert. Mit `@ProfileJson` entstehen zusätzlich `PROFILE_MISMATCH`-Zeilen gegen die vom Aufrufer autoritativ vorgegebenen Werte.

Der Einsatz eignet sich für kontrollierte Inventur, Migrationsvorbereitung und Driftprüfung. RCSI, Statistikoptionen, Parameterisierung, Query Store, Recovery Model, ADR oder andere Einstellungen bleiben workload- und betriebsabhängig. Die Procedure führt kein `ALTER DATABASE` aus und formuliert keine universelle Konfigurationsempfehlung.

## Nicht beantwortete Fragen

Variation beweist weder Fehler noch Performanceursache. Zwei Datenbanken können absichtlich verschieden konfiguriert sein. Ein lokaler Mehrheitswert ist nicht automatisch organisatorischer Standard. Ein Profilwert dokumentiert die Erwartung des Aufrufers, nicht ihre technische Angemessenheit. Die Procedure bewertet keine Lizenzierung, keinen Change-Prozess und keine Anwendungskompatibilität.

Unsichtbare, offline befindliche oder berechtigungsbedingt ausgelassene Datenbanken fehlen. Versionsabhängige Optionen erscheinen nur, wenn ihre Katalogspalte vorhanden ist. Query-Store-Optionen zeigen Zustand und Konfiguration, nicht den Inhalt oder die Workloadwirkung. Secondary-Werte von Database Scoped Configurations werden separat erhalten und nicht mit dem Primärwert vermischt.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
      @DatabaseNames = N'[ExampleDatabaseA]|[ExampleDatabaseB]',
      @MaxZeilen = 200,
      @ResultSetArt = 'CONSOLE';
```

Verwenden Sie mit folgendem Aufruf ein ausdrücklich synthetisches Profil:

```sql
EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
      @DatabaseNames = N'[ExampleDatabaseA]',
      @ProfileJson = N'[{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]',
      @MaxZeilen = 200,
      @ResultSetArt = 'CONSOLE';
```

Versionieren und genehmigen Sie das Profil vor der produktiven Nutzung. Übernehmen Sie dabei die exakten sichtbaren Schreibweisen aus `settings`. Eine Profilabweichung ist Review-Evidenz und kein Änderungsauftrag.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste exakter, einteiliger SQL-Datenbanknamen, z. B. N'AppDb&#124;[Reporting Db]'. &#124; trennt außerhalb von [...]; ]] maskiert eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Leere Elemente, ungültige Klammerung, mehrteilige oder überlange Namen und doppelte gültige Namen sind ungültig. NULL, leerer Text oder nur U+0020-Leerzeichen bedeuten keinen Namensfilter; dann gelten alle sichtbaren, online befindlichen und zugreifbaren Kandidaten ohne Datenbanksnapshots. Nur eine nach Entfernung äußerer U+0020-Leerzeichen nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Nicht vorhandene, ausgeschlossene, offline befindliche oder für den Login nicht zugreifbare explizite Namen erzeugen DATABASE_UNAVAILABLE; explizite Systemnamen master, tempdb, model und msdb ohne Opt-in erzeugen SYSTEM_DATABASE_EXCLUDED. Namen und Duplikate werden case-sensitiv verglichen. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Systemdatenbanken mit ID 1 bis 4 aus; 1 bezieht sie zusätzlich zu Datenbanken mit ID über 4 ein. NULL ist ungültig. Der Wert wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. Auch einbezogene Systemdatenbanken müssen sichtbar, online und zugreifbar sein. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Filtert Datenbanknamen. NULL bedeutet kein Pattern. Nach Entfernung äußerer U+0020-Leerzeichen wird optional ohne Beachtung der Groß-/Kleinschreibung ein Präfix entfernt: LIKE: für SQL-LIKE, REGEX: für case-sensitive Regex oder REGEXI: für case-insensitive Regex. Ohne Präfix gilt LIKE. Der Rest wird nach Präfixentfernung nicht erneut getrimmt; leerer Eingang und leeres Präfixergebnis sind ungültig. LIKE wird case-sensitiv ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Parser validiert die Regex-Syntax nicht vorab. Der Kandidatenhelper führt REGEXP_LIKE aus; eine fehlerhafte Regex kann dabei einen nicht abgefangenen Laufzeitfehler auslösen, ohne normalen Statusabschluss. Nur eine aktive, nichtleere Datenbankliste ist mit einem nicht-NULL-Pattern unvereinbar. |
| `@ProfileJson` | `nvarchar(max)` | `NULL` | NULL verwendet ausschließlich den lokalen Vergleich; Leertext, U+0020-Leertext und ein leeres Array sind ungültig. Ansonsten ein JSON-Array eindeutiger Objekte mit exakt den case-sensitiven Feldnamen settingScope, settingName und expectedValue, z. B. [{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]. settingScope wird getrimmt und großgeschrieben; erlaubt sind ausschließlich DATABASE für Datenbankoptionen, SCOPED für Database Scoped Configurations und QUERY_STORE für Query-Store-Optionen. settingName wird zu nvarchar(128) konvertiert, getrimmt und muss nichtleer sein. expectedValue wird zu nvarchar(4000) konvertiert und darf nicht NULL sein; leerer Text ist zulässig. Nicht konvertierbare Einträge, ungültiges/leer strukturiertes Array, NULL-Felder, unbekannte Scopes und doppelte Scope/Name-Paare unter case-sensitivem Vergleich sind ungültig. Zusätzliche JSON-Felder werden ignoriert. Einstellungsnamen und Soll-/Istwerte werden mit SQL_Latin1_General_CP1_CI_AS verglichen; reine Unterschiede der Groß-/Kleinschreibung erzeugen keine Abweichung. Ein Name ohne sichtbare passende Einstellung erzeugt PROFILE_SETTING_NOT_VISIBLE. Ohne Profil wird lokale Variation, mit Profil zusätzlich DriftType PROFILE_MISMATCH mit FindingCode EXPLICIT_PROFILE_MISMATCH ausgewiesen; keine Konfiguration wird geändert. |
| `@MaxZeilen` | `int` | `2000` | Begrenzt settings- und drift-Zeilen jeweils separat, nicht die Inventarisierung oder andere Gruppen. Positive Werte sind das jeweilige Maximum; 0 oder NULL bedeutet unbegrenzt. Negative Werte sind ungültig. Die vollständigen Einstellungen und Befunde werden zunächst berechnet und materialisiert, danach werden Zeilen über dem Limit entfernt. settings wird nach DatabaseName, SettingScope und SettingName sortiert; drift nach DriftType, SettingScope, SettingName und DatabaseName. HasMoreSettingRows und HasMoreDriftRows melden erkannte Kürzungen; Die Statuszählung erfolgt vor dem Entfernen überzähliger Zeilen; SettingRowCount und DriftRowCount geben jeweils das Minimum aus Vollmenge und Limit an. Profil, Quellenstatus und Warnungen bleiben ungekürzt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wählt reguläre Resultsets. Nach Trim und Umwandlung in Großbuchstaben sind genau CONSOLE, RAW, TABLE und NONE zulässig. CONSOLE liefert eine beschriftete Driftansicht; RAW liefert sechs Resultsets in Reihenfolge moduleStatus, settings, drift, profile, sourceStatus, warnings. TABLE schreibt angeforderte Gruppen in vorhandene lokale #Temp-Tabellen. NONE liefert keine regulären Resultsets. NULL, Leertext und andere Werte sind ungültig. @JsonErzeugen steuert unabhängig den JSON-OUTPUT-Parameter. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE ist ein JSON-Objekt mit Resultatnamen und vorhandenen lokalen #Temp-Zielen erforderlich, z. B. {"settings":"#DbSettings"}. Erlaubt sind moduleStatus, settings, drift, profile, sourceStatus und warnings; Namen werden case-sensitiv verglichen. Ziele müssen vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein. ##Tabellen, reservierte #Monitor-Namen, doppelte Zuordnungen/Ziele und unbekannte Resultatnamen sind ungültig. In TABLE muss die Zuordnung nichtleer und gültig sein. Außerhalb von TABLE sind NULL, Leertext und nur U+0020-Leerzeichen zulässig; ein anderer nichtleerer Wert ist ungültig. Zielnamen sind höchstens 116 Zeichen lang. Der Preflight prüft die Zuordnung und Ziele; der spätere Writer ersetzt die Seed-Spalte durch das Ergebnisschema. Die Gruppen bedeuten: moduleStatus Modulstatus, settings Einstellungen, drift Unterschiede, profile Sollprofil, sourceStatus Quellenstatus, warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | 0 lässt @Json auf NULL; 1 befüllt es mit meta, settings, drift, profile, sourceStatus und warnings. settings und drift beachten jeweils @MaxZeilen. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter für das optionale JSON-Ergebnis. Wird vor Hilfe- und Analyseverzweigung auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Zum Empfangen ist OUTPUT zu binden; der Parameter kann ausgelassen werden, wenn kein JSON benötigt wird. |
| `@PrintMeldungen` | `bit` | `1` | Steuert nur die zusätzliche Meldung mit RAISERROR-Schweregrad 10 und NOWAIT bei Modulstatus ungleich AVAILABLE. 0 unterdrückt die Meldung, 1 gibt sie aus; Resultsets und Status-OUTPUT-Werte bleiben unabhängig. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | Bei 1 wird PRINT-Hilfe ausgegeben und vor Validierung sowie Katalogzugriff zurückgekehrt. @Json wurde zuvor auf NULL gesetzt; Status-OUTPUT-Parameter werden in diesem Pfad nicht beschrieben. Bei 0 oder NULL läuft die Analyse. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Status im normalen Analysepfad: AVAILABLE bedeutet keine Teilquellenwarnung; AVAILABLE_LIMITED bedeutet, dass mindestens eine Quelle oder Kandidat eingeschränkt war; INVALID_PARAMETER bezeichnet ungültige Auswahl-, Profil-, Zeilen- oder Ausgabeparameter; INTERNAL_ERROR bezeichnet einen internen Kandidaten-/Temp-Tabellenfehler; UNAVAILABLE_FEATURE meldet nicht verfügbare Regex-Funktionalität (SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank erforderlich). DENIED_PERMISSION und TIMEOUT sind Quellenstatus und führen regelmäßig zu AVAILABLE_LIMITED, nicht zu globalen Statuswerten. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist den Parameter nicht zu und erhält den vorherigen Variableninhalt. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT-Bit: 0 bei AVAILABLE, 1 bei eingeschränktem oder fehlgeschlagenem Ergebnis. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu, daher bleibt ein gebundener NULL-Eingang NULL und ein anderer Anfangswert erhalten. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Fehlernummer aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Fehler- oder Hinweismeldung aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt. |

### RAW-Inventar

```sql
EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
      @DatabaseNames=N'AppDb|[Reporting Db]'
    , @ResultSetArt='RAW';
```

### JSON mit Profil

```sql
DECLARE @ConfigurationJson nvarchar(max);
DECLARE @ConfigurationProfile nvarchar(max)=N'[{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]';
EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
      @ProfileJson=@ConfigurationProfile
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@ConfigurationJson OUTPUT;
SELECT @ConfigurationJson AS [DatabaseConfigurationAnalysisJson];
```

### TABLE in lokale Temp-Tabelle

```sql
CREATE TABLE #DatabaseConfigurationAnalysis_HelpExample (Seed int NULL);
DECLARE @ConfigurationTableMap nvarchar(max)=N'{"settings":"#DatabaseConfigurationAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
          @ResultSetArt='TABLE'
        , @ResultTablesJson=@ConfigurationTableMap;
    SELECT * FROM #DatabaseConfigurationAnalysis_HelpExample;
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte Vertrag umfasst `moduleStatus`, `settings`, `drift`, `profile`, `sourceStatus` und `warnings`. Prüfen Sie zuerst Modul- und Quellstatus. Verifizieren Sie danach `profile`, sofern es geliefert wurde. `settings` ist das Rohinventar je Datenbank und Scope. `drift` enthält lokale Variation und explizite Profilabweichung. `warnings` zeigt nicht sichtbare Profileinträge, verweigerte Datenbanken oder Teilquellen.

Alle 42 lokalen Textspalten verwenden die Frameworkcollation
`SQL_Latin1_General_CP1_CS_AS`. Die sechs TABLE-Exporte enthalten zusammen
32 Textspalten. Damit übernimmt ein Export keine abweichende `tempdb`-Collation.
Die bewusst case-insensitiven Vergleiche von Profilnamen und Einstellungswerten
behalten ihre bisherige Bedeutung.

`@MaxZeilen` begrenzt `settings` und `drift` nach derselben Sortierung in RAW,
TABLE, CONSOLE und JSON. Die vollständige Inventur, Driftberechnung und
Quellenstatus entstehen vor dieser Auswahl. `SettingRowCount` und
`DriftRowCount` im Modulstatus zählen die ausgewählten Zeilen; die zugehörigen
`HasMore*`-Kennzeichen zeigen weitere materialisierte Zeilen an. Profil,
Quellenstatus und Warnungen werden durch dieses Ausgabelimit nicht gekürzt.
## Eine Zeile bedeutet

In `settings` bedeutet eine Zeile eine Einstellung einer Datenbank aus genau einer Quellgruppe. In `drift` ist eine Zeile eine Datenbank-Einstellung, die vom lokalen Referenzwert oder expliziten Profilwert abweicht. `MatchingDatabaseCount` beschreibt beim lokalen Vergleich die Zahl sichtbarer Datenbanken mit dem aktuellen Wert; `ComparedDatabaseCount` ist der Nenner dieser Einstellung. In `sourceStatus` ist eine Zeile eine Datenbank-Quellkombination.

## So lesen

`DriftType` trennt `LOCAL_VARIATION` von `PROFILE_MISMATCH`. Berücksichtigen Sie beim lokalen Vergleich `ReferenceValue`, `MatchingDatabaseCount` und `ComparedDatabaseCount` gemeinsam. Bei Gleichstand wählt die Procedure deterministisch nach Wert; dadurch entsteht Stabilität, aber keine fachliche Präferenz. Beim Profilvergleich ist `ExpectedValue` exakt die gelieferte Zeichenfolge, verglichen ohne Groß- und Kleinschreibung. `PROFILE_SETTING_NOT_VISIBLE` kann einen Tippfehler, eine Versionsdifferenz oder fehlende Sichtbarkeit bedeuten.

## Warum kann das problematisch sein?

Unbeabsichtigte Abweichungen können Verhalten, Recovery, Optimierung, Statistikpflege oder Query-Store-Erfassung verändern. Besonders nach Migrationen oder automatisierten Deployments ist ein reproduzierbares Profil hilfreich. Gleichzeitig können pauschale Sollwerte Schaden verursachen, wenn Datenbanken unterschiedliche Workloads, Verfügbarkeitsanforderungen oder Kompatibilitätsziele besitzen.

## Wann ist es kein Problem?

Eine Abweichung kann bewusst und dokumentiert sein. Unterschiedliche Compatibility Levels während einer gestuften Migration, unterschiedliche Recovery Models oder Query-Store-Zustände bei speziellen Datenbanken sind mögliche Gegenbeispiele. Auch lokale Mehrheiten können historisch zufällig entstanden sein. Ohne erwartetes Betriebsprofil gibt die Procedure deshalb nur Variation aus.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `ExampleDatabaseB` weicht als einzige Datenbank vom freigegebenen Profil `AUTO_CLOSE=OFF` ab, und der Changeverlauf zeigt eine unbeabsichtigte Aktivierung. Das rechtfertigt eine geplante Korrektur mit Rollback, nicht eine automatische DDL-Ausführung.

**Gegenbeispiel:** `ExampleLegacyDatabase` bleibt absichtlich auf einem niedrigeren Compatibility Level, während die Migration getestet wird. Die Variation ist erwartet und sollte dokumentiert, nicht „vereinheitlicht“ werden.

**Nicht entscheidbar:** Ein Profilwert ist nicht sichtbar und die Scoped-Quelle steht auf `DENIED_PERMISSION`. Stellen Sie zuerst die erforderliche Sichtbarkeit her und interpretieren Sie eine fehlende Zeile nicht als fehlende Einstellung.

## Leere oder partielle Ausgabe

Eine leere `drift`-Menge bedeutet: Im sichtbaren Scope wurde keine Variation beziehungsweise Profilabweichung erzeugt. Sie sagt nichts über ausgelassene Datenbanken oder nicht inventarisierte Einstellungen. `AVAILABLE_LIMITED` weist auf eine fehlende Teilquelle hin. Jede Kombination aus Datenbank und Quellgruppe besitzt einen eigenen Status, sodass vorhandene Werte nicht wegen einer anderen fehlenden Quelle verworfen werden.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Serverkatalog einmal sowie je sichtbarer Datenbank zwei kleine Konfigurationskataloge. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, unbegrenzte Ausgabe und großes explizites Profil. |
| Haupttreiber | Datenbankzahl und Zahl versionsabhängiger Scoped Configurations. |
| Skalierung | Annähernd linear zur Datenbankzahl; keine Benutzerobjekt- oder Nutzdatenscans. |
| Ressourcen | Katalog-CPU, dynamische Cross-Database-Batches und kleine TempDB-Aggregationen. |
| Begrenzungswirkung | Datenbankfilter wirkt vor lokalen Katalogzugriffen; `@MaxZeilen` begrenzt Ausgabe, nicht Inventur. |
| Locking und Nebenwirkungen | Read-only, `LOCK_TIMEOUT 0`; keine Konfigurationsänderung und keine Persistenz. |
| Schutzmechanismus | Getrennte Quellstatus, versionsadaptive Spaltenprüfung und nur explizites Sollprofil. |
| Sicherer Einsatz | Kleine Datenbankliste, Rohinventar prüfen, Profil separat freigeben. |
| Aussagegrenze | Katalogsnapshot ohne Workloadwirkung, Changehistorie oder universelle Sollwerte. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Einstellungen variieren, und welche weichen von einem autorisierten Profil ab?

### Technischer Hintergrund

`master.sys.databases` liefert gemeinsame Datenbankoptionen. `sys.database_scoped_configurations` und `sys.database_query_store_options` werden je Kandidat in isolierten dynamischen Batches gelesen. Die dynamische Zeichenfolge wird bereits bei der Verkettung als `nvarchar(max)` aufgebaut, damit beide lokalen Katalogabfragen erhalten bleiben. Eine versionsabhängige Option wie Optimized Locking wird nur projiziert, wenn die Katalogspalte sichtbar vorhanden ist. Das Profil ist ein JSON-Array eindeutiger Scope-/Name-Paare.

### Datenkette

`master.sys.databases`, `sys.database_scoped_configurations`, `sys.database_query_store_options`.

### Source Select

Die Konfiguration besteht aus einem serverweiten Datenbankkatalog und datenbanklokalen Konfigurationssichten:

```sql
SELECT
      [d].[name]
    , [d].[compatibility_level]
    , [d].[recovery_model_desc]
    , [d].[is_auto_close_on]
    , [d].[is_auto_shrink_on]
FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[name] = N'ExampleDatabase'
  AND [d].[state] = 0;

-- Erst im Kontext der ausgewählten Datenbank:
SELECT [name], [value], [value_for_secondary]
FROM [sys].[database_scoped_configurations] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Filtern Sie die Datenbankliste vor dem Kontextwechsel. Fragen Sie Query Store und zusätzliche versionsabhängige Sichten nur für verbleibende Datenbanken ab; ein globales `TOP` darf nicht vor der fachlichen Datenbankauswahl stehen.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Katalogsnapshot pro Quelle. Zustände können sich zwischen Datenbanken und Quellzugriffen ändern; `CapturedAtUtc` kennzeichnet den Aufruf, nicht eine atomare serverweite Transaktion.

### Bewertung und Gegenprobe

Prüfen Sie Abweichung mit freigegebenem Profil, Changehistorie, Anwendungstest und Workloadevidenz. Klären Sie vor DDL immer Rollback und betroffene Verfügbarkeits-/Recovery-Verträge.

### Typische Fehlinterpretation

Der lokal häufigste Wert ist nicht als Best Practice zu interpretieren. Ebenso stellt eine Profilabweichung keine automatische Reparaturanweisung dar.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Query Store, Statistik-, Recovery- und Verfügbarkeitsmodule sowie der externe Konfigurations-/Changevertrag der Organisation.

## Primärquellen

- [Zeichenfolgenverkettung und große Datentypen](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/string-concatenation-transact-sql?view=sql-server-ver17)
- [sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17)
- [sys.database_scoped_configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver17)
- [sys.database_query_store_options](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#19-monitorusp_databaseconfigurationanalysis)
