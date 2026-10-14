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

Ohne Datenbankfilter werden sichtbare Online-Benutzerdatenbanken gewählt.
Systemdatenbanken sind opt-in. Namenslisten und LIKE-/Regex-Patterns verwenden
den bestehenden exklusiven Filtervertrag. Es gibt keinen CURRENT-Scope und
kein Datenbankanzahllimit.

## Resultsets und Leserichtung

RAW liefert `moduleStatus`, `configurations`, `counters`, `waits`, `cache`,
`sourceStatus` und `warnings`. TABLE schreibt dieselben benannten Mengen in
vorhandene lokale Seed-Temp-Tabellen. JSON verwendet Schema 1 und dieselben
Arrays. CONSOLE liefert eine Übersicht; NONE unterdrückt fachliche Resultsets.
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

Fehlende Berechtigung, unerwartet fehlende Werte und tatsächliche Quellenfehler
bleiben je Quelle erhalten. Ein Auswahlfehler verhindert die Serverquellen
nicht. Der erste tatsächliche Fehler folgt der Konfigurationsauswahl und
danach Counter-, Wait- und Cachekontext. Andere verfügbare Mengen bleiben
ausgabefähig. Ungültige Parameter und nicht unterstützte Filter starten kein
Sampling.

## Eigenlast und Grenzen

Die Procedure liest je ausgewählter Datenbank einen kleinen Katalog. Counter
sind auf drei Namen, Waits auf RESOURCE_SEMAPHORE_QUERY_COMPILE und Cache auf
zwei Klassen begrenzt. `@SampleSeconds` ist standardmäßig 0 und erlaubt genau
ein WAITFOR von einer bis 60 Sekunden. Tatsächliche Intervalle werden getrennt
ausgegeben; eine exakte Echtzeitdauer wird nicht garantiert. `@MaxZeilen`
begrenzt die Ausgaben, nicht die Zahl ausgewählter Datenbanken. Locktimeout
und XACT_ABORT werden nach dem Aufruf restauriert; Nutzdaten und Serveroptionen
werden nicht geändert.

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
