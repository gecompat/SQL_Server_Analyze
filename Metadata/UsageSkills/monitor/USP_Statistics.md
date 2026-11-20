---
skill_format_version: "1.0.0"
name: "monitor.USP_Statistics"
schema_name: "monitor"
object_name: "USP_Statistics"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Analysiert Statistikdefinitionen, letzte Aktualisierung, Stichprobe, Modification Counter sowie versionsadaptiv die Herkunft persistierter Statistiken auf lesbaren Replikaten; vollständige ungezielte Scans sind gruppengeschützt."
source_path: "Code/03_ObjectIndex/040_USP_Statistics.sql"
---

# monitor.USP_Statistics

## Zweck und Einsatz

Analysiert Statistikdefinitionen, letzte Aktualisierung, Stichprobe, Modification Counter sowie versionsadaptiv die Herkunft persistierter Statistiken auf lesbaren Replikaten; vollständige ungezielte Scans sind gruppengeschützt.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

Je Datenbank sys.stats, sys.stats_columns, sys.columns, sys.objects, sys.tables, sys.schemas, sys.dm_db_stats_properties, sys.fn_hadr_is_primary_replica, auf SQL Server 2025 capability-geprüfte sys.stats-Spalten sowie optional sys.dm_db_incremental_stats_properties.

Metadata Visibility und SELECT auf Statistikspalten bzw. Eigentum/db_owner/db_ddladmin/sysadmin für dm_db_stats_properties.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @SchemaNamePattern | nvarchar(4000) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @ObjectNamePattern | nvarchar(4000) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @StatisticsNames | nvarchar(max) | nein | NULL |
| @StatisticsNamePattern | nvarchar(4000) | nein | NULL |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @MinModificationPercent | decimal(9,2) | nein | 0 |
| @MinAlterTage | int | nein | 0 |
| @MitIncrementellenDetails | bit | nein | 0 |
| @MaxZeilen | int | nein | 10000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder eine bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder eine nach äußerem Trimmen leere Eingabe bedeutet keine explizite Auswahl; der Kandidatenhelfer wählt alle zulässigen sichtbaren Online-Benutzerdatenbanken, soweit kein Pattern einschränkt. Pipe trennt nur außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt. Leere Elemente, ungültige SQL-Namen, case-sensitive Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Eine nichtleere Liste ist mit einem nicht-NULL-Datenbankpattern exklusiv.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt deren Aufnahme, soweit sichtbar und online. NULL ist im Datenbankkandidatenhelfer ungültig. Beim Binden zu bit konvertierbare numerische Nichtnullwerte werden zu 0 oder 1 konvertiert.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Datenbanknamen-Pattern. NULL deaktiviert es; leer oder nach Präfixentfernung leer ist ungültig. Äußere Leerzeichen werden getrimmt; die Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt, ohne Präfix gilt LIKE; danach wird nicht erneut getrimmt. LIKE verwendet %, _ und [...] mit case-sensitiver Framework-Collation. regex: verwendet Flag c, regexi: Flag i. Für Datenbanknamen prüft der Kandidatenhelfer Regex-Unterstützung im Installationsdatenbankkontext; erforderlich sind SQL Server 2025 und Compatibility Level 170. Nicht mit einer nichtleeren @DatabaseNames-Liste kombinieren.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. SQL-bit-Bestätigung mit 0 oder 1; 0 bleibt 0, von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. STATISTICS_TARGETED verlangt kein Gruppengate. VOLL oder @MitIncrementellenDetails=1 aktiviert zusätzlich CATALOG_DEEP und verlangt ausdrücklich 1; 0 bestätigt diesen Pfad nicht. NULL ist im normalen Datenbankauswahl-/Deep-Prüfpfad INVALID_PARAMETER. Bestätigung wird vor der Gruppen-/Tokenberechtigung geprüft: 1 verleiht keine Rolle und keine SQL-Rechte; ohne Berechtigung folgt DENIED_GROUP.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere oder nur aus Leerzeichen bestehende Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen validiert und case-sensitive verglichen. Doppelte Werte derselben Namensart und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @SchemaNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Schemanamen. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor der Erkennung eines Präfixes like:, regex: oder regexi: entfernt; danach bleibt das Pattern unverändert. Ohne Präfix und mit like: gilt case-sensitives SQL-LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex wird inline in der jeweiligen Quelldatenbank ausgeführt; dafür gibt es keine eigene Versionsvorprüfung, sodass fehlende Unterstützung als datenbankweise isolierter Fehler auftreten kann. Nicht mit nicht-NULL @SchemaNames kombinieren.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, mit höchstens 128 Zeichen geprüft und case-sensitive verglichen. Doppelte Objektnamen und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit @ObjectNamePattern kombinieren; bei nicht-NULL @FullObjectNames ist diese Kombination ebenfalls ungültig.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern. NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere Leerzeichen werden vor dem Erkennen von like:, regex: oder regexi: entfernt; danach wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Feldregex läuft inline je Quelldatenbank ohne eigene Versionsvorprüfung; fehlende Unterstützung kann als isolierter Datenbankfehler erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. Bei einem Datenbankteil ist das Schema erforderlich; vierteilige Linked-Server-Bezüge sind unzulässig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt und nach PARSENAME/sysname-Grenzen geprüft. NULL bedeutet kein Filter; ein leerer nvarchar-String ist EMPTY_LIST, Leerzeichen ergibt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemanamen bleiben offen. Duplikate und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @SchemaNames oder @ObjectNames kombinieren.

