# [monitor].[USP_TraceFlags]

**Bereich:** Server Health<br>
**Zweck:** Inventarisiert aktive globale und sessionbezogene Trace Flags.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche globalen Trace Flags und Trace Flags der aufrufenden Session meldet DBCC TRACESTATUS(-1) zum Erhebungszeitpunkt?** Sie bestimmt nicht selbst Zweck oder Wirkung eines Flags; diese Bewertung erfordert versionsspezifische Dokumentation. Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TraceFlags]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_TraceFlags] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | Eingabeform: SQL-bit; 0 bedeutet unterdrückt die Informationsmeldung bei einem Nicht-AVAILABLE-Status, 1 bedeutet gibt eine Severity-10-Meldung mit Modulname und Fehlertext aus. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Hilfe` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet führt nach dem Preflight die DBCC-Erhebung ohne Hilfetext fort, 1 bedeutet druckt Hilfe und kehrt vor DBCC und Statusoutputs zurück. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Eingabeform: ein einzelner Code CONSOLE, RAW, TABLE oder NONE; führende/abschließende Leerzeichen werden entfernt und Groß-/Kleinschreibung wird mit UPPER vereinheitlicht. NULL wird durch COALESCE zu leerem Text, ein leerer oder nur aus Leerzeichen bestehender Wert bleibt leer; alle drei Fälle sind ungültig. Nur die vier genannten Werte sind gültig. CONSOLE und TABLE wählen ihre Fachprojektion und setzen den internen Modus anschließend auf NONE, damit kein generisches Fachresultset zusätzlich ausgegeben wird; RAW liefert rohe Fachresultsets, NONE unterdrückt Resultsets. Ungültige Codes (einschließlich NULL/leer) setzen INVALID_PARAMETER und IsPartial=1; intern werden wegen des nicht-NONE-Modus Status und die nicht-RAW-Fachprojektion ausgegeben. Bei TABLE erfolgt zuerst der Ziel-Preflight; sein Fehler wird geworfen. JSON-Erzeugung ist unabhängig vom ResultSetArt. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Eingabeform: ein gültiges JSON-Objekt mit genau einer Eigenschaft, deren Name exakt traceFlags lautet und deren Stringwert eine vorhandene lokale #temp-Tabelle bezeichnet. Das Ziel muss vor dem Aufruf existieren, leer sein und genau eine Seed-/Platzhalterspalte besitzen; globale ##-Tabellen, permanente Tabellen, Namen mit reserviertem Präfix #Monitor und Namen über 116 Zeichen sind unzulässig. Der Helper ergänzt das Ausgabeschema. Nur bei ResultSetArt=TABLE erforderlich. Außerhalb TABLE werden NULL, leerer oder nur aus Leerzeichen bestehender Inhalt akzeptiert; nichtleerer Inhalt wirft Fehler 51011. Bei TABLE validiert der Preflight JSON und Ziel und wirft bei ungültiger oder fehlender Angabe Fehler 51011; Status-OUTPUT-Parameter werden dann nicht zugewiesen. |
| `@JsonErzeugen` | `bit` | `0` | Eingabeform: SQL-bit; 0 bedeutet lässt @Json nach dem anfänglichen Zurücksetzen auf NULL, 1 bedeutet erstellt JSON mit meta, traceFlags und warnings. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang des JSON-Dokuments, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt vor TABLE-Preflight und Hilfe auf NULL gesetzt. Bei erfolgreicher Hilfe-Rückkehr bleibt @Json NULL; andere Status-/Fehler-OUTPUTs werden dort nicht zugewiesen. Im normalen Pfad wird @Json nur bei @JsonErzeugen=1 nach der Quellverarbeitung befüllt; sonst bleibt es NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte und Bedeutungen: AVAILABLE (kein festgestellter Eingabe- oder abgefangener Quellfehler), INVALID_PARAMETER (ungültige ResultSetArt), DENIED_PERMISSION (abgefangene Quellfehler 229, 297, 300 oder 371), ERROR_HANDLED (übrige abgefangene Quellfehler, einschließlich 1222; kein eigener TIMEOUT-Code). Die reguläre Zuweisung erfolgt nach der Quellverarbeitung; Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert und ein früher Preflight-THROW erreicht die Zuweisung nicht. Ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für die Teilstatuskennzeichnung: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER oder behandeltem Quellfehler. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @IsPartialOut=@Empfaenger OUTPUT angeben; die Variable muss bit sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei abgefangenem DBCC-Fehler die Quellfehlernummer; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorNumberOut=@Empfaenger OUTPUT angeben; die Variable muss int sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Parameter für bei Fehler den Quelltext beziehungsweise bei INVALID_PARAMETER den Hinweis auf die zulässigen ResultSetArt-Werte; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorMessageOut=@Empfaenger OUTPUT angeben; die Variable muss nvarchar(2048) sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird. |

### Aufrufbeispiele

CONSOLE:

```sql
EXEC [monitor].[USP_TraceFlags] @ResultSetArt = 'CONSOLE';
```

RAW:

```sql
EXEC [monitor].[USP_TraceFlags] @ResultSetArt = 'RAW';
```

JSON (unabhängig von der Resultsetausgabe):

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_TraceFlags]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

TABLE (Ziel vor dem TRY als Seed-Tabelle anlegen; beide Pfade räumen sie auf):

```sql
CREATE TABLE [#TraceFlags_HelpExample] ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_TraceFlags]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"traceFlags":"#TraceFlags_HelpExample"}';
    DROP TABLE [#TraceFlags_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID('tempdb..#TraceFlags_HelpExample') IS NOT NULL
        DROP TABLE [#TraceFlags_HelpExample];
    THROW;
END CATCH;
```

HELP (führt keine Quellenabfrage aus; bei TABLE würde der Ziel-Preflight vor HELP laufen):

```sql
EXEC [monitor].[USP_TraceFlags] @Hilfe = 1;
```


## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `traceFlags`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem aktiven Trace Flag und seinem Scope.

## So lesen

Prüfen Sie Flagnummer, global/session Scope, Aktivierungsquelle, Version und dokumentierte Bedeutung.

## Warum kann das problematisch sein?

Undokumentierte oder veraltete Flags können Optimizer- oder Engineverhalten unerwartet verändern.

## Wann ist es kein Problem?

Dokumentierte Flags können bewusste Workarounds oder Diagnosehilfen sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein altes Kompatibilitätsflag nach Upgrade kann neue Standardverbesserungen überdecken. Prüfen Sie Startup Parameters, Microsoft-Dokumentation und Changehistorie.

**Ähnlich aussehender Gegenfall:** Dokumentierte Flags können bewusste Workarounds oder Diagnosehilfen sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Die Procedure fängt Fehler des DBCC-Aufrufs ab und liefert dann IsPartial=1 mit Status, Fehlernummer und Fehlertext. Der Aufruf liest globale Flags und Flags der aktuellen Session; Flags anderer Sitzungen sind nicht Teil des Scopes. Eine leere Ausgabe beschreibt daher den gelieferten Snapshot und belegt keine Aussage zu anderen Verbindungen. Ein Zeilenlimit oder Scopefilter ist nicht implementiert.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Führt genau einmal `DBCC TRACESTATUS(-1) WITH NO_INFOMSGS` aus und gibt die aktiven globalen/sessionbezogenen Flags aus. CONSOLE, RAW, TABLE und JSON projizieren dieselbe materialisierte kleine Quelle. |
| Teuerster Pfad | Gegenüber dem Standard gibt es keinen tieferen Quellpfad; zusätzliche Ausgabeformate erhöhen nur Serialisierung und Transfer der bereits ermittelten Flagzeilen. |
| Haupttreiber | Anzahl aktuell aktiver Trace Flags. Es werden weder Konfigurationskataloge noch Scheduler-DMVs, Startupdateien oder Datenbankobjekte gescannt. |
| Skalierung | Die DBCC-Ausgabe ist instanzweit und gewöhnlich sehr klein. Sortierung nach Flagnummer und JSON-/TABLE-Ausgabe wachsen linear mit den aktiven Flags. |
| Ressourcen | Geringe CPU und eine kleine Temp-Tabelle für die vier DBCC-Spalten `TraceFlag`, `Status`, `GlobalFlag`, `SessionFlag`. |
| Begrenzungswirkung | Die Procedure besitzt weder Scopefilter noch `@MaxZeilen`; es wird absichtlich die vollständige aktive Flagliste ausgegeben. `@ResultSetArt = 'NONE'` unterdrückt Ausgabe, spart aber den DBCC-Aufruf nicht. |
| Locking und Nebenwirkungen | `DBCC TRACESTATUS` liest nur Zustand und aktiviert/deaktiviert kein Flag. Es werden keine Nutzdatenlocks absichtlich gehalten; die Flagkonfiguration kann sich unmittelbar nach dem Snapshot ändern. |
| Schutzmechanismus | Kein Gate und kein Limit. Der Quellvertrag ist konstruktiv auf genau einen read-only `DBCC TRACESTATUS(-1)`-Aufruf begrenzt; die Procedure setzt oder löscht keine Trace Flags. Ausgabeunterdrückung ist kein Quellkostenschutz. |
| Sicherer Einsatz | CONSOLE im Standardpfad und Status zuerst lesen. Die Ausgabe enthält Flagnummer und Scope, aber keine Pfade, SQL-Texte oder Konfigurationswerte. |
| Aussagegrenze | Der Snapshot zeigt nur aktive Flags und erklärt weder ihren Zweck noch, ob sie per Startup, globalem DBCC oder Session gesetzt wurden. Für Supportstatus und Wirkung sind SQL-Version, Scope und separate Startparameter-/Konfigurationsquellen nötig. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche globalen oder sessionbezogenen Trace Flags sind aktiv und welche Engineverhaltensänderung ist damit verbunden?

### Technischer Hintergrund

Trace Flags aktivieren Diagnose- oder Verhaltenspfade auf globaler/sessionbezogener Scope. Manche wurden durch Database Scoped Configurations oder neuere Defaults ersetzt; Supportstatus ist versionsabhängig. Startupparameter können globale Flags früh setzen.

### Datenkette

`DBCC TRACESTATUS(-1)` → Temp-Tabelle → nach Flagnummer sortierte
CONSOLE-/RAW-/TABLE-/JSON-Projektion. Es gibt keine Childmodule.

### Source Select

Kein `SELECT` auf eine DMV: Die Engine stellt aktive Trace Flags über einen DBCC-Befehl bereit. Der direkte Quellaufruf lautet:

```sql
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;
```

Die Procedure fängt dieses Resultset in einer lokalen Temp-Tabelle ab und projiziert es sortiert in die Ausgabeformate.

**Wichtig für die Eigenlast:** Der Befehl liefert nur aktive globale und sessionbezogene Flags und ändert keinen Zustand. Es existiert kein serverseitiger Flagfilter; Filterung erfolgt erst nach der kleinen DBCC-Ausgabe.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Runtimezustand. Sessionflags gelten nur im jeweiligen Kontext; globale Flags gelten bis zur Deaktivierung oder zum Neustart.

### Bewertung und Gegenprobe

Prüfen Sie Flagnummer, Scope, Startupbezug, dokumentierter Zweck, Version und aktuelle Notwendigkeit. Behandeln Sie undokumentierte Flags besonders vorsichtig.

### Typische Fehlinterpretation

Aktiv heißt nicht, dass jeder Workloadpfad betroffen ist. Ein früher notwendiges Flag kann nach Upgrade redundant oder schädlich sein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_StartupParameters`, Server Configuration und offizielle versionsspezifische Dokumentation.

Für den [DBCC-Statusbefehl](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-tracestatus-transact-sql?view=sql-server-ver15) genügt unter SQL Server die Rolle `public`; der Aufruf der Procedure benötigt zusätzlich `EXECUTE`. Sitzungsflags anderer Verbindungen gehören nicht zum Abfrageumfang.

## Primärquellen

- [DBCC TRACESTATUS](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-tracestatus-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#6-monitorusp_traceflags)
