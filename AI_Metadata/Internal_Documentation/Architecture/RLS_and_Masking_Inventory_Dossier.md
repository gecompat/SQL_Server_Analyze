# Sichtbares Inventar für Row-Level Security und Dynamic Data Masking

**Stand:** 27. Oktober 2026.
**Status:** V1 regulär in PR #473 integriert; erforderliche Head-/Main-Prüfungen bestanden. Ein separater Modul-Reifeabschluss ist nicht dokumentiert. Der Katalogvertrag bleibt caller-sichtbar und erhebt keinen Enforcement- oder Vollständigkeitsanspruch.
**Artefakt-UID:** `urn:uuid:01a1727d-1d09-7e6d-9418-6a3a3c2068b1`.
**Registrierung:** `DEFERRED`; keine lesbare Kennung vergeben.
**Arbeitselement:** Teil des kontinuierlichen Intake `WI-0010`; kein neues Arbeitselement.
**Planung:** Rang 17 der [Entwicklungswellen](../Quality/Development_Waves_2026-10.md); erster begrenzter Slice.

## Diagnosefrage und Abgrenzung

Der erste Slice beantwortet ausschließlich, welche Row-Level-Security-Policies,
zugehörigen Predicate-Metadaten und Dynamic-Data-Masking-Spalten der
Aufrufer in den gewählten Datenbanken im Katalog sehen kann. Er liest keine
geschützten Tabellenzeilen.

Der Bericht gibt weder Predicate-Definitionen noch Masking-Expressions aus.
Er bewertet nicht die Wirksamkeit, Gesundheit oder Vollständigkeit der
Policies, führt keine Zugriffsprobe aus und berechnet keine effektiven
Berechtigungen. Ein sichtbarer Policy- oder Masking-Eintrag beweist keine
Abdeckung aller Objekte oder Principals. Ein erfolgreiches leeres Ergebnis
ist kein Abwesenheitsbeweis, wenn Katalogmetadaten eingeschränkt sichtbar sind.

Die vorhandene [Spezialfeatureinventur](../../../Documentation/Analysis_Guides/Procedures/USP_SpecialFeatureInventory.md)
zählt ausgewählte Featuremetadaten, liefert aber keine Policy-/Predicate- und
Masked-Column-Zeilen. Die [Datenbankprincipal-Analyse](Database_Principal_Analysis_Dossier.md)
behandelt Principals, direkte Rollenmitgliedschaften und explizite Rechte;
dieser Slice dupliziert diese Mengen nicht. Die bestehende
`RLS_DYNAMIC_MASKING`-Zeile bleibt `RESEARCHED_NOT_IMPLEMENTED`; Klassifikation,
Agent-Proxies, MSDTC und Legacy-Mirroring bleiben eigenständige offene Themen.

## Quellen und Inventare

Die SQL-Quellen sind lokale, datenbankgebundene Katalogsichten. Die spätere
Implementierung erfasst je Datenbank und Quellgruppe getrennte Status- und
Zeitklammern. Die Kataloge unterliegen Metadata Visibility; nur sichtbare
Zeilen dürfen als Ergebnis ausgegeben werden.

| Inventar | Quelle | Vorgesehene stabile Felder | Nicht ausgeben |
|---|---|---|---|
| `securityPolicies` | `sys.security_policies` | Datenbankbindung, `object_id`, sichtbarer Policyname und Schema, `is_enabled`, `is_not_for_replication`, `uses_database_collation`, rohes `is_schemabinding_enabled`, `create_date`, `modify_date` | `principal_id`/Besitzer-SID, implizite oder effektive Principals, Wirksamkeitsurteil |
| `securityPredicates` | `sys.security_predicates` mit Policybezug | Datenbankbindung, Policy- und Predicate-ID, `target_object_id`, `predicate_type`, `predicate_type_desc`, `operation`, `operation_desc` | `predicate_definition`, Funktions-/Argumenttext, daraus abgeleitete Regel oder Zielspalten |
| `maskedColumns` | `sys.masked_columns` mit sichtbarer Tabellen-/Schemaauflösung | Datenbankbindung, `object_id`, `column_id`, sichtbare Schema-, Tabellen- und Spaltennamen, `is_masked` | `masking_function`, tatsächliche oder maskierte Werte, Spaltendefinitionen außerhalb nötiger Namensauflösung |

