# [monitor].[USP_CompileContextAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Trennt lokale OPTIMIZED_SP_EXECUTESQL-Konfiguration von serverweiter Compile-Evidenz.<br>
**Beobachtungsart:** Katalog, Momentaufnahme und optionales begrenztes Sample<br>
**Kostenklasse:** LOW_MEDIUM; Sampling ist opt-in.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt die sichtbare Konfiguration ausgewählter Datenbanken und
daneben drei serverweite SQL-Statistics-Counter, einen Compile-Wait und zwei
aggregierte Memory-Cache-Klassen. Die Konfiguration ist einer Datenbank
zugeordnet; die Serverwerte bleiben unabhängig von dieser Auswahl.

## Nicht beantwortete Fragen

Die Ausgabe identifiziert keine konkrete Query, Datenbank oder Ursache von
Compile-Aktivität. Ein aktiviertes OPTIMIZED_SP_EXECUTESQL ist kein
Gesundheitsurteil. SQL-Texte, Plan-XML, Cachehandles und Reparaturen gehören
nicht zum Vertrag.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CompileContextAnalysis]
      @SampleSeconds=0, @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Ohne Datenbankfilter wählt der Datenbankauswahlhelfer sichtbare, zugreifbare, online befindliche Datenbanken ohne Snapshots; Systemdatenbanken sind opt-in. Eine exakte Pipe-Liste und ein Pattern sind gegenseitig exklusiv. Listen werden bracket-aware geprüft, leere/äußere Leerwerte bedeuten keine Einschränkung, doppelte oder ungültige Namen werden abgelehnt. Patterns verwenden den gemeinsamen LIKE-/Regex-Präfixvertrag. Regex erfordert SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank. Es gibt keinen CURRENT-Scope und kein Datenbankanzahllimit.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, N'' und eine nach außen getrimmte leere Zeichenfolge bedeuten keine Einschränkung; andernfalls ist eine eindeutige Pipe-Liste exakter SQL-Datenbanknamen zulässig. Es gilt die bracket-aware Namenslistenprüfung des Datenbankauswahlhelfers: äußere Segmentleerzeichen werden entfernt, Namen mit Leerzeichen oder Pipe können bracket-quotiert werden, und ]] maskiert darin eine schließende Klammer. Ungültige Elemente, doppelte gültige Namen sowie eine gleichzeitige nichtleere Namensliste und ein gesetztes Pattern führen zu INVALID_PARAMETER. Die Procedure fordert für die Auswahlklasse STANDARD_CURRENT an; der gebundene Klassenvertrag setzt dafür kein High-Impact-Gruppengate. Die Auswahl umfasst sichtbare, zugreifbare, online befindliche Datenbanken ohne Datenbank-Snapshots; fehlende oder nicht auswählbare explizite Namen werden als DATABASE_SELECTION-Warnings gemeldet. Ohne Einschränkung gibt es keinen CURRENT-Scope und kein Vorab- oder Datenbankanzahllimit. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Datenbanken mit database_id 1 bis 4 aus; 1 lässt master, tempdb, model und msdb in die Auswahl zu. NULL wird als ungültiger Parameter behandelt. Der Schalter gewährt selbst keine Berechtigung und macht nicht zugreifbare Datenbanken nicht sichtbar. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL bedeutet kein Pattern. Ein gesetztes Pattern wird nach dem gemeinsamen Parservertrag außen getrimmt; die Präfixe like:, regex: und regexi: wählen LIKE, case-sensitive Regex beziehungsweise case-insensitive Regex, ohne Beachtung der Präfixgroßschreibung. Ohne Präfix gilt LIKE. Nach dem Präfix darf der Inhalt nicht leer sein; ein ungültiges/leeres Pattern und die gleichzeitige Verwendung mit einer nichtleeren exakten Namensliste führen zu INVALID_PARAMETER. LIKE wird case-sensitive ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank; andernfalls meldet der Auswahlhelfer UNAVAILABLE_FEATURE. Der Regextext wird nicht vorab syntaktisch geprüft. NULL ist damit von leerem Text und einem leeren Präfix zu unterscheiden. Eine fehlerhafte Regex kann im Auswahlhelfer beim Ausführen scheitern; der umgebende CATCH dokumentiert eine partielle DATABASE_SELECTION-Quelle, während unabhängige Serverquellen weiterlaufen können. |
