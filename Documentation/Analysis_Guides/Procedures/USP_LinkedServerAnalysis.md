# [monitor].[USP_LinkedServerAnalysis]

Inventarisiert Linked Server lokal. Ein Verbindungstest erfordert zwei ausdrückliche opt-ins.

**Bereich:** Server Health und verteilte Abhängigkeiten
**Zweck:** Trennt sichtbare lokale Linked-Server-Konfiguration, kumulativen Waitkontext und einen optionalen punktuellen Verbindungstest.
**Beobachtungsart:** aktuelles Kataloginventar, kumulative Server-Waits und optionaler Remote-Verbindungstest
**Kostenklasse:** LOW im Standardpfad, HIGH_OPT_IN für den Remote-Test

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, welche Linked Server im aktuellen Sicherheitskontext sichtbar sind und für welche registrierten Ziele eine gesondert autorisierte Konnektivitätsprüfung erforderlich ist. Der Standardpfad eignet sich für Inventur, Providerprüfung und die Vorbereitung einer Abhängigkeitsanalyse. Er liest keine Remotetabelle, führt keine verteilte Abfrage aus und ändert weder Login-Mappings noch Serveroptionen.

## Nicht beantwortete Fragen

Ein sichtbarer Linked Server beweist nicht, dass jede Datenbank, jedes Objekt oder jede Remoteanmeldung erreichbar ist. Ein erfolgreicher `sp_testlinkedserver`-Aufruf belegt nur den Verbindungsaufbau zum Testzeitpunkt. Er misst weder Abfragelatenz noch Transaktionsverhalten, Delegation, Failover, Datenqualität oder Berechtigungen auf einem fachlichen Remoteobjekt. Kumulative `OLEDB`- und `REMOTE`-Waits können außerdem aus früheren Workloads stammen und werden nicht einer einzelnen Registrierung zugerechnet.

## Sicherer Einstieg

`EXEC [monitor].[USP_LinkedServerAnalysis] @Hilfe = 1;` beschreibt alle Parameter, Ausgabeoptionen und Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @ConnectivityTestEnabled = 0, @ResultSetArt = 'CONSOLE';
```

Der Aufruf materialisiert nur lokale Katalogevidenz. Erst die Kombination aus `@ConnectivityTestEnabled = 1` und `@HighImpactConfirmed = 1` aktiviert `sp_testlinkedserver`. Ist nur der erste Schalter gesetzt, liefert die Procedure `AUTHORIZATION_REQUIRED`, bevor der erste Remotezugriff erfolgt.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@ConnectivityTestEnabled` | `bit` | `0` | 0 führt keinen Remote-Test aus; 1 fordert ihn an und startet ihn nur gemeinsam mit @HighImpactConfirmed=1. NULL ist ungültig und ergibt INVALID_PARAMETER. sp_testlinkedserver läuft für jeden inventarisierten Linked Server. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 bestätigt den Remotezugriff nicht; 1 bestätigt ihn. NULL ist ungültig. Tests starten nur bei @ConnectivityTestEnabled=1 und diesem Schalter=1. Bei aktivem Test und fehlender Bestätigung lautet der Status AUTHORIZATION_REQUIRED; allein aktiviert dieser Schalter keinen Test. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@MaxZeilen` | `int` | `2000` | NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte wählen nach ServerName sortierte Inventarzeilen für RAW/CONSOLE/TABLE/JSON. Inventarisierung und Remoteprüfungen laufen vollständig vor Begrenzung; Status und LinkedServerCount beziehen sich auf alle Server. Negative Werte ergeben INVALID_PARAMETER und keine begrenzten Zeilen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wählt CONSOLE für die beschriftete Linked-Server-Ansicht, RAW für Status, Inventarzeilen und zusätzliche kumulative Waitwerte, TABLE für die benannte Tabellenausgabe oder NONE ohne reguläre Resultsets. Äußere U+0020-Leerzeichen werden entfernt und Groß-/Kleinschreibung normalisiert. JSON enthält nur Linked-Server-Zeilen und wird unabhängig über @JsonErzeugen angefordert. NULL, Leertext oder andere Werte ergeben INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel linkedServers und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | 0 lässt @Json NULL; 1 serialisiert LimitedRows nach ServerName sortiert, also dieselbe begrenzte Auswahl wie die Inventar-Zeilenausgaben. NULL aktiviert IF nicht; leer wird []. Waitwerte sind nicht Teil des JSON-Arrays. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben. |
| `@PrintMeldungen` | `bit` | `1` | 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (kein Linked Server), AVAILABLE_LIMITED (Remoteprüfung teilweise fehlgeschlagen), AUTHORIZATION_REQUIRED (Test angefordert, zweites Opt-in fehlt), INVALID_PARAMETER (ungültige Ausgabeart, Zeilengrenze oder NULL-Opt-in). Zeilenstatus: AVAILABLE oder bei Remotefehler DENIED_PERMISSION, SOURCE_TIMEOUT, SOURCE_UNAVAILABLE; ConnectivityStatus ist NOT_EXECUTED, AUTHORIZATION_REQUIRED, SUCCEEDED oder FAILED. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Bei regulärem Abschluss NULL ohne abgefangenen Remote-Testfehler. Andernfalls enthält der Wert ERROR_NUMBER() des zuletzt abgefangenen Remote-Testfehlers; mehrere Fehler überschreiben den Wert jeweils. Die Einzelzeilen behalten ihre jeweiligen Fehlerhinweise. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender Remote-Testbestätigung. Bei abgefangenen Remote-Testfehlern enthält der Wert die letzte ERROR_MESSAGE(); sonst NULL. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON-Ausgabe

```sql
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#LinkedServerAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"linkedServers":"#LinkedServerAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#LinkedServerAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

