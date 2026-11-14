# [monitor].[USP_DatabaseDdlTriggerInventory]

Die Procedure inventarisiert datenbankweite DDL-Trigger, die der Caller in ausgewählten ONLINE-Datenbanken als Metadaten sehen kann. Sie liest `sys.triggers` mit `parent_class=0`. Triggerdefinitionen, Ereignisinhalte, Tabellenwerte und Server- oder Logon-Trigger gehören nicht zur Quelle. Die Aufnahme führt keinen Trigger und keine DDL-Aktion aus.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseDdlTriggerInventory]
    @DatabaseNames=N'[ExampleDatabase]',
    @ResultSetArt='CONSOLE',
    @PrintMeldungen=0;
```

Ohne Datenbankfilter werden caller-sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots ausgewählt. Prüfen Sie bei unerwarteter Leere zuerst `sourceStatus`: Eine erfolgreiche leere sichtbare Menge belegt keine globale Abwesenheit von Triggern.

## Interpretation

`ParentClass=0` und `ParentClassDesc=DATABASE` kennzeichnen die im V1-Scope enthaltenen datenbankweiten DDL-Trigger. `TriggerType` ist der native Katalogwert: `TR` bezeichnet einen SQL-Trigger, `TA` einen CLR-Trigger. `TriggerTypeDesc` bleibt der native Beschreibungstext; weitere künftige Werte werden nicht verworfen. `IsDisabled=0` bedeutet lediglich, dass der Katalogschalter nicht deaktiviert ist. Die Procedure prüft weder, ob ein Ereignis den Trigger auslöst, noch die Folgen seines Codes oder einer Transaktionsrücknahme.

`MetadataVisibility=VISIBLE_ONLY` gilt für jede gelieferte Zeile. Die Metadatensicht hängt von den Rechten des Callers ab; auch eine erfolgreiche Quelle kann Zeilen verbergen. `CreateDate` und `ModifyDate` sind native `datetime`-Katalogwerte ohne UTC-Umdeutung. Die Datenbanken werden nacheinander gelesen, weshalb die Aufnahme nicht atomar ist.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, leer oder äußere U+0020-Leerzeichen: keine exakte Einschränkung. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen; `|` innerhalb `[...]` ist Namensinhalt, `]]` maskiert `]`. Leere, doppelte oder über 128 Zeichen lange Namen sind ungültig; jedes rohe Segment hat höchstens 4000 UTF-16-Codeeinheiten. Nicht mit einem nicht-NULL-Pattern kombinieren. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt IDs bis 4 aus; 1 lässt sichtbare, zugreifbare Systemdatenbanken zu. NULL ist ungültig. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL: kein Pattern; nicht-NULL-Leertext ist ungültig. Zulässig sind `like:`, `regex:`, `regexi:` oder ohne Präfix LIKE. LIKE und regex sind case-sensitiv, regexi nicht. LIKE verwendet `%`, `_` und Zeichenklassen ohne eigene ESCAPE-Klausel. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Frameworkdatenbank. Nicht mit aktiver exakter Liste kombinieren. |
| `@MaxZeilen` | `int` | `1000` | 1 bis 2147483647 begrenzt nur ausgegebene Fachzeilen; NULL oder 0 ist unbegrenzt, negativ ungültig. |
| `@LockTimeoutMs` | `int` | `0` | 0 bis 60000 Millisekunden je Datenbankbatch, 0 bedeutet NOWAIT; NULL ist ungültig. Der vorherige Sessionwert wird wiederhergestellt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim und Großschreibung genau `CONSOLE` (eine formatierte Fachmenge), `RAW` (vier Resultsets), `TABLE` (benannte Temp-Ziele) oder `NONE` (keine Fachresultsets). NULL und leer sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE: JSON-Objekt mit mindestens einem der exakt geschriebenen Schlüssel `moduleStatus`, `ddlTriggers`, `sourceStatus`, `warnings`. Werte sind verschiedene vorhandene, leere lokale `#Temp`-Tabellen mit genau einer Seed-Spalte; Name höchstens 116 Zeichen, nicht `##` oder `#Monitor`. Doppelte/unbekannte Schlüssel und doppelte/ungültige Ziele werden vor Quellenzugriff abgewiesen. Ein späterer Schreibfehler kann frühere Zielschreibungen belassen. Außerhalb TABLE nur NULL, leer oder U+0020-Leerzeichen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON unabhängig von der Resultsetart; 0 oder NULL erzeugt keines. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optional mit einer `nvarchar(max)`-Variable und OUTPUT binden. Der Eingang wird auf NULL gesetzt; nur ein normaler Pfad mit `@JsonErzeugen=1` füllt das Dokument. Hilfe, frühe Eingabefehler und äußerer CATCH lassen NULL. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt niedrige Severity-Meldungen zu Fehlern aus; 0 oder NULL unterdrücken sie. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@Hilfe` | `bit` | `0` | 1 gibt Hilfe vor Datenbankauswahl und Quelle aus, mit `AVAILABLE` und `IsPartial=0`; 0 oder NULL führen den normalen Pfad aus. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optional an `varchar(40)` mit OUTPUT binden; Eingang wird gelöscht. `AVAILABLE`: nur Hilfe; `AVAILABLE_LIMITED`: erfolgreiche sichtbare Quelle; `SKIPPED`: keine Kandidaten; `INVALID_PARAMETER`: ungültige Eingabe/Auswahl; `INTERNAL_ERROR`: Auswahlhelfer; `SELECTION_UNAVAILABLE`: fehlender Auswahlstatus; `UNAVAILABLE_FEATURE`: Regexvoraussetzung; `DATABASE_UNAVAILABLE`: Ziel nicht verfügbar; `SYSTEM_DATABASE_EXCLUDED`: Systemziel ohne Opt-in; `DENIED_PERMISSION`: nativer Berechtigungsfehler; `SOURCE_UNAVAILABLE`: sonstiger Quellenfehler; `TIMEOUT`: Fehler 1222; `ERROR_HANDLED`: äußerer Fehler. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optional an `bit` mit OUTPUT binden; Eingang wird gelöscht. Hilfe liefert 0, normale Läufe und Fehlerpfade 1. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optional an `int` mit OUTPUT binden; Eingang wird gelöscht. Hilfe/Erfolg lassen NULL; direkte Parameterfehler liefern 51011, gefangene SQL- oder Writerfehler ihre Fehlernummer. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optional an `nvarchar(2048)` mit OUTPUT binden; Eingang wird gelöscht. Hilfe/Erfolg lassen NULL; gefangene Meldungen werden links auf 2048 Zeichen begrenzt. |

