# [monitor].[USP_CheckFrameworkCapabilities]

**Bereich:** Common<br>
**Zweck:** Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** Nicht empirisch bestimmt

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?** Sie unterstützt die Entscheidung, ob der gewünschte Analysepfad sicher und eindeutig vorbereitet ist oder der Fachaufruf wegen Policy, Capability oder ungültigem Scope unterbleiben muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @NurNichtVerfuegbar = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Hilfe und Parameter

@Hilfe=1 gibt den SQL-seitigen Hilfetext aus. @Json wird zu Beginn zurückgesetzt. Ein TABLE-Ziel wird zuvor validiert; ein fehlerhafter Preflight kann vor der Hilfe abbrechen.

| Parameter | Typ und Standard | Wirkung und NULL-Verhalten |
|---|---|---|
| @DatabaseNames | nvarchar(max), NULL | Bracket-aware Pipe-Liste exakter Namen; NULL/leer/Whitespace ohne Einschränkung. Duplikate oder ungültige Listenform sind INVALID_PARAMETER; nicht verfügbare angeforderte Datenbanken erscheinen als Warning. Exklusive Kombination mit Pattern. |
| @SystemdatenbankenEinbeziehen | bit, 0 | 0 schließt master, tempdb, model und msdb aus; 1 erlaubt die Auswahl. NULL ist ungültig. |
| @DatabaseNamePattern | nvarchar(4000), NULL | NULL ohne Filter. like: oder kein Präfix nutzt case-sensitive SQL LIKE mit %, _ und Zeichenklassen. regex: ist case-sensitiv, regexi: case-insensitiv; Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Leer/leerem Präfixmuster ungültig; exklusiv mit exakter Liste. |
| @HighImpactConfirmed | bit, 0 | 0 oder 1 wird an den Kandidatenhelper übergeben; NULL ist ungültig. Da die Analyseklasse dort NULL ist, löst diese Procedure kein High-Impact-Deep-Gate aus. |
| @AnalyseKlasse | varchar(64), NULL | NULL nimmt alle Katalogfeatures; sonst ein definierter Katalogcode. Leer oder unbekannt ist INVALID_PARAMETER. |
| @NurNichtVerfuegbar | bit, 0 | 1 filtert die ausgegebenen Capabilityzeilen auf IsUsable=0. NULL ergibt durch das SQL-Prädikat denselben Filter. Erhebungen und Summary werden nicht eingeschränkt. |
| @MitGruppenpruefung | bit, 1 | 1 fragt VW_AnalyseAccessCurrent pro Feature ab; 0 oder NULL überspringt diese Gruppenprüfung. |
| @ResultSetArt | varchar(16), CONSOLE | CONSOLE, RAW, TABLE oder NONE; case-insensitiv, äußere Leerzeichen getrimmt. NULL/ungültig ergibt INVALID_PARAMETER. |
| @ResultTablesJson | nvarchar(max), NULL | TABLE-Zuordnung als JSON-Objekt capabilities auf vorhandenes, leeres lokales Temp-Table-Ziel mit genau einer Seed-Spalte bit NULL. Nichtleere Zuordnung außerhalb TABLE führt zu THROW 51011. |
| @JsonErzeugen | bit, 0 | 1 erzeugt JSON; NULL aktiviert es nicht. |
| @Json | nvarchar(max), NULL OUTPUT | Ausgabeparameter; wird bei Aufrufbeginn zurückgesetzt. |
| @PrintMeldungen | bit, 1 | Severity-10-Meldung bei Gesamtfehler oder mindestens einer nicht nutzbaren Capability. 0/NULL unterdrückt nur diese Meldung. |
| @Hilfe | bit, 0 | 1 gibt Hilfe aus und überspringt Kandidatenauswahl und Capabilityprobes. NULL aktiviert sie nicht; TABLE-Preflight liegt davor. |

~~~sql
-- Hilfe und Standard
EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
EXEC [monitor].[USP_CheckFrameworkCapabilities];
-- Datenbank-/Klassen-Scope und RAW
EXEC [monitor].[USP_CheckFrameworkCapabilities] @DatabaseNames=N'[ExampleDb]', @AnalyseKlasse='STANDARD_CURRENT', @ResultSetArt='RAW';
-- JSON unabhängig von fachlichen Resultsets
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
-- TABLE exportiert nur capabilities
CREATE TABLE #Capabilities_HelpExample (Seed bit NULL);
DECLARE @Map nvarchar(max)=N'{"capabilities":"#Capabilities_HelpExample"}';
EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
DROP TABLE #Capabilities_HelpExample;
~~~

