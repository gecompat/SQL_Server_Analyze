# [monitor].[USP_UpgradeFeatureUsageAnalysis]

Die Procedure zeigt instanzweite native Deprecated-Begegnungszähler und eine
begrenzte Konfigurationsregel für eine ausdrücklich ausgewählte Zielversion.
Sie beantwortet, welche Beobachtungen SQL Server im aktuellen Enginekontext
bereitstellt. Sie erteilt keine Upgradefreigabe. Kostenklasse: LOW_MEDIUM.

## Vorbereitung und Aufruf

Installieren Sie den aktuellen Frameworkkern. Die Procedure liest
sys.dm_os_sys_info vor und nach genau einer Aufnahme der gefilterten
sys.dm_os_performance_counters sowie sys.configurations für lightweight pooling.
Auf SQL2019 benötigen die DMVs VIEW SERVER STATE, ab SQL2022 VIEW SERVER
PERFORMANCE STATE. Die Procedure vergibt keine Rechte. Fehlende Rechte einer
Quelle verhindern die unabhängigen anderen Reads nicht.

Führen Sie den Aufruf außerhalb einer Callertransaktion mit
IMPLICIT_TRANSACTIONS OFF aus. Die Procedure setzt ihre eigenen Reads auf
LOCK_TIMEOUT 0 und stellt LOCK_TIMEOUT sowie XACT_ABORT anschließend wieder her.
Sie liest keine Hostdateien und ändert keine Serverkonfiguration.

