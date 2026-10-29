# Verbindliche Parameter- und API-Konvention

Stand: 2026-10-29

## Grundsatz

Dieselbe Funktionalität verwendet in sämtlichen öffentlichen `monitor`-Objekten exakt denselben Parameternamen, Datentyp, Defaultvertrag und dieselbe Semantik. Objekt-, Parameter-, Spalten- und Aliasnamen sind wegen `SQL_Latin1_General_CP1_CS_AS` exakt case-sensitiv.

Textuelle **Steuerwerte** werden dagegen mit `UPPER(LTRIM(RTRIM(...)))` normalisiert. Daher sind beispielsweise `RAW`, `raw` und `Raw` gleichwertig. Fachliche Werte wie Datenbank-, Schema-, Objekt-, Login- oder Programmnamen werden nicht normalisiert und case-sensitiv verglichen.

## Kanonische Querschnittsparameter

- `@MaxZeilen int`: positive Werte begrenzen, `NULL`/`0` bedeutet unbegrenzt, negative Werte sind `INVALID_PARAMETER`.
- `@MaxAnalyseobjekte int`: getrenntes Budget für zu analysierende Pläne/Objekte.
- `@DatabaseNames nvarchar(max)`: bracket-aware Pipe-Liste; `NULL`/`N''` = keine Einschränkung, also alle sichtbaren Online-Benutzerdatenbanken.
- `@DatabaseNamePattern nvarchar(4000)`: ein einzelnes `like:`, `regex:` oder `regexi:` Pattern; exklusiv zu `@DatabaseNames`.
- `@SystemdatenbankenEinbeziehen bit=0`: Systemdatenbanken sind ausschließlich opt-in.
- `@HighImpactConfirmed bit=0`: bestätigt nur einen tatsächlich aktivierten ressourcenintensiven Pfad.
- `@SessionIds nvarchar(max)`: Liste numerischer Session-IDs; Pipe, Beistrich und Strichpunkt sind gleichwertige Trennzeichen und dürfen gemischt werden.
- `@ResultSetArt varchar(16)='CONSOLE'`, `@ResultTablesJson nvarchar(max)=NULL`, `@JsonErzeugen bit=0`, `@Json nvarchar(max)=NULL OUTPUT`.
- `@PrintMeldungen bit=1`, `@Hilfe bit=0`.

## Geltungsbereich nach Procedure-Rolle

Die gemeinsame Ausgabesteuerung gilt für Procedures mit einem fachlichen
Resultset-Vertrag. Die öffentlichen Vorbereitungshelfer
[USP_PrepareDatabaseCandidates](../../Code/01_Common/083_USP_PrepareDatabaseCandidates.sql)
und [USP_PrepareNameFilters](../../Code/01_Common/084_USP_PrepareNameFilters.sql)
befüllen dagegen Temp-Tabellen des Aufrufers und liefern technische
OUTPUT-Werte; sie besitzen keine Renderer- oder JSON-Ausgabesteuerung.
[USP_ConfigureSnapshotTarget](../../Code/10_SnapshotBaseline/080_USP_ConfigureSnapshotTarget.sql)
ist ein persistenter Konfigurationsbefehl mit Status-OUTPUTs und ebenfalls
kein fachlicher Resultset-Renderer. Diese Rollenunterschiede sind keine
fehlenden Ausgabeparameter. `@Hilfe bit=0` gilt auch für diese Procedures;
erforderliche Eingabe- und OUTPUT-Argumente ihrer Signaturen bleiben bei
einem Hilfeaufruf erforderlich.

Ein Zeilenlimit ist nur dort Teil der Schnittstelle, wo die Procedure
`@MaxZeilen` tatsächlich deklariert. Aus seiner Abwesenheit folgt weder eine
Begrenzung noch automatisch ein fehlender Pflichtparameter. Wird der Parameter
angeboten, gilt der oben beschriebene positive, NULL-/0- und Negativvertrag.
Zusätzliche Status-OUTPUTs sind ebenfalls procedureabhängig; ihre Verfügbarkeit
ist der jeweiligen Signatur zu entnehmen.

Der [JSON-Konstruktor USP_CreateExecutionEvidenceJson](../Analysis_Guides/Procedures/USP_CreateExecutionEvidenceJson.md)
hat abweichend vom optionalen Analyseexport den Default `@JsonErzeugen bit=1`,
weil sein Zweck die Erzeugung eines Execution-Evidence-JSON ist. Dieser
quellseitige Default bleibt erhalten. JSON wird auch dort über `@Json OUTPUT`
ausgegeben und ist kein zusätzlicher Wert von `@ResultSetArt`.

## Query Store

`@QueryStoreDatabaseNames` bezeichnet die Datenbanken, deren Query Store gelesen wird. `@ReferencedDatabaseNames` filtert dagegen auf Datenbanken, die in gespeicherten Plänen referenziert werden. Diese Funktionen sind bewusst getrennt.

## Extended Events

`@ExtendedEventSessionNames`/Pattern filtern Inventar- und Runtime-Listen. `@SourceExtendedEventSessionName` bezeichnet genau eine Forensikquelle für Event-, Deadlock- oder Blocked-Process-Auswertung.
