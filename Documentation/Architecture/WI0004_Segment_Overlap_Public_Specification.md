# WI-0004: Begrenzte Columnstore-Segmentüberlappung

**Status:** Vom Benutzer am 14. Oktober 2026 konkret freigegeben; Implementierung und Abnahme folgen getrennt.  
**Basis:** `monitor.USP_Columnstore` 1.1.0.  
**Umfang:** getrenntes lesendes Opt-in des bestehenden WI-0004; die gelieferte Ordering-Inventur bleibt erhalten.

## Diagnosevertrag

Die Erweiterung zählt vergleichbare Metadatenintervalle je Columnstore-Index, Partition und Spalte. Sie liefert weder Sortierqualität noch eine Performanceprognose, tatsächliche Segmentelimination oder eine Rebuildempfehlung. Eine deklarierte Order-Spalte ist keine Voraussetzung; die Ausgabe beschreibt nur die beobachteten Segmentgrenzen im gewählten Scope.

Zwei neue Parameter werden angehängt, damit die Position vorhandener Parameter erhalten bleibt:

| Parameter | Typ und Default | Vertrag |
|---|---|---|
| `@MitSegmentUeberlappung` | `bit = 0` | `1` aktiviert den neuen Pfad; `NULL` entspricht `0`. |
| `@MaxSegmenteAnalyse` | `int = 2000` | Bei aktiviertem Pfad sind nur Werte von 1 bis 10000 zulässig. `NULL`, 0 und negative Werte sind dort ungültig. Bei deaktiviertem Pfad wird dieser Parameter nicht ausgewertet. |

Der aktivierte Pfad verlangt `@AnalyseModus='GEZIELT'`, genau einen gültigen exakten Datenbanknamen in `@DatabaseNames` und genau einen gültigen zweigliedrigen Namen in `@FullObjectNames`. Die bestehenden bracket-aware Parser gelten. Datenbank-/Schema-/Objektpatterns und zusätzliche Schema-/Objektlisten sind für diesen Pfad ungültig. Es werden alle sichtbaren Columnstore-Indizes des exakt benannten Objekts berücksichtigt. Diese zusätzliche Begrenzung betrifft ausschließlich das aktivierte Opt-in.

Vor dem ersten Segmentzugriff müssen `COLUMNSTORE_CURRENT`, `COLUMNSTORE_DEEP` und die bestehende `@HighImpactConfirmed`-Policy erfüllt sein. Das Opt-in aktiviert weder Physical Stats noch die bisherige Segment- oder Dictionaryausgabe. Die bestehenden Flags behalten ihren eigenen Vertrag.

## Quelle, Vergleichbarkeit und Version

Der neue Pfad ist ab SQL Server 2022 verfügbar. Auf SQL Server 2019 wird für ihn `UNAVAILABLE_VERSION` gemeldet, ohne neue Segmentabfragen oder Zugriff auf neuere Spalten. Die bestehenden anderen Quellen bleiben ausgabefähig. Fehler der vorgelagerten Parameter-, Filter- und Gruppenprüfung haben Vorrang vor einem Versionsfallback.

Eine einzige lokale Quellenaufnahme verbindet `sys.column_store_segments` über beide nativen Partitionskennungen mit `sys.partitions`, dem gewählten Objekt/Index und `sys.columns`/`sys.types`. Identität ist `(partition_id, hobt_id, column_id, segment_id)` innerhalb der gewählten Datenbank. Doppelte oder unvollständige Identitäten verwerfen die gesamte neue Aufnahme ohne Gruppenwerte; Zeilen werden weder still dedupliziert noch vor Sentinel-/Gruppenprüfung ausgefiltert. databaseStatus meldet dafür AVAILABLE_LIMITED, IsPartial=1 und den technischen Detailgrund INCONSISTENT_SEGMENT_IDENTITY; ErrorNumber und ErrorMessage bleiben NULL, weil kein nativer SQL-Fehler erhoben wurde. Dieser technische Befund hat innerhalb der materialisierten N+1-Zeilen Vorrang vor der Limitentscheidung. Fehlende optionale Spalten-/Typnamen werden über LEFT JOIN erhalten und als nicht vergleichbar erfasst. Die Aufnahme liest keine Tabellenzeilen oder Dictionaries. Intervallgrenzen bleiben interne Rechenwerte und werden nicht ausgegeben.

