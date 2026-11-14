# [monitor].[USP_LoadedModuleInventory]

Die Procedure zeigt Metadaten von Modulen, die im Aufnahmezeitpunkt im Adressraum des SQL-Server-Prozesses geladen sind. Ihre einzige Fachquelle ist `sys.dm_os_loaded_modules`. Sie gibt den nativen `name` als `ModuleName` unverändert einschließlich eines möglichen vollständigen Pfads aus; `ModuleBasename` ist ein zusätzliches Komfortfeld. Die Aufnahme ist keine Host-, Filtertreiber-, Signatur-, Malware- oder Gesundheitsprüfung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_LoadedModuleInventory]
    @NurBuildFlags=0,
    @MaxZeilen=100,
    @ResultSetArt='CONSOLE',
    @PrintMeldungen=0;
```

Der Caller braucht Zugriff auf die DMV. SQL Server 2019 verlangt dafür `VIEW SERVER STATE`, SQL Server 2022 und neuer `VIEW SERVER PERFORMANCE STATE`. Die Procedure erteilt keine Berechtigung und führt ohne Elevation im Caller-Kontext aus. Der normale Aufruf verlangt außerhalb einer Caller-Transaktion `@@TRANCOUNT=0` und `IMPLICIT_TRANSACTIONS OFF`; die Hilfe ist auch innerhalb einer Caller-Transaktion erlaubt. Ein tatsächlich verweigerter Zugriff wird mit nativer Fehlernummer und auf 2048 Zeichen begrenztem nativem Fehlertext gemeldet. Laufzeitzeilen und Fehlertexte können Pfade enthalten; vor Speicherung in Repository-Artefakten ist der Artefakt-Datenschutzvertrag anzuwenden.

## Interpretation

Eine `loadedModules`-Zeile beschreibt eine projizierte DMV-Zeile. `ModuleName` ist der unveränderte native `name` einschließlich eines möglichen Pfads. `ModuleBasename` ist dessen letzter Bestandteil nach Windows- oder Linux-Trennzeichen. Ein leerer oder nach der Abtrennung noch doppelpunkttragender Name wird als NULL ausgegeben; `warnings` nennt die Uneindeutigkeit. Der Basename ersetzt den nativen Namen nicht. Gleiche öffentliche Zeilen bleiben mehrfach erhalten; aus ihnen folgt keine eindeutige Modulidentität.

`FileVersion` und `ProductVersion` sind die nativen Versionszeichenfolgen. `Debug`, `Patched`, `Prerelease`, `PrivateBuild` und `SpecialBuild` sind native Build-Flags, die auch NULL sein können. `Language` bleibt ein nativer ganzzahliger Wert. Ein gesetztes Flag ist kein Sicherheitsurteil. Die Procedure liest weder `base_address`, `company` noch `description`; `ModuleName` bleibt als Runtimewert in der Ergebnistabelle erhalten.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@NurBuildFlags` | `bit` | `0` | 0 lässt alle projizierten Quellzeilen für die Ausgabe zu; 1 lässt nur Zeilen mit mindestens einem der fünf nativen Build-Flags gleich 1 zu. NULL ist im normalen Pfad ungültig. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Die Auswahl erfolgt nach dem vollständigen DMV-Read. |
| `@MaxZeilen` | `int` | `1000` | Positive Werte 1 bis 2147483647 begrenzen nur die nach den zehn öffentlichen Feldern sortierte Ausgabe. NULL oder 0 bedeuten unbegrenzt; negative Werte sind ungültig. Ein Leertext ist keine eigene int-Eingabeform und wird gegebenenfalls schon vor dem Procedure-Aufruf von SQL Server konvertiert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | SQL Server bindet oder kürzt zunächst auf `varchar(16)`; danach sind nach äußerem U+0020-Trimmen und Großschreibung genau `CONSOLE` für eine formatierte Fachmenge, `RAW` für vier Resultsets, `TABLE` für benannte lokale Temp-Ziele oder `NONE` ohne Fachresultsets. NULL und leer sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ein JSON-Objekt mit mindestens einem exakt geschriebenen Schlüssel `moduleStatus`, `loadedModules`, `sourceStatus` oder `warnings`. Werte sind unqualifizierte lokale `#Temp`-Namen, weder `##` noch `#Monitor`; die Konvertierung zu `sysname` geschieht vor den Guards, danach gilt `LEN<=116`. Gruppenschlüssel sind binär verschieden, Zielnamen case-insensitiv verschieden. Jedes Ziel existiert leer mit genau einer beliebigen Seed-Spalte. Teilmapping mit mindestens einer Gruppe ist zulässig. Doppelte oder unbekannte Schlüssel und ungültige Ziele werden vor dem DMV-Read als `INVALID_PARAMETER` abgewiesen. Ein späterer Writerfehler ist technisch und kann frühere Zielschreibungen belassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt zusätzlich JSON unabhängig von `@ResultSetArt`; 0 erzeugt keines. NULL ist im normalen Pfad ungültig. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optional an eine `nvarchar(max)`-Variable mit OUTPUT binden; der Eingang wird auf NULL zurückgesetzt. Bei `@JsonErzeugen=1` liefert der normale Pfad JSON, auch mit Quellenfehlerstatus und leerer Fachmenge. Hilfe, direkte Parameterfehler und technische Ausgabefehler liefern NULL. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt zusätzliche Severity-10-Meldungen mit nativem oder Framework-Fehlertext aus; 0 unterdrückt sie. NULL ist im normalen Pfad ungültig. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Die Hilfe-PRINT-Ausgabe ist unabhängig. |
| `@Hilfe` | `bit` | `0` | 1 gibt Hilfe vor Validierung und DMV-Read aus und kehrt mit `AVAILABLE` und `IsPartial=0` zurück; 0 führt die Aufnahme nur bei `@@TRANCOUNT=0` und `IMPLICIT_TRANSACTIONS OFF` aus; andernfalls `INVALID_PARAMETER` mit 51011 ohne DMV-Read. NULL ist im normalen Pfad ungültig. Andere bitkonvertierbare Nichtnullwerte werden 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optional an `varchar(40)` mit OUTPUT binden; der Eingang wird gelöscht. `AVAILABLE`: Hilfe; `AVAILABLE_LIMITED`: erfolgreicher nichtleerer DMV-Read; `EMPTY_UNPROVEN`: erfolgreicher leerer DMV-Read; `DENIED_PERMISSION`: nativer Berechtigungsfehler; `UNAVAILABLE_OBJECT`: fehlende DMV; `ERROR_HANDLED`: sonstiger Quellen- oder technischer Fehler; `INVALID_PARAMETER`: ungültige Eingabe. Eine Filterung kann bei `AVAILABLE_LIMITED` null Ausgabezeilen ergeben. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optional an `bit` mit OUTPUT binden; der Eingang wird gelöscht. Hilfe liefert 0, jeder normale Lauf und Fehlerpfad 1. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optional an `int` mit OUTPUT binden; der Eingang wird gelöscht. Hilfe und erfolgreicher Read liefern NULL; direkte Parameterfehler 51011, behandelte Quellenfehler die native SQL-Fehlernummer und technische Fehler die tatsächliche oder Writer-Fehlernummer. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optional an `nvarchar(2048)` mit OUTPUT binden; der Eingang wird gelöscht. Erfolg liefert NULL. Native Quellen- und Technikfehler liefern den auf 2048 Zeichen begrenzten `ERROR_MESSAGE`-Text, TABLE-Helfer ihren begrenzten Fehlertext; direkte Eingabefehler haben eigene Validierungsmeldungen. |

