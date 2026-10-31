# [monitor].[USP_ServerConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Zeigt konfigurierte und aktive Serveroptionen mit Bewertungscontext.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Serveroptionen weichen von Default/Empfehlung ab und welche Werte sind tatsächlich aktiv?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerConfiguration]
      @NurKernparameter = 1,
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_ServerConfiguration] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@NurKernparameter` | `bit` | `1` | Eingabeform: SQL-bit; 0 bedeutet der Filterausdruck wählt alle sys.configurations-Zeilen, weil `@NurKernparameter=0` wahr ist, 1 bedeutet der IN-Filter wählt nur die folgende kuratierte Liste: max degree of parallelism; cost threshold for parallelism; max server memory (MB); min server memory (MB); optimize for ad hoc workloads; backup compression default; remote admin connections; contained database authentication; clr enabled; clr strict security; xp_cmdshell; Ole Automation Procedures; external scripts enabled; blocked process threshold (s); query wait (s); affinity mask; affinity64 mask. NULL wirkt ebenfalls wie die Kernliste: für diese Namen ist die IN-Bedingung wahr, für andere bleibt `NULL=0 OR false` unbekannt und die Zeile wird herausgefiltert.. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@PrintMeldungen` | `bit` | `1` | Eingabeform: SQL-bit; 0 bedeutet unterdrückt die Informationsmeldung bei einem Nicht-AVAILABLE-Status, 1 bedeutet gibt eine Severity-10-Meldung mit Modulname und Fehlertext aus. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Hilfe` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet führt die Erhebung ohne Hilfetext fort, 1 bedeutet druckt Hilfe und beendet die Procedure vor Erhebung und Statusoutputs. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Eingabeform: ein einzelner Code CONSOLE, RAW, TABLE oder NONE; führende/abschließende Leerzeichen werden entfernt und Groß-/Kleinschreibung wird mit UPPER vereinheitlicht. NULL wird durch COALESCE zu leerem Text, ein leerer oder nur aus Leerzeichen bestehender Wert bleibt leer; alle drei Fälle sind ungültig. Nur die vier genannten Werte sind gültig. CONSOLE und TABLE wählen ihre Fachprojektion und setzen den internen Modus anschließend auf NONE, damit kein generisches Fachresultset zusätzlich ausgegeben wird; RAW liefert rohe Fachresultsets, NONE unterdrückt Resultsets. Ungültige Codes (einschließlich NULL/leer) setzen INVALID_PARAMETER und IsPartial=1; intern werden wegen des nicht-NONE-Modus Status und die nicht-RAW-Fachprojektion ausgegeben. Bei TABLE erfolgt zuerst der Ziel-Preflight; sein Fehler wird geworfen. JSON-Erzeugung ist unabhängig vom ResultSetArt. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Eingabeform: ein gültiges JSON-Objekt mit genau einer Eigenschaft, deren Name exakt configuration lautet und deren Stringwert eine vorhandene lokale #temp-Tabelle bezeichnet. Das Ziel muss vor dem Aufruf existieren, leer sein und genau eine Seed-/Platzhalterspalte besitzen; globale ##-Tabellen, permanente Tabellen, Namen mit reserviertem Präfix #Monitor und Namen über 116 Zeichen sind unzulässig. Der Helper ergänzt das Ausgabeschema. Nur bei ResultSetArt=TABLE erforderlich. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Inhalt akzeptiert; nichtleerer Inhalt wirft Fehler 51011. Bei TABLE validiert der Preflight JSON und Ziel und wirft bei ungültiger oder fehlender Angabe Fehler 51011; Status-OUTPUT-Parameter werden dann nicht zugewiesen. |
| `@JsonErzeugen` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet lässt @Json nach dem anfänglichen Zurücksetzen auf NULL, 1 bedeutet erstellt JSON mit meta, configuration und warnings. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang des JSON-Dokuments, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt vor TABLE-Preflight und Hilfe auf NULL gesetzt. Bei erfolgreicher Hilfe-Rückkehr bleibt @Json NULL; andere Status-/Fehler-OUTPUTs werden dort nicht zugewiesen. Im normalen Pfad wird @Json nur bei @JsonErzeugen=1 nach der Quellverarbeitung befüllt; sonst bleibt es NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte und Bedeutungen: AVAILABLE (kein festgestellter Eingabe- oder abgefangener Quellfehler), INVALID_PARAMETER (ungültige ResultSetArt), DENIED_PERMISSION (abgefangene Quellfehler 229, 297, 300 oder 371), TIMEOUT (Quellfehler 1222), ERROR_HANDLED (übrige abgefangene Quellfehler). Die reguläre Zuweisung erfolgt nach der Quellverarbeitung; Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert und ein früher Preflight-THROW erreicht die Zuweisung nicht. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für die Teilstatuskennzeichnung: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER oder behandeltem Quellfehler. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @IsPartialOut=@Empfaenger OUTPUT angeben; die Variable muss bit sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei abgefangenem Quellfehler die Quellfehlernummer; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorNumberOut=@Empfaenger OUTPUT angeben; die Variable muss int sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei Fehler den Quelltext beziehungsweise bei INVALID_PARAMETER den Hinweis auf die zulässigen ResultSetArt-Werte; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorMessageOut=@Empfaenger OUTPUT angeben; die Variable muss nvarchar(2048) sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |

### Aufrufbeispiele

CONSOLE:

```sql
EXEC [monitor].[USP_ServerConfiguration] @ResultSetArt = 'CONSOLE';
```

RAW:

```sql
EXEC [monitor].[USP_ServerConfiguration] @ResultSetArt = 'RAW';
```

JSON (unabhängig von der Resultsetausgabe):

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ServerConfiguration]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

TABLE (Ziel vor dem TRY als Seed-Tabelle anlegen; beide Pfade räumen sie auf):

```sql
CREATE TABLE [#ServerConfiguration_HelpExample] ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ServerConfiguration]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"configuration":"#ServerConfiguration_HelpExample"}';
    DROP TABLE [#ServerConfiguration_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#ServerConfiguration_HelpExample') IS NOT NULL
        DROP TABLE [#ServerConfiguration_HelpExample];
    THROW;
END CATCH;
```

HELP (führt keine Quellenabfrage aus; bei TABLE würde der Ziel-Preflight vor HELP laufen):

```sql
EXEC [monitor].[USP_ServerConfiguration] @Hilfe = 1;
```


## Resultsets und Leserichtung

Der TABLE-Vertrag registriert ausschließlich `configuration`. Der Modulstatus wird als Resultset ausgegeben, sofern die Resultsetausgabe nicht unterdrückt ist. RAW liefert das Konfigurationsresultset; CONSOLE rendert dieselbe Fachquelle. JSON enthält meta, configuration und warnings. Die Konfigurationstabelle ist nicht mit anders granularen Resultsets zu summieren.

## Eine Zeile bedeutet

Eine Zeile entspricht einer von sys.configurations gelieferten und durch @NurKernparameter ausgewählten Serveroption; die Ausgabe ergänzt Grenzen, configured/running value, Dynamic-/Advanced-Flags sowie einen regelbasierten Finding- und Interpretationstext.

## So lesen

Vergleichen Sie Configured Value, Run Value, Dynamic/Advanced-Status, Default und Beschreibung.

## Warum kann das problematisch sein?

Abweichende Run Values können ausstehendes Reconfigure/Restart anzeigen; extreme Werte können Ressourcen falsch begrenzen.

## Wann ist es kein Problem?

Abweichung vom Default ist kein Fehler. Produktive Systeme benötigen oft bewusste Anpassungen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Niedriges max server memory kann absichtlich Speicher für andere Dienste reservieren. Prüfen Sie erst OS-, Workload- und Memorykontext.

**Ähnlich aussehender Gegenfall:** Abweichung vom Default ist kein Fehler. Produktive Systeme benötigen oft bewusste Anpassungen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Fehler bei sys.dm_os_sys_info oder sys.configurations werden abgefangen und als Status mit IsPartial=1, Fehlernummer und Fehlertext ausgegeben. Die Schedulerzahl kann für die MAXDOP-Interpretation NULL sein, wenn die Quellabfrage fehlschlägt; die Procedure wertet die Optionen weiterhin im TRY-Block aus, sofern kein Fehler den Block beendet. Es existiert kein Zeilenlimit. Bei @NurKernparameter=1 ist eine nicht gelistete Option absichtlich nicht sichtbar; fehlende Zeilen sind keine Nullwerte.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | `@NurKernparameter = 1` liest eine feste Liste betriebsrelevanter Optionen und eine Schedulerzahl für Kontext/Findinglogik. Konfigurierter und aktiver Wert werden gemeinsam ausgegeben. |
| Teuerster Pfad | `@NurKernparameter = 0` liest alle Zeilen aus `sys.configurations`; auch das bleibt ein kleiner Serverkatalog ohne Child- oder Historienpfad. |
| Haupttreiber | Anzahl der Serverkonfigurationsoptionen. Die Procedure liest keine `sp_configure`-Änderungshistorie und keine Database-Scoped Configurations. |
| Skalierung | Linear mit wenigen hundert Konfigurationszeilen; CASE-Bewertung und Sortierung sind gering. Resultgröße ist unabhängig von Datenbank-/Workloadgröße. |
| Ressourcen | Eine SQLOS-Infozeile, ein Serverkatalogscan und eine kleine Temp-Tabelle. Kein `RECONFIGURE`, XML, Sampling oder Cross-Database-SQL. |
| Begrenzungswirkung | Der Kernparameter-Schalter reduziert Quelle und Ausgabe fachlich; ein Max-Rows-Parameter existiert nicht. `NONE` unterdrückt nur Resultsets, nicht die Erhebung. |
| Locking und Nebenwirkungen | Read-only. Werte können zwischen `dm_os_sys_info` und `sys.configurations` geändert werden; die Procedure selbst setzt keine Option und führt kein `RECONFIGURE` aus. |
| Schutzmechanismus | Kein Gate. `@NurKernparameter = 1` begrenzt die Auswahl auf 17 festgelegte Namen; 0 wählt alle Einträge aus `sys.configurations`. Beide Pfade lesen nur und ändern keine Konfiguration. |
| Sicherer Einsatz | Mit `@NurKernparameter = 1` starten; erst für ein Konfigurationsaudit auf alle Optionen erweitern. Ausgabe enthält keine Kennwörter oder Dateipfade. |
| Aussagegrenze | Ein Finding markiert Reviewbedarf, nicht automatisch Fehlkonfiguration. Edition, Workload, NUMA, verfügbare RAM-/CPU-Ressourcen und Änderungsfenster müssen separat berücksichtigt werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Serveroptionen weichen von Default/Empfehlung ab und welche Werte sind tatsächlich aktiv?

### Technischer Hintergrund

`sys.configurations` besitzt configured `value` und `value_in_use`, Dynamic/Advanced Flags. Manche Änderungen greifen sofort, andere nach RECONFIGURE oder Restart. Optionen beeinflussen Parallelität, Memory, Security, Remotezugriff und Engineverhalten.

### Datenkette

`sys.configurations`, `sys.dm_os_sys_info`.

### Source Select

Der Konfigurationskern liest dokumentierten und aktiven Wert direkt aus `sys.configurations`:

```sql
SELECT
      [c].[configuration_id]
    , [c].[name]
    , [c].[value]
    , [c].[value_in_use]
    , [c].[is_dynamic]
    , [c].[is_advanced]
FROM [sys].[configurations] AS [c] WITH (NOLOCK)
WHERE [c].[name] IN
      (N'max server memory (MB)',
       N'max degree of parallelism',
       N'cost threshold for parallelism');
```

**Wichtig für die Eigenlast:** Die Quelle ist klein. Konfigurationsnamen bereits im Quellselect begrenzen; die Procedure liest nur und führt weder `sp_configure` noch `RECONFIGURE` aus.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Konfigurationsstand; einige Änderungen an `value` sind noch nicht in use.

### Bewertung und Gegenprobe

Berücksichtigen Sie Configured und In Use, Is Dynamic, Is Advanced, Version und Edition, Workload und Änderungsgrund gemeinsam. Priorisieren Sie Abweichungen, korrigieren Sie diese jedoch nicht automatisch.

### Typische Fehlinterpretation

Der Standardwert ist nicht in jedem Kontext geeignet, und eine bekannte Empfehlung gilt nicht universell. Mehrere Optionen interagieren, etwa MAXDOP mit Cost Threshold oder Max Memory mit der Betriebssystemreserve.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Spezifische Topologie-/Memory-/Securitymodule und kontrolliertes Changeverfahren.

## Primärquellen

- [sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#5-monitorusp_serverconfiguration)
