# [monitor].[USP_MsdbHealthAnalysis]

Inventarisiert msdb-Dateigröße und sichtbare Zeitbereiche ausgewählter Betriebsquellen, ohne Daten zu löschen.

**Bereich:** Server Health und Betriebsmetadaten
**Zweck:** Trennt physische `msdb`-Größe von Zeilenanzahl und sichtbarem Zeitfenster ausgewählter Historienquellen.
**Beobachtungsart:** sequenzieller aktueller Aggregationssnapshot
**Kostenklasse:** LOW bis MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, welche `msdb`-Quelle gegen eine festgelegte Aufbewahrungs-, Kapazitäts- oder Betriebsregel geprüft werden sollte. Sie aggregiert Datenbankdateien sowie vorhandene Backup-, Restore-, SQL-Agent- und Maintenance-Plan-Tabellen und die Database-Mail-View `msdb.dbo.sysmail_allitems`. Tabellen und Views werden als lesbare Quellen erkannt. Das Ergebnis ist eine Bestands- und Zeitfensterevidenz. Die Procedure führt keine Bereinigung, keinen Shrink und keine Agentaktion aus.

## Nicht beantwortete Fragen

Eine hohe Zeilenanzahl oder alte Zeile bestimmt keine fachlich richtige Retention. Die Procedure kennt weder Recovery Point Objective noch Audit-, Compliance-, Incident- oder Betriebsanforderungen. Sie prüft nicht, ob ein Backup restaurierbar ist, ob ein Job erfolgreich konfiguriert wurde oder ob eine Mail den Empfänger erreicht hat. Dateigröße ist außerdem nicht identisch mit belegtem Platz, künftigem Wachstum oder notwendiger Verkleinerung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Führen Sie die erste Inventur in einem geeigneten Betriebsfenster aus. Die einzelnen Quellen werden mit `COUNT_BIG`, `MIN` und `MAX` gelesen. Auf großen Historientabellen kann dies I/O erzeugen, obwohl keine Nutzdaten oder Meldungstexte ausgegeben werden. `@MaxZeilen` begrenzt die Ausgabe, nicht die Aggregationsarbeit innerhalb einer vorhandenen Quelle.

## Resultsets und Leserichtung

CONSOLE zeigt `msdbHealth`. RAW liefert zuerst den Modulstatus und danach die Quellenzeilen. TABLE exportiert ausschließlich das benannte Resultset; JSON verwendet dieselbe lokale Materialisierung. Lesen Sie zuerst `Area`, `SourceObject` und `StatusCode`. Ordnen Sie `RowCount`, `OldestUtc`, `NewestUtc` und `SizeMb` danach gegen die dokumentierte Aufbewahrungsregel ein. Nicht vorhandene optionale Tabellen erscheinen als `UNSUPPORTED`, Quellfehler als `SOURCE_UNAVAILABLE`.

`@MaxZeilen = NULL` und `0` liefern alle Quellenzeilen. Positive Werte begrenzen
CONSOLE, RAW, TABLE und JSON auf denselben nach `Area` ausgewählten Bestand.
Der RAW-Modulstatus zählt mit `EvidenceRows` weiterhin sämtliche ermittelten
Quellenzeilen vor der Ausgabebegrenzung. Negative Werte ergeben
`INVALID_PARAMETER` und keine fachlichen Ergebniszeilen.

Für `AGENT_HISTORY` zählt `RowCount` sämtliche sichtbaren Job- und Stepzeilen
aus `msdb.dbo.sysjobhistory`. Beide Zeitgrenzen bleiben NULL; das Modul
interpretiert weder `run_date`, `run_time` noch `run_duration`. Die Anzahl
belegt keine Zahl ausgeführter Jobs und keine bestimmte Aufbewahrungsdauer.

## Beispiele und Gegenbeispiele

Eine frische synthetische Example-Lab-Instanz kann für mehrere Historien `RowCount = 0` liefern; dies ist ein zulässiger Leerfall. Ein kontrolliert erzeugtes synthetisches Backup kann ein kurzes sichtbares Zeitfenster belegen, ohne damit Restorefähigkeit nachzuweisen. Ein Gegenbeispiel ist die Empfehlung, alle alten Backupzeilen allein aufgrund von `OldestUtc` zu löschen. Auch eine große `msdb` rechtfertigt keinen automatischen Shrink.

## Leere oder partielle Ausgabe

Eine vorhandene, aber leere Historientabelle erzeugt eine Quellenzeile mit `RowCount = 0` und leeren Zeitgrenzen. Fehlt eine optionale Tabelle auf der konkreten Plattform oder Installation, bleibt diese Abwesenheit als `UNSUPPORTED` sichtbar. Scheitert eine einzelne Aggregation, setzt die Procedure `AVAILABLE_LIMITED`, erhält andere Quellen und dokumentiert die Quellgrenze. Ein vollständiger Berechtigungsnachweis erfordert einen gezielten eingeschränkten Lauf.