Ausgelassene Argumente erhalten ihren jeweiligen Default. Die bit- und int-Konvertierung durch SQL Server geschieht vor der internen Validierung.

## Resultsets

`RAW` liefert `moduleStatus`, `loadedModules`, `sourceStatus` und `warnings` in dieser Reihenfolge. `loadedModules` enthält genau `ModuleName`, `ModuleBasename`, `FileVersion`, `ProductVersion`, `Debug`, `Patched`, `Prerelease`, `PrivateBuild`, `SpecialBuild` und `Language`. Die vollständigen vier Schemas und Datentypen stehen in [ResultSets.csv](../../../Metadata/Inventory/ResultSets.csv). `TABLE` schreibt dieselben benannten Schemas; `CONSOLE` liefert eine formatierte Fachmenge mit `ModuleName` als Objekt; `Detail` zeigt Basename, Datei- und Produktversion, die fünf Flagwerte in der Reihenfolge `Debug/Patched/Prerelease/PrivateBuild/SpecialBuild` sowie `Language`. `NONE` liefert keine Fachresultsets. Optionales JSON enthält `meta` mit `schemaVersion=1` und alle vier Arrays, auch wenn eines leer ist.

```sql
CREATE TABLE #ExampleLoadedModules ([Seed] int NULL);
EXEC [monitor].[USP_LoadedModuleInventory]
    @NurBuildFlags=0,
    @MaxZeilen=100,
    @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"loadedModules":"#ExampleLoadedModules"}';
SELECT * FROM #ExampleLoadedModules;
DROP TABLE #ExampleLoadedModules;
```