| `@SampleSeconds` | `tinyint` | `0` | 0 liest Counter und Waits jeweils einmal als Momentaufnahme; Before-, Delta-, Rate- und Intervallwerte sind dabei NULL. 1 bis 60 führt zwei Aufnahmen aus und genau ein gemeinsames WAITFOR mit der angegebenen Anzahl Sekunden dazwischen aus. Counter und Waits erhalten getrennte, unmittelbar nach ihrer jeweiligen Aufnahme gebundene UTC-Intervalle; die tatsächliche Dauer kann von der angeforderten Wartezeit abweichen. NULL oder ein Wert über 60 ist INVALID_PARAMETER; ein negativer Wert kann im tinyint-Eingabetyp nicht dargestellt werden. Sampling bleibt serverweit und wird nicht den ausgewählten Datenbanken zugeordnet. |
| `@MaxZeilen` | `int` | `2000` | 0 und NULL bedeuten keine Zeilenbegrenzung. Jeder positive int-Wert von 1 bis 2.147.483.647 begrenzt jeweils configurations, counters, waits, cache, sourceStatus und warnings nach deren Erhebung; moduleStatus bleibt eine einzelne Zeile. Die jeweiligen Gruppen werden nach ihren festen Schlüsseln sortiert und unabhängig gekürzt. Die Begrenzung reduziert weder die gelesenen Datenquellen noch die Zahl ausgewählter Datenbanken; die gemeldete RowCount zählt die materialisierten Zeilen aus configurations, counters, waits und cache vor der nachfolgenden Kürzung und nicht die ausgegebenen Zeilen. Negative Werte führen zu INVALID_PARAMETER. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Der Wert wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind genau RAW (sieben fachliche Resultsets in der Reihenfolge moduleStatus, configurations, counters, waits, cache, sourceStatus, warnings), TABLE (nur die per JSON-Mapping ausgewählten Resultgruppen in lokale Temp-Tabellen schreiben), CONSOLE (eine formatierte Übersicht aus Konfigurationen, Counter-Rohwerten, Waitzeit und Cacheeinträgen sowie einer Modulstatuszeile mit Status und RowCount) und NONE (keine fachlichen Resultsets). NULL oder ein anderer Wert wird zu einem leeren beziehungsweise nicht erlaubten Modus und führt zu INVALID_PARAMETER. JSON-Erzeugung und Meldungsausgabe werden unabhängig davon gesteuert. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur mit TABLE wird die JSON-Zuordnung verarbeitet; bei einem anderen Modus führt ein nichtleerer, außen getrimmter Wert zu einer ausgelösten Ausnahme. Für TABLE ist ein gültiges, nichtleeres JSON-Objekt mit mindestens einer Zuordnung erforderlich. Erlaubte, exakt groß-/kleinschreibungsabhängige Schlüssel sind moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings; jeder Wert benennt eine vorhandene, leere lokale #Temp-Tabelle. Die Zielnamen müssen höchstens 116 Zeichen lang sein, dürfen nicht mit ## beginnen und nicht dem reservierten Präfix #Monitor entsprechen. Doppelte Schlüssel oder Ziele, unbekannte Schlüssel, NULL-/Nicht-String-Werte, fehlende oder gefüllte Ziele sowie Ziele mit mehr als einer Seed-Spalte werden vor den fachlichen Quellenzugriffen abgelehnt. Der spätere Writer ersetzt die Seed-Spalte durch das fachliche Ergebnisschema. NULL, leerer oder nur aus U+0020-Leerzeichen bestehender Wert genügt bei TABLE nicht und löst INVALID_RESULT_TABLE_MAPPING aus. moduleStatus bedeutet Modulstatus, configurations Konfigurationen, counters Counterwerte, waits Waitwerte, cache Cacheaggregate, sourceStatus Quellenstatus und warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt unabhängig von der ResultSetArt ein JSON-Dokument im OUTPUT-Parameter, einschließlich Metadaten und der sieben Gruppen moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings. 0 erzeugt es nicht; dann bleibt @Json NULL. NULL ist INVALID_PARAMETER. Schema 1 enthält eine einzelne meta-Struktur mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage; Gruppen sind Arrays, leere Gruppen werden als [] ausgegeben und NULL-Spalten bleiben enthalten. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Zum Empfang ist eine passend typisierte lokale Variable mit OUTPUT-Bindung zu übergeben. Der Wert wird zu Beginn des Aufrufs vor dem HELP-Zweig auf NULL gesetzt. Bei aktivierter JSON-Erzeugung enthält er das Schema-1-Dokument; bei deaktivierter Erzeugung und auch bei HELP bleibt er NULL. Die Initialisierung findet vor möglichen Ausnahmen statt. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll. |
| `@PrintMeldungen` | `bit` | `1` | 1 lässt bei einem nicht AVAILABLE-Gesamtstatus eine Statusmeldung mit Schweregrad 10 und WITH NOWAIT ausgeben; 0 unterdrückt diese Meldung. NULL ist INVALID_PARAMETER. Der Schalter unterdrückt weder CONSOLE-Ausgaben noch fachliche Resultsets oder die OUTPUT-Bindungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 1 druckt die eingebauten Hilfetexte, setzt die vier Status-/Fehler-OUTPUTs auf AVAILABLE, 0, NULL und NULL und kehrt vor Validierung, Kandidatenauswahl und Quellenzugriff zurück. @Json wurde bereits vorher auf NULL gesetzt. 0 führt den normalen Ablauf aus; NULL wird durch die IF-Prüfung wie 0 behandelt und ist kein eigener Validierungsfehler. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Bei HELP wird AVAILABLE zugewiesen. Nach normaler Verarbeitung sind die Gesamtwerte: AVAILABLE ohne markierte Partialität, AVAILABLE_LIMITED bei tatsächlich partieller Evidenz, INVALID_PARAMETER bei ungültigen geprüften Modus-, Mengen-, Sample-, Bit- oder Auswahlparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlenden Regex-Voraussetzungen. Eine abgefangene Auswahl-Ausnahme wird als partielle DATABASE_SELECTION-Quelle erfasst; unabhängige Serverquellen können danach weiterlaufen. Nicht abgefangene Mapping-/Ausgabefehler umgehen den normalen Abschlusssatz. Die Bindung ist optional: zum Empfangen eine varchar(40)-Variable mit OUTPUT übergeben; andernfalls auslassen. HELP überschreibt einen anfänglichen NULL- oder anderen Empfängerwert mit AVAILABLE. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | HELP setzt sie auf 0. Im normalen Abschluss ist 1 gesetzt, wenn eine Quelle oder explizite Datenbankauswahl-Warnung partiell ist oder ein Counter-/Wait-Sample nicht vergleichbar ist; dann wird ein zuvor AVAILABLE-Status zu AVAILABLE_LIMITED. 0 bedeutet nur, dass diese Implementierungsbedingungen keine Partialität markiert haben, nicht dass zwischenzeitliche Resets ausgeschlossen sind. Bei ungültigen geprüften Eingaben wird 1 gesetzt. Bei nicht abgefangenen Ausnahmen wird der normale Abschluss nicht erreicht. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die erste tatsächlich gespeicherte Fehlernummer in der Quellenreihenfolge und innerhalb einer Quelle in Beobachtungsreihenfolge: Konfiguration/Datenbankauswahl, Serverstartzeit oder Counter, Waits, danach Cache. Fehlende Zeilen und Versionsfallbacks ohne ausgelöste SQL-Ausnahme liefern für sich keine Fehlernummer; ein vom Auswahlhelfer zurückgegebener Status kann dennoch eine Fehlermeldung ohne Fehlernummer hinterlassen. Bei keinem gespeicherten Fehler ist der Wert NULL; nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die zur ersten gespeicherten ErrorNumber gehörende SQL-Fehlermeldung in derselben Quellenreihenfolge; wenn weder eine gespeicherte SQL-Ausnahme noch eine Fehlermeldung des Auswahlhelfers vorliegt, ist der Wert NULL. Hinweise zu fehlenden Zeilen, Versionsfallbacks oder sonstigen Quellenlimits stehen in sourceStatus und warnings. Nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON-Ausgabe

