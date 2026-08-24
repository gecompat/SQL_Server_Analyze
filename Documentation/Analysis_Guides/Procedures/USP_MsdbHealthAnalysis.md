# [monitor].[USP_MsdbHealthAnalysis]

Inventarisiert msdb-Dateigröße und sichtbare Zeitbereiche ausgewählter Betriebsquellen, ohne Daten zu löschen.

```sql
EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

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

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql)