Die erste Vergleichsfläche ist bewusst begrenzt:

- Die Basistypen `bit`, `tinyint`, `smallint`, `bigint` und `money` verwenden bei Encoding 1 oder 2 gültige native `min_data_id`-/`max_data_id`-Werte. Der Vergleich bleibt numerisch als vorzeichenbehaftetes `bigint`; eine Umwandlung in unsigned sortierte Binärwerte ist ausgeschlossen. Aliasdatentypen werden nach ihrem Basistyp klassifiziert.
- Die Basistypen `binary`, `varbinary`, `char`, `nchar`, `varchar` und `nvarchar` verwenden bei Encoding 3 oder 5 gültige native `min_deep_data`-/`max_deep_data`-Werte. LOB-Spalten sind ausgeschlossen. Verglichen wird ausschließlich innerhalb derselben Spalte/Partition. Stringgruppen verlangen denselben nicht-NULL Segment-Collationwert; unterschiedliche oder fehlende Werte machen die Gruppe unvollständig. Es wird kein interner Collationwert als SQL-Collationname interpretiert.
- Andere Typen oder Encodings, NULL-Grenzen, `minimum > maximum`, nicht-positive native `row_count` oder inkonsistente Bereichsmetadaten werden als nicht vergleichbar erfasst. NULL-Grenzen beweisen keinen Berechtigungsfehler. Nur ein tatsächlicher nativer Fehler begründet einen entsprechenden Fehlerstatus.

Die Auswahl stützt sich auf das von Microsoft verlinkte Beispiel, ist jedoch ein eigener enger Produktvertrag. Interne Katalogfelder werden nicht als allgemeiner oder stabiler Decoder aller SQL-Datentypen dargestellt. Der native Nachweis muss die tatsächlich unterstützten Klassen prüfen; synthetische Projektionen ersetzen keine positive native Segmentquelle.

## Mengen- und Zeitgrenzen

Es werden höchstens `@MaxSegmenteAnalyse + 1` Segmentzeilen für den gesamten exakt gewählten Objekt-Scope materialisiert. Die zusätzliche Zeile ist nur ein Überschreitungssentinel. Bei Überschreitung wird keine Überlappung berechnet und `segmentOverlap` bleibt leer. `databaseStatus` meldet `AVAILABLE_LIMITED`, `IsPartial=1` und den technischen Grund `SEGMENT_LIMIT_EXCEEDED`; die beobachtete Mindestmenge ist die Grenze plus eins, kein vollständiger Katalogcount. Bestehende andere Ergebnisse bleiben erhalten.

Diese Begrenzung schützt Materialisierung und nachfolgende Berechnung. Sie garantiert weder eine maximale Zahl intern gelesener Katalogseiten noch eine CPU-, Speicher- oder Echtzeitdeadline. Scopeprüfung, Katalogzugriff und gegebenenfalls Sortierung bleiben kostenwirksam. `@LockTimeoutMs` und Callerrestaurierung behalten den vorhandenen Vertrag. Kein Retry, Indexumbau oder Wartungseingriff wird eingeführt.

Bei einer Aufnahme innerhalb der Grenze werden Gruppen aus allen tatsächlich aufgenommenen Zeilen gebildet. Enthält eine Gruppe auch nur eine nicht vergleichbare Zeile, bleiben beide Paarmetriken für diese ganze Gruppe NULL. Vergleichbare Teilmengen werden nicht als vollständige Gruppenwerte ausgegeben. Andere vollständig vergleichbare Gruppen können weiterhin Werte liefern. Eine erfolgreiche leere sichtbare Segmentquelle meldet `AVAILABLE` mit null Zeilen; dies beweist keine globale Featureabwesenheit.