```sql
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#CompileContextAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"configurations":"#CompileContextAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#CompileContextAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_CompileContextAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

RAW liefert in fester Reihenfolge `moduleStatus`, `configurations`, `counters`, `waits`, `cache`, `sourceStatus` und `warnings`. TABLE schreibt nur die im Mapping genannten Gruppen in vorhandene, leere lokale Seed-Temp-Tabellen. JSON wird unabhängig von der ResultSetArt über `@Json OUTPUT` erzeugt und enthält Schema 1, Metadaten sowie dieselben sieben Arrays. CONSOLE zeigt Konfigurationen je Datenbank, Counter-Rohwerte, Waitzeit, Cacheeinträge und Modulzeile; NONE unterdrückt die fachlichen Resultsets, nicht eine angeforderte JSON-Ausgabe.
Die nativen Schemas stehen im [freigegebenen Vertrag](../../Architecture/WI0006_Compile_Context_Public_Specification.md).

Lesen Sie zuerst Quellenstatus, Partialität und Warnings. Fehlende Werte und
NULL-Raten werden nicht als null Aktivität interpretiert. Erwarteter
Versionsfallback allein setzt keine Partialität.

## Eine Zeile bedeutet

Eine Konfigurationszeile gehört zu einer ausgewählten Datenbank. Counter und
Waits enthalten native kumulative Werte oder ein über Schlüssel und Typ
gebundenes Paar. Eine Cachezeile aggregiert SQLCP beziehungsweise OBJCP;
Einträge sind keine Zahl ausgeführter Queries oder Single-use-Pläne.

## So lesen

`Enabled` beschreibt ausschließlich die lokale Konfiguration.
`BeforeValue` und `AfterValue` bleiben Rohwerte. Eine Rate benötigt einen
unterstützten Typ, vergleichbare Serverstartzeiten und das eigene positive
Counterintervall. `ResetDetected=0` schließt einen zwischenzeitlichen Reset
nicht aus. Rückläufige gebundene Werte oder eine geänderte Serverstartzeit
setzen den Resetindikator; die betroffenen Deltas und Raten bleiben NULL.

## Warum kann das problematisch sein?

Kumulative Werte können seit Serverstart oder letztem Reset angewachsen sein.
Ihre Höhe allein beschreibt keine aktuelle Compile-Last. Eine Datenbankauswahl
verteilt serverweite Aktivität nicht auf diese Datenbanken.

## Wann ist es kein Problem?

Ein unbeprobter Counter mit NULL-Rate ist bei `@SampleSeconds=0` erwartbar.
UNAVAILABLE_VERSION für OPTIMIZED_SP_EXECUTESQL ist auf SQL Server 2019 und
2022 der vorgesehene Fallback. Keine dieser Aussagen erzeugt ein Finding.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max);
EXEC [monitor].[USP_CompileContextAnalysis]
      @DatabaseNames=N'[ExampleDatabase]', @SampleSeconds=1,
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS [Json];
```

