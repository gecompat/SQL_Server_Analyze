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

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@TargetMajorVersion` | `int` | `NULL` | Eingabeform: einzelne SQL-int-Zahl 15, 16 oder 17; andere Werte sind ungültig. NULL wählt keine Zielbewertung. Ausgelassen entspricht Default NULL. Leerwert ist für int keine eigene Eingabeform und wird bei expliziter Konvertierung gemäß SQL Server behandelt. Zulässige Werte taxativ: 15 = SQL Server 2019, 16 = SQL Server 2022, 17 = SQL Server 2025. Bei beobachteter Source-Major 15/16/17 muss das Ziel mindestens der Source-Major entsprechen. Eine nicht unterstützte oder nicht ermittelte Sourceversion verhindert diese Sourcebewertung. Wirkung: Zielregel gilt nur für lightweight pooling ab Ziel 17; Usage-Zeilen bleiben TARGET_NOT_SELECTED bei NULL beziehungsweise UNMAPPED_SOURCE_FEATURE bei ausgewähltem Ziel. |
| `@MaxZeilen` | `int` | `1000` | Eingabeform: SQL-int; NULL oder 0 bedeutet unbegrenzte Ausgabe der nativen Counterzeilen, positive Werte 1 bis 2147483647 begrenzen ausschließlich deprecatedUsage/Counter-Ausgabe, negative Werte sind ungültig. Ausgelassen entspricht 1000. Leerwert ist keine eigene int-Eingabeform; explizite Konvertierung folgt SQL Server. Der vollständige gefilterte native Countercache wird vor diesem Limit gelesen; context, configuration und sources werden nicht dadurch gekürzt. OutputLimited vergleicht NativeCounterRows mit ReturnedCounterRows. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Eingabeform: Zeichenwert; äußere U+0020-Leerzeichen werden entfernt, dann mit UPPER normalisiert; zulässige Werte taxativ: CONSOLE = vier fachliche Gruppen formatiert ausgeben; RAW = vier typisierte Resultsets in Reihenfolge context, deprecatedUsage, configuration, sources; TABLE = zugeordnete Gruppen in Caller-Temp-Tabellen schreiben; NONE = fachliche Resultsets unterdrücken. Maßgeblich ist der bei Eintritt bereits an varchar(16) zugewiesene SQL-Wert; längere Textargumente können davor auf diese Typbreite gekürzt werden. Erst dieser Wert wird normalisiert und gegen die vier Optionen geprüft. NULL und leer oder nur U+0020-Leerzeichen werden zu leer und sind ungültig; ausgelassen verwendet Default 'CONSOLE'. Andere nach Typzuweisung und Normalisierung verbleibende Werte sind ungültig. Bei TABLE muss @ResultTablesJson eine gültige Zuordnung enthalten; bei allen anderen Modi muss es NULL, leer oder nur U+0020-Leerzeichen sein. NONE unterdrückt nur fachliche Resultsets; JSON, Status-OUTPUTs und durch @PrintMeldungen gesteuerte Meldungen bleiben möglich. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Eingabeform: bei @ResultSetArt=TABLE ein nichtleeres gültiges JSON-Objekt, dessen Schlüssel taxativ folgende Bedeutung haben: context = Aufnahme-, Versions- und Enginekontext; deprecatedUsage = native Deprecated-Counter; configuration = begrenzte Optionsbewertung; sources = vier Quellenzustände und Fehler und dessen Werte eindeutige Namen vorhandener leerer lokaler #Temp-Tabellen sind. Jede Zuordnung ist optional; mindestens eine ist erforderlich. Resultset-Schlüssel werden binär und damit einschließlich Groß-/Kleinschreibung verglichen. Zielnamen dürfen höchstens LEN 116 umfassen; doppelte Ziele werden case-insensitiv erkannt. JSON-Werte müssen Strings sein; doppelte Resultsetnamen, doppelte Zieltabellen und unbekannte Schlüssel sind unzulässig. Jede Ziel-Temp-Tabelle muss eine beliebige einzelne Seed-Spalte haben; Typ und Spaltenname sind nicht festgelegt, und eine Seed-Zeile ist nicht zulässig. Ziel muss lokale #Temp-Tabelle, nicht ##Temp oder #Monitor-Präfix sein. Ein Teilmapping exportiert nur die benannten Gruppen. NULL/leer oder nur U+0020-Leerzeichen wird außerhalb TABLE akzeptiert; in TABLE ungültig. Ausgelassen entspricht NULL. Ungültige Zuordnung schlägt vor den fachlichen Quellenreads fehl. |
| `@JsonErzeugen` | `bit` | `0` | Eingabeform: bit-Schalter. 0 = kein JSON erzeugen; 1 = JSON im OUTPUT @Json erzeugen. NULL ist ungültig. Ausgelassen entspricht 0. Andere bitkonvertierbare Nichtnullwerte werden durch SQL-bit-Konvertierung auf 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Hilfe und Parameter-/Setup-/Ausgabefehler liefern @Json=NULL; regulär abgefangene Quellenfehler erlauben weiterhin ein partielles JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Argument optional; für den Rückgabewert eine Variable des deklarierten Typs mit OUTPUT binden. Default NULL; initial wird der empfangene Wert auf NULL zurückgesetzt. Bei @Hilfe=1 oder Parameter-/Setup-/Ausgabefehlern bleibt beziehungsweise wird er NULL; regulär abgefangene Quellenfehler erlauben partielles JSON. Bei regulärer Analyse und @JsonErzeugen=1 enthält er ein JSON-Objekt mit meta sowie context, deprecatedUsage, configuration und sources als Arrays; bei @JsonErzeugen=0 bleibt er NULL. Eingabeinhalt wird nicht als Steuerwert verwendet; ausgelassen ist die OUTPUT-Bindung optional, der Default initialisiert intern NULL. |
| `@PrintMeldungen` | `bit` | `1` | Eingabeform: bit-Schalter. 0 = keine zusätzlichen Severity-10-Meldungen über RAISERROR bei regulären Quellenfehlern oder im CATCH; 1 = solche Meldungen ausgeben, wenn der jeweilige Fehlerpfad eintritt. NULL ist ungültig. Ausgelassen entspricht 1. Andere bitkonvertierbare Nichtnullwerte werden als 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Steuert weder Resultsets noch Status-OUTPUTs. Die Hilfe-PRINTs bleiben unabhängig von diesem Schalter aktiv. |
| `@Hilfe` | `bit` | `0` | Eingabeform: bit-Schalter. 0 = normale Parameterprüfung und Analyse; 1 = Hilfe-PRINTs ausgeben und ohne gewöhnliche Parameter-/Quellenvalidierung RETURN ausführen. NULL ist ungültig, wenn nicht 1. Ausgelassen entspricht 0. Andere bitkonvertierbare Nichtnullwerte werden als 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Vor dem Hilfepfad werden @Json=NULL, @StatusCodeOut=PARTIAL, @IsPartialOut=1 und Fehler-OUTPUTs NULL initialisiert; Hilfe überschreibt Status auf AVAILABLE und IsPartial auf 0. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Bindung: Caller bindet varchar(40) OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Taxative Statuswerte: AVAILABLE = Hilfe wurde ausgegeben; PARTIAL = reguläre Analyse mit beobachteten Counter- oder Optionszeilen; DENIED_PERMISSION = keine fachlichen Zeilen und ausschließlich Rechtefehler; ERROR_HANDLED = sonstiger Fehler beziehungsweise abgefangener Ausgabe-/Setupfehler; EMPTY_UNPROVEN = erfolgreiche leere Beobachtung ohne Nutzungsfrei- oder Kompatibilitätsnachweis; UNAVAILABLE_OBJECT = tatsächliche Source-Major nicht unterstützt/nicht ermittelbar; INVALID_PARAMETER = ungültige Aufruf-/TABLE-Zuordnung. Normale Quellenfehler werden als Status gemeldet und liefern RETURN 0; technische Fehler liefern nonzero RETURN. Bei Ausgabe-/Setupfehlern wird der technische Fehlerstatus über die Fehlerprojektion auf ERROR_HANDLED oder bei 51011 auf INVALID_PARAMETER abgebildet. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT-Bindung: Caller bindet bit OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Reguläre Analyse setzt 1, weil AssessmentCoverage stets LIMITED_OBSERVATION ist; Hilfe setzt 0, weil keine Analyse ausgeführt wurde. Bei ungültigen Parametern oder technischen Fehlern bleibt der Teilstatus 1; beim Eintritt wird 1 initialisiert. Die Eingabewerte NULL, 0 und 1 steuern den Aufruf nicht. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Bindung: Caller bindet int OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Hilfe und fehlerfreie Ausführung liefern NULL. Bei regulären Quellenfehlern wird der erste tatsächliche SQL-Fehler nach Quellenreihenfolge ausgegeben; bei Parameterfehlern 51011; bei technischem Ausgabe-/Setupfehler der tatsächliche Fehler beziehungsweise der gesetzte technische Fehlercode. Ohne Fehler bleibt NULL. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Bindung: Caller bindet nvarchar(2048) OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Hilfe und fehlerfreie Ausführung liefern NULL. Vorrang hat die Meldung des ersten Quellenfehlers mit Fehlernummer nach Quellenreihenfolge; ohne Fehlernummer folgt die erste vorhandene Quellenmeldung. Auch eine fehlende Enginebindung kann eine Meldung ohne Fehlernummer liefern; bei Parameter-/TABLE-Preflightfehlern oder technischem Fehler wird die tatsächlich gesetzte Fehlermeldung ausgegeben. Die vollständige quellenbezogene Fehlerlage bleibt im sources-Ergebnis, soweit dieses Ergebnis erreicht wird. |

```sql
-- Hilfe; überspringt die gewöhnliche Parameter- und Quellenvalidierung.
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @Hilfe = 1;
GO