Policy- und Predicate-IDs sind nur zusammen mit Datenbank und Aufnahme
interpretierbar. Für Masking gilt dieselbe Bindung für Objekt- und Spalten-IDs.
Fehlende Namensauflösung darf die native ID-Zeile nicht löschen oder in eine
geratene Identität umwandeln; der Name bleibt dann `NULL` und die Quelle erhält
eine begrenzte Warnung.

## Öffentlicher Produktvertrag

Vorgeschlagene Procedure: `[monitor].[USP_RowLevelSecurityAndMaskingInventory]`.
Die Prüfung des aktuellen Objektinventars ergab keinen gleichnamigen
Produktkonflikt. SQL Server 2019+ ist die bestehende portable Produktbaseline;
dieser Vertrag führt keinen versions- oder Compatibility-Level-Zweig ein.

Die Parameter übernehmen die Reihenfolge, Typen und Defaults der bestehenden
[Datenbankprincipal-Procedure](Database_Principal_Analysis_Dossier.md). Es
werden keine eigenen Auswahl- oder Ausgabehelfer definiert.

| Position | Parameter | Typ | Default / Richtung |
|---:|---|---|---|
| 1 | `@DatabaseNames` | `nvarchar(max)` | `NULL` |
| 2 | `@SystemdatenbankenEinbeziehen` | `bit` | `0` |
| 3 | `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` |
| 4 | `@MaxZeilen` | `int` | `1000` |
| 5 | `@LockTimeoutMs` | `int` | `0` |
| 6 | `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` |
| 7 | `@ResultTablesJson` | `nvarchar(max)` | `NULL` |
| 8 | `@JsonErzeugen` | `bit` | `0` |
| 9 | `@Json` | `nvarchar(max)` | `NULL OUTPUT` |
| 10 | `@PrintMeldungen` | `bit` | `1` |
| 11 | `@Hilfe` | `bit` | `0` |
| 12 | `@StatusCodeOut` | `varchar(40)` | `NULL OUTPUT` |
| 13 | `@IsPartialOut` | `bit` | `NULL OUTPUT` |
| 14 | `@ErrorNumberOut` | `int` | `NULL OUTPUT` |
| 15 | `@ErrorMessageOut` | `nvarchar(2048)` | `NULL OUTPUT` |

Die Datenbankauswahl folgt exakt dem bestehenden Vertrag: Ohne Filter werden
alle sichtbaren Online-Benutzerdatenbanken verarbeitet;
`@DatabaseNames` verwendet die bracket-aware Pipe-Liste und
`@DatabaseNamePattern` den getrennten LIKE-/versionsabhängigen Regexpfad.
Systemdatenbanken bleiben standardmäßig ausgeschlossen.
`@MaxZeilen` 0 oder `NULL` bedeutet unbegrenzt; negative Werte werden
abgewiesen. Das Limit gilt global je fachlichem Inventar über alle
ausgewählten Datenbanken, mit deterministischer Sortierung nach Datenbank-ID
und den nativen Fachschlüsseln. Kontext-, Status- und Warnmengen bleiben
ungekürzt. Das Limit begrenzt die Ausgabe, nicht die vorgelagerte Katalogarbeit.
`@LockTimeoutMs` übernimmt 0 bis 60000; `NULL` und negative Werte sind ungültig.
Ausgabearten sind `CONSOLE`, `RAW`, `TABLE` und `NONE`.
`@ResultTablesJson` verwendet unverändert das Mapping- und Vorprüfungsformat
des referenzierten Datenbankprincipal-Vertrags; es gibt keine RLS-spezifischen
TABLE-Zielregeln.

## Resultset- und JSON-Schema

Alle Textfelder verwenden `SQL_Latin1_General_CP1_CS_AS`. Schema-Version ist
`1`. RAW liefert die sieben Resultsets in der unten angegebenen Reihenfolge;
TABLE exportiert dieselben benannten Mengen über `@ResultTablesJson OUTPUT`.
CONSOLE verwendet `securityPolicies` als einziges Standardinventar; die
Inventare `securityPredicates` und `maskedColumns` bleiben über RAW, TABLE
und JSON verfügbar und werden nicht als abwesend interpretiert, wenn sie im
Console-Standard nicht erscheinen. Der gemeinsame Status- und Warnvertrag
weist auf leere, limitierte oder nicht verfügbare Quellen hin. `NONE` liefert
kein Resultset. JSON verwendet die Hülle `meta` mit
`resultName`, `schemaVersion`, `generatedAtUtc`, `statusCode`, `isPartial`,
`errorNumber` und `errorMessage`; die Array-Schlüssel lauten genau
`moduleStatus`, `databaseContext`, `securityPolicies`, `securityPredicates`,
`maskedColumns`, `sourceStatus` und `warnings`. Arrays bewahren NULL-Felder.
Feldnamen und Reihenfolge der JSON-Objekte entsprechen den folgenden
Resultsets.

