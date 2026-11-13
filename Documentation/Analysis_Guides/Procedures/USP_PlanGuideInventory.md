# [monitor].[USP_PlanGuideInventory]

Die Procedure inventarisiert caller-sichtbare Plan-Guide-Katalogzeilen in ausgewählten ONLINE-Datenbanken. Sie liest ausschließlich Kennungen, Namen, Scope-Metadaten, den Deaktivierungsschalter und Katalogzeitpunkte aus `sys.plan_guides`. Es werden keine SQL-, Batch-, Parameter- oder Hint-Definitionen gelesen. Die Procedure führt keine Validierung, Kompilierung oder Plan-Guide-Änderung aus.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanGuideInventory]
    @DatabaseNames=N'[ExampleDatabase]',
    @ResultSetArt='CONSOLE',
    @PrintMeldungen=0;
```

Ohne Datenbankfilter werden caller-sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots ausgewählt. Eine erfolgreiche leere Fachmenge bedeutet nur, dass in diesem sichtbaren Scope keine Zeile geliefert wurde. Sie belegt keine globale Abwesenheit.

## Interpretation

`ScopeType` 1 steht für `OBJECT`, 2 für `SQL` und 3 für `TEMPLATE`. Der native Wert und `ScopeTypeDesc` bleiben erhalten, auch wenn eine spätere SQL-Server-Version einen weiteren Wert einführt. `IsDisabled=0` bedeutet, dass der Katalogschalter nicht deaktiviert ist; es beweist weder Gültigkeit noch Anwendung auf eine Abfrage. `ValidationStatus` lautet für jede gelieferte Zeile `UNASSESSED`. `CreateDate` und `ModifyDate` sind native Katalogwerte ohne UTC-Umdeutung. `ScopeObjectId` kann NULL sein und wird nicht zu einem Objektnamen aufgelöst.

Die Aufnahme erfolgt Datenbank für Datenbank und ist nicht atomar. `WITH (NOLOCK)` mindert Sperrkonflikte, erlaubt aber inkonsistente Momentaufnahmen. Pro Quelle zeigen `sourceStatus`, `ObservedRows`, `ReturnedRows` und `IsLimited` eine erfolgreiche sichtbare Aufnahme, einen Fehler oder eine reine Ausgabekürzung. Ein Fehler liefert keine künstliche Nullzeile. Die Procedure verlangt kein pauschales `VIEW DEFINITION` vor dem Lesen; SQL Server bestimmt die Metadatensicht des Callers. Ein nativer Berechtigungsfehler wird als `DENIED_PERMISSION` ausgewiesen; ein kontrolliert erzwungener nativer Fehlerfall ist für V1 noch nicht qualifiziert. Eine erfolgreich leere, aber berechtigungsbedingt eingeschränkte Sicht bleibt `AVAILABLE_LIMITED` mit `IsPartial=1`.

`@MaxZeilen` begrenzt nur die ausgegebenen Plan-Guide-Zeilen nach `DatabaseId, PlanGuideId`. Kandidatenauswahl, Katalogzugriffe und Sortierarbeit werden dadurch nicht begrenzt. `@LockTimeoutMs` gilt je Datenbankbatch und ist keine Gesamtdauergrenze.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, leer oder äußere U+0020-Leerzeichen: keine exakte Einschränkung. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen; `|` innerhalb `[...]` ist Namensinhalt, `]]` maskiert `]`. Leere, doppelte oder über 128 Zeichen lange Namen sind ungültig; jedes rohe Segment hat höchstens 4000 UTF-16-Codeeinheiten. Nicht mit einem nicht-NULL-Pattern kombinieren. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt IDs bis 4 aus; 1 lässt sichtbare, zugreifbare Systemdatenbanken zu. NULL ist ungültig. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL: kein Pattern; nicht-NULL-Leertext ist ungültig. Zulässig sind `like:`, `regex:`, `regexi:` oder ohne Präfix LIKE. LIKE und regex sind case-sensitiv, regexi nicht. LIKE verwendet `%`, `_` und Zeichenklassen ohne eigene ESCAPE-Klausel. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Frameworkdatenbank. Nicht mit aktiver exakter Liste kombinieren. |
| `@MaxZeilen` | `int` | `1000` | 1 bis 2147483647 begrenzt nur ausgegebene Fachzeilen; NULL oder 0 ist unbegrenzt, negativ ungültig. |
| `@LockTimeoutMs` | `int` | `0` | 0 bis 60000 Millisekunden je Datenbankbatch, 0 bedeutet NOWAIT; NULL ist ungültig. Der vorherige Sessionwert wird wiederhergestellt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim und Großschreibung genau `CONSOLE` (eine formatierte Fachmenge), `RAW` (vier Resultsets), `TABLE` (benannte Temp-Ziele) oder `NONE` (keine Fachresultsets). NULL und leer sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE: JSON-Objekt mit mindestens einem der exakt geschriebenen Schlüssel `moduleStatus`, `planGuides`, `sourceStatus`, `warnings`. Werte sind verschiedene vorhandene, leere lokale `#Temp`-Tabellen mit genau einer Seed-Spalte; Name höchstens 116 Zeichen, nicht `##` oder `#Monitor`. Doppelte/unbekannte Schlüssel und doppelte/ungültige Ziele werden vor Quellenzugriff abgewiesen. Ein späterer Schreibfehler kann frühere Zielschreibungen belassen. Außerhalb TABLE nur NULL, leer oder U+0020-Leerzeichen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON unabhängig von der Resultsetart; 0 oder NULL erzeugt keines. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optional mit einer `nvarchar(max)`-Variable und OUTPUT binden. Der Eingang wird auf NULL gesetzt; nur ein normaler Pfad mit `@JsonErzeugen=1` füllt das Dokument. Hilfe, frühe Eingabefehler und äußerer CATCH lassen NULL. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt niedrige Severity-Meldungen zu Fehlern aus; 0 oder NULL unterdrücken sie. Numerische 0 wird 0, andere Zahlen werden 1. |
| `@Hilfe` | `bit` | `0` | 1 gibt Hilfe vor Datenbankauswahl und Quelle aus, mit `AVAILABLE` und `IsPartial=0`; 0 oder NULL führen den normalen Pfad aus. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optional an `varchar(40)` mit OUTPUT binden; Eingang wird gelöscht. `AVAILABLE`: nur Hilfe; `AVAILABLE_LIMITED`: erfolgreiche sichtbare Quelle; `SKIPPED`: keine Kandidaten; `INVALID_PARAMETER`: ungültige Eingabe/Auswahl; `INTERNAL_ERROR`: Auswahlhelfer; `SELECTION_UNAVAILABLE`: fehlender Auswahlstatus; `UNAVAILABLE_FEATURE`: Regexvoraussetzung; `DATABASE_UNAVAILABLE`: Ziel nicht verfügbar; `SYSTEM_DATABASE_EXCLUDED`: Systemziel ohne Opt-in; `DENIED_PERMISSION`: nativer Berechtigungsfehler; `SOURCE_UNAVAILABLE`: sonstiger Quellenfehler; `TIMEOUT`: Fehler 1222; `ERROR_HANDLED`: äußerer Fehler. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optional an `bit` mit OUTPUT binden; Eingang wird gelöscht. Hilfe liefert 0, normale Läufe und Fehlerpfade 1. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optional an `int` mit OUTPUT binden; Eingang wird gelöscht. Hilfe/Erfolg lassen NULL; direkte Parameterfehler liefern 51011, gefangene SQL- oder Writerfehler ihre Fehlernummer. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optional an `nvarchar(2048)` mit OUTPUT binden; Eingang wird gelöscht. Hilfe/Erfolg lassen NULL; gefangene Meldungen werden links auf 2048 Zeichen begrenzt. |