CONSOLE übergibt capabilities an den Console-Renderer. RAW liefert Meta, Capabilities, Summary und Warnings als vier Resultsets. TABLE schreibt ausschließlich capabilities; NONE unterdrückt fachliche Resultsets. Meldungen und JSON sind unabhängig von diesen Modi. JSON enthält meta, capabilities, summary und warnings, kein Datenbankstatus-Array.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `capabilities`. RAW beginnt mit dem Meta-Resultset und endet mit Datenbank-Warnings; das Capabilityresultset enthält den Scope pro Feature. CONSOLE übergibt die Capabilitydaten an den Console-Renderer. JSON erhält den technischen Kontext in `meta`, `capabilities`, `summary` und `warnings`. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und das JSON-Array `capabilities` verwenden denselben nach der vollständigen Prüfung materialisierten Export mit 27 Feldern und 15 explizit collatierten Textspalten. `@NurNichtVerfuegbar=1` beschränkt ihn auf `IsUsable=0`; auch ein NULL-Wert dieses Parameters erhält das bestehende Prädikat und zeigt nur diese Zeilen. Die Zusammenfassung und der Gesamtstatus bewerten weiterhin alle geprüften Capabilities. JSON enthält `meta`, `capabilities`, `summary` und `warnings`; ein zusätzliches Datenbankstatus-Array wird nicht ausgegeben.

## Eine Zeile bedeutet

Eine Capability-Zeile bewertet ein Feature in einem Server- oder Datenbank-Scope. Dieselbe Fähigkeit kann deshalb je Datenbank unterschiedlich ausfallen.

## So lesen

Lesen Sie die Angaben in dieser Reihenfolge: `VersionSupported` → `GroupAccessAllowed` → `HasRequiredPermission` → `IsQueryable` → `IsFeatureEnabled` → `IsUsable`.

## Warum kann das problematisch sein?

`HasRequiredPermission=1`, aber `IsQueryable=0` zeigt, dass eine formale Permission nicht genügt. Datenbankstatus, Plattform, Replica-Rolle oder Laufzeitfehler begrenzen den Pfad.

## Wann ist es kein Problem?

Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Query Store kann versionsseitig unterstützt und lesbar, aber deaktiviert sein. Ein leeres Query-Store-Resultset sagt dann nichts über die Queryqualität. Nur Scopes mit `IsUsable=1` fachlich auswerten.

**Ähnlich aussehender Gegenfall:** Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Leere Capability-Ausgaben sind anhand von Meta, Summary und Warnings zu lesen. Ohne auswählbare Datenbankkandidaten fehlen Datenbank-Scoped Zeilen; SERVER-Scoped Features können dennoch geprüft und ausgegeben werden, wenn die Kandidatenauswahl insgesamt verfügbar ist. Ein Feature mit DATABASE-Scope kann ohne Kandidat keine Zeile liefern. Explizit angeforderte, nicht verfügbare Datenbanken werden in Warnings ausgewiesen.