Kurze und lange Retentionsfenster werden nur mit kontrolliert erzeugten Historien oder einer ausdrücklich autorisierten Testinstanz bewertet. Bestehende fremde Historien werden weder als Fixture verwendet noch für einen Test verändert. Ein nicht reproduzierbarer Altbestand bleibt externe Evidenz.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` bis `MEDIUM` |
| Standardpfad | Dateigröße plus Aggregate je vorhandener Historientabelle |
| Teuerster Pfad | `COUNT_BIG`, `MIN` und `MAX` auf großen, unzureichend indizierten Historien |
| Haupttreiber | Zeilenumfang, Datumsindexierung und paralleles Historienwachstum |
| Skalierung | Sequenziell je vordefinierter Quelle |
| Ressourcen | `msdb`-I/O, CPU für Aggregate und kurze Metadatenzugriffe |
| Begrenzungswirkung | `@MaxZeilen` begrenzt Ausgabe; Quellumfang bleibt bestehen |
| Locking und Nebenwirkungen | Read-only mit `NOLOCK`; keine Bereinigung oder Dateimutation |
| Schutzmechanismus | Isolierter Fehlerstatus je Quelle und feste Quellenliste |
| Sicherer Einsatz | In einem Betriebsfenster und mit dokumentierter Retention als Gegenprobe |
| Aussagegrenze | Umfang und Zeitfenster sind kein Gesundheits- oder Löschurteil |

## Eine Zeile bedeutet

Eine Zeile beschreibt die Dateigröße oder eine Historienquelle wie Backup, Restore, Agent, Mail oder Maintenance Plans.

## So lesen

Zeilenanzahl und Zeitstempel zeigen Umfang und Fenster, aber keine fachlich richtige Retention.

## Warum kann das problematisch sein?

Unbegrenzte Historien können msdb wachsen lassen; zu kurze Historien können Diagnoseevidenz reduzieren.

## Wann ist es kein Problem?

Eine große msdb kann bei vielen Datenbanken, Jobs und freigegebenen Aufbewahrungsfristen angemessen sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche msdb-Quelle sollte gegen ihre Aufbewahrungsregel geprüft werden?

### Technischer Hintergrund

Pro vorhandener Tabelle wird eine Aggregation ausgeführt; Quellfehler bleiben als partielle Evidenz erhalten.

### Datenkette

`sys.master_files` und ausgewählte `msdb.dbo`-Tabellen → Größen- und Zeitfensterinventar.

### Source Select

```sql
SELECT COUNT_BIG(*) [RowCount], MIN([backup_finish_date]) [OldestUtc], MAX([backup_finish_date]) [NewestUtc]
FROM [msdb].[dbo].[backupset] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Große Historientabellen können I/O verursachen; wählen Sie ein geeignetes Betriebsfenster.

### Zeit- und Scope-Modell

Quellen werden nacheinander gelesen und können währenddessen wachsen.

Eine getrennte tatsächliche SQL-2025/Docker-Probe bestätigt eine automatische
Vierzeilen-Grenze pro Job. Drei erfolgreiche eigene Agentläufe hinterlassen
zwei, vier und vier Historyzeilen; die zuerst erzeugten zwei Zeilen
verschwinden ohne manuellen Purge. Sämtliche Werte des zweiten Zeilenpaars
bleiben erhalten. NONE/JSON erhält in jeder Phase den aktuellen
AGENT_HISTORYcount, NULL-Zeitgrenzen und eine nicht leere EvidenceLimit
bei Status AVAILABLE ohne Partial oder Consumerfehler. Diese Probe
belegt keine globale Grenzüberschreitung, Altersretention oder andere Engine.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft eine globale
Agent-Historiengrenze von sechs Zeilen bei einer Vierzeilen-Grenze pro Job.
Vier erfolgreiche Läufe zweier eigener aktivierter Jobs mit je einem TSQL-Step in der
Reihenfolge A, B, A, B hinterlassen zwei, vier, sechs und sechs Zeilen.
Das erste A-Paar verschwindet ohne manuellen Purge; sämtliche Werte der
beiden jüngeren Paare bleiben erhalten. NONE/JSON erhält die jeweiligen
AGENT_HISTORYcounts, NULL-Zeitgrenzen und eine nicht leere EvidenceLimit
ohne Partial oder Consumerfehler. Andere Limits und Altersretention bleiben offen.