## Resultsets

`RAW` liefert `moduleStatus`, `planGuides`, `sourceStatus` und `warnings` in dieser Reihenfolge. `planGuides` enthält genau `DatabaseId`, `DatabaseName`, `PlanGuideId`, `PlanGuideName`, `ScopeType`, `ScopeTypeDesc`, `IsDisabled`, `ScopeObjectId`, `CreateDate`, `ModifyDate`, `ValidationStatus`. Die nativen Typen und alle vier vollständigen Schemas stehen in [ResultSets.csv](../../../Metadata/Inventory/ResultSets.csv). `TABLE` verwendet dieselben benannten Schemata. `CONSOLE` liefert genau eine formatierte Fachmenge, auch mit erklärender Zeile bei leerem Ergebnis. JSON enthält `meta` mit `schemaVersion=1` sowie alle vier benannten Arrays, auch wenn eines leer ist.

```sql
CREATE TABLE #ExamplePlanGuides ([Seed] int NULL);
EXEC [monitor].[USP_PlanGuideInventory]
    @DatabaseNames=N'[ExampleDatabase]',
    @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"planGuides":"#ExamplePlanGuides"}';
SELECT * FROM #ExamplePlanGuides;
DROP TABLE #ExamplePlanGuides;
```

Die Syntax und Aussagegrenzen der Datenbankauswahl stehen in [Common Contracts](../Common_Contracts.md). Die [Plan-Cache-Übersicht](../04_Plan_Cache.md) trennt diesen Katalog-Slice von flüchtigen Cache- und Showplan-Metriken.
