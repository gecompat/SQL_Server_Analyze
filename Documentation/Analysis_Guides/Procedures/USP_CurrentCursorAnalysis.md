# [monitor].[USP_CurrentCursorAnalysis]

Inventarisiert aktive Cursor; Details werden für genau eine Session aktiviert.

**Bereich:** Current State
**Zweck:** Liefert begrenzte Cursor-Ressourcen- und Dormanzevidenz für genau eine bekannte Session.
**Beobachtungsart:** flüchtiger DMV-Snapshot der ausgewählten einzelnen Session
**Kostenklasse:** MEDIUM_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist für eine bereits identifizierte Session vorgesehen. Sie zeigt, ob dort zum Lesezeitpunkt Cursor sichtbar sind und welche kumulativen Worker-, Read-, Write- und Dormanzwerte eine gezielte Gegenprüfung begründen. Der Detailpfad bleibt standardmäßig deaktiviert und akzeptiert höchstens eine Session-ID. Dadurch wird verhindert, dass eine allgemeine Current-State-Abfrage unbeabsichtigt alle Cursor der Instanz inventarisiert.

## Nicht beantwortete Fragen

Eine Cursorzeile beweist keine fehlerhafte Programmierung und keine aktuelle Lastursache. Kumulative Reads, Writes und Worker Time können aus früheren Fetches stammen. `dormant_duration` misst die Zeit seit dem Beginn der letzten Cursorabfrage und ist kein Beweis für eine offene Transaktion oder einen Ressourcenblocker. Die Procedure liest weder Clientcode noch Parameterwerte und leitet keine automatische Cursorersetzung ab.

## Sicherer Einstieg