## Eine Zeile bedeutet

Eine Zeile bezeichnet eine native, unter den Caller-Rechten gelesene DMV-Zeile mit dem unveränderten nativen Namen und dem zusätzlichen Basenamen. Sie belegt weder einen Hostbestand außerhalb des SQL-Prozesses noch den Ursprung, die Vertrauenswürdigkeit oder eine bestimmte Verwendung des Moduls.

## So lesen

Prüfen Sie zuerst `sourceStatus`: `NativeReadState`, `StatusCode` und `ErrorNumber` trennen einen erfolgreichen Read von einer tatsächlichen Störung. `ObservedRows` zählt den vollständigen DMV-Read, `MatchedRows` die Flag-Auswahl und `ReturnedRows` die nach `@MaxZeilen` ausgegebenen Zeilen. Bei einem Quellenfehler bleiben diese drei Zahlen NULL; ein erfolgreicher leerer Read meldet jeweils 0. Danach lesen Sie `loadedModules` und `warnings`.

## Warum kann das problematisch sein?

Ein Modulname oder Build-Flag kann als Beleg für einen Hosttreiber, eine Signatur oder ein Sicherheitsproblem fehlgedeutet werden. Die DMV sieht nur den SQL-Prozess, und die ausgegebenen Werte enthalten keine Prüfung von Herkunft oder Integrität. Ein kleines `@MaxZeilen` verkürzt die Ausgabe, aber nicht DMV-Read, Flag-Auswahl und Sortierung.

## Wann ist es kein Problem?

Für eine begrenzte Aufnahme der momentan im SQL-Prozess gemeldeten Module reichen die öffentlichen Felder und der Quellenstatus. Wenn eine Datei, ein Hosttreiber oder eine Signatur geprüft werden soll, ist eine eigenständig autorisierte Untersuchung mit anderen Datenquellen nötig.

## Technische Vertiefung

### Leitfrage

Welche Modulmetadaten liefert `sys.dm_os_loaded_modules` im aktuellen SQL-Prozess unter den Caller-Rechten, mit unverändertem Modulnamen einschließlich möglichem Pfad, aber ohne Prozessadresse? Die Procedure beantwortet keine Host- oder Risiko-Frage.

### Technischer Hintergrund

Die DMV enthält native Modulnamen mit möglichen Pfaden, zwei Versionsfelder, fünf Build-Flags und einen Sprachwert. Die Procedure übernimmt den nativen Namen unverändert und leitet zusätzlich im Quell-Select den Basenamen ab. Für Namen ohne eindeutigen pfadfreien letzten Bestandteil bleibt `ModuleBasename` NULL und ein konstanter Warnhinweis wird gesetzt. Gleiche zehn Feldwerte werden nicht zusammengeführt.

### Datenkette