Die Aggregation verwendet sortierte Endpunktzählungen oder ein gleichwertiges Verfahren mit linear begrenzter Materialisierung. Ein unbeschränkter quadratischer Pair-Join gehört nicht zum Vertrag. Gleichzeitige Loads/DDL können das read-only Katalogbild verändern; die Aufnahme ist keine transaktionale Zusicherung eines unveränderlichen Objektzustands.

## Exakte Paarsemantik

Vergleiche werden nur innerhalb derselben Datenbank, desselben Objekt-/Index-/Partitions-/Spalten-Schlüssels durchgeführt. Für zwei verschiedene, gültige Segmente `a` und `b` gelten folgende disjunkte Definitionen:

- `StrictOverlapPairCount` zählt ungeordnete Paare mit `a.minimum < b.maximum AND b.minimum < a.maximum`.
- `BoundaryTouchPairCount` zählt ungeordnete Paare ohne diese strikte Bedingung, aber mit `a.maximum = b.minimum OR b.maximum = a.minimum`.

Ein Paar wird genau einmal gezählt, ein Segment nie gegen sich selbst. Gleiche Grenzen, doppelte Bereichswerte, Punktintervalle und negative numerische Werte bleiben erhalten. Beispielsweise berühren sich `[1,2]` und `[2,3]`, während `[1,3]` und `[2,4]` strikt überlappen. Ein Punkt `[2,2]` innerhalb `[1,3]` erfüllt die strikte Bedingung; zwei Punkte `[2,2]` sind eine Berührung. Diese technische Definition bewertet potentielle Bereichsüberschneidung und beweist keine gemeinsamen Tabellenwerte.

Eine vollständig vergleichbare Gruppe mit genau einem Segment liefert beide Metriken als 0. Eine nicht vergleichbare oder abgeschnittene Quelle liefert dafür NULL beziehungsweise keine Gruppenzeile, niemals ersatzweise 0. Es gibt keine Prozentkennzahl namens Order Quality.

## Native Ausgabe `segmentOverlap`

Eine Zeile beschreibt eine tatsächlich beobachtete Objekt-/Index-/Partitions-/Spaltengruppe. Das native Schema hat folgende Reihenfolge; alle Textspalten verwenden die bestehende explizite Framework-Collation.

| Spalte | Nativer Typ | NULL |
|---|---|---|
| `DatabaseName` | `sysname` | nein |
| `SchemaName` | `sysname` | nein |
| `ObjectName` | `sysname` | nein |
| `ObjectId` | `int` | nein |
| `IndexId` | `int` | nein |
| `IndexName` | `sysname` | ja |
| `PartitionNumber` | `int` | nein |
| `ColumnId` | `int` | nein |
| `ColumnName` | `sysname` | ja |
| `SystemTypeName` | `sysname` | ja |
| `ObservedSegmentCount` | `bigint` | nein |
| `ComparableSegmentCount` | `bigint` | nein |
| `UncomparableSegmentCount` | `bigint` | nein |
| `StrictOverlapPairCount` | `bigint` | ja |
| `BoundaryTouchPairCount` | `bigint` | ja |
| `SourceStatus` | `varchar(40)` | nein |
| `IsPartial` | `bit` | nein |
| `ReasonCode` | `varchar(60)` | ja |
| `CollectionTimeUtc` | `datetime2(3)` | nein |