`EXEC [monitor].[USP_CurrentCursorAnalysis] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_CurrentCursorAnalysis] @SessionIds = N'57', @IncludeCursorDetails = 1, @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Ersetzen Sie `57` nur durch eine zuvor mit den Current-State-Modulen bestimmte Session-ID. Ohne `@IncludeCursorDetails = 1` liefert der Aufruf kontrolliert `NOT_EXECUTED`. Pipe-Listen mit mehreren IDs und Werte außerhalb des Sessionbereichs werden als `INVALID_PARAMETER` abgelehnt.

## Parametervertrag

Die folgenden Verträge beschreiben jeden Parameter einzeln. `@Hilfe = 1` kehrt vor der normalen Parameter- und TABLE-Prüfung zurück. Die JSON-Empfangsvariable wird bereits vor der Hilfe auf NULL gesetzt; die vier Status- und Fehler-OUTPUT-Parameter behalten im Hilfepfad ihre Eingangswerte.

| Parameter | Typ, Default, Eingabeform und Wirkung |
|---|---|
| `@IncludeCursorDetails` | bit, Default 0. 0 liest keine Zeilen aus sys.dm_exec_cursors und lässt Status NOT_EXECUTED (sofern kein Parameterfehler vorliegt); 1 aktiviert den Quellscan. NULL ist ungültig und ergibt INVALID_PARAMETER. Andere bit-Werte sind bei T-SQL-Konvertierung nicht darstellbar. Das Opt-in betrifft genau @TargetSessionId; es erfolgt kein instanzweiter Cursor-Scan. |
| `@SessionIds` | nvarchar(max), Default NULL. NULL sowie eine nach LTRIM/RTRIM leere Eingabe (äußere U+0020-Leerzeichen) wählen die aufrufende Session @@SPID. Sonst ersetzt die Funktion zunächst jedes Komma und Semikolon durch Pipe und zerlegt danach an Pipes außerhalb bracket-quotierter Bereiche [ ... ]; innerhalb eines solchen Bereichs trennt Pipe nicht und ]] maskiert eine schließende Klammer. Der Parser trimmt äußere U+0020-Leerzeichen, entquotet Klammern aber nicht. Ein Rohsegment über 4000 UTF-16-Codeeinheiten wird ITEM_TOO_LONG; leere Segmente werden EMPTY_ITEM und ungültige/unvollständige Klammerstruktur INVALID_BRACKET_SYNTAX. Für eine gültige Parserzeile muss TRY_CONVERT(bigint, ItemText) gelingen. Nach der Zahlenkonvertierung muss genau ein gültiger Zahlenwert im Bereich 1 bis 32767 verbleiben. Mehrere Elemente (auch Duplikate), ungültige Segmente, nicht konvertierbare Zahlenwerte und Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Es findet keine Deduplikation statt und es wird nicht vorab geprüft, ob die Session existiert oder sichtbar ist. Tabs oder sonstige Zeichen werden nicht pauschal als ungültig eingestuft; die Parser- und TRY_CONVERT-Ergebnisse entscheiden. |
| `@MaxZeilen` | int, Default 200. NULL wird ausdrücklich zu 0 normalisiert. Negative Werte ergeben INVALID_PARAMETER. 0 bedeutet keine praktische Limitierung bis TOP(2147483647), nicht null Zeilen; positive Werte begrenzen die in die lokale Tabelle übernommenen Zeilen auf höchstens diesen Wert. Auswahlreihenfolge für TOP: WorkerTime absteigend, Reads absteigend, CursorId aufsteigend. JSON ordnet WorkerTime absteigend, CursorId aufsteigend; die materialisierten Zeilen bleiben dieselben. |
| `@ResultSetArt` | varchar(16), Default 'CONSOLE'. NULL und nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leere Eingaben ergeben nach UPPER einen ungültigen Modus und INVALID_PARAMETER. Geschlossene Werte: CONSOLE erzeugt über InternalEmitConsoleResult ein lesbares Resultset mit Ergebnislabel cursors (bei leerer Quelle eine verständliche Leerzeile); RAW gibt ein Status-/Zähler-Resultset und nur bei @IncludeCursorDetails=1 zusätzlich Cursorzeilen aus; TABLE materialisiert die erlaubte Zuordnung cursors in eine geprüfte lokale #Temp-Zieltabelle; NONE gibt keine fachlichen Resultsets aus. Es gibt keine weiteren erlaubten Werte. Groß-/Kleinschreibung wird durch UPPER vereinheitlicht, äußere U+0020-Leerzeichen werden entfernt. CONSOLE und TABLE setzen intern den Modus für die Statusmeldung auf NONE; @PrintMeldungen=1 kann daher auch bei diesen beiden Ausgabearten eine Status-PRINT-Meldung auslösen. |
| `@ResultTablesJson` | nvarchar(max), Default NULL. Für CONSOLE, RAW und NONE muss der Wert NULL oder nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leer sein; ein anderer Wert löst 51011 aus. Für TABLE ist ein gültiges JSON-Objekt mit genau der Zuordnung des Resultnamens cursors zu einer lokalen #Temp-Tabelle erforderlich, z. B. N'{"cursors":"#CursorExport"}'. NULL/leer, falsche Schlüssel oder Typen, globale ##- und permanente Tabellen, reserviertes Präfix #Monitor, zu lange/fehlende Ziele sowie doppelte Ziele werden abgelehnt. Das Ziel muss vorab vorhanden und leer sein und genau eine Seed-/Dummy-Spalte haben; diese wird an das Cursor-Resultatschema angepasst. Die TABLE-Vorprüfung läuft vor Parameter-/Quellenprüfung und kann bei Fehlern mit THROW abbrechen. |
| `@JsonErzeugen` | bit, Default 0. 0 oder NULL erzeugt kein JSON; @Json bleibt NULL. 1 erzeugt @Json als JSON-Array der materialisierten Cursorzeilen ohne Status-/Fehler-Envelope; bei null Cursorzeilen ist der Wert []. Das Array enthält dieselbe begrenzte Materialisierung und wird nach WorkerTime absteigend und CursorId aufsteigend geordnet. Der Parameter wird nicht separat validiert; nur der Vergleich mit 1 aktiviert die Erzeugung. |
| `@Json` | nvarchar(max), OUTPUT, Default NULL (Bindung als OUTPUT erforderlich, wenn der Aufrufer den Wert empfangen soll). Der bisherige Eingabewert wird beim Eintritt sofort überschrieben und auf NULL gesetzt; bei @JsonErzeugen=1 wird er später durch das JSON-Array ersetzt, sonst bleibt er NULL. Bei @Hilfe=1 ist er ebenfalls bereits NULL, weil die Initialisierung vor dem Hilfezweig liegt. Das JSON enthält keine Status- oder Fehlerhülle. |
| `@PrintMeldungen` | bit, Default 1. 1 gibt nach der Analyse Status: &lt;Status&gt; per PRINT aus, wenn der interne Modus NONE ist; dies gilt direkt für NONE und wegen der internen Umschaltung auch für CONSOLE und TABLE. 0 oder NULL unterdrückt diese Statusmeldung. Der Hilfezweig liegt davor und druckt seine Hilfe unabhängig von diesem Parameter. |
| `@Hilfe` | bit, Default 0. 1 druckt die eingebettete Hilfe und Beispielaufrufe und kehrt vor Lock-Timeout-Änderung, TABLE-Vorprüfung, Parameter-Validierung und Quellenzugriff zurück. 0 oder NULL setzt den normalen Pfad fort. Im Hilfezweig wird @Json zuvor auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Parameter werden nicht beschrieben und behalten daher ihre übergebenen Eingangswerte. Die Hilfe-PRINTs hängen nicht von @PrintMeldungen ab. |
| `@StatusCodeOut` | varchar(40), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert überschrieben. Geschlossene Statusmenge: NOT_EXECUTED bedeutet, dass Cursordetails nicht angefordert wurden; INVALID_PARAMETER kennzeichnet ungültige Parameter; AVAILABLE bedeutet, dass mindestens eine Cursorzeile gelesen wurde; AVAILABLE_EMPTY bedeutet, dass keine Cursorzeile sichtbar war; DENIED_PERMISSION kennzeichnet abgefangene Fehler 229, 297, 300, 371 oder 916 beim DMV-Zugriff; SOURCE_UNAVAILABLE kennzeichnet einen anderen abgefangenen Fehler beim Quellzugriff. Der Hilfezweig kehrt vor der Zuweisung zurück und lässt den Eingangswert bestehen. Ein THROW vor normalem Rücklauf erreicht die Zuweisung am Prozedurende nicht. |
| `@IsPartialOut` | bit, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit 0 (vollständig im Modulstatus) oder 1 überschrieben. 1 wird bei INVALID_PARAMETER und abgefangenem DMV-Fehler gesetzt. Der Hilfezweig weist den Parameter nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht. |
| `@ErrorNumberOut` | int, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der abgefangenen SQL-Fehlernummer überschrieben; ohne abgefangenen Fehler bleibt das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht. |
| `@ErrorMessageOut` | nvarchar(2048), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der Validierungs-/abgefangenen DMV-Fehlermeldung überschrieben; wenn keine gesetzt ist, ist das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht. |

## Resultsets und Leserichtung

CONSOLE gibt eine lesbare Ansicht mit dem Ergebnislabel `cursors` aus; bei leerem Bestand liefert sie eine verständliche Leerzeile. RAW liefert zuerst Status und Zähler und gibt Cursorzeilen nur bei `@IncludeCursorDetails = 1` als weiteres Resultset aus. TABLE und JSON verwenden dieselbe begrenzte lokale Materialisierung. Lesen Sie zunächst `StatusCode`, `IsPartial` und Zielsession. Danach ordnen Sie `IsOpen`, `FetchStatus`, `WorkerTime`, `Reads`, `Writes`, `DormantDuration` und `FindingContext` ein. `RESOURCE_CONTEXT`, `DORMANT_CONTEXT` und `INVENTORY_ONLY` sind Kontextklassen, keine Severitywerte.

## Beispiele und Gegenbeispiele

Ein synthetischer `ExampleCursor` mit einem erfolgten Fetch kann als sichtbarer Positivfall dienen. Ein offener Cursor mit einer Dormanz über 60 Sekunden erhält `DORMANT_CONTEXT` vor kumulativen Reads oder Worker Time; andere offene Cursor mit solchen Arbeitswerten erhalten `RESOURCE_CONTEXT`. Ein Gegenbeispiel ist die Behauptung, ein hoher kumulativer Wert belege aktuelle CPU-Last. Ebenso ist ein lokaler administrativer Cursor nicht allein aufgrund seiner Existenz ein Defekt.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet, dass für die ausgewählte Session beim Lesezeitpunkt kein Cursor sichtbar war. Der Cursor kann kurz zuvor geschlossen worden sein. `DENIED_PERMISSION` trennt fehlende DMV-Berechtigungen von `SOURCE_UNAVAILABLE` für sonstige Quellenfehler. Wenn die Session zwischen Auswahl und DMV-Zugriff endet, ist eine leere Momentaufnahme zulässig und muss mit Requests und Sessionstatus gegengeprüft werden.

Bei einem Berechtigungsvergleich ist zu beachten, dass SQL Server 2019 `VIEW SERVER STATE` und SQL Server 2022 oder neuer `VIEW SERVER PERFORMANCE STATE` für die serverweite DMV vorsieht. Der tatsächliche Teststatus muss deshalb zusammen mit Product Major Version und Berechtigungsprofil dokumentiert werden.

## Zeilenlimit

Ein positives `@MaxZeilen` begrenzt die materialisierten Cursorzeilen. `NULL`
und `0` werden zu `0` normalisiert; die Abfrage verwendet dann `TOP (2147483647)` und hat damit kein engeres positives Zeilenlimit. Die Auswahl erfolgt nach `WorkerTime` absteigend, `Reads` absteigend und `CursorId` aufsteigend. Negative Werte liefern `INVALID_PARAMETER`.
Der Default bleibt `200`; Opt-in und Einzelsessionprüfung gelten bei jedem
Limit. Verwenden Sie für eine begrenzte Gegenprobe einen positiven Wert.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM_OPT_IN` |
| Standardpfad | Keine DMV-Detailabfrage; Status `NOT_EXECUTED` |
| Teuerster Pfad | `sys.dm_exec_cursors` für eine aktive ressourcenreiche Session |
| Haupttreiber | Cursorzahl und interne Cursorstatistik der Zielsession |
| Skalierung | Genau eine Session; positive `@MaxZeilen` begrenzen die Ausgabe |
| Ressourcen | Server-DMV-Zugriff und lokale Sortierung |
| Begrenzungswirkung | Session-ID begrenzt die Quelle; positive `@MaxZeilen` begrenzen die Materialisierung |
| Locking und Nebenwirkungen | Read-only; kein Fetch, Close oder Deallocate fremder Cursor |
| Schutzmechanismus | Explizites Opt-in und Einzelsessionvalidierung |
| Sicherer Einsatz | Nach vorheriger Identifikation einer konkreten Session |
| Aussagegrenze | Momentaufnahme und kumulative Werte beweisen keine Ursache |