`@NurNichtVerfuegbar=1` filtert die ausgegebenen Capabilityzeilen auf `IsUsable=0`; NULL bewirkt durch das SQL-Prädikat denselben Filter. Summary und Gesamtstatus basieren auf allen gesammelten Capabilityzeilen. Deshalb kann die Capabilityausgabe leer sein, während Summary-Zeilen vorhanden sind. Ein ungültiger Analyseklassen- oder Scopeparameter ist am Status in `meta` (RAW oder JSON) zu erkennen; Kandidatenwarnungen beschreiben die konkret nicht auswählbaren Datenbanken. CONSOLE rendert nur Capabilities und zeigt bei leerer Ausgabe „Keine fachlichen Ergebnisse“. JSON enthält `meta`, `summary` und `warnings` zusätzlich zum `capabilities`-Array.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | Nicht empirisch bestimmt |
| Standardpfad | Ohne Scope werden alle sichtbaren Online-Benutzerdatenbanken mit allen Katalogfeatures kombiniert. Für jede Serverfeaturezeile und jede `(Datenbank, Feature)`-Zeile führt der Code die anwendbaren Versions-, Gruppen-, Berechtigungs-, Probe- und Enablementprüfungen aus. |
| Teuerster Pfad | Viele Datenbanken × viele Datenbankfeatures mit `@MitGruppenpruefung = 1`; jede Kombination kann dynamische Permission-, Probe- und Enablementstatements ausführen. Die Templates des Katalogs werden tatsächlich ausgeführt; ihre Kosten und ihr Zugriffsumfang sind ohne Einzelfallprüfung nicht aus der Featuredefinition abzuleiten. Dadurch wird kein Fachmodul allein wegen seiner Katalogzeile aufgerufen. |
| Haupttreiber | Produkt aus Zahl der ausgewählten Datenbanken und DATABASE-Features plus konstante SERVER-Features. Dynamisches SQL wird je Kombination kompiliert/ausgeführt. |
| Skalierung | Annähernd linear mit den Featurekombinationen. Eine einzelne Analyseklasse reduziert den Featurekatalog früh; Datenbankscope reduziert DATABASE-Kombinationen. JSON/Sortierung sind nachgeordnet. |
| Ressourcen | Frameworkkatalogviews, Datenbankkandidaten, Login-/Permissionchecks und SQL-Templates per `sp_executesql`; Temp-Tabellen für Capability- und Warningzeilen. |
| Begrenzungswirkung | `@DatabaseNames` und `@AnalyseKlasse` begrenzen tatsächliche Probeanzahl. `@NurNichtVerfuegbar` filtert erst die Ausgabe und spart keine Probe-/Enablementaufrufe.  |
| Locking und Nebenwirkungen | Die Procedure vergibt keine Rechte. Probe- und Enablementtemplates werden ausgeführt; ein Probeerfolg ist keine Aussage über Kosten, Vollständigkeit späterer Fachdaten oder externe Gesundheit. Datenbankstatus/Berechtigung kann sich während der Schleife ändern, daher sind Capabilityzeilen kein atomarer Snapshot. |
| Schutzmechanismus | Der Aufruf an `USP_PrepareDatabaseCandidates` verwendet bewusst `@AnalysisClass = NULL`; damit löst `@HighImpactConfirmed` hier kein Deep-Gate aus. Die ausgeführten Probe- und Enablementtemplates sind anhand ihrer konkreten SQL-Definitionen zu beurteilen. |
| Sicherer Einsatz | Eine `ExampleDatabase` und eine konkrete Analyseklasse prüfen; die vollständige Matrix nur für Inventar-/Upgradeaudits ausführen. `@NurNichtVerfuegbar` dient Lesbarkeit, nicht Lastreduktion. |
| Aussagegrenze | `IsUsable` bezeichnet das Ergebnis der katalogbasierten Prüfungen im aktuellen Kontext. Es garantiert weder Berechtigung auf jede spätere Fachzeile noch geringe Kosten, Datenvollständigkeit oder erfolgreiche Ausführung des eigentlichen Analysemoduls. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?

### Technischer Hintergrund

Version, Edition, Featurekonfiguration und formale Permission sind verschiedene Ebenen. Die Procedure führt capability-orientierte Prüfungen aus und kann geschützte Testabfragen dynamisch ausführen. Dadurch wird zwischen `supported`, `enabled`, `permitted`, `queryable` und `usable` unterschieden.

### Datenkette

`sys.sp_executesql`.

### Source Select

Die Capability-Prüfung startet mit dem deklarativen Featurekatalog; datenbankbezogene Einträge werden erst danach mit den ausgewählten Datenbanken vervielfacht:

```sql
SELECT
      [f].[FeatureCode]
    , [f].[ScopeType]
    , [f].[AnalysisClass]
    , [f].[MinimumMajorVersion]
    , [f].[ProbeSqlTemplate]
FROM [monitor].[VW_FrameworkFeatureCatalog] AS [f]
WHERE [f].[AnalysisClass] = 'STANDARD_CURRENT'
  AND [f].[MinimumMajorVersion]
      <= TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
```

**Wichtig für die Eigenlast:** Analyseklasse und Datenbankscope vor dem Ausführen der Probe-Statements einschränken. Die Probes führen die im Katalog hinterlegten Templates aus. `TOP (0)` an einzelnen Stellen ist kein empirischer Kosten- oder Sicherheitstest; die Templates können je Datenbank wiederholt werden.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Umgebungszustand; Ergebnisse können sich nach Konfigurationsänderung, Failover, Datenbankstatuswechsel oder Berechtigungsänderung ändern.

### Bewertung und Gegenprobe

Berücksichtigen Sie die Prüfkette in der dokumentierten Reihenfolge. `HasRequiredPermission=1` bei `IsQueryable=0` weist auf eine zusätzliche Laufzeitgrenze hin. `IsFeatureEnabled=0` kann bei einem bewusst ungenutzten Feature normal sein.

### Typische Fehlinterpretation

Capability ist kein Nachweis, dass relevante Daten vorhanden sind. Query Store kann nutzbar, aber leer sein; XE kann abfragbar, aber ohne passende Session sein.

### Folgeanalyse

Starten Sie nur Fachmodule, deren benötigte Quelle nutzbar ist. Prüfen Sie bei einem Partialstatus die jeweilige Datenbank oder Quelle gezielt.

## Primärquellen

- [sys.sp_executesql](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#3-monitorusp_checkframeworkcapabilities)