**@StatisticsNames:** @StatisticsNames nvarchar(max); Default: NULL. Exakte einteilige Statistiknamen als bracket-aware Pipe-Liste. NULL bedeutet kein exakter Filter; eine leere Nicht-NULL-Liste ist ungültig. Pipe trennt außerhalb von [...], ]] maskiert ]; Elemente werden getrimmt, als einteilige SQL-Namen bis 128 Zeichen validiert und case-sensitive verglichen. Duplikate sowie Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Nicht mit nicht-NULL @StatisticsNamePattern kombinieren.

**@StatisticsNamePattern:** @StatisticsNamePattern nvarchar(4000); Default: NULL. Optionales Statistiknamen-Pattern. NULL deaktiviert den Filter; leere Eingabe oder leeres Präfix ist ungültig. Äußere Leerzeichen werden vor Erkennung von like:, regex: oder regexi: getrimmt; der Rest wird nicht erneut getrimmt. Ohne Präfix/like: gilt case-sensitives LIKE mit %, _ und [...]; regex: nutzt Flag c, regexi: Flag i. Regex wird im jeweiligen Quelldatenbankbatch ausgewertet und hat keine separate Versionsvorprüfung; Fehler können pro Datenbank isoliert werden. Nicht mit nicht-NULL @StatisticsNames kombinieren. Ein Statistikpattern allein erfüllt den GEZIELT-Filter von USP_Statistics nicht; ein zusätzlicher Schema-/Objektfilter ist erforderlich. Das gilt auch beim weitergereichten Aufruf aus der Verteilungsanalyse.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. Text wird getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind ausschließlich GEZIELT und VOLL; NULL wird als GEZIELT behandelt. Bei USP_Statistics verlangt GEZIELT mindestens eine exakte Schema-/Objekt-/Statistikliste, @FullObjectNames oder ein Schema-/Objektpattern; nur eine Datenbank genügt nicht. VOLL prüft CATALOG_DEEP. Die Verteilungsanalyse prüft CATALOG_DEEP unabhängig vom Modus; GEZIELT verlangt dort einen Objekt-, Schema- oder Statistikfilter. Ein gültiger Scope bleibt erforderlich.

**@MinModificationPercent:** @MinModificationPercent decimal(9,2); Default: 0. Mindestanteil geänderter Zeilen relativ zur Statistikzeilenzahl, decimal(9,2)-Wert von 0 bis 100 einschließlich; bei der Parameterbindung wird auf zwei Nachkommastellen konvertiert. Werte außerhalb dieses Bereichs werden als INVALID_PARAMETER abgewiesen; NULL ist nicht ausdrücklich abgewiesen und führt wegen des SQL-NULL-Vergleichs nicht zu dieser Bereichsverletzung. 0 lässt alle passenden Statistiken zu; höhere Werte filtern nach ModificationPercent. Bei Nullbasis wird der Anteil zu NULL und der Filterausdruck fällt aus der Auswahl.

**@MinAlterTage:** @MinAlterTage int; Default: 0. Nichtnegative ganze Zahl von 0 bis 2147483647. 0 deaktiviert den Altersfilter; positive Werte vergleichen DATEDIFF(DAY,last_updated,SYSDATETIME()) mit dieser Untergrenze. Gezählt werden überschrittene Kalendertagsgrenzen gemäß der Serveruhr, nicht volle 24-Stunden-Perioden. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck als UNKNOWN; dann erfüllen nur Zeilen mit last_updated IS NULL den gesonderten Alterszweig. Solche NULL-Zeitpunkte passieren auch bei positiver Grenze, ohne dadurch ein gemessenes Alter zu belegen.

