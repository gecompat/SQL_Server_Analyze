# [monitor].[USP_TempDBConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Bewertet TempDB-Dateien, Größen, Wachstum, Gleichheit und Konfigurationsrisiken.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Ist TempDB hinsichtlich Dateianzahl, Größe, Growth, Layout und Optionen robust konfiguriert?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TempDBConfiguration]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_TempDBConfiguration] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | Eingabeform: SQL-bit; 0 bedeutet unterdrückt den Severity-10-Hinweis bei Status ungleich AVAILABLE, 1 bedeutet gibt den Severity-10-Hinweis mit Fehlertext aus. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Hilfe` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet setzt die Hilfeprüfung nicht auf wahr und führt nach dem Preflight die Erhebung fort, 1 bedeutet druckt die Hilfe und kehrt vor Quellenabfrage und Statusoutputs zurück. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Eingabeform: ein einzelner Code CONSOLE, RAW, TABLE oder NONE; führende/abschließende Leerzeichen werden entfernt und Groß-/Kleinschreibung wird mit UPPER vereinheitlicht. NULL wird durch COALESCE zu leerem Text, ein leerer oder nur aus Leerzeichen bestehender Wert bleibt leer; alle drei Fälle sind ungültig. Nur die vier genannten Werte sind gültig. CONSOLE und TABLE wählen ihre Fachprojektion und setzen den internen Modus anschließend auf NONE, damit kein generisches Fachresultset zusätzlich ausgegeben wird; RAW liefert rohe Fachresultsets, NONE unterdrückt Resultsets. Ungültige Codes (einschließlich NULL/leer) setzen INVALID_PARAMETER und IsPartial=1; intern werden wegen des nicht-NONE-Modus Status und die nicht-RAW-Fachprojektion ausgegeben. Bei TABLE erfolgt zuerst der Ziel-Preflight; sein Fehler wird geworfen. JSON-Erzeugung ist unabhängig vom ResultSetArt. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Eingabeform: ein gültiges JSON-Objekt mit genau einer Eigenschaft, deren Name exakt files lautet und deren Stringwert eine vorhandene lokale #temp-Tabelle bezeichnet. Das Ziel muss vor dem Aufruf existieren, leer sein und genau eine Seed-/Platzhalterspalte besitzen; globale ##-Tabellen, permanente Tabellen, Namen mit reserviertem Präfix #Monitor und Namen über 116 Zeichen sind unzulässig. Der Helper ergänzt das Ausgabeschema. Nur bei ResultSetArt=TABLE erforderlich. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Inhalt akzeptiert; nichtleerer Inhalt wirft Fehler 51011. Bei TABLE validiert der Preflight JSON und Ziel und wirft bei ungültiger oder fehlender Angabe Fehler 51011; Status-OUTPUT-Parameter werden dann nicht zugewiesen. |
| `@JsonErzeugen` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet lässt @Json nach dem anfänglichen Zurücksetzen auf NULL, 1 bedeutet erstellt das JSON-Dokument mit meta, files, configuration und warnings. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang des JSON-Dokuments, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt vor TABLE-Preflight und Hilfe auf NULL gesetzt. Bei erfolgreicher Hilfe-Rückkehr bleibt @Json NULL; andere Status-/Fehler-OUTPUTs werden dort nicht zugewiesen. Im normalen Pfad wird @Json nur bei @JsonErzeugen=1 nach der Quellverarbeitung befüllt; sonst bleibt es NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte und Bedeutungen: AVAILABLE (kein festgestellter Eingabe- oder abgefangener Quellfehler), INVALID_PARAMETER (ungültige ResultSetArt), DENIED_PERMISSION (abgefangene Quellfehler 229, 297, 300, 371 oder 916), TIMEOUT (Quellfehler 1222), ERROR_HANDLED (übrige abgefangene Quellfehler). Die reguläre Zuweisung erfolgt nach der Quellverarbeitung; Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert und ein früher Preflight-THROW erreicht die Zuweisung nicht. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für 0 bei AVAILABLE; 1 bei ungültiger ResultSetArt oder abgefangenem Quellfehler. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @IsPartialOut=@Empfaenger OUTPUT angeben; die Variable muss bit sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei abgefangenem Quellfehler die Quellfehlernummer; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorNumberOut=@Empfaenger OUTPUT angeben; die Variable muss int sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei Fehler den Fehlertext beziehungsweise bei INVALID_PARAMETER den Hinweis auf die zulässigen ResultSetArt-Werte; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorMessageOut=@Empfaenger OUTPUT angeben; die Variable muss nvarchar(2048) sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |

### Aufrufbeispiele

CONSOLE:

```sql
EXEC [monitor].[USP_TempDBConfiguration] @ResultSetArt = 'CONSOLE';
```

RAW:

```sql
EXEC [monitor].[USP_TempDBConfiguration] @ResultSetArt = 'RAW';
```

JSON (unabhängig von der Resultsetausgabe):

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_TempDBConfiguration]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

TABLE (Ziel vor dem TRY als Seed-Tabelle anlegen; beide Pfade räumen sie auf):

```sql
CREATE TABLE [#TempDBConfiguration_HelpExample] ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_TempDBConfiguration]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"files":"#TempDBConfiguration_HelpExample"}';
    DROP TABLE [#TempDBConfiguration_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#TempDBConfiguration_HelpExample') IS NOT NULL
        DROP TABLE [#TempDBConfiguration_HelpExample];
    THROW;
END CATCH;
```

HELP (führt keine Quellenabfrage aus; bei TABLE würde der Ziel-Preflight vor HELP laufen):

```sql
EXEC [monitor].[USP_TempDBConfiguration] @Hilfe = 1;
```


## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `files`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Die Dateisicht enthält eine Zeile je TempDB-Datei. RAW ergänzt ein separates Resultset mit den aus sys.configurations verfügbaren ausgewählten Einstellungen; dieses kann je Einstellung eine Zeile enthalten. Die Procedure erzeugt keine Findings.

## So lesen

Berücksichtigen Sie Dateianzahl, Größen-/Growth-Gleichheit, Autogrowth-Einheit, freien Platz, Version Store und Contentionkontext gemeinsam.

## Warum kann das problematisch sein?

Ungleich große Datenfiles werden proportional unterschiedlich genutzt; kleine Growthschritte erzeugen viele Wachstumsereignisse.

## Wann ist es kein Problem?

Nicht jede Instanz benötigt acht Dateien. CPU, Contention und Workload entscheiden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Vier gleich große Dateien ohne Contention können besser sein als acht ungleich große. Prüfen Sie Current TempDB, Filegrowth-Historie und Contention.