Das Sample betrifft weiterhin den Server. Die Angabe einer einzelnen
Datenbank ist kein Nachweis, dass deren Abfragen die Counterdifferenz erzeugt
haben. Das JSON wird über den OUTPUT-Parameter `@Json` ausgelesen.

## Leere oder partielle Ausgabe

Fehlende Berechtigungen, unerwartet fehlende Werte und Quellenfehler bleiben je Quelle erhalten. Eine während der Kandidatenauswahl ausgelöste Ausnahme wird als partielle DATABASE_SELECTION-Quelle erfasst; die unabhängigen Serverquellen können danach weiterlaufen. Ein vom Auswahlhelfer zurückgegebener ungültiger oder nicht unterstützter Filterstatus beendet dagegen die fachliche Erhebung. Der erste gespeicherte SQL-Fehler folgt der Reihenfolge Konfiguration/Datenbankauswahl, Serverstartzeit oder Counter, Waits und Cache; andere verfügbare Mengen bleiben ausgabefähig. Ungültige Parameter und nicht unterstützte Filter starten kein Sampling.

## Eigenlast und Grenzen

Die Procedure liest je ausgewählter Datenbank einen kleinen Katalog. Counter
sind auf drei Namen, Waits auf RESOURCE_SEMAPHORE_QUERY_COMPILE und Cache auf
zwei Klassen begrenzt. `@SampleSeconds` ist standardmäßig 0 und erlaubt genau
ein WAITFOR von einer bis 60 Sekunden. Tatsächliche Intervalle werden getrennt
ausgegeben; eine exakte Echtzeitdauer wird nicht garantiert. `@MaxZeilen` begrenzt nach der Erhebung configurations, counters, waits, cache, sourceStatus und warnings jeweils unabhängig; moduleStatus bleibt erhalten. Die Begrenzung reduziert weder Quellenaufnahmen noch die Zahl ausgewählter Datenbanken. Die Procedure setzt intern LOCK_TIMEOUT auf 0 und XACT_ABORT aus und restauriert im normalen und im CATCH-Pfad den zuvor geltenden Locktimeout sowie ein zuvor aktiviertes XACT_ABORT. Nutzdaten und Serverkonfiguration werden nicht geändert.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokale Konfiguration und welche getrennte serverweite Compile-Evidenz
sind im sichtbaren Scope verfügbar?

