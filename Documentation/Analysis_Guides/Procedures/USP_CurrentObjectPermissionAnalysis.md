# [monitor].[USP_CurrentObjectPermissionAnalysis]

**Bereich:** Server Health und Berechtigungsdiagnostik.  
**Zweck:** Zeigt native OBJECT-Rechte des aktuellen Aufrufers für ein ausdrücklich benanntes Schema-/Objektpaar je ausgewählter Datenbank.  
**Beobachtungsart:** Getrennte, nicht atomare Katalogaufrufe.  
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Welche OBJECT-Rechte meldet `sys.fn_my_permissions` für den aktuellen Ausführungskontext und dasselbe ausdrücklich benannte Schema-/Objektpaar in jeder ausgewählten Datenbank? Die Procedure ergänzt die [SERVER-/DATABASE-Rechte](USP_CurrentCallerPermissionAnalysis.md). Sie liest keine Datenzeilen des Zielobjekts und ändert keine Identität.

## Nicht beantwortete Fragen

Eine leere Ausgabe, ein verborgenes Objekt oder der native Fehler 15151 beweist weder Objektabwesenheit noch einen verweigerten Statementzugriff. `subentity_name` ist eine native Spaltenbezeichnung und kein eigenständiger COLUMN-Rechte- oder Statementbeweis. Andere Principals, Grant-/Deny-Ketten, tatsächliche Datenzugriffe und globale Vollständigkeit bleiben außerhalb des Berichts.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentObjectPermissionAnalysis]
    @DatabaseNames=N'[ExampleDatabase]',
    @SchemaName=N'dbo', @ObjectName=N'ExampleObject',
    @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Ohne Datenbankfilter verarbeitet die Procedure sichtbare ONLINE-Benutzerdatenbanken mit `HAS_DBACCESS=1`; Snapshots bleiben ausgeschlossen. Schema und Objekt sind jeweils genau ein roher einteiliger Name. Die Quelle quotiert sie intern und löst sie in jeder Zieldatenbank unter deren SQL-Collation auf.

## Parameter und weitere Aufrufbeispiele