**@MitIncrementellenDetails:** @MitIncrementellenDetails bit; Default: 0. Bit-Schalter: 0 lässt das zusätzliche Partitionsresultset und JSON-Array aus; 1 liest nach der Hauptabfrage inkrementelle Details nur für bereits materialisierte Ergebnisstatistiken mit IsIncremental=1. Aktivierung prüft CATALOG_DEEP und braucht gegebenenfalls die Gruppenfreigabe. NULL löst diese Zusatzabfrage nicht aus. Die Obergrenze gilt je Datenbank und Detailquery; fehlgeschlagene Detailquellen werden datenbankweise als Teilfehler markiert, während Basisstatistiken erhalten bleiben.

**@MaxZeilen:** @MaxZeilen int; Default: 10000. Nichtnegative int-Obergrenze von 0 bis 2147483647. NULL oder 0 wird intern als unbegrenzt behandelt; negative Werte sind ungültig. Die TOP-Grenze gilt je Datenbank und je Haupt- beziehungsweise Detailabfrage, nicht global. Ergebnisse werden vor TOP nach ModificationPercent absteigend priorisiert; bei mehreren Datenbanken kann die Gesamtzahl die angegebene Zahl überschreiten.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Ganzzahlige Wartezeit für Metadatenlocks in Millisekunden, zulässig von 0 bis 60000 einschließlich. 0 wartet nicht; Werte außerhalb des Bereichs sind ungültig. Der Wert wird nur in isolierten dynamischen Datenbankbatches gesetzt. SET-Werte des Prozedur- oder dynamischen Batchscopes werden bei Rückkehr zurückgenommen; der eigenständige SET-Batch belegt keine weiterreichende Sessionwirkung.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind CONSOLE, RAW, TABLE und NONE. CONSOLE liefert beschriftete Status- und Fachresultsets; RAW liefert dieselben Statusbereiche mit technischen Fachdaten; TABLE schreibt das typisierte Resultset statistics nach erfolgreichem Vorab-Preflight; NONE unterdrückt Resultsets. NULL/leer wird ungültig. @ResultTablesJson darf nur bei TABLE nichtleer sein. Die Konsolenausgabe erzeugt bei leerer Fachquelle eine verständliche Leerzeile.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. JSON-Konfiguration der lokalen TABLE-Zieltabelle; nur bei @ResultSetArt=TABLE darf der bereinigte Inhalt nichtleer sein. Für TABLE ist die Konfiguration erforderlich und muss den zulässigen Resultnamen statistics auf eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte abbilden. NULL/leer bei TABLE führt zum Preflightfehler; ungültige Ziele werfen einen Fehler vor der fachlichen Analyse. Bei anderen Ausgabearten ist ein nichtleerer Wert ein Fehler.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter: 0 erzeugt kein JSON und lässt @Json nach seiner anfänglichen NULL-Zuweisung NULL; 1 erzeugt das JSON mit meta, statistics, incrementalStatistics und databaseStatus. NULL ist nicht als ungültig abgefangen und aktiviert die IF-Bedingung nicht.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter vom Typ nvarchar(max). Optional mit einer nvarchar(max)-OUTPUT-Variablen zu binden; eine fehlende Bindung verhindert den Prozeduraufruf nicht. Wird bei Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält er das JSON-Objekt mit den Schlüsseln meta, statistics, incrementalStatistics und databaseStatus; sonst bleibt er NULL. Meta enthält resultName, schemaVersion=2, generatedAtUtc, statusCode, isPartial und rowCount.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für eine zusätzliche Warnmeldung via RAISERROR mit Severity 10 und NOWAIT. 1 gibt sie bei Status ungleich AVAILABLE aus; 0 unterdrückt diese Meldung. NULL aktiviert die IF-Bedingung nicht. Der Schalter ändert Status, Resultsets und JSON nicht.

**@Hilfe:** @Hilfe bit; Default: 0. SQL-bit-Schalter: 1 druckt die PRINT-Hilfe und kehrt vor den eigentlichen Statistikabfragen und der Ergebniskonstruktion zurück; 0 führt den normalen Ablauf fort. Von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1, NULL aktiviert Hilfe nicht. Patternparsing, Namensfilter, Datenbankkandidaten und ein bedingt aktiviertes Deep-Gate laufen bereits davor. Auch TABLE-Preflight und die Abweisung einer nichtleeren TABLE-Zuordnung bei anderer Ausgabeart erfolgen vor Hilfe; Hilfe ist daher kein voraussetzungsloser Filter-/Berechtigungs-Bypass.

## Resultate und Ausgabe

