# [monitor].[USP_PrepareDatabaseCandidates]

**Bereich:** Common, öffentlicher Vorbereitungshelfer<br>
**Zweck:** Befüllt die vom Aufrufer bereitgestellte Datenbank-Kandidatenliste.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Datenbanken sind zum Ermittlungszeitpunkt sichtbar, online und filterkonform?** Sie unterstützt die Scope-Vorbereitung. Sie bestätigt keine spätere CONNECT- oder Objektberechtigung und ersetzt keine Capability-Prüfung des Fachmoduls.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Performance- oder Verfügbarkeitsursache und keine Aussage über Daten außerhalb des aktuellen Execution-Kontexts. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

Diese öffentliche Hilfsprocedure bereitet den Kandidatenscope einer Analyse vor und liefert keine normalen Analyse-Resultsets. Im normalen Verarbeitungspfad erwartet sie vom Aufrufer angelegte lokale Temp-Tabellen mit den dokumentierten vollständigen Schemas. Im Listen- und LIKE-Pfad hängt die Procedure Kandidaten und Warnungen an und leert die Ziele nicht. Beim Regexpfad bearbeitet sie alle Zeilen der Kandidatentabelle, auch bereits vorhandene: nicht passende Zeilen werden gelöscht; bei UNAVAILABLE_FEATURE löscht sie sämtliche Kandidatenzeilen. Für einen isolierten Aufruf sind deshalb frische Tabellen zu verwenden. Der Hilfemodus kann ohne diese Tabellen aufgerufen werden, muss aber weiterhin alle erforderlichen OUTPUT-Parameter binden.

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Hilfe anzeigen

Der Hilfemodus gibt Parameter, Listen-/Patternregeln, Zieltabellenschemas und Aufrufvarianten aus, bevor er Zieltabellen oder Datenbanken verarbeitet. Die erforderlichen OUTPUT-Parameter bleiben auch bei `@Hilfe=1` Teil der SQL-Signatur:

```sql
DECLARE @StatusCode varchar(40),
        @ErrorMessage nvarchar(2048),
        @CrossDatabaseRequested bit;

EXEC [monitor].[USP_PrepareDatabaseCandidates]
      @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
    , @Hilfe = 1;
```

Ein `AVAILABLE`-Status allein belegt nicht, dass jede explizit angeforderte Datenbank ausgewählt wurde. Prüfen Sie Kandidaten und gegebenenfalls Warnungen gemeinsam. Die Prüfung der Kandidatentabelle verwendet nur zwei Spalten mit `TOP (0)`; sie bestätigt das vollständige Schema nicht. Scheitert der TOP (0)-Probe der Warnungstabelle, wird sie still als nicht verfügbar behandelt; ein späterer Warnungsinsert kann weiterhin einen Fehler auslösen. Warnungen werden angehängt, und vorhandene Kandidatenzeilen beeinflussen, welche angeforderten Namen als fehlend gelten. Ohne Präfix oder mit like: gilt SQL LIKE mit %, _, Zeichenklassen in eckigen Klammern unter SQL_Latin1_General_CP1_CS_AS. regex: nutzt REGEXP_LIKE mit Flag c (case-sensitive), regexi: mit Flag i (case-insensitive); beide benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Vor der Moduserkennung werden äußere Leerzeichen der Eingabe entfernt. Die Präfixerkennung ist case-insensitive; nach dem Abtrennen des Präfixes bleiben innere Leerzeichen und Groß-/Kleinschreibung im Pattern erhalten. Eigene Statuswerte sind AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR und UNAVAILABLE_FEATURE; bei gesetzter Analyseklasse können HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP von der delegierten Pfadprüfung zurückkommen.


### Normalen Aufruf prüfen

Das Beispiel legt die vollständigen Zielschema-Spalten an. Der synthetische Name kann als Warnung erscheinen, falls er in der aktuellen Instanz nicht auswählbar ist. Die Tabellen sind frisch, damit angehängte Zeilen eindeutig diesem Aufruf zugeordnet werden können.

~~~sql
CREATE TABLE #PrepareDatabaseCandidates_HelpExample (
    DatabaseId int NOT NULL,
    DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    IsReadOnly bit NULL, CompatibilityLevel tinyint NULL,
    CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    IsSystemDatabase bit NULL, RequestedOrdinal int NULL
);
CREATE TABLE #PrepareDatabaseCandidates_WarningExample (
    RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048),
        @CrossDatabaseRequested bit;
EXEC [monitor].[USP_PrepareDatabaseCandidates]
     @DatabaseNames=N'[ExampleDatabase]',
     @CandidateTable=N'#PrepareDatabaseCandidates_HelpExample',
     @WarningTable=N'#PrepareDatabaseCandidates_WarningExample',
     @StatusCode=@StatusCode OUTPUT,
     @ErrorMessage=@ErrorMessage OUTPUT,
     @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;
SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage,
       @CrossDatabaseRequested AS CrossDatabaseRequested;
SELECT * FROM #PrepareDatabaseCandidates_HelpExample;
SELECT * FROM #PrepareDatabaseCandidates_WarningExample;
DROP TABLE #PrepareDatabaseCandidates_WarningExample;
DROP TABLE #PrepareDatabaseCandidates_HelpExample;
~~~

## Resultsets und Leserichtung

Diese Hilfsprocedure besitzt bewusst keinen öffentlichen TABLE-Export. Sie befüllt die vom Parent bereitgestellten Temp-Strukturen beziehungsweise OUTPUT-Statuswerte. Zuerst sind Status und Warnungen des Parents zu lesen; erst danach darf dessen Fachresultset interpretiert werden. Ein direkter Aufruf ohne den dokumentierten Tabellenvertrag ist kein Ersatz für den Parentpfad.

## Eine Zeile bedeutet

Bei einer frisch angelegten Tabelle entspricht jede eingefügte Zeile einer im Ermittlungszeitpunkt akzeptierten Datenbank. In wiederverwendeten Tabellen können frühere Zeilen stehen. Eine passende Warnungstabelle erhält angeforderte, aber nicht auswählbare Namen.

## So lesen

Berücksichtigen Sie Kandidaten, Warnungen und OUTPUT-Status gemeinsam. Prüfen Sie, ob jede ausdrücklich angeforderte Datenbank tatsächlich in der Kandidatenliste enthalten ist.

## Warum kann das problematisch sein?

Eine offline, unsichtbare oder unzulässige Datenbank fehlt in der Fachanalyse. Wird die Warnung ignoriert, kann ein unvollständiger Scope fälschlich als Entwarnung erscheinen.

## Wann ist es kein Problem?

Eine große sichtbare Datenbankmenge ist allein kein Deep-Pfad. Die Auswahl wird
nicht vorab gekürzt; erst die tatsächlich aktivierte Analyseklasse entscheidet,
ob `@HighImpactConfirmed = 1` erforderlich ist.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zwei Datenbanken werden angefordert, eine ist offline. Das Fachergebnis enthält nur die online Datenbank; die fehlende Datenbank muss als nicht untersuchter Scope dokumentiert werden.

**Ähnlich aussehender Gegenfall:** Eine große sichtbare Datenbankmenge ist allein kein Deep-Pfad. Die Auswahl wird
nicht vorab gekürzt; erst die tatsächlich aktivierte Analyseklasse entscheidet,
ob `@HighImpactConfirmed = 1` erforderlich ist. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei frisch angelegter Kandidatentabelle bedeutet eine leere Tabelle nach dem Aufruf, dass sie keine Kandidaten enthält. Ursachen sind fehlende Treffer oder Regexfilterung; Regex kann zuvor eingefügte Zeilen wieder löschen. Prüfen Sie deshalb Status und gegebenenfalls Warnungen gemeinsam. Prüfen Sie bei expliziten Namen den Status und eine erfolgreich geprüfte Warnungstabelle. Ein fehlgeschlagener TOP (0)-Probe wird still als nicht verfügbare Warnungstabelle behandelt, und spätere Warnungsinserts können Fehler auslösen. Bei wiederverwendeten Tabellen können frühere Zeilen fortbestehen. Der Regexpfad löscht nicht passende Zeilen; wenn die Regexvoraussetzungen fehlen, löscht er alle Zeilen vor UNAVAILABLE_FEATURE. Spätere Fehler werden nicht durch eine allgemeine atomare Rücknahme abgesichert.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Validiert Listen/Pattern; der TOP (0)-Probe prüft bei der Kandidatentabelle nur DatabaseId und DatabaseName, nicht das vollständige Zielschema. Optional wird genau eine Analyseklasse geprüft. Die Procedure materialisiert alle passenden sichtbaren Online-Datenbanken aus `TVF_DatabaseCandidates`. Ohne Scope sind das alle Benutzerdatenbanken. |
| Teuerster Pfad | Sehr lange explizite Liste oder Regex über eine Instanz mit vielen Datenbanken, Systemdatenbanken eingeschlossen und Warningtabelle aktiv. Die Procedure öffnet die Kandidatendatenbanken nicht und liest keine Fachkataloge. |
| Haupttreiber | Zahl der `master.sys.databases`-Zeilen und Eingabeelemente. Dynamisches SQL prüft ausgewählte Spalten der lokalen Temp-Tabellen und fügt Kandidaten/Warnings ein. |
| Skalierung | Linear mit Datenbank- und Listenzahl; case-sensitive Duplikat-/Syntaxprüfung ist klein. Regex kann auf allen Datenbanknamen arbeiten, bleibt aber reine Namensfilterung. |
| Ressourcen | Master-Metadaten, Parser-TVFs und lokale Temp-Tabellen. Mit nichtleerem `@AnalysisClass` prüft der delegierte Pfad zusätzlich Frameworkzugriff und Policy; dabei kann auch ein Login-Token gelesen werden. Es gibt keinen Capability-, `msdb`- oder Nutzdatenscan. |
| Begrenzungswirkung | Es gibt absichtlich keine Datenbank-Mengenbegrenzung. Exakte Liste/Pattern reduzieren Kandidaten; der Parent muss spätere Facharbeit selbst limitieren. Nicht ausgewählte explizite Namen werden nur bei erfolgreich geprüftem Warnungsziel als Warning angehängt. |
| Locking und Nebenwirkungen | Read-only gegenüber Systemkatalogen und Schreibzugriff nur auf lokale Parent-Temp-Tabellen. Datenbankstatus kann sich nach Kandidatenermittlung ändern. |
| Schutzmechanismus | Bei nichtleerem `@AnalysisClass` delegiert die Procedure Pfad- und Policyprüfungen. Die High-Impact-Bestätigung und die Gruppenautorisierung sind getrennte Prüfungen: `@HighImpactConfirmed = 1` bestätigt einen bestätigungspflichtigen Analysepfad, gewährt aber keine Gruppenfreigabe. `NULL` überspringt diese delegierte Prüfung und autorisiert keinen späteren Childpfad. |
| Sicherer Einsatz | Nur als Parent-Helfer mit korrekt angelegter Kandidaten-/Warningtabelle; für Produktionsanalysen einen ausdrücklich abgegrenzten, zur Zielumgebung passenden Datenbanknamen statt des NULL-Scopes angeben. |
| Aussagegrenze | Kandidat bedeutet sichtbar, online und filterkonform zum Ermittlungszeitpunkt. Es beweist weder spätere CONNECT-/Objektberechtigung noch erfolgreichen Cross-Database-Zugriff; Statuswechsel bleiben Sache des Fachmoduls. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Datenbanken gehören tatsächlich zum Cross-Database-Auftrag und dürfen sicher verarbeitet werden?

