# [monitor].[USP_StartupParameters]

**Bereich:** Server Health<br>
**Zweck:** Zeigt SQL-Server-Startparameter, Pfade und dauerhaft aktivierte Flags.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Mit welchen Service-/Engineparametern wurde die Instanz gestartet?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StartupParameters]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_StartupParameters] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst. |
| `@Hilfe` | `bit` | `0` | 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Bindung an varchar(16): CONSOLE beschriftet startupParameters, RAW liefert die technischen Zeilen und TABLE exportiert startupParameters; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden intern für reguläre Resultsets zu NONE und danach über eigene Exportzweige bedient. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. Bei einem Quellenfehler ersetzt dessen Status INVALID_PARAMETER; bei erfolgreicher Quellenprüfung bleibt INVALID_PARAMETER bestehen. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein JSON-Objekt mit startupParameters erforderlich, das auf eine existierende leere lokale #temp-Tabelle mit genau einer Seed-Spalte zeigt. Andernfalls wirft der Preflight vor der Hilfe Fehler 51011. Außerhalb von TABLE ist nur NULL oder leerer/nur aus Leerzeichen bestehender Inhalt zulässig. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt unabhängig von ResultSetArt zusätzlich JSON, 0 erzeugt es nicht; NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. NONE unterdrückt Resultsets, nicht aber Quellenabfragen oder angefordertes JSON. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. Statuswerte: AVAILABLE; INVALID_PARAMETER; UNAVAILABLE_PLATFORM (DMV fehlt und Host ist Linux); UNAVAILABLE_OBJECT (DMV fehlt und Linux ist nicht erkannt); DENIED_PERMISSION (Fehler 229, 297, 300 oder 371); ERROR_HANDLED (sonstiger Registrylesefehler). Zuweisung erst nach Quellenprüfung, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, 1 bei invalidem Modus, nicht verfügbarer DMV oder abgefangenem Quellfehler. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer eines abgefangenen Registrylesefehlers, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Enthält Quell-/Validierungshinweis oder NULL bei AVAILABLE. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |

```sql
EXEC [monitor].[USP_StartupParameters] @ResultSetArt = 'RAW';
```

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_StartupParameters]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

```sql
CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_StartupParameters]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"startupParameters":"#StartupParameters_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#StartupParameters_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#StartupParameters_HelpExample];
```