| Reihenfolge / Name | Feldfolge mit Typen und Nullbarkeit |
|---|---|
| 1 `moduleStatus` | `ModuleName sysname NOT NULL`, `CapturedAtUtc datetime2(3) NOT NULL`, `StatusCode varchar(40) NOT NULL`, `IsPartial bit NOT NULL`, `RowCount bigint NOT NULL`, `Detail nvarchar(1000) NOT NULL` |
| 2 `databaseContext` | `DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`, `StateDescription nvarchar(60) NULL`, `ContainmentDescription nvarchar(60) NULL`, `ContextStatus varchar(40) NOT NULL` |
| 3 `securityPolicies` | `DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`, `PolicyObjectId int NOT NULL`, `PolicyName sysname NOT NULL`, `SchemaId int NOT NULL`, `SchemaName sysname NULL`, `IsEnabled bit NOT NULL`, `IsNotForReplication bit NOT NULL`, `UsesDatabaseCollation bit NOT NULL`, `IsSchemabindingEnabled bit NULL`, `CreateDate datetime NOT NULL`, `ModifyDate datetime NOT NULL` |
| 4 `securityPredicates` | `DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`, `PolicyObjectId int NOT NULL`, `PredicateId int NOT NULL`, `TargetObjectId int NOT NULL`, `PredicateType int NOT NULL`, `PredicateTypeDescription nvarchar(60) NOT NULL`, `Operation int NULL`, `OperationDescription nvarchar(60) NULL` |
| 5 `maskedColumns` | `DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`, `ObjectId int NOT NULL`, `ColumnId int NOT NULL`, `SchemaName sysname NULL`, `TableName sysname NULL`, `ColumnName sysname NOT NULL`, `IsMasked bit NOT NULL` |
| 6 `sourceStatus` | `DatabaseId int NULL`, `DatabaseName sysname NULL`, `SourceKey varchar(64) NOT NULL`, `SourceKind varchar(16) NOT NULL`, `StartedAtUtc datetime2(3) NOT NULL`, `CompletedAtUtc datetime2(3) NOT NULL`, `StatusCode varchar(40) NOT NULL`, `VisibilityScope varchar(32) NOT NULL`, `ObservedRows bigint NULL`, `ReturnedRows bigint NULL`, `IsLimited bit NOT NULL`, `ErrorNumber int NULL`, `ErrorMessage nvarchar(2048) NULL` |
| 7 `warnings` | `DatabaseId int NULL`, `DatabaseName sysname NULL`, `WarningCode varchar(64) NOT NULL`, `SourceKey varchar(64) NULL`, `Detail nvarchar(1000) NOT NULL` |

String-bearing fields above are `COLLATE SQL_Latin1_General_CP1_CS_AS`.
The `IsSchemabindingEnabled` column preserves the native catalog bit including
NULL when the catalog exposes it. If the catalog view does not expose that
field, the nullable result field is returned as NULL with a bounded
`SOURCE_UNAVAILABLE` warning for `SECURITY_POLICIES`. The product does not
invert, normalize or interpret the native bit. The database IDs, policy IDs
and object/column IDs are meaningful only with their database and capture
context.