Ein vollständiger DMV-Read füllt die zehnfeldrige Projektion mit nativem Namen und Basenamen. Erst danach wählt `@NurBuildFlags` Zeilen aus und `@MaxZeilen` begrenzt die Ausgabe in deterministischer Reihenfolge der öffentlichen Felder. Der Lauf setzt `sourceStatus`, `warnings` und `moduleStatus` und gibt die gewählten Gruppen über RAW, TABLE, CONSOLE und optional JSON aus. Eine positive Ausgabelimitierung ist kein Quellenlimit.

### Source Select

Der Ausschnitt zeigt die fachliche Projektion des Quell-Selects. Er lässt die vollständige Fehler- und Ausgabelogik weg und zeigt den nativen Namen einschließlich möglichem Pfad, aber keine Prozessadresse.

```sql
SELECT [m].[name],CASE WHEN [b].[BaseName] IS NULL
              OR NULLIF(LTRIM(RTRIM([b].[BaseName])),N'') IS NULL
              OR CHARINDEX(N':',[b].[BaseName])>0
            THEN NULL ELSE [b].[BaseName] END,
       [m].[file_version],[m].[product_version],[m].[debug],[m].[patched],
       [m].[prerelease],[m].[private_build],[m].[special_build],
       [m].[language]
FROM [sys].[dm_os_loaded_modules] AS [m] WITH (NOLOCK)
CROSS APPLY
(
    SELECT RIGHT([m].[name],
        CHARINDEX(N'\',REVERSE(REPLACE([m].[name],N'/',N'\'))+N'\')-1)
        AS [BaseName]
) AS [b];
```

**Wichtig für die Eigenlast:** Die DMV wird vollständig gelesen und die zehnfeldrige Projektion sortiert, auch wenn `@MaxZeilen` klein ist. `WITH (NOLOCK)` vermeidet keine unstete Aufnahme bei parallelen Änderungen. Die Procedure nutzt keinen Gesamtzeit- oder Quellenbudgetschalter.

### Zeit- und Scope-Modell

`CapturedAtUtc` markiert den Aufnahmeanfang, aber nicht einen atomaren Zeitpunkt aller DMV-Zeilen. Die Versionszeichenfolgen haben keinen eigenen Zeitbezug. Ein Quellenfehler ist keine leere Menge. Ein erfolgreicher leerer Read ist `EMPTY_UNPROVEN`, weil die beobachtete Leere allein weder die SQL-Prozessumgebung noch mögliche Erfassungsbedingungen erklärt.

### Bewertung und Gegenprobe

Vergleichen Sie eine erwartete Zeile im selben Caller-Kontext mit einer direkten DMV-Abfrage derselben zehn Feldwerte einschließlich des unveränderten nativen Namens. Prüfen Sie alle zehn Felder und die Multiplizität, nicht nur den Basenamen. Der native SQL-Server-2025-Vertragstest nutzt die vorhandenen DMV-Zeilen als positive Quelle und provoziert kein Laden eines Moduls. Erwartete und behandelte Fixturepfade melden nur konstante oder numerische Diagnosen; eine allgemeine Freiheit von Engine- oder Compile-Ausgaben ist damit nicht zugesichert. Ein kontrolliert erzwungener nativer Berechtigungsfehler ist für diesen V1-Test kein zugesicherter Nachweis.

### Typische Fehlinterpretation

`ModuleName` kann einen vollständigen Dateipfad enthalten. Sein Wert ist weder ein Signatur- noch ein Vertrauensnachweis. `Patched=1` oder `Debug=1` bewertet weder Sicherheit noch Betriebszustand. `AVAILABLE_LIMITED` mit `ReturnedRows=0` kann bei eingeschalteter Flag-Auswahl auftreten; es bedeutet nicht, dass die DMV null Zeilen hatte.

### Folgeanalyse

Bei unerwarteter Leere prüfen Sie `NativeReadState`, den nativen Fehlercode, die Flag-Auswahl und das Ausgabelimit. Für eine Dateipfad-, Signatur- oder Hosttreiberfrage braucht es einen gesonderten, ausdrücklich autorisierten Daten- und Berechtigungsvertrag.

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/330_USP_LoadedModuleInventory.sql) zeigt die kanonische Implementierung. Das Dokument [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) beschreibt allgemeine Beobachtungsgrenzen.
