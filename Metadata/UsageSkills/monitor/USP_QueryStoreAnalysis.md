---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreAnalysis"
schema_name: "monitor"
object_name: "USP_QueryStoreAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert Query-Store-Module mit einheitlichem Quell- und Referenzdatenbankvertrag."
source_path: "Code/05_QueryStore/080_USP_QueryStoreAnalysis.sql"
---

# monitor.USP_QueryStoreAnalysis

## Zweck und Einsatz

Orchestriert Query-Store-Module mit einheitlichem Quell- und Referenzdatenbankvertrag. JSON enthält benannte Modulobjekte.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_QueryStoreStatus]`, `[monitor].[USP_QueryStoreRuntimeStats]`, `[monitor].[USP_QueryStoreWaitStats]`, `[monitor].[USP_QueryStorePlanChanges]`, `[monitor].[USP_QueryStoreRegressions]`, `[monitor].[USP_QueryStoreForcedPlans]`, `[monitor].[USP_QueryStoreHints]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |
| @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MitStatus | bit | nein | 1 |
| @MitRuntimeStats | bit | nein | 1 |
| @MitWaitStats | bit | nein | 0 |
| @MitPlanChanges | bit | nein | 0 |
| @MitRegressionen | bit | nein | 0 |
| @MitForcedPlans | bit | nein | 0 |
| @MitHints | bit | nein | 0 |
| @MitReplicaKontext | bit | nein | 1 |
| @MitIQP | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. Unveränderte Weitergabe an alle neun Teilmodule; eigene Namensprüfung und kontrollierter Auswahlstatus liegen beim tatsächlich aktivierten Teilmodul.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. Weitergabe an alle neun Teilmodule. Bei gleichzeitig effektiver nichtleerer Namensliste wird der Aufruf dort abgewiesen, keine Liste bevorzugt. LIKE unterstützt %, _ und Zeichenklassen [...].

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Ausgelassen/0: keine High-Impact-Bestätigung. 1 bestätigt einen tatsächlich aktivierten gruppengeschützten Pfad, ohne Modul oder Rechte zu aktivieren. Der Orchestrator prüft NULL nicht selbst; bei erreichter Datenbankvorbereitung eines aktivierten Teilmoduls ist es INVALID_PARAMETER. Alle neun Teilmodule erhalten den Wert. Die Query-Store-Basisklasse hat kein Gruppengate; Referenzfilter, breite Zeitfenster und >1000/unbegrenzte Limits können je Teilmodul QUERY_STORE_DEEP verlangen. Replica-Kontext aktiviert keinen Deep-Pfad; IQP verlangt unabhängig vom Limit CATALOG_DEEP mit Bestätigung und Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; Status, Hints, Replica-Kontext und IQP erhalten diesen Filter nicht. Ohne eines der fünf aktivierten Teilmodule wird er nicht verarbeitet.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Weitergabe nur an RuntimeStats, WaitStats, PlanChanges, Regressions und ForcedPlans; die anderen vier Teilmodule erhalten ihn nicht. LIKE unterstützt %, _ und Zeichenklassen [...].

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Untergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Bei zwei gesetzten Grenzen lehnt der Orchestrator nur VonUtc > BisUtc ab; Gleichheit passiert diese Prüfung, kann im Teilmodul aber ungültig sein. Runtime, Waits und Replica-Kontext setzen NULL auf eine Stunde vor ihrem effektiven Ende und berücksichtigen vollständige überlappende Intervalle. PlanChanges erhält nur VonUtc; dort bedeutet NULL kein Zeitfilter. Regressionen erhalten ihn als Vergleichsbeginn und leiten die Baseline standardmäßig aus der Stunde davor ab. Status, ForcedPlans, Hints und IQP erhalten keinen Zeitparameter. DATEADD-Defaults an frühen datetime2-Grenzen können im Teilmodul überlaufen und werden dann als Aufruffehler erfasst.

**@BisUtc:** @BisUtc datetime2(7); Default: NULL. Ausgelassen/NULL wird unverändert weitergegeben, keine globale offene Obergrenze. UTC-datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T13:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Runtime, Waits, Replica-Kontext und Regressionen lösen NULL jeweils auf ihren eigenen aktuellen UTC-Endzeitpunkt auf; bei zugleich NULLem Beginn gilt dort die letzte Stunde. Getrennte Aufrufe garantieren keinen identischen Endzeitpunkt. Regressionen verwenden ihn als Vergleichsende; die Baseline liegt standardmäßig in der Stunde vor Vergleichsbeginn. PlanChanges und die übrigen Teilmodule erhalten BisUtc nicht. Der Orchestrator lehnt nur zwei gesetzte Grenzen mit VonUtc > BisUtc ab; strengere Teilmodulprüfungen bleiben wirksam.