`ComparableSegmentCount + UncomparableSegmentCount = ObservedSegmentCount`. Nur vollständig vergleichbare Gruppen erhalten `SourceStatus='AVAILABLE'`, `IsPartial=0`, NULL-Reason und nicht-NULL Paarmetriken. Unvollständige Gruppen erhalten `AVAILABLE_LIMITED`, `IsPartial=1`, `INCOMPLETE_RANGE_METADATA` und NULL-Paarmetriken. Diese Gruppe enthält weiterhin die beobachteten Counts. Quellenfehler ohne vertrauenswürdige Gruppenidentität liefern keine erfundenen Gruppenzeilen und werden in `databaseStatus` erfasst.

## Ausgabemodi und Defaultkompatibilität

Bei ausgeschaltetem Opt-in bleiben Parameterverhalten und Ausgabe der vorhandenen RAW-Resultsets, TABLE-Mengen `rowgroups`/`ordering`, JSON-Schema 1 einschließlich der bisherigen Arrays und CONSOLE unverändert. Insbesondere wird kein zusätzliches leeres Resultset oder JSON-Feld ausgegeben.

Bei eingeschaltetem Opt-in hängt RAW genau eine `segmentOverlap`-Menge an die vorhandenen Mengen an. TABLE erlaubt zusätzlich die Zuordnung `segmentOverlap` in `@ResultTablesJson`; vorhandene Zuordnungen bleiben gültig. NONE unterdrückt weiterhin fachliche Resultsets. JSON verwendet im aktivierten Pfad Schema 2 mit dem zusätzlichen Array `segmentOverlap`, auch bei begrenzter, leerer oder versionsbedingt nicht verfügbarer Quelle. CONSOLE liefert weiterhin genau ein Resultset und richtet es im aktivierten Pfad auf `segmentOverlap` aus. Ohne aktiviertes Opt-in bleibt das neue TABLE-Mapping ungültig.

Die neue Menge wird deterministisch nach `DatabaseName, SchemaName, ObjectName, IndexId, PartitionNumber, ColumnId` sortiert. `@MaxZeilen` begrenzt nach dieser Ordnung die ausgegebenen Gruppen: NULL/0 sind vollständig innerhalb der separaten Segmentanalysegrenze, negativ ist ungültig. Der Ausgabeausschnitt verändert keine Segmentcounts oder Paarberechnung seiner enthaltenen Gruppen. Die bestehende Modul-RowCount-Logik zählt die tatsächlich ausgegebenen neuen Gruppen zusätzlich. Gleichaufrufbezogene physische TABLE-/JSON-Parität bleibt exakt.

## Fehler- und Partialitätsmatrix

Die neue Quelle ergänzt den vorhandenen Datenbankstatus, ersetzt aber keine vorhandene Quelle oder ihre Fehlerpriorität. Native Fehlernummer und native Fehlermeldung bleiben nach dem vorhandenen Laufzeitvertrag diagnostisch erhalten. Repositoryartefakte erhalten keine realen Logs oder Nutzdaten.

| Zustand des neuen Pfads | Neue Gruppen | `databaseStatus` für diese Quelle |
|---|---|---|
| Ungültiger aktivierter Parameter oder Scope | keine | `INVALID_PARAMETER`; keine neue Segmentaufnahme |
| Gruppen-/High-Impact-Gate nicht erfüllt | keine | vorhandener Gate-Status; keine neue Segmentaufnahme |
| SQL Server 2019 nach gültigem Gate | keine | `UNAVAILABLE_VERSION`; neuer dynamischer Quellenzugriff entfällt |
| Erfolgreich sichtbar leer | keine | `AVAILABLE`, RowCount 0 |
| Doppelte oder unvollständige native Identität | keine; gesamte neue Aufnahme verworfen | AVAILABLE_LIMITED, IsPartial 1, INCONSISTENT_SEGMENT_IDENTITY; ErrorNumber/ErrorMessage NULL |
| Segmentgrenze überschritten | keine | `AVAILABLE_LIMITED`, IsPartial 1, `SEGMENT_LIMIT_EXCEEDED` |
| Gruppen mit fehlender Vergleichbarkeit | beobachtete Gruppen, betroffene Metriken NULL | `AVAILABLE_LIMITED`, IsPartial 1 |
| Tatsächlicher nativer Fehler | keine neuen Gruppen aus dieser fehlgeschlagenen Aufnahme | bisheriges Mapping: Rechtefehler `DENIED_PERMISSION`, 1222 `TIMEOUT`, 207/208 `UNAVAILABLE_OBJECT`, sonst `ERROR_HANDLED`; IsPartial 1 |