CONSOLE priorisiert das benannte Resultset `linkedServers`. RAW liefert zunächst den Modulstatus, danach das Inventar und anschließend den kumulativen Waitkontext. TABLE schreibt ausschließlich `linkedServers` in das unter `@ResultTablesJson` benannte lokale Temp-Ziel. RAW-Inventar und JSON sind nach ServerName geordnet. CONSOLE und TABLE verwenden dieselbe begrenzte Mitgliedschaft, garantieren aber keine physische Zeilenreihenfolge. Lesen Sie zuerst den Modulstatus und danach je Zeile `ConnectivityStatus`, `StatusCode` und `EvidenceLimit`; Provider- und Optionsspalten sind erst in diesem Kontext zu bewerten.

`@MaxZeilen = NULL` und `0` geben das Inventar in CONSOLE, RAW, TABLE und JSON ohne Ausgabebegrenzung aus; positive Werte bestimmen dieselbe deterministisch nach ServerName ausgewählte Mitgliedschaft in allen vier Ausgabewegen. RAW und JSON sind nach ServerName geordnet; CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Status, Zählung und Zahl ausdrücklich aktivierter Verbindungstests beziehen sich weiterhin auf den vollständigen Bestand. Negative Werte setzen `INVALID_PARAMETER` und liefern keine Inventarzeilen. Katalogzugriff und Verbindungstests werden durch die Ausgabegrenze nicht begrenzt.


## Beispiele und Gegenbeispiele