```sql
EXEC [monitor].[USP_StartupParameters] @Hilfe = 1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag exportiert startupParameters. Bei RAW steht das Modulstatusresultset vor den Fachergebnissen; CONSOLE liefert nur die jeweilige lesbare Fachansicht und TABLE schreibt nur das benannte Ziel. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Startparameter oder einer daraus abgeleiteten Konfigurationsinformation.

## So lesen

Prüfen Sie Parameterart, Pfade, Trace Flags, Startoptionen und Dienstkontext.

## Warum kann das problematisch sein?

Falsche Master-/Errorlog-/Startpfade oder unerwartete Flags können Start und Engineverhalten beeinflussen.

## Wann ist es kein Problem?

Abweichende Pfade sind häufig bewusstes Storage-Design.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein Trace Flag als Startup-Parameter erklärt, warum es nach jedem Restart wieder aktiv ist. Prüfen Sie Trace-Flag-Dokumentation, Dateisystem und Dienstkonfiguration.

**Ähnlich aussehender Gegenfall:** Abweichende Pfade sind häufig bewusstes Storage-Design. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für USP_StartupParameters bedeutet eine leere Fachausgabe, dass die gefilterte DMV-Abfrage keine Zeile lieferte oder die Quelle nicht verfügbar war; Status und Fehlerfelder unterscheiden diese Fälle. Die Procedure hat keine Teilquellenaggregation und kein Zeilenlimit. Bei fehlender DMV liefert sie UNAVAILABLE_PLATFORM auf Linux oder UNAVAILABLE_OBJECT, wenn Linux nicht erkannt wird; ein abgefangener Lesefehler setzt IsPartial=1. NULL ist nicht als gemessene 0 zu lesen; seine Bedeutung hängt vom jeweiligen Quellfeld ab.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Erkennt zunächst Plattform/Verfügbarkeit und liest dann aus `sys.dm_server_registry` nur `SQLArg%`, `ImagePath` und `ObjectName`; Werte werden als Trace Flag, Master-Daten-/Logpfad, Errorlogpfad oder Other klassifiziert. |
| Teuerster Pfad | Kein Deep-Pfad. Auch eine Instanz mit vielen Startargumenten liefert nur wenige Registry-DMV-Zeilen; RAW/JSON verbreitern lediglich die Ausgabe. |
| Haupttreiber | Anzahl der SQL-Startargument-/Dienstparameterzeilen. Auf Linux oder ohne DMV wird kontrolliert `UNAVAILABLE_PLATFORM`/`UNAVAILABLE_OBJECT` geliefert, kein alternativer Datei-/Shellzugriff gestartet. |
| Skalierung | Praktisch konstant; LIKE-Klassifikation und Sortierung wachsen linear mit wenigen Registrywerten. |
| Ressourcen | Ein Hostplattform-Lookup, ein kleiner Metadaten-Existenzcheck und optional ein gefilterter `sys.dm_server_registry`-Scan. Kein direkter Registryzugriff außerhalb SQL Server. |
| Begrenzungswirkung | Kein Zeilenlimit; vollständige Startargumente sind fachlich erforderlich. `NONE` unterdrückt Ausgabe, führt Plattform-/DMV-Prüfung und Quellabfrage dennoch aus. |
| Locking und Nebenwirkungen | Read-only. Startparameter werden weder geschrieben noch aktiviert; Änderungen außerhalb SQL Server können nach dem Snapshot erfolgen und wirken teils erst nach Dienstneustart. |
| Schutzmechanismus | Kein Gate und kein Zeilenparameter. Die Implementierung beschränkt `sys.dm_server_registry` fest auf `SQLArg%`, `ImagePath` und `ObjectName`, prüft zuvor die Plattform/Quellverfügbarkeit und führt keinen allgemeinen Registryscan aus. |
| Sicherer Einsatz | CONSOLE direkt nutzen, aber Pfade, Dienstkonto und ImagePath als sensible Betriebsmetadaten schützen. Trace-Flag-Wirkung separat versionsspezifisch prüfen. |
| Aussagegrenze | Die Procedure zeigt DMV-sichtbare Startwerte, nicht deren Änderungsverlauf oder tatsächliche Dateiexistenz. Ein `-T`-Argument beweist Konfiguration beim Start, aber nicht automatisch aktuelle Notwendigkeit oder Supportstatus. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Mit welchen Service-/Engineparametern wurde die Instanz gestartet?

### Technischer Hintergrund

Startupparameter definieren unter anderem Master Data/Log, Errorlog, Trace Flags und weitere Engineoptionen. Registry-/Service-DMVs liefern konfigurierte Parameter; einige Änderungen benötigen Dienstneustart und können Startfähigkeit beeinflussen.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_server_registry`.

### Source Select

Auf Windows liest der direkte Quellpfad nur Startup- und Dienstparameter aus der Registry-DMV:

```sql
SELECT
      [r].[registry_key]
    , [r].[value_name]
    , CONVERT(nvarchar(2048), [r].[value_data]) AS [value_data]
FROM [sys].[dm_server_registry] AS [r] WITH (NOLOCK)
WHERE [r].[value_name] LIKE N'SQLArg%'
   OR [r].[value_name] IN (N'ImagePath', N'ObjectName');
```

**Wichtig für die Eigenlast:** Der `value_name`-Filter wirkt direkt an der kleinen DMV. Pfade und Dienstidentitäten können in realen Resultsets schutzbedürftig sein; sie gehören nicht ungeprüft in Repositoryartefakte. Auf nicht unterstützten Plattformen wird kein Ersatz erfunden.

### Zeit- und Scope-Modell

Die Auswertung beschreibt die Konfiguration der laufenden Instanz und ihre Wirkung seit dem letzten Start.

### Bewertung und Gegenprobe

Prüfen Sie Parameter, Quelle, Reihenfolge, Pfad-/Flagbedeutung und Abgleich mit Runtime Trace Flags/Errorlog. Abweichung von Standard kann bewusst sein.

### Typische Fehlinterpretation

Ein angezeigter Parameter beweist nicht, dass sein Zielpfad gesund oder noch erforderlich ist. Änderungen ohne Recoveryzugang können Instanzstart verhindern.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Trace Flags, OS/Filesystem und dokumentiertes Restart-/Rollbackrunbook.

## Primärquellen

- [sys.dm_server_registry](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-server-registry-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#7-monitorusp_startupparameters)