-- RAW mit explizitem Ziel SQL Server 2025.
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis]
      @TargetMajorVersion = 17,
      @ResultSetArt = 'RAW';
GO

-- JSON-OUTPUT mit Status- und Fehler-OUTPUTs.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit,
        @ErrorNumber int, @ErrorMessage nvarchar(2048);
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis]
      @TargetMajorVersion = 17,
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @Json OUTPUT,
      @StatusCodeOut = @Status OUTPUT,
      @IsPartialOut = @Partial OUTPUT,
      @ErrorNumberOut = @ErrorNumber OUTPUT,
      @ErrorMessageOut = @ErrorMessage OUTPUT;
SELECT @Status AS [StatusCode], @Partial AS [IsPartial],
       @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
GO

-- TABLE: nur zwei Gruppen exportieren; lokale Ziele sind leer und besitzen je eine beliebige Seed-Spalte.
CREATE TABLE #UsageOut ([Seed] int NULL);
CREATE TABLE #SourcesOut ([Seed] int NULL);
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis]
      @TargetMajorVersion = 17,
      @ResultSetArt = 'TABLE',
      @ResultTablesJson = N'{"deprecatedUsage":"#UsageOut","sources":"#SourcesOut"}';
SELECT * FROM #UsageOut;
SELECT * FROM #SourcesOut;
DROP TABLE #UsageOut;
DROP TABLE #SourcesOut;
GO
```

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