### Technischer Hintergrund

Die Procedure ermittelt aus exakten Namen oder Pattern einen Kandidatenscope. Ohne explizite Einschränkung ermittelt sie alle sichtbaren, zugreifbaren und online befindlichen Benutzerdatenbanken. Es gibt keinen CURRENT-Scope und keine Vorabbegrenzung. Systemdatenbanken sind opt-in. Die Procedure prüft zusätzlich die vom Aufrufer tatsächlich aktivierte Analyseklasse und beendet einen bestätigungspflichtigen Pfad vor dem teuren Fachzugriff mit `HIGH_IMPACT_CONFIRMATION_REQUIRED`.

### Datenkette

`master.sys.databases`, `sys.sp_executesql`.

### Source Select

Der zentrale Kandidatenpfad beginnt direkt im serverweiten Datenbankkatalog:

```sql
SELECT
      [d].[database_id]
    , [d].[name]
    , [d].[state_desc]
    , [d].[user_access_desc]
    , [d].[is_read_only]
    , [d].[compatibility_level]
FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[state] = 0
  AND [d].[database_id] > 4
  AND (@DatabaseNamePattern IS NULL
       OR [d].[name] LIKE @DatabaseNamePattern);
```

**Wichtig für die Eigenlast:** Exakte Namensliste oder LIKE-Pattern wirken bereits an der Kandidatenquelle. Regex benötigt spätere Auswertung und darf nicht als gleichwertige frühe Quellbegrenzung beschrieben werden.

### Zeit- und Scope-Modell

Die Auswertung liefert eine Momentaufnahme der Datenbankliste. Zwischen Kandidatenermittlung und späterer dynamischer Abfrage kann eine Datenbank offline gehen, failovern oder gelöscht werden.

### Bewertung und Gegenprobe

Explizit angeforderte, aber ausgeschlossene Datenbanken müssen als fehlende Evidenz dokumentiert werden. Eine Analyse über neun von zehn angeforderten Datenbanken ist nicht automatisch eine vollständige Entwarnung.

### Typische Fehlinterpretation

Pattern und explizite Liste sind alternative Einschränkungen und dürfen nicht
gleichzeitig gesetzt werden. Eine explizit nicht verfügbare Datenbank bleibt als
Warning sichtbar; sie darf nicht als erfolgreich untersuchter Scope gelten.

### Folgeanalyse

Berücksichtigen Sie Warnings und OUTPUT-Status zusammen mit jedem Cross-Database-Resultset.

## Primärquellen

- [sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../01_Common.md#4-monitorusp_preparedatabasecandidates)
