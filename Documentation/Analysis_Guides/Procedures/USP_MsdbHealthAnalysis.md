# [monitor].[USP_MsdbHealthAnalysis]

Inventarisiert msdb-Dateigröße und sichtbare Zeitbereiche ausgewählter Betriebsquellen, ohne Daten zu löschen.

**Bereich:** Server Health und Betriebsmetadaten
**Zweck:** Trennt physische `msdb`-Größe von Zeilenanzahl und sichtbarem Zeitfenster ausgewählter Historienquellen.
**Beobachtungsart:** sequenzieller aktueller Aggregationssnapshot
**Kostenklasse:** LOW bis MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, welche `msdb`-Quelle gegen eine festgelegte Aufbewahrungs-, Kapazitäts- oder Betriebsregel geprüft werden sollte. Sie aggregiert Datenbankdateien sowie vorhandene Backup-, Restore-, SQL-Agent-, Database-Mail- und Maintenance-Plan-Tabellen. Das Ergebnis ist eine Bestands- und Zeitfensterevidenz. Die Procedure führt keine Bereinigung, keinen Shrink und keine Agentaktion aus.

## Nicht beantwortete Fragen

Eine hohe Zeilenanzahl oder alte Zeile bestimmt keine fachlich richtige Retention. Die Procedure kennt weder Recovery Point Objective noch Audit-, Compliance-, Incident- oder Betriebsanforderungen. Sie prüft nicht, ob ein Backup restaurierbar ist, ob ein Job erfolgreich konfiguriert wurde oder ob eine Mail den Empfänger erreicht hat. Dateigröße ist außerdem nicht identisch mit belegtem Platz, künftigem Wachstum oder notwendiger Verkleinerung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Führen Sie die erste Inventur in einem geeigneten Betriebsfenster aus. Die einzelnen Quellen werden mit `COUNT_BIG`, `MIN` und `MAX` gelesen. Auf großen Historientabellen kann dies I/O erzeugen, obwohl keine Nutzdaten oder Meldungstexte ausgegeben werden. `@MaxZeilen` begrenzt die Ausgabe, nicht die Aggregationsarbeit innerhalb einer vorhandenen Quelle.

## Resultsets und Leserichtung

CONSOLE zeigt `msdbHealth`. RAW liefert zuerst den Modulstatus und danach die Quellenzeilen. TABLE exportiert ausschließlich das benannte Resultset; JSON verwendet dieselbe lokale Materialisierung. Lesen Sie zuerst `Area`, `SourceObject` und `StatusCode`. Ordnen Sie `RowCount`, `OldestUtc`, `NewestUtc` und `SizeMb` danach gegen die dokumentierte Aufbewahrungsregel ein. Nicht vorhandene optionale Tabellen erscheinen als `UNSUPPORTED`, Quellfehler als `SOURCE_UNAVAILABLE`.

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

### Bewertung und Gegenprobe

Vergleichen Sie Werte mit Backup-, Agent-, Mail- und Wartungsrichtlinien sowie realem Wachstum.

### Typische Fehlinterpretation

Eine alte Zeile beweist nicht, dass sie gelöscht werden darf.

### Folgeanalyse

Prüfen Sie Agentjobs, Backupkette und Dateiwachstum vor einer separat freigegebenen Retentionsänderung.

## Primärquellen

- [Backup- und Restore-Systemtabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backup-and-restore-tables-transact-sql?view=sql-server-ver17)
- [dbo.sysjobhistory](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql)
