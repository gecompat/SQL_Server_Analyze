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

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @ConnectivityTestEnabled = 0, @ResultSetArt = 'CONSOLE';
```

Der Aufruf materialisiert nur lokale Katalogevidenz. Erst die Kombination aus `@ConnectivityTestEnabled = 1` und `@HighImpactConfirmed = 1` aktiviert `sp_testlinkedserver`. Ist nur der erste Schalter gesetzt, liefert die Procedure `AUTHORIZATION_REQUIRED`, bevor der erste Remotezugriff erfolgt.

## Resultsets und Leserichtung

CONSOLE priorisiert das benannte Resultset `linkedServers`. RAW liefert zunächst den Modulstatus, danach das Inventar und anschließend den kumulativen Waitkontext. TABLE schreibt ausschließlich `linkedServers` in das unter `@ResultTablesJson` benannte lokale Temp-Ziel. JSON enthält dasselbe begrenzte Inventar. Lesen Sie zuerst den Modulstatus und danach je Zeile `ConnectivityStatus`, `StatusCode` und `EvidenceLimit`; Provider- und Optionsspalten sind erst in diesem Kontext zu bewerten.

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
| Begrenzungswirkung | `@MaxZeilen` begrenzt Ausgabe, nicht die Zahl aktivierter Verbindungstests |
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