Bei gemischten Gruppen bleibt jede Gruppenaussage separat gebunden. Bestehende Gesamtstatusbildung wird weiterverwendet; ein neues erfolgreiches Resultset verdeckt keinen früheren Quellenfehler.

## Geplante Abnahme nach Vertragsfreigabe

Die Planung ist ein einzelner kohärenter Änderungsschritt mit einem Implementierer und höchstens einem unabhängigen Reviewer. Kosten sind UNKNOWN. Bisherige WI-0005/0006/0007/0009- und Mailbudgets werden nicht wieder geöffnet. Ein eigener endlicher Runtimeplan wird erst nach Vertragsfreigabe und aktueller Lab-/Quellenbindung reserviert.

Die impact-basierte Primärprüfung läuft auf SQL Server 2025. Ein nativer SQL-2022-Fall prüft die tatsächliche erste unterstützte Katalogfläche, ein SQL-2019-Fall den Fallback. Zusätzliche Engines laufen nur nach erfolgreicher Primärprüfung und bei bereits verfügbarer freigegebener Infrastruktur; keine Installation oder Imagebeschaffung folgt aus diesem Entwurf. Bestehende Ordering-Nachweise werden nur am gleichen unveränderten Binding wiederverwendet.

Erforderlich sind eigene positive Segmentquellen für numerische und Deep-Metadaten sowie unabhängige native Aufnahme vor Assertion. Gegenproben binden negative Zahlen, Extremwerte, gleiche Grenzen, Punktintervalle, Grenzberührung, gemischte Encodings, NULL-Grenzen, ungleiche Collationwerte, Gruppen-/Partitionsisolation, 1/N/N+1-Segmentgrenzen und getrennte Ausgabegrenzen. Die Paardefinition wird für kleine Gegenproben zusätzlich durch eine unabhängige vollständige Paarenumeration geprüft; die Produktberechnung verwendet den begrenzten Algorithmus. Physische Schemas/JSON-Parität, RAW-/TABLE-/CONSOLE-/NONE-Verhalten, ausgeschaltete Defaults, Gruppen-/High-Impact-/Parameter-/Versionspfade, Callerrestaurierung, unveränderte Quellen und ausschließlich eigener Cleanup sind getrennte Pflichtgates. Geänderte Inputs erhalten frische Pflichtprüfungen; unveränderte erfolgreiche Prüfungen werden nicht erneut ausgeführt.

## Primärquellen und Aussagegrenzen

- [Microsoft: sys.column_store_segments](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-column-store-segments-transact-sql?view=sql-server-ver17): Metadatenfelder, Rechte, interne Werte und neue Deep-Grenzen.
- [Microsoft: Ordered Columnstore](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/ordered-columnstore-indexes?view=sql-server-ver17): begrenzte Vergleichbarkeit und Abhängigkeit der Abfragewirkung vom Workload.
- [Microsoft-Beispiel mit ausgewählten Typen/Encodings](https://github.com/microsoft/sql-server-samples/blob/master/samples/features/columnstore/ordered-columnstore/order-quality.sql): Herkunft der engen Vergleichsklassen; dessen Binärnormalisierung, Rangtie-Verhalten und Prozenturteil werden nicht ungeprüft übernommen.

Quellen gelesen am 14. Oktober 2026. Sie ersetzen weder die konkrete Vertragsfreigabe noch die spätere native Qualifikation.