## Resultsets

`RAW` liefert `moduleStatus`, `ddlTriggers`, `sourceStatus` und `warnings` in dieser Reihenfolge. `ddlTriggers` enthält genau `DatabaseId`, `DatabaseName`, `TriggerObjectId`, `TriggerName`, `ParentClass`, `ParentClassDesc`, `TriggerType`, `TriggerTypeDesc`, `IsDisabled`, `CreateDate`, `ModifyDate` und `MetadataVisibility`. Native Typen und alle vier Schemas stehen in [ResultSets.csv](../../../Metadata/Inventory/ResultSets.csv). `TABLE` schreibt dieselben benannten Schemas; `CONSOLE` liefert eine formatierte Fachmenge einschließlich Leerhinweis, `NONE` keine Fachresultsets. Optionales JSON enthält `meta` mit `schemaVersion=1` und alle vier benannten Arrays, auch wenn eines leer ist.

```sql
CREATE TABLE #ExampleDdlTriggers ([Seed] int NULL);
EXEC [monitor].[USP_DatabaseDdlTriggerInventory]
    @DatabaseNames=N'[ExampleDatabase]',
    @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"ddlTriggers":"#ExampleDdlTriggers"}';
SELECT * FROM #ExampleDdlTriggers;
DROP TABLE #ExampleDdlTriggers;
```

Die Syntax der Datenbankauswahl steht in [Common Contracts](../Common_Contracts.md).

## Eine Zeile bedeutet

Eine Zeile bezeichnet einen für den Caller im Lesezeitpunkt sichtbaren datenbankweiten DDL-Trigger. `DatabaseId` und `TriggerObjectId` ordnen die Katalogzeile zu. Name, Typ, Schalter und Zeitwerte beschreiben die gespeicherte Konfiguration. Eigentümerschaft, ausführbarer Inhalt, Ereigniszuordnung und tatsächliche Wirkung werden nicht ermittelt.

## So lesen

Lesen Sie zuerst `moduleStatus` und dann `sourceStatus` je Datenbank. `StatusCode`, `ObservedRows`, `ReturnedRows` und `IsLimited` trennen einen Quellenfehler von einer erfolgreichen sichtbaren Leere oder einer reinen Ausgabekürzung. Danach können Sie `ddlTriggers` nach `DatabaseId, TriggerObjectId` einordnen. `warnings` benennt Auswahl-, Quellen- und Aussagegrenzen.

## Warum kann das problematisch sein?

Ein aktivierter DDL-Trigger kann Schemaänderungen synchron beeinflussen oder zurücknehmen. Die Metadatenaufnahme belegt diesen Effekt nicht; sie zeigt lediglich den Schalter. Eine eingeschränkte Berechtigung kann Trigger verbergen, und eine auf `@MaxZeilen` gekürzte Ausgabe kann einen sichtbaren Teilbestand zeigen. Beide Fälle dürfen nicht als vollständiges Inventar ausgegeben werden.

## Wann ist es kein Problem?