**@MitStatus:** @MitStatus bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreStatus; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und die IF-Bedingung aktiviert das Teilmodul nur bei genau 1; außerdem verhindert NULL im Schalterbündel, dass dessen All-aus-Guard TRUE wird. Die Orchestratorprüfung prüft nur, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Query-Store-Zustand, Capture- und Retentioneinstellungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitRuntimeStats:** @MitRuntimeStats bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreRuntimeStats; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Runtime- und Ressourcenwerte je Query/Plan. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitWaitStats:** @MitWaitStats bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreWaitStats; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert aggregierte Query-Store-Waitkategorien. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitPlanChanges:** @MitPlanChanges bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStorePlanChanges; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Querysummaries und gespeicherte Pläne von Queries mit mehreren Plänen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitRegressionen:** @MitRegressionen bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreRegressions; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gewichteten Metrikvergleich von Baseline und Vergleichsfenster. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitForcedPlans:** @MitForcedPlans bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreForcedPlans; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert Inventar erzwungener Pläne und Force-Fehler ohne Änderung der Planbindungen. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitHints:** @MitHints bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_QueryStoreHints; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Geprüft wird ausschließlich, ob alle neun Schalter exakt 0 sind. Das Teilmodul liefert gespeicherte Query-Store-Hints und deren Fehlerstatus ab SQL Server 2022 ohne Setzen von Hints. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitReplicaKontext:** @MitReplicaKontext bit; Default: 1. 0 deaktiviert, 1 aktiviert USP_QueryStoreReplicaAnalysis; ausgelassen ergibt 1. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Vor SQL Server 2025 kann das aktivierte Teilmodul den tatsächlichen Status UNAVAILABLE_VERSION melden. Das Teilmodul liefert rollengetrennte Query-Store-Runtime-, Wait- und Forcing-Evidenz; vor SQL Server 2025 kontrolliert UNAVAILABLE_VERSION, kein aktueller AG-Gesundheitsnachweis. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MitIQP:** @MitIQP bit; Default: 0. 0 deaktiviert, 1 aktiviert USP_IntelligentQueryProcessingAnalysis; ausgelassen ergibt 0. NULL wird nicht zu 0 normalisiert und aktiviert das Teilmodul nicht; NULL verhindert zugleich, dass der All-aus-Guard TRUE wird. Das Teilmodul liefert einen eigenen tatsächlichen Status. Das Teilmodul liefert datenbankweite IQP-Konfiguration und Feedback-/Tuningevidenz; dieser Pfad verlangt CATALOG_DEEP-Freigabe und HighImpactConfirmed=1. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Ausgelassen: 100. Positive ganze int-Werte von 1 bis 2147483647 sind das weitergereichte Limit; NULL/0 bedeutet in den empfangenden Teilmodulen unbegrenzt. Negative Werte lehnt der Orchestrator vor allen Teilmodulaufrufen als INVALID_PARAMETER ab. Weitergabe an acht Teilmodule außer Status; jedes begrenzt eigene Ergebnismengen nach seinem Aggregations-/Kandidatenvertrag. Kein Gesamtlimit über alle Teilmodulzeilen und kein Limit für das Aufrufjournal mit höchstens neun Zeilen. >1000 beziehungsweise NULL/0 kann in unterstützenden Query-Store-Teilmodulen Deep aktivieren; das IQP-Gate ist ohnehin erforderlich.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach äußerem U+0020-Trim und Großschreibung genau vier Werte: RAW wird an ausgewählte Teilmodule weitergegeben und liefert deren Resultsets vor zwei Orchestratorresultsets (Metadaten und Aufrufjournal); CONSOLE führt Teilmodule mit NONE aus und zeigt nur das Journal mit Ergebnislabel oder bei Leere eine Hinweiszeile; TABLE führt Teilmodule mit NONE aus und schreibt nur das Journal in moduleStatus; NONE unterdrückt normale Resultsets aller Teilmodule und des Orchestrators. JSON ist unabhängig, technische Meldungen werden separat gesteuert. NULL, leer, nur U+0020 oder andere Werte sind im normalen Ablauf INVALID_PARAMETER. Die Bindung an varchar(16) erfolgt vor der Prüfung.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt wirft dort im normalen Pfad Fehler 51011; Hilfe kehrt vorher zurück. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel moduleStatus erforderlich. Der Stringwert benennt ein vorhandenes, leeres lokales #Temp-Ziel mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116, kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel oder ungültige Ziele scheitern im ThrowOnError-Preflight des normalen Pfads nach Hilfe und vor Fachvalidierung. Der Writer ersetzt die Seed-Struktur. moduleStatus enthält nur die fünf Journalfelder ExecutionOrdinal, ModuleName, InvocationStatus, ErrorNumber und ErrorMessage, weder Teilmodul-Fachdaten noch übergeordnete Metadaten.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Ausgelassen/0: @Json bleibt NULL. 1 erzeugt das Gesamt-JSON unabhängig vom Ausgabemodus und wird auch an jedes aktivierte Teilmodul weitergegeben. NULL wird vom Orchestrator nicht selbst abgewiesen und erzeugt kein Gesamt-JSON; Teilmodule behandeln ihn nach eigenem Vertrag, Replica-Kontext meldet dabei INVALID_PARAMETER. Das Objekt enthält meta (Orchestratorstatus), status (Statusmodul), runtimeStats, waitStats, planChanges, regressions, forcedPlans, queryHints, replicaContext, intelligentQueryProcessing sowie warnings (gefiltertes Aufrufjournal). Nicht ausgeführte oder ohne JSON zurückgekehrte Teilmodule erscheinen als JSON null. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter; eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Der Eingabewert wird beim Eintritt stets durch NULL ersetzt; nur JsonErzeugen=1 füllt das Gesamtobjekt. Bei Hilfe bleibt NULL. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem Fehler, etwa frühem Mapping-THROW, ist keine OUTPUT-Rückübertragung zugesichert.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Ausgelassen: 1. 0 unterdrückt unterstützte optionale Severity-10-Quellen-/Truncationmeldungen, 1 erlaubt sie. Der Orchestrator hat keinen eigenen Meldungszweig, sondern gibt den Wert an alle neun aktivierten Teilmodule weiter. Replica-Kontext und IQP besitzen derzeit keinen solchen Meldungszweig; Replica-Kontext wertet NULL im normalen Ablauf trotzdem als INVALID_PARAMETER. In den übrigen unterstützenden Meldungszweigen unterdrückt NULL die Ausgabe; der Orchestrator normalisiert ihn nicht. Resultset-/JSON-Daten und Hilfe-PRINTs sind unabhängig. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@Hilfe:** @Hilfe bit; Default: 0. Ausgelassen/0 oder NULL: normaler Ablauf. 1 druckt Hilfe und Beispiele und beendet vor normalen Orchestratorprüfungen und Teilmodulaufrufen. SQL-Typbindung und die im Quelltext vorangestellten OUTPUT-Zuweisungen bleiben aktiv; lokale Journaltabelle, Locktimeout-Änderung und Mappingprüfungen werden im Hilfezweig nicht ausgeführt. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ExecutionOrdinal] tinyint NOT NULL , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreAnalysis

Orchestriert neun Query-Store-Teilmodule in fester Reihenfolge: Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints, Replica-Kontext und IQP. Standardmäßig aktiv sind Status, Runtime und Replica-Kontext; es entsteht keine atomare Gesamtaufnahme.

Die normalen Orchestratorprüfungen betreffen nur negative @MaxZeilen, den Ausgabemodus, VonUtc > BisUtc bei zwei gesetzten Grenzen und neun exakt ausgeschaltete Modulschalter. Weitere Parameterprüfungen und Datenbankfreigaben erfolgen nur in tatsächlich aktivierten Teilmodulen. Hilfe kehrt vor den Mappingprüfungen zurück.

Bei den ersten sieben Teilmodulen bedeutet EXECUTED nur eine Rückkehr ohne THROW, auch bei kontrollierter fachlicher Ablehnung. Replica-Kontext und IQP liefern eigene Status-OUTPUTs. RAW liefert Teilmodulresultsets vor Orchestratormetadaten und Aufrufjournal; CONSOLE/TABLE zeigen ausschließlich das Journal. Fachresultate bleiben bei aktivierter JSON-Erzeugung in benannten Teilmodulobjekten erhalten.

DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreAnalysis
Version      : 2.2.0
Stand        : 2026-07-27
Zweck        : Orchestriert Query-Store-Module mit einheitlichem Quell- und
               Referenzdatenbankvertrag. JSON enthält benannte Modulobjekte.
Änderungen   : 2.2.0 - SQL25-005 Replica-Kontext als versionsadaptives Standardteilmodul.
                2.1.0 - IQP-Evidenz als kostenbewusstes opt-in Teilmodul.
               2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreAnalysis
Orchestriert neun Query-Store-Teilmodule in fester Reihenfolge: Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints, Replica-Kontext und IQP. Standardmäßig aktiv sind Status, Runtime und Replica-Kontext; es entsteht keine atomare Gesamtaufnahme.
Die normalen Orchestratorprüfungen betreffen nur negative @MaxZeilen, den Ausgabemodus, VonUtc > BisUtc bei zwei gesetzten Grenzen und neun exakt ausgeschaltete Modulschalter. Weitere Parameterprüfungen und Datenbankfreigaben erfolgen nur in tatsächlich aktivierten Teilmodulen. Hilfe kehrt vor den Mappingprüfungen zurück.
Bei den ersten sieben Teilmodulen bedeutet EXECUTED nur eine Rückkehr ohne THROW, auch bei kontrollierter fachlicher Ablehnung. Replica-Kontext und IQP liefern eigene Status-OUTPUTs. RAW liefert Teilmodulresultsets vor Orchestratormetadaten und Aufrufjournal; CONSOLE/TABLE zeigen ausschließlich das Journal. Fachresultate bleiben bei aktivierter JSON-Erzeugung in benannten Teilmodulobjekten erhalten.
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#QueryStoreAnalysis_HelpExample"}';
 SELECT * FROM [#QueryStoreAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreAnalysis_HelpExample];
 THROW;
END CATCH;
```