```sql
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis]
      @TargetMajorVersion = 17,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Ohne @TargetMajorVersion erfolgt keine Zielbewertung. Zulässig sind 15, 16 und
17 ab der tatsächlichen unterstützten Source-Major. Positive Werte für @MaxZeilen begrenzen die ausgegebenen Counterzeilen.
NULL und 0 geben den abgegrenzten nativen Scope vollständig aus; negative Werte
sind ungültig. Der native Cache
wird vor dem Limit aufgebaut. NativeCounterRows und ReturnedCounterRows zeigen
die beiden Mengen, OutputLimited meldet die Kürzung.

## Eine Zeile bedeutet

RAW liefert vier typisierte Resultsets in der Reihenfolge context,
deprecatedUsage, configuration und sources. CONSOLE formatiert dieselben vier
Gruppen; NONE unterdrückt die fachlichen Resultsets. Der optionale JSON-OUTPUT
enthält meta und diese vier benannten Arrays. TABLE exportiert die ausdrücklich
benannten Gruppen über @ResultTablesJson. Spalten und Typen stehen im
[Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv); Parameter stehen
in der [Procedure-Referenz](../../Reference/Procedure_Reference.md).

| Gruppe | Interpretation |
|---|---|
| context | Source-/Targetversion, beobachtetes Zeitfenster, Enginebindung, native und ausgegebene Countermenge. |
| deprecatedUsage | Native Objekt-, Counter- und Featurenamen, Countertyp und unveränderter bigint-Rohwert. |
| configuration | Getrennte konfigurierte und wirksame Optionswerte mit begrenzter Zielversionsregel. |
| sources | Vier unabhängige Quellenzustände, tatsächliche Readmenge, native Fehler und Aussagegrenze. |

Die Usagewerte sind Enginebegegnungen seit SQL-Server-Start. Einige Features
zählen schon bei der Kompilierung. Es handelt sich weder um Ausführungszahlen
noch um Datenbankzuordnungen, Raten oder Lastanteile. Null beweist keine
Nichtverwendung. Countertypen werden unverändert ausgegeben und nicht pauschal
zu einer Summe oder Differenz zusammengeführt.

EngineContextConfirmed verlangt eindeutige identische native Startzeit und
Startticks vor und nach dem Read sowie ein geordnetes Messfenster. Die
Startzeit ist ein lokaler nativer datetime-Wert und kein UTC-Startmarker. Bei
fehlender Bindung bleiben erfolgreich gelesene Counter erhalten; ihre
ObservationStatus-Werte werden ENGINE_CONTEXT_UNBOUND. Die ausgegebenen
Engine-Startfelder bleiben dann NULL. Auch gleiche Marker beweisen keine
Resetkontinuität für einen späteren Vergleich.

Ohne Ziel lautet TargetAssessment TARGET_NOT_SELECTED. Mit Ziel bleiben die
nativen Featurenamen UNMAPPED_SOURCE_FEATURE. Sie werden nicht anhand ähnlicher
Namen automatisch einer Deprecationliste zugeordnet.

Die einzige kuratierte Regel DEPRECATED_LIGHTWEIGHT_POOLING_17 in
RuleCatalogVersion 1 beschreibt lightweight pooling ab Zielmajor 17. Der
wirksame Wert 1 ergibt CONFIGURED_DEPRECATED_AT_TARGET; konfiguriert 1 bei
wirksam 0 ergibt PENDING_DEPRECATED_CONFIGURATION. Bei beiden Werten 0 lautet
die Beobachtung NOT_CONFIGURED_IN_OBSERVATION. Ziele 15/16 liegen außerhalb
dieser Regel. Ungültige oder nicht eindeutig beobachtete native Optionswerte
ergeben INVALID_NATIVE_VALUE. Die Procedure aktiviert die Option nicht.

## So lesen

AssessmentCoverage bleibt LIMITED_OBSERVATION und IsPartial bleibt bei jeder
regulären Analyse 1. Beobachtete Counter- oder Optionszeilen ergeben PARTIAL,
auch wenn eine andere Quelle scheitert. Erfolgreiche leere Reads bleiben
SUCCEEDED mit NativeRows=0. Ein gescheiterter Read meldet FAILED mit
NativeRows=NULL und dem tatsächlichen SQL-Fehler. Leere fachliche Mengen sind
kein bestandener Kompatibilitätstest.

Ohne fachliche Zeilen ergibt eine reine Rechteverweigerung DENIED_PERMISSION,
ein sonstiger Quellenfehler ERROR_HANDLED und ein erfolgreicher leerer Scope
EMPTY_UNPROVEN. Eine nicht unterstützte Sourceversion ergibt UNAVAILABLE_OBJECT
mit nicht gestarteten Reads. Die OUTPUT-Fehlerprojektion enthält den ersten
tatsächlichen SQL-Fehler nach Quellenreihenfolge; sources behält weitere Fehler.

Reguläre Quellenfehler liefern RETURN 0 und bleiben über Status/OUTPUT sichtbar.
Ungültige Aufrufparameter liefern 51011. Technische Ausgabe- oder Setupfehler
liefern einen von null verschiedenen RETURN, den tatsächlichen Fehler über
OUTPUT und keinen JSON-Teilerfolg. Prüfen Sie bei TABLE-Fehlern die Namen und
Schemas der vorbereiteten lokalen Zieltabelle.

Für Datenbankabhängigkeiten folgt die
[Portabilitätsanalyse](USP_DatabasePortabilityAnalysis.md). Tatsächliche Version,
Edition und Plattform zeigt die
[Versionsinformation](USP_ServerVersionInformation.md). Discontinued Features,
Breaking Changes, Treiber, Betriebssystemvoraussetzungen und Hostadapter
benötigen zusätzliche Prüfung und gehören nicht zum Abdeckungsversprechen.

## Primärquellen

Der Regelstand wurde am 26. Oktober 2026 geprüft:

- [Deprecated Features object](https://learn.microsoft.com/en-us/sql/relational-databases/performance-monitor/sql-server-deprecated-features-object?view=sql-server-ver17) beschreibt Begegnungszähler und Auslöser.
- [Performance-Counter-DMV](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17) beschreibt Rohspalten und Rechte.
- [lightweight pooling](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/lightweight-pooling-server-configuration-option?view=sql-server-ver17) beschreibt Option, wirksamen Zustand und Deprecation ab SQL2025.

## Warum kann das problematisch sein?

Ein positiver Begegnungszähler kann auf eine Abhängigkeit von veralteter
Funktionalität hinweisen. Ohne Quellcode- und Workloadprüfung lässt sich daraus
weder die betroffene Anwendung noch ihre Upgradefähigkeit bestimmen.

## Wann ist es kein Problem?

Eine isolierte Begegnung kann schon durch eine Kompilierung entstehen. Ein
solcher Rohwert verlangt Einordnung und ist kein eigener Störungsnachweis.

## Technische Vertiefung

### Leitfrage

Welche SQL-sichtbaren Beobachtungen liegen für den aktuellen Enginekontext vor?

### Technischer Hintergrund

Die begrenzte Regel und die nicht zugeordneten nativen Featurenamen bleiben
getrennte Evidenzarten. Die Zielversion ist eine Aufrufentscheidung.

### Datenkette

Native Enginebeobachtung, vollständiger gefilterter Countercache, zweite
Enginebeobachtung und Optionscache führen zu vier typisierten Ergebnissen.
Erst die Ausgabemenge wird begrenzt.

### Source Select

```sql
SELECT [object_name], [counter_name], [instance_name], [cntr_type], [cntr_value]
FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
WHERE [object_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'%SQL%Deprecated Features%'
  AND RTRIM([counter_name]) COLLATE Latin1_General_100_BIN2 = N'Usage';
```

**Wichtig für die Eigenlast:** Ressourcen-Scope ist die Instanz; der gefilterte Cache wird genau einmal pro
Aufruf gelesen. Es erfolgt keine Workloadausführung oder Zählerrücksetzung.

### Zeit- und Scope-Modell

Die beiden nativen Startmarker begrenzen die aktuelle Aufnahme. Ein späterer
Vergleich benötigt eigene Quellen- und Resetbindung.

### Bewertung und Gegenprobe

Prüfen Sie sources vor der Interpretation eines Rohwerts. Vergleichen Sie die
getrennten Konfigurationswerte mit dem nativen Optionskatalog und gleichen Sie
den Featurenamen mit der offiziellen Dokumentation der gewählten Zielversion ab.

### Typische Fehlinterpretation

OBSERVED_ZERO beweist keine Nichtverwendung. PARTIAL und ein leeres Ergebnis
bestätigen keine erfolgreiche Upgradeprüfung.

### Folgeanalyse

Die Portabilitätsanalyse untersucht getrennte Datenbankabhängigkeiten. Für die
weitere technische Einordnung führen die
[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_upgradefeatureusageanalysis)
und das [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) fort.