Der gemeinsame `sourceStatus`- und `warnings`-Vertrag übernimmt Felder,
Bedeutung und Ausgabegrenzen des Datenbankprincipal-Moduls. Für diese
Procedure sind die Quellschlüssel `DATABASE_SELECTION`, `TARGET_SELECTION`,
`DATABASE_CONTEXT`, `SECURITY_POLICIES`, `SECURITY_PREDICATES` und
`MASKED_COLUMNS` vorgesehen. `SourceKind` ist für Kataloglesungen `NATIVE`,
für die Kandidatenauswahl `SELECTION`; `VisibilityScope` ist `VISIBLE_ONLY`
oder `UNPROVEN`. Eine erfolgreich gelesene Quelle erhält `AVAILABLE_LIMITED`;
eine nicht ausgeführte Quelle `SKIPPED`. Ein während der Aufnahme nicht mehr
verfügbares Ziel erhält `DATABASE_UNAVAILABLE`; ein anderer Katalogfehler
`SOURCE_UNAVAILABLE`. Auswahlfehler behalten die Statuswerte des gemeinsamen
Kandidatenhelpers. Ein erfolgreicher Kontext erhält `ContextStatus`=`AVAILABLE_LIMITED`;
ein nicht erreichbares Ziel `DATABASE_UNAVAILABLE`, ein anderer Fehler
`SOURCE_UNAVAILABLE`. Für `warnings.WarningCode` sind `OUTPUT_LIMIT`,
`SOURCE_UNAVAILABLE` und `DATABASE_UNAVAILABLE` vorgesehen. Fehler und
Timeouts werden nicht in leere erfolgreiche Mengen umgedeutet. Sichtbare leere
Ergebnisse bleiben `IsPartial=1` und belegen keine Vollständigkeit.

Die sortierte Ausgabe verwendet `databaseContext(DatabaseId)`,
`securityPolicies(DatabaseId, PolicyObjectId)`,
`securityPredicates(DatabaseId, PolicyObjectId, PredicateId)`,
`maskedColumns(DatabaseId, ObjectId, ColumnId)`,
`sourceStatus(DatabaseId, DatabaseName, SourceKey)` und
`warnings(DatabaseId, DatabaseName, WarningCode, SourceKey)`. `moduleStatus`
steht einmal pro Aufruf. Sein `RowCount` ist die Summe der tatsächlich
zurückgegebenen Zeilen aus den drei limitierbaren Inventaren. Jede
`sourceStatus`-Zeile hält `ObservedRows`, `ReturnedRows` und `IsLimited`
getrennt.

Der Katalogzugriff bleibt im Caller-Kontext. Die Microsoft-Quellen nennen
`ALTER ANY SECURITY POLICY` beziehungsweise objektbezogenes `VIEW DEFINITION`
für die Security-Policy-/Predicate-Metadaten sowie Tabellenberechtigung oder
`VIEW ANY DEFINITION` für `sys.masked_columns`. Diese Werte werden nicht als
Produktberechtigungsprüfung oder Vollständigkeitsnachweis verwendet; das Modul
vergibt keine Rechte. Eingeschränkte Sicht bleibt eine permanente Grenze.

## Status, Sichtbarkeit und Ausgabegrenzen

Der Bericht läuft ausschließlich im Caller-Kontext, liest nur die genannten
Katalogmetadaten und ändert keine Policy, Berechtigung oder Identität. Das
gemeinsame Fehler- und Transaktionsverhalten bleibt das des vorhandenen
Modulvertrags: reguläre OUTPUT-/RETURN-Rückgabe bei abgefangenen Fehlern,
`@Json=NULL` bei Vorprüfungs- und äußeren Fehlern, keine Übernahme von Commit
oder Rollback einer Caller-Transaktion. Die genaue Implementierungsfolge und
Wiederherstellung des Session-Locktimeouts folgen dem bestehenden
Datenbankprincipal- und Frameworkvertrag.

## Implementierung und Abnahmekriterien

Das Dossier konkretisiert das einzelne read-only-Modul einschließlich Installer, Navigator, Parameter- und Resultsetinventaren. Der integrierte V1-Scope ändert weder Spezialfeatureinventur noch Datenbankprincipal-Ausgabe. Die unabhängige Prüfung und die vorgeschriebenen Head-/Main-Gates erfolgten im regulären Lieferweg.

Der synthetische Vertrag deckt positive und leere Kataloge, Auswahl, globale Limits, TABLE- und JSON-Ausgabe, Callerzustand und Privacy-Sentinels ab. Die statischen Vertragsprüfungen binden Parameter, Resultsetinventar und Produktprojektionen. Das Modul erfasst caller-sichtbare Katalogmetadaten; ein leeres oder begrenztes Ergebnis bleibt `AVAILABLE_LIMITED`/partial und beweist keine Vollständigkeit.

## Primärquellen