## Eine Zeile bedeutet

Eine Zeile beschreibt einen sichtbaren Cursor mit Session, Status, Typ und kumulativen Arbeitswerten.

## So lesen

Prüfen Sie zuerst `StatusCode` und `IsPartial`. Offenstatus, Worker Time, Reads, Writes und Dormanz liefern Kontext, aber keinen Ursachenbeweis.

## Warum kann das problematisch sein?

Langlebige Cursor können lange Transaktionen oder wiederholte zeilenweise Arbeit begleiten.

## Wann ist es kein Problem?

Kurze lokale Cursor und kleine administrative Schleifen können erwartetes Verhalten sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Cursor benötigen eine gezielte Gegenprobe?

### Technischer Hintergrund

Der aktivierte Detailpfad liest `sys.dm_exec_cursors` mit der validierten einzelnen Zielsession. Ohne explizite Sessionauswahl verwendet er die aufrufende Session. Es wird kein Cursor verändert.

### Datenkette

Validierte einzelne Zielsession → `sys.dm_exec_cursors` → nach dem Zeilenlimit materialisiertes Cursorinventar.

### Source Select

```sql
SELECT TOP (200) [session_id], [cursor_id], [name], [properties], [is_open], [worker_time], [reads], [writes]
FROM [sys].[dm_exec_cursors](@@SPID)
ORDER BY [worker_time] DESC;
```

**Wichtig für die Eigenlast:** `@SessionIds` akzeptiert in diesem bewusst begrenzten Analysepfad genau eine bekannte Session-ID. Begrenzen Sie zusätzlich die Ausgabe mit `@MaxZeilen`.

### Zeit- und Scope-Modell

Die Ausgabe ist ein flüchtiger Snapshot der ausgewählten einzelnen Session; Cursor können während der Analyse verschwinden.

### Bewertung und Gegenprobe

Korrelieren Sie auffällige Sessions mit Requests, Blocking, Transaktionen und Anwendungskontext.

### Typische Fehlinterpretation

Ein hoher kumulativer Wert beweist keine aktuell hohe Last.

### Folgeanalyse

Prüfen Sie `USP_CurrentRequests`, `USP_CurrentBlocking` und den zugehörigen Plan im gleichen Zeitfenster.

## Primärquellen

- [sys.dm_exec_cursors](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-cursors-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/02_CurrentState/110_USP_CurrentCursorAnalysis.sql)

[Current-State-Bereichsleitfaden](../02_Current_State.md)