Eine getrennte native SQL-2025/Docker-Probe prüft die datenbankselektive
Bereinigung zweier eigener Backup-/Restorepaare. Beide neuen eigenen
Datenbanken werden tatsächlich gesichert und unter ihrem eigenen Namen
restauriert. Die Historienzeiten sind anschließend kontrolliert gesetzt;
die Gegenprobe besitzt ältere Zeitwerte. Zwei native datenbankbezogene
Purges liefern Backup- und Restorecounts zwei, eins und null. Nach dem
ersten Purge bleiben sämtliche Werte der älteren Gegenprobe in allen
acht Historienquellen erhalten; nach dem zweiten sind alle acht leer.
Neun NONE-/TABLE-/CONSOLE-Aufrufe bestätigen native Counts und Zeitgrenzen
sowie vollständige TABLE-/CONSOLE-/JSON-Parität. Historienwerte, acht
Katalogfelder beider eigenen Datenbanken und Callerzustand bleiben erhalten.
Eigene Datenbanken, Lab und State werden entfernt. Dies belegt keine
automatische Altersretention, allgemeine Purgegarantie oder andere Engine.

Eine getrennte native SQL-2025/Docker-Probe prüft die exakte Altersgrenze
zweier eigener Backup-/Restorepaare mit kontrollierten Historienzeiten.
Beim Stichtag 2025-01-01T12:00:00 bleibt das genau gleich datierte Paar
mit sämtlichen Werten aller acht Historienquellen erhalten; nur das ältere
Paar verschwindet. Ein Stichtag eine Sekunde später entfernt auch das
verbliebene Paar. Backup-Start, Backup-Ende und Restorezeit besitzen je
Paar denselben kontrollierten Zeitpunkt. Neun NONE-/TABLE-/CONSOLE-Aufrufe
bestätigen Counts zwei, eins und null, native Zeitgrenzen, vollständige
Ausgabeparität sowie erhaltene Quellen-, Katalog- und Callerwerte.
Diese gemeinsame Datumsgrenze belegt weder getrennte Backup-/Restorezeitregeln
noch automatische Altersretention oder die Erhaltung physischer Backupdateien.

Eine getrennte native SQL-2025/Docker-Probe prüft die exakte Mailretentionsgrenze
mit injizierten unsent-, sent-, failed- und retrying-Zeilen. Gleich datierte
Zielzeilen bleiben am Stichtag erhalten; eine Sekunde später sind sie entfernt.
Ältere Zeilen der drei anderen Status bleiben mit sämtlichen Mailitemwerten
erhalten. 36 NONE-/TABLE-/CONSOLE-Aufrufe bestätigen Counts, native Zeitgrenzen,
Ausgabeparität und Callererhaltung bei deaktivierten Database Mail XPs.
Die konkrete native Prozedur vergleicht send_request_date strikt mit dem
Stichtag. Beide Zeitfelder sind in der Fixture gleich gesetzt; unabhängige
sent_date-Regeln, tatsächliche Statusentstehung und Mailversand sind unbelegt.

Eine weitere native SQL-2025/Docker-Probe trennt die Wirkung der beiden
Mailzeitfelder mit bewusst zeitlich widersprüchlichen synthetischen Werten.
Ein altes send_request_date führt trotz zukünftigem sent_date zur Entfernung;
ein send_request_date am Stichtag bleibt trotz älterem sent_date erhalten.
Die Grenze eine Sekunde später entfernt diese Zeile. Mit NULL-Datum und
weiterhin gesetztem Zielstatus werden auch dessen restliche Zeilen entfernt.
Die anderen drei Status bleiben mit sämtlichen Mailitemwerten unverändert.
48 NONE-/TABLE-/CONSOLE-Aufrufe bestätigen Counts, native MIN/MAX-Werte,
Ausgabeparität und Callererhaltung. Mail-XPs bleiben deaktiviert; die
synthetischen Zeitwerte belegen keine tatsächliche Mailzustandsentstehung.

### Bewertung und Gegenprobe

Vergleichen Sie Werte mit Backup-, Agent-, Mail- und Wartungsrichtlinien sowie realem Wachstum.

### Typische Fehlinterpretation

Eine alte Zeile beweist nicht, dass sie gelöscht werden darf.

### Folgeanalyse

Prüfen Sie Agentjobs, Backupkette und Dateiwachstum vor einer separat freigegebenen Retentionsänderung.

## Primärquellen

- [Backup- und Restore-Systemtabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backup-and-restore-tables-transact-sql?view=sql-server-ver17)
- [dbo.sysjobhistory](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql?view=sql-server-ver17)
- [Database-Mail-Objekte](https://learn.microsoft.com/en-us/sql/relational-databases/database-mail/database-mail-messaging-objects?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql)