- Microsoft Learn: [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17) — beschreibt Filter-/Block-Prädikate und deren Laufzeitwirkung; diese Laufzeitwirkung wird hier nicht geprüft.
- Microsoft Learn: [`sys.security_policies`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-policies-transact-sql?view=sql-server-ver17) — Policyzeilen und sichtbare Konfigurationsfelder. `is_schemabinding_enabled` wird als Rohwert ohne Normalisierung gespeichert.
- Microsoft Learn: [`sys.security_predicates`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-predicates-transact-sql?view=sql-server-ver17) — Predicate-Typ, Operation und Definition; die Definitionsspalte ist ausdrücklich ausgeschlossen.
- Microsoft Learn: [Dynamic Data Masking](https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking?view=sql-server-ver17) und [`sys.masked_columns`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-masked-columns-transact-sql?view=sql-server-ver17) — Maskingmetadaten; die Maskingfunktion wird nicht ausgegeben.
- Microsoft Learn: [Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17) — Katalogabfragen können sichtbare Teilmengen oder leere Ergebnisse liefern.

## Integrierter V1-Stand und Grenzen

PR #473 integriert den Vertrag mit 15 Parametern und sieben Resultsets. Der erfolgreiche SQL-Server-2025-Funktionslauf [40534609883](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40534609883) umfasst 139 Verträge jeweils exakt einmal, CL170, Deployment, Berechtigungs- und Regexfälle, Standalone-Execution-Plan sowie Containercleanup. Der erfolgreiche SQL-stdout wurde unterdrückt; ein separat exportierter PASS-Marker-Transcript für Vertrag 139 liegt nicht vor. Der quellgebundene Laufzeit-PASS bleibt belegt. Eine kontrollierte Timeout-Probe wurde nicht ausgeführt. Zusätzliche native SQL-Server-2019-/2022-Qualifikation fand nicht statt. Alle acht Head-Prüfungen und fünf Main-Prüfungen bestanden.

Die Evidenz umfasst synthetische positive und leere Kataloge, Auswahl, globale Limits, alle sieben unabhängigen physischen Schemas in TABLE- und JSON-Ausgabe, eingeschränkte Sichtbarkeit, isoliertes DENY 229, Caller-Erhaltung und eigens aufgeräumte Fixtures. Native `predicate_id` wird auf `security_predicate_id` abgebildet. Wenn die CI-Engine `is_schemabinding_enabled` nicht bereitstellt, liefert das Modul einen typisierten NULL-Wert mit fester Warnung. Diese Belege zeigen keine unbeschränkte Katalogsicht, effektive Rechte oder Enforcement.

Die 13 Head-CI-Kandidaten einschließlich Wiederholungen bleiben als kompakte Fehlerhistorie erhalten: 1–2 veraltete Zählstände; 3 Legacy-Lock; 4 Fixture-Syntax; 5 Legacy-CurrentRequests-Fehler 1222; 6 CREATE_SCHEMA-Batchfehler; 7 optionales Schemafeld 207; 8 statischer 950-Probe-/Predicate-ID-Fehler 207; 9 TABLE-Aggregat 57228; 10 Legacy-165-PrepareNameFilters-Fehler 1222 vor Vertrag 139; 11 gleiche Head-Diagnose mit TABLE-`moduleStatus`-Zählfehler 57236; 12 fixer Seed und vollständige Sieben-Schema-ABI vor Fixtureframeworkfehler 15151 im falschen Master-Kontext; 13 getrennter PASS-/Cleanup-Lauf. Diese Einträge beschreiben Fehlerfolgen und behaupten keine gemeinsame Ursache.

## Nächste getrennte OpenScope-Kandidaten

Das kontinuierliche WI-0010-Intake priorisiert für Schritt 39 ein Dossier zu MSDTC (`DISTRIBUTED_TRANSACTIONS`). Schritt 40 kann einen begrenzten SQL-sichtbaren Slice implementieren, falls das Dossier eine ausführbare Abgrenzung samt Datenquellen, Rechten, Datenschutz und Abnahme festlegt. Fehlt eine portable Evidenzbasis, bleibt die Umsetzung offen; DATABASE_MIRRORING ist danach der nächste getrennte Kandidat. Klassifikation und Agent-Proxies bleiben weitere offene Themen. Die Planung vergibt keine neue Kennung und behauptet keine Umsetzung.
