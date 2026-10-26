# Sichtbares Inventar für Row-Level Security und Dynamic Data Masking

**Stand:** 26. Oktober 2026.
**Status:** `IMPLEMENTED_UNREVIEWED`; Produkt- und Testkandidat in Schritt 35. Unabhängiger Review und Laufzeitprüfung stehen aus.
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
The `IsSchemabindingEnabled` column preserves the catalog bit including NULL;
the product does not invert, normalize or interpret it. The database IDs,
policy IDs and object/column IDs are meaningful only with their database and
capture context.

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

## Erster Implementierungsschritt und Abnahmekriterien

Der nächste Produkt-PR kann das hier konkretisierte einzelne read-only-Modul
mit Installer, Navigator, Parameter- und Resultsetinventaren umsetzen. Der
Scope dieses Dossiers enthält noch keinen Produktcode und keine neue Freigabe-
oder Bestätigungsbedingung. Die unabhängige Prüfung und vorgeschriebenen
Head-/Main-Gates bleiben Teil des bestehenden Lieferwegs. Die Implementation
ändert die Spezialfeatureinventur und Datenbankprincipal-Ausgabe nicht.

Die erste fokussierte Testauswahl soll synthetische positive und leere
Katalogfälle, getrennte Policy-/Predicate-/Masking-Quellenfehler,
eingeschränkte Metadatensicht mit erhaltenem `AVAILABLE_LIMITED`/Partialstatus,
exakte Datenbankauswahl, Zeilenlimit und Caller-/Transaktionserhaltung
abdecken. Unabhängige Schemaprüfungen müssen alle drei Feldmengen und alle
Ausgabearten binden. Privacyprüfungen müssen sicherstellen, dass weder
`predicate_definition` noch `masking_function` noch Tabellenwerte ausgegeben
werden. Der Produkt- und Fixturekandidat ist hinzugefügt. Der lokale SQL-Test,
der unabhängige Review und das erforderliche SQL-Server-2025-Head-Gate sind
noch nicht abgeschlossen.

## Primärquellen

- Microsoft Learn: [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17) — beschreibt Filter-/Block-Prädikate und deren Laufzeitwirkung; diese Laufzeitwirkung wird hier nicht geprüft.
- Microsoft Learn: [`sys.security_policies`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-policies-transact-sql?view=sql-server-ver17) — Policyzeilen und sichtbare Konfigurationsfelder. `is_schemabinding_enabled` wird als Rohwert ohne Normalisierung gespeichert.
- Microsoft Learn: [`sys.security_predicates`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-predicates-transact-sql?view=sql-server-ver17) — Predicate-Typ, Operation und Definition; die Definitionsspalte ist ausdrücklich ausgeschlossen.
- Microsoft Learn: [Dynamic Data Masking](https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking?view=sql-server-ver17) und [`sys.masked_columns`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-masked-columns-transact-sql?view=sql-server-ver17) — Maskingmetadaten; die Maskingfunktion wird nicht ausgegeben.
- Microsoft Learn: [Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17) — Katalogabfragen können sichtbare Teilmengen oder leere Ergebnisse liefern.

## Nächster ausführbarer Schritt

Der Produktkandidat und die öffentliche Referenz bilden das festgelegte
V1-Schema ab. Der synthetische Laufzeitvertrag prüft positive und leere
Kataloge, Auswahl, globale Limits, Ausgabearten, Callerzustand und
Privacy-Sentinels. Der statische Vertragsvalidator bindet Parameter,
Resultsetinventar und Produktprojektionen. Diese Prüfungen wurden lokal noch
nicht ausgeführt. Unabhängiger Review, SQL-Server-2025-Head-CI und reguläre
PR-Gates bleiben erforderlich; Laufzeitevidenz liegt noch nicht vor.

\n