### Technischer Hintergrund

Die drei Counter gehören zum SQL-Statistics-Objekt. Ihre native Typsemantik
wird durch `TVF_InterpretPerformanceCounter` bestimmt. Waitstatistik und Cache
besitzen eigene Quellen und liefern keine Queryzuordnung.

### Datenkette

Lokale `sys.database_scoped_configurations` sowie serverweite
`sys.dm_os_performance_counters`, `sys.dm_os_sys_info`, `sys.dm_os_wait_stats`
und `sys.dm_os_memory_cache_counters` werden getrennt materialisiert.

### Source Select

```sql
SELECT [counter_name], [cntr_type], [cntr_value]
FROM [sys].[dm_os_performance_counters]
WHERE RTRIM([object_name]) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'%:SQL Statistics'
  AND [counter_name] COLLATE SQL_Latin1_General_CP1_CS_AS
      IN(N'Batch Requests/sec',N'SQL Compilations/sec',N'SQL Re-Compilations/sec');
```

**Wichtig für die Eigenlast:** Die drei Counter, der einzelne Waittyp und die
beiden Cacheklassen begrenzen die jeweilige Quelle. Das Ausgabelimit reduziert
weder diese Snapshots noch die Zahl ausgewählter Datenbanken.

### Zeit- und Scope-Modell

Die Aufnahmen sind nicht atomar. Die Counter- und Waitklammern werden jeweils
unmittelbar nach der eigenen Quellenaufnahme gebunden; nur die Counterklammer
bestimmt die Rate. Serverstartzeiten werden vor und nach dem gemeinsamen
Sample geprüft. Cache bleibt eine einzelne Momentaufnahme.

### Bewertung und Gegenprobe

Prüfen Sie Schlüssel, Typ, Intervall, Resetindikator und Quellenstatus
gemeinsam. Fehlende Gegenzeilen, veränderte Bindung und unbekannte Typen
rechtfertigen keine berechnete Rate. Eine unabhängige Ursachenanalyse benötigt
weitere passende Evidenz; diese Procedure behauptet keine Ursache.

### Typische Fehlinterpretation

Counter-Namen mit `/sec` machen einen einzelnen kumulativen Rohwert nicht zur
Rate. Cacheeinträge sind keine ausgeführten Statements. Ein Wait-Reset mit
anschließendem Anwachsen kann in zwei Aufnahmen unsichtbar bleiben.

### Folgeanalyse

Die vorhandenen `USP_DatabaseConfigurationAnalysis`, `USP_PerformanceCounters`
und Plan-Cache-Analyseflächen können passenden Kontext ergänzen. Ihre
Ergebnisse werden nicht automatisch zu einem Compile-Storm-Finding verbunden.

## Primärquellen

- [Datenbankkonfiguration](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql?view=sql-server-ver17)
- [Performance-Counter](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17)
- [Waitstatistik](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17)
- [Memory-Cache-Counter](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-memory-cache-counters-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#monitorusp_compilecontextanalysis)