SQL bindet die angegebenen Werte zuerst an die Signaturtypen. Für Textparameter gibt es keinen nicht dokumentierten Leertext-Sonderdefault.

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, leer oder nur äußere U+0020-Leerzeichen bedeuten keine Liste. Sonst gilt die gemeinsame bracket-aware Pipe-Liste einteiliger Datenbanknamen; `|` trennt außerhalb `[...]`, `]]` maskiert dort `]`. Exakte Namen werden case-sensitive verglichen; doppelte und fehlerhafte Segmente sind ungültig. Eine aktive Liste und ein Pattern sind unvereinbar. Nicht verfügbare gültige Namen erzeugen Auswahlwarnungen, keinen Abwesenheitsbeweis. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Datenbank-IDs bis 4 aus; 1 erlaubt sie nur bei Sichtbarkeit, ONLINE und Zugriff. NULL ist INVALID_PARAMETER. SQL bindet 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL bedeutet kein Pattern. LIKE, REGEX und REGEXI sind die gemeinsamen case-insensitiven Präfixe; ohne Präfix gilt LIKE. Leeres Pattern ist ungültig. REGEX/REGEXI erfordern SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank; native Syntaxfehler bleiben sichtbar. |
| `@SchemaName` | `nvarchar(max)` | `NULL` | Im regulären Pfad genau ein roher einteiliger Schemaname, ohne Liste oder Wildcard. NULL, leer, nur U+0020 oder über 256 UTF-16-Bytes sind INVALID_PARAMETER. Kein stilles Trimmen oder Abschneiden; intern `QUOTENAME`. Hilfe ist ohne Namen zulässig. |
| `@ObjectName` | `nvarchar(max)` | `NULL` | Im regulären Pfad genau ein roher einteiliger Objektname, ohne Liste oder Wildcard. NULL, leer, nur U+0020 oder über 256 UTF-16-Bytes sind INVALID_PARAMETER. Kein stilles Trimmen oder Abschneiden; intern `QUOTENAME`. Der zusammengesetzte qualifizierte Name darf vor der sysname-Bindung höchstens 256 UTF-16-Bytes haben. |
| `@MaxZeilen` | `int` | `1000` | NULL oder 0 ist unbegrenzt; negativ ist INVALID_PARAMETER. Positiv begrenzt OBJECT-Zeilen global erst nach allen Quellenlesungen, geordnet nach DatabaseId, EntityName, SubentityName und PermissionName. Kontext-, Status- und Warnungszeilen bleiben ungekürzt; `ObservedRows`, `ReturnedRows`, `IsLimited` trennen Aufnahme und Ausgabe. |
| `@LockTimeoutMs` | `int` | `0` | 0 bis 60000 Millisekunden; NULL, negativ und größer 60000 sind INVALID_PARAMETER. 0 bedeutet NOWAIT für dynamische Quellen; vorbereitende Temp-DDL erhält bei eingehendem Timeout 0 bis zu 1000 ms. Der Callerwert wird wiederhergestellt; es gibt keine Gesamtzeitgarantie. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach SQL-Bindung, äußerem U+0020-Trim und UPPER sind CONSOLE (eine beschriftete Sicht), RAW (fünf native Mengen), TABLE (zugeordnete lokale #Temp-Ziele) und NONE (keine fachlichen Mengen) zulässig. NULL/leer/andere Codes sind ungültig. Werte über 16 Zeichen können bereits bei der SQL-Bindung gekürzt werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Außerhalb TABLE nur NULL/leer/U+0020. TABLE verlangt mindestens eine eindeutige Zuordnung der fünf Gruppennamen zu vorhandenen leeren lokalen #Temp-Zielen mit genau einer Seed-Spalte. Keine doppelten Ziele, keine ##- oder #Monitor*-Ziele; Namen höchstens 116 Zeichen. Der gemeinsame Helper lehnt fehlerhafte Zuordnung vor Quellenzugriff ab. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON unabhängig vom Resultmodus, 0 und NULL nicht. SQL bindet 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1. JSON enthält meta und dieselben fünf Arrays mit NULL-Feldern. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger; mit OUTPUT binden. Beim Eintritt, bei Hilfe, Validierungsfehler und äußerem Fehler NULL; im regulären Pfad nur bei `@JsonErzeugen=1` gesetzt. |
| `@PrintMeldungen` | `bit` | `1` | 1 erlaubt niedrige NOWAIT-Diagnosemeldungen, 0 oder NULL unterdrückt sie. Hilfe druckt unabhängig. SQL bindet 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1. |
| `@Hilfe` | `bit` | `0` | 1 druckt die Hilfe und liefert AVAILABLE/IsPartial=0/RETURN 0 vor TABLE- oder Quellenprüfung; 0 und NULL gehen in den regulären Pfad. JSON und Fehlerausgaben bleiben bei Hilfe NULL. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger. Hilfe AVAILABLE; Eingabefehler INVALID_PARAMETER; Auswahlfehler behalten ihren Status. Regulär: AVAILABLE_LIMITED bei einer nichtleeren OBJECT-Quelle, EMPTY_UNPROVEN bei nur erfolgreichen leeren Quellen, sonst erster nativer Quellenfehler oder NO_TARGETS. Quellenfehler ändern RETURN 0 nicht. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger. Hilfe 0; Validierung, regulärer Bericht und äußerer Fehler 1. Caller-Sicht, leere Quellen, Outputlimit und getrennte Zeitpunkte begrenzen die Aussage. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger. Hilfe NULL, Validierung 51011; sonst erste native Fehlernummer nach DatabaseId/SourceKey oder NULL. Äußere Fehler bleiben numerisch erkennbar. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger. Hilfe NULL, Validierung feste Diagnose; sonst erste native Fehlermeldung nach DatabaseId/SourceKey oder NULL. Äußere Fehler bleiben diagnostisch erhalten. |

### RAW-Ausgabe

RAW liefert `moduleStatus`, `callerContexts`, `objectPermissions`, `sourceStatus` und `warnings` in dieser Reihenfolge, mit nativen Spaltentypen aus `Metadata/Inventory/ResultSets.csv`.

### JSON und Diagnose-OUTPUTs

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int;
EXEC [monitor].[USP_CurrentObjectPermissionAnalysis]
    @SchemaName=N'dbo', @ObjectName=N'ExampleObject',
    @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
    @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT,
    @ErrorNumberOut=@Error OUTPUT;
```

Die JSON-Arrays haben dieselben fünf Gruppennamen. Die OUTPUTs beschreiben den gesamten Aufruf; einzelne Quellen stehen in `sourceStatus`.

### TABLE-Ausgabe

TABLE schreibt nur angeforderte Gruppen in vorhandene lokale #Temp-Ziele gemäß `@ResultTablesJson`. Der gemeinsame Helper prüft Zielsyntax, Eindeutigkeit und Schema vor dem fachlichen Zugriff; ein TABLE-Fehler bedeutet keine leere OBJECT-Quelle.

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

`moduleStatus` enthält den gesamten Berichtsstatus. `callerContexts` zeigt je erfasster Quelle die numerischen Kontext-IDs. `objectPermissions` enthält ausschließlich native Rechtezeilen samt angefragtem Ziel und Datenbank. `sourceStatus` dokumentiert je Auswahl- und OBJECT-Quelle Zeiten, Sichtbarkeit, Fehler und Zeilenzahlen. `warnings` hält begrenzte Auswahl- und Quellwarnungen fest. CONSOLE verdichtet dies zu genau einem fachlichen Resultset.

## Eine Zeile bedeutet

Eine OBJECT-Zeile ist ein Recht, das die native Funktion für das qualifizierte Ziel in genau einer ausgewählten Datenbank unter dem tatsächlichen Aufrufer meldete. Ein `subentity_name` bleibt lediglich ein natives Feld derselben Zeile.

## So lesen

Lesen Sie zuerst `moduleStatus` und alle `sourceStatus`-Zeilen. Vergleichen Sie `ObservedRows` mit `ReturnedRows`; bei `IsLimited=1` sind weitere aufgenommene Rechte nicht ausgegeben. Eine leere OBJECT-Menge benötigt eine erfolgreiche Quellenzeile, bleibt aber `EMPTY_UNPROVEN`.

## Warum kann das problematisch sein?

Ein Objekt kann wegen Metadatensicht oder Kontext für den Aufrufer unsichtbar sein. Ein Fehler 15151 ist ohne zusätzliche Berechtigung kein eindeutiger Existenz- oder Denybeweis. Ein globales Outputlimit kann Rechtezeilen aus späteren Datenbanken verdecken.

## Wann ist es kein Problem?

Eine erfolgreiche native Zeile beantwortet die enge Frage nach dem von `sys.fn_my_permissions` gemeldeten OBJECT-Recht zu diesem Zeitpunkt. Sie behauptet keine erfolgreiche Ausführung eines konkreten Statements.

## Beispiele und Gegenbeispiele

Eine synthetische SELECT-Freigabe kann unter einem eigenen eingeschränkten CI-Caller als native Zeile erscheinen. Ein gesondertes DENY kann denselben Zugriff bei einem anderen eigenen Ziel verhindern. Dieser Fixturevergleich belegt keine Rechte anderer Principals.

## Leere oder partielle Ausgabe

Fehlerhafte Datenbanken werden getrennt behandelt. Die übrigen Datenbankquellen bleiben auswertbar. Eine leere oder verborgene Zielquelle, ein nativer Fehler und ein begrenzter Auszug werden getrennt ausgewiesen; keiner dieser Zustände beweist vollständige Abwesenheit.

## Eigenlast und Grenzen

Die Procedure liest je ausgewählter Datenbank eine native OBJECT-Quelle. `@MaxZeilen` begrenzt erst die Ausgabe, nicht die Zahl der Funktionsaufrufe. Die dynamischen Lesebatches verwenden den angegebenen LOCK_TIMEOUT; es gibt keine atomare Datenbankübergreifende Aufnahme und kein Gesamtdauerlimit.

## Technische Vertiefung

### Leitfrage

Welche OBJECT-Rechte meldet die Engine für dasselbe ausdrücklich benannte Ziel im aktuellen Caller-Kontext je ausgewählter Datenbank?

### Technischer Hintergrund

`sys.fn_my_permissions` liefert `entity_name`, `subentity_name` und `permission_name`. Der qualifizierte Name wird nach bytegenauer Kapazitätsprüfung sicher quotiert und als `sysname` gebunden. Die SQL-Collation der jeweiligen Datenbank bestimmt die native Objektauflösung.

### Datenkette

Die gemeinsame Datenbankauswahl liefert sichtbare ONLINE-Ziele. Ein isolierter Batch je Ziel liest die native Funktion und die numerischen Caller-IDs. Danach werden Status, Limit, JSON und die gewählte Ausgaberoute erzeugt.

### Source Select

```sql
SELECT entity_name, subentity_name, permission_name
FROM sys.fn_my_permissions(N'[dbo].[ExampleObject]', N'OBJECT');
```

Der Source Select ist eine synthetische Form des nativen Aufrufs. Er benötigt den gewünschten Datenbankkontext und dessen tatsächlichen Caller; er ist keine eigenständige Produktabnahme.

**Wichtig für die Eigenlast:** Die Procedure liest die native OBJECT-Quelle in jeder ausgewählten Datenbank vollständig vor dem globalen `@MaxZeilen`-Ausgabelimit. Die Zahl der ausgewählten Datenbanken bestimmt die Zahl der Caller-Quellenaufrufe; ein kleines Limit setzt keine Gesamtdauergrenze.

### Zeit- und Scope-Modell

`CapturedAtUtc` und Quellzeiten sind UTC-Aufnahmezeiten. Quellen werden nacheinander gelesen; ein Rechtewechsel während des Aufrufs kann unterschiedliche Zustände ergeben. Datenbankauswahl und Objektsicht bleiben caller-sichtbar.

### Bewertung und Gegenprobe

Für einen konkreten Zugriff ist eine getrennte, autorisierte Statementprüfung am betroffenen Securable nötig. Der Bericht selbst führt sie nicht aus und erweitert keine Rechte.

### Typische Fehlinterpretation

`EMPTY_UNPROVEN` bedeutet keinen bewiesenen DENY und keinen Nachweis, dass das Objekt fehlt. `subentity_name` beweist keine eigenständige COLUMN-Rechteaufnahme.

### Folgeanalyse

Die [aktuellen SERVER-/DATABASE-Rechte](USP_CurrentCallerPermissionAnalysis.md) und die [Principal-Kataloge](USP_DatabasePrincipalAnalysis.md) liefern andere Ausschnitte. Sie ersetzen keine gezielte Statementprüfung.

## Primärquellen

- [Microsoft Learn: sys.fn_my_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-my-permissions-transact-sql?view=sql-server-ver17)
- [Microsoft Learn: Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_currentobjectpermissionanalysis)
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