Ein passender Positivfall ist ein synthetischer `ExampleLinkedServer`, der lokal registriert und im Standardpfad mit `ConnectivityStatus = 'NOT_EXECUTED'` ausgegeben wird. Nach einer ausdrücklichen Freigabe darf ein kontrollierter Lab-Endpunkt getestet werden; `SUCCEEDED` ist dann ausschließlich Verbindungsevidenz. Ein Gegenbeispiel ist die Deutung eines hohen kumulativen `OLEDB`-Waitwerts als Defekt genau dieses Linked Servers. Ebenso ist `FAILED` kein Beweis für einen dauerhaften Ausfall, weil Netzwerk, Login-Mapping und Gegenstelle zum Testzeitpunkt separat wirken.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet, dass im sichtbaren Scope kein Linked Server registriert ist. Eine leere Ausgabe beweist nicht, dass keine externe Abhängigkeit über Anwendungscode, SSIS, CLR oder andere Mechanismen besteht. Ein fehlgeschlagener optionaler Test setzt die betroffene Zeile auf `SOURCE_UNAVAILABLE` und macht den Gesamtaufruf partiell; andere lokale Inventarzeilen bleiben erhalten. Bei fehlender High-Impact-Bestätigung wird kein Remoteversuch begonnen.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` lokal; `HIGH_OPT_IN` bei aktiviertem Remote-Test |
| Standardpfad | Einmaliger Zugriff auf `sys.servers`; kein Remotezugriff |
| Teuerster Pfad | Sequenzielle Ausführung von `sp_testlinkedserver` je sichtbarem Linked Server |
| Haupttreiber | Anzahl der Registrierungen sowie Netzwerk-, Provider- und Login-Timeouts |
| Skalierung | Lokales Inventar skaliert mit Registrierungen; Remotezeit skaliert je Ziel |
| Ressourcen | Lokale Katalogarbeit; optional Netzwerk, Provider und Remoteanmeldung |
| Begrenzungswirkung | `@MaxZeilen` begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON; Status und Tests bleiben ungekürzt |
| Locking und Nebenwirkungen | Katalogzugriff ist read-only; der Test kann externe Verbindungen aufbauen |
| Schutzmechanismus | Doppeltes Opt-in vor dem ersten Remotezugriff |
| Sicherer Einsatz | Zuerst lokales Inventar, Remotepfad nur im vereinbarten Testfenster |
| Aussagegrenze | Verbindungstest und Waitsnapshot sind kein fachlicher End-to-End-Test |

## Eine Zeile bedeutet

Eine Zeile beschreibt einen registrierten Linked Server und den getrennten Status des Verbindungstests.

## So lesen

`NOT_EXECUTED` ist der sichere Standard; `FAILED` gilt nur für den konkreten Testzeitpunkt.

## Warum kann das problematisch sein?

Linked Server erweitern Vertrauens-, Netzwerk- und Fehlerdomänen und können verteilte Abhängigkeiten einführen.

## Wann ist es kein Problem?

Ein kontrollierter Linked Server kann eine freigegebene Integrationsschnittstelle sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche lokale Konfiguration benötigt eine autorisierte Konnektivitäts- oder Workloadgegenprobe?

### Technischer Hintergrund

Nur der doppelte opt-in Pfad ruft `sp_testlinkedserver` auf; fachliche Remotedaten werden nicht abgefragt.

### Datenkette

`sys.servers` → Inventar; optional `sp_testlinkedserver` → Teststatus; Waitstatistik → kumulativer Kontext.

### Source Select

```sql
SELECT [name], [product], [provider], [is_data_access_enabled], [is_rpc_out_enabled]
FROM [sys].[servers] WITH (NOLOCK)
WHERE [is_linked] = 1;
```

**Wichtig für die Eigenlast:** Lassen Sie den externen Verbindungstest standardmäßig deaktiviert.

### Zeit- und Scope-Modell

Das Inventar ist aktuell, Waitwerte sind kumulativ und der Test gilt nur für seinen Zeitpunkt.

### Bewertung und Gegenprobe

Prüfen Sie Eigentümer, Login-Mapping, Provider, Netzwerkfreigabe und reale Abfragen getrennt.

### Typische Fehlinterpretation

Ein erfolgreicher Test beweist weder Objektberechtigung noch akzeptable Laufzeit.

### Folgeanalyse

Korrelieren Sie Remote-Waits, Errorlog und Requestevidenz in einem vereinbarten Testfenster.

## Primärquellen

- [sys.servers](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-servers-transact-sql?view=sql-server-ver17)
- [sp_testlinkedserver](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-testlinkedserver-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/220_USP_LinkedServerAnalysis.sql)