1. Modulstatus. 2. Status je Datenbank. 3. Statistikübersicht. 4. optionale inkrementelle Partitionsdetails.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| statistics | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL, [StatisticsId] int NOT NULL,[StatisticsName] sysname NOT NULL,[IsIndexStatistics] bit NOT NULL,[IsAutoCreated] bit NULL,[IsUserCreated] bit NULL, [IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) NULL,[NoRecompute] bit NULL,[IsIncremental] bit NULL,[HasPersistedSample] bit NULL, [IsTemporary] bit NULL,[CurrentReplicaRole] varchar(40) NULL,[CurrentReplicaRoleStatus] varchar(40) NOT NULL,[ReplicaRoleId] tinyint NULL,[ReplicaRoleDesc] nvarchar(60) NULL,[ReplicaName] sysname NULL,[ReplicaMetadataStatus] varchar(40) NOT NULL, [StatisticsColumns] nvarchar(max) NULL,[LastUpdated] datetime2 NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[SamplePercent] decimal(9,4) NULL, [Steps] int NULL,[UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,4) NULL, [PersistedSamplePercent] float NULL,[DaysSinceLastUpdate] int NULL,[VisibilityOrState] varchar(40) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @MaxZeilen=100, @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_Statistics

Inventarisiert sichtbare Statistikdefinitionen und Update-Properties im ausgewählten Datenbank- und Objektumfang.

GEZIELT verlangt eine exakte Schema-, Objekt- oder Statistikliste, einen vollständigen Objektbezug oder ein Schema-/Objektpattern. VOLL und aktivierte inkrementelle Details prüfen zusätzlich CATALOG_DEEP.

CONSOLE liefert beschriftete Fachresultate; RAW liefert technische Resultsets; TABLE schreibt statistics; NONE unterdrückt Resultsets. JSON wird unabhängig über @JsonErzeugen erzeugt.

Beispiel: EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_Statistics
Version      : 1.2.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Analysiert Statistikdefinitionen, letzte Aktualisierung,
               Stichprobe, Modification Counter sowie versionsadaptiv die
               Herkunft persistierter Statistiken auf lesbaren Replikaten;
               vollständige ungezielte Scans sind gruppengeschützt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.stats, sys.stats_columns, sys.columns,
               sys.objects, sys.tables, sys.schemas,
               sys.dm_db_stats_properties, sys.fn_hadr_is_primary_replica,
               auf SQL Server 2025 capability-geprüfte sys.stats-Spalten sowie
               optional sys.dm_db_incremental_stats_properties.
Parameter    : Die folgende Signatur enthält die öffentlichen Parameter und
               Defaults. Die eingebettete PRINT-Hilfe beschreibt jede
               Eingabeform, NULL-/Leerwertregel, Grenze und feste Option.
Resultsets   : 1. Modulstatus. 2. Status je Datenbank. 3. Statistikübersicht. 4. optionale inkrementelle Partitionsdetails.
Berechtigung : Metadata Visibility und SELECT auf Statistikspalten bzw. Eigentum/db_owner/db_ddladmin/sysadmin für dm_db_stats_properties.
Eigenlast    : Gezielte Abfrage moderat; VOLL und inkrementelle Details durch CATALOG_DEEP/Cross-Database geschützt und begrenzt.
Locking      : READUNCOMMITTED-Kataloge, LOCK_TIMEOUT und je Datenbank isolierter dynamischer Batch.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @SchemaNamePattern=N'dbo', @ObjectNamePattern=N'FactSales';
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @MinModificationPercent=10;
  EXEC monitor.USP_Statistics @Hilfe=1;
Änderungen   : 1.2.0 - SQL25-004 erhält IsTemporary, aktuelle Replica-Rolle
                         und die Herkunftsfelder replica_role_id,
                         replica_role_desc und replica_name versionsadaptiv.
                         Der äußere LOCK_TIMEOUT bleibt unverändert; jeder
                         Datenbankread setzt ihn nur im isolierten Dynamic SQL.
               1.1.0 - Inkrementelle Partitionsdetails werden bei aktiviertem
                         Schalter auch als Resultset und JSON-Array veröffentlicht.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_Statistics
Inventarisiert sichtbare Statistikdefinitionen und Update-Properties im ausgewählten Datenbank- und Objektumfang.
GEZIELT verlangt eine exakte Schema-, Objekt- oder Statistikliste, einen vollständigen Objektbezug oder ein Schema-/Objektpattern. VOLL und aktivierte inkrementelle Details prüfen zusätzlich CATALOG_DEEP.
CONSOLE liefert beschriftete Fachresultate; RAW liefert technische Resultsets; TABLE schreibt statistics; NONE unterdrückt Resultsets. JSON wird unabhängig über @JsonErzeugen erzeugt.
Beispiel: EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';
JSON: DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [ExampleJson];
CREATE TABLE [#Statistics_HelpExample]([Seed] int NULL); BEGIN TRY     EXEC [monitor].[USP_Statistics] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"statistics":"#Statistics_HelpExample"}'; END TRY BEGIN CATCH     DROP TABLE [#Statistics_HelpExample];     THROW; END CATCH; DROP TABLE [#Statistics_HelpExample];
```