**Ähnlich aussehender Gegenfall:** Nicht jede Instanz benötigt acht Dateien. CPU, Contention und Workload entscheiden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Die Procedure liest tempdb.sys.database_files und die drei benannten Einstellungen aus sys.configurations. Fehler der Quellabfragen werden abgefangen und als Status mit IsPartial=1, Fehlernummer und Fehlertext ausgegeben. Es gibt keinen Zeilenlimitparameter; die sichtbaren Dateizeilen bilden den aktuellen TempDB-Dateikatalog ab. Eine nicht vorhandene Konfigurationszeile kann auch bedeuten, dass die Einstellung in der Engineversion nicht verfügbar ist.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest alle aktuellen TempDB-Dateizeilen sowie genau drei bekannte TempDB-Konfigurationsnamen. CONSOLE/TABLE exportieren die Dateisicht; RAW/JSON enthalten zusätzlich die Konfigurationssicht. |
| Teuerster Pfad | Gegenüber dem Standard existiert kein tiefer Modus. Viele TempDB-Dateien und gleichzeitige JSON-/RAW-Ausgabe verbreitern nur die kleine Katalogmenge; Dateiinhalte und Allokationsseiten werden nicht gelesen. |
| Haupttreiber | Anzahl der Zeilen in `tempdb.sys.database_files`; die `sys.configurations`-Quelle ist auf drei Namen begrenzt. Dateigröße beeinflusst die Abfragekosten nicht. |
| Skalierung | Linear mit der Zahl der TempDB-Dateien. Umrechnung von Pages in MB, Growthtyp und Sortierung nach `file_id` sind konstante beziehungsweise sehr kleine CPU-Arbeit. |
| Ressourcen | Zwei kurze Katalogabfragen und kleine Temp-Tabellen. Kein Zugriff auf `sys.dm_db_file_space_usage`, Dateiinhalte, PFS/GAM/SGAM oder Nutzerobjekte. |
| Begrenzungswirkung | Kein Zeilenlimit; erfasst werden alle TempDB-Dateizeilen und die verfügbaren Zeilen für drei festgelegte Konfigurationsnamen. `@ResultSetArt = 'NONE'` spart nur Resultsetausgabe, nicht die Quellabfragen. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe auf TempDB und Serverkonfiguration. Gleichzeitiges Datei-ADD/GROWTH kann dazu führen, dass Dateiliste und Konfigurationssicht verschiedene Momente abbilden. |
| Schutzmechanismus | Kein Gate und kein Scopeparameter. Die feste Begrenzung ist die reale TempDB-Dateizahl plus genau drei abgefragte Konfigurationsnamen; Benutzerdaten, Allokationsseiten und Dateiinhalte liegen außerhalb des implementierten Pfads. |
| Sicherer Einsatz | CONSOLE ist kostengünstig; physische Dateipfade aus RAW/JSON/TABLE nur im geschützten Betriebskontext speichern oder weitergeben. |
| Aussagegrenze | Die Procedure bewertet Konfiguration, nicht aktuelle TempDB-Auslastung, Latchkonkurrenz oder Dateilatenz. Gleiche Dateigröße beweist weder gleichmäßiges Autogrowth noch proportionale Nutzung. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist TempDB hinsichtlich Dateianzahl, Größe, Growth, Layout und Optionen robust konfiguriert?

### Technischer Hintergrund

TempDB wird bei jedem Start neu erstellt. Datafiles bilden Allocationkonkurrenz ab; gleich große Dateien begünstigen Proportional Fill. Autogrowth ist Notfallkapazität, kein laufendes Sizingmodell. Version Store, Internal/User Objects verursachen Runtimebelegung.

### Datenkette

`sys.configurations`, `tempdb.sys.database_files`.

### Source Select

Dateigröße, Wachstum und Ablage kommen direkt aus dem TempDB-Dateikatalog:

```sql
SELECT
      [f].[file_id]
    , [f].[name] AS [LogicalFileName]
    , [f].[type_desc]
    , [f].[size] * 8.0 / 1024.0 AS [SizeMb]
    , [f].[growth]
    , [f].[is_percent_growth]
    , [f].[physical_name]
FROM [tempdb].[sys].[database_files] AS [f] WITH (NOLOCK)
WHERE [f].[state] = 0
ORDER BY [f].[type], [f].[file_id];
```

**Wichtig für die Eigenlast:** Die Quelle ist klein und benötigt keinen Nutzdatenscan. `physical_name` kann in realen Resultsets umgebungsspezifisch sein; nicht ungeprüft exportieren. Die Procedure ändert weder Dateigröße noch Anzahl oder Wachstum.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Katalog- und Dateistand; der TempDB-Inhalt besteht seit dem Engine-Start.

### Bewertung und Gegenprobe

Prüfen Sie Datafile Count relativ zu Workload und CPU, gleiche Initialgröße und Growth, absolute Growthgröße, Volumeplatz, Logfile und versionsabhängige Optionen. Begründen Sie Änderungen anhand gemessener Contention und nicht anhand einer pauschalen Maximalzahl.

### Typische Fehlinterpretation

Mehr Dateien lösen nicht jeden PAGELATCH-Wait; zu viele Dateien erhöhen Verwaltung/Recovery/Storage. Gleichheit beweist keine ausreichende Kapazität.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentTempDB`, Internal Contention, Current IO.

## Primärquellen

- [tempdb database](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#4-monitorusp_tempdbconfiguration)