Für die Frage, welche datenbankweiten DDL-Trigger im Caller-Kontext sichtbar und deaktiviert sind, genügt die begrenzte Katalogaufnahme. Wenn ein konkretes DDL-Ereignis oder eine Rücknahme untersucht werden soll, braucht es getrennte Ereignis- und Laufzeitevidenz unter einem eigenen Berechtigungs- und Datenschutzvertrag.

## Technische Vertiefung

### Leitfrage

Welche datenbankweiten DDL-Trigger sind in den ausgewählten ONLINE-Datenbanken für diesen Caller sichtbar, und welche Datenbanken wurden tatsächlich gelesen? Die Procedure beantwortet keine Frage zur Codeausführung oder zum Ergebnis eines DDL-Ereignisses.

### Technischer Hintergrund

`sys.triggers` enthält datenbankweite DDL-Trigger mit `parent_class=0`; DML-Trigger haben eine andere Parent-Klasse und sind aus diesem Resultset ausgeschlossen. Der Katalog liefert Typ, Disabled-Schalter und Zeitwerte. Die Source verbindet keine Definition, kein Event-Resultset und keine Owner-Information. Für den Quellenzugriff wird kein pauschales `VIEW DEFINITION` vorab verlangt; SQL Server begrenzt die sichtbare Metadatenmenge nach den Caller-Rechten.

### Datenkette

Der gemeinsame Auswahlhelfer liefert Kandidaten. Vor und nach dem Katalogbatch prüft die Procedure Datenbank-ID, Name und `create_date` gegen `master.sys.databases`. Der Batch liest dann `sys.triggers` in der ausgewählten Datenbank, schreibt Zeilen und Quellenstatus und begrenzt erst danach die Ausgabe. `@MaxZeilen` reduziert daher nicht die Datenbankauswahl oder Katalogarbeit.

### Source Select

Dieser Ausschnitt zeigt die fachliche Projektion im dynamischen Batch einer bereits ausgewählten Datenbank. `@Id` und `@Name` sind zuvor geprüfte, gebundene Werte der Procedure; der Ausschnitt ist kein eigenständiger Aufruf.

```sql
SELECT @Id, @Name, [object_id], [name], [parent_class],
       [parent_class_desc], [type], [type_desc], [is_disabled],
       [create_date], [modify_date], 'VISIBLE_ONLY'
FROM [sys].[triggers] WITH (NOLOCK)
WHERE [parent_class]=0;
```

**Wichtig für die Eigenlast:** Der Katalog wird je ausgewählter Datenbank im Caller-Kontext gelesen. `@MaxZeilen` beschränkt nur die spätere Ausgabe; Quellenlesung und Sortierung bleiben davon unberührt. `WITH (NOLOCK)` vermindert Sperrkonflikte, erlaubt aber inkonsistente Momentaufnahmen.

### Zeit- und Scope-Modell

Die Datenbanken werden nacheinander, nicht als globaler Snapshot gelesen. `CreateDate` und `ModifyDate` werden ohne Zeitzonenumrechnung ausgegeben. `@LockTimeoutMs` wirkt pro Katalogbatch und ist keine Gesamtdauergrenze. Datenbankidentität wird vor und nach dem Batch geprüft, kann aber eine parallele Änderung zwischen Quellen nicht ausschließen.

### Bewertung und Gegenprobe

Vergleichen Sie bei einer erwarteten Zeile unter demselben Caller die Datenbank-ID, Trigger-ID und den Disabled-Schalter mit `sys.triggers WHERE parent_class=0`. Prüfen Sie den Quellenstatus und eine mögliche Ausgabekürzung. Eine solche Gegenprobe bestätigt sichtbare Katalogmetadaten, keine Triggerwirkung. Ein kontrolliert erzwungener nativer Berechtigungsfehler ist für V1 kein vorausgesetzter Abnahmenachweis.

### Typische Fehlinterpretation

`IsDisabled=0` heißt nicht, dass der Trigger zuletzt ausgelöst wurde. `ObservedRows=0` mit `AVAILABLE_LIMITED` ist kein globaler Nullbestand. Ein Quellenfehler hat dagegen unbekannte Zeilenzahl und darf nicht als leere Quelle gelesen werden. `TA` kennzeichnet nur den nativen CLR-Triggertyp; die Procedure aktiviert keine CLR-Laufzeit.

### Folgeanalyse

Bei unerwarteter Leere prüfen Sie Datenbankauswahl, Caller-Rechte und `sourceStatus`. Bei einem konkreten DDL-Problem untersuchen Sie Ereigniszuordnung, Definition und Laufzeit in einem getrennt autorisierten Verfahren. Serverweite DDL- und Logon-Trigger bleiben außerhalb dieses V1-Resultsets.

[Technische Detailbeschreibung](../../../Code/03_ObjectIndex/100_USP_DatabaseDdlTriggerInventory.sql) zeigt die kanonische Implementierung. Das Dokument [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) erläutert die allgemeinen Beobachtungsgrenzen.
