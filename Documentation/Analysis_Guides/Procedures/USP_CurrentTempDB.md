# [monitor].[USP_CurrentTempDB]

**Bereich:** Current State  
**Zweck:** Zeigt aktuelle TempDB-Belegung nach Session, Verbrauchsart und Datei.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTempDB]
      @MitDateien = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Sessionallokation, eine Verbrauchsart oder eine TempDB-Datei. Diese Granularitäten dürfen nicht addiert werden, ohne das Resultset zu beachten.

## So lesen

Zuerst Gesamt- und Dateiauslastung, danach User Objects, Internal Objects, Version Store und verursachende Sessions unterscheiden.

## Warum kann das problematisch sein?

Wachsende Internal Objects können Sorts, Hashes oder Spills anzeigen. Version Store deutet eher auf lange Snapshot-/RCSI-Transaktionen.

## Wann ist es kein Problem?

Kurzzeitige Spitzen während kontrollierter ETL- oder Indexoperationen sind akzeptabel, wenn Dateien vorallokiert sind und kein Autogrowth-Sturm entsteht.

## Beispiel und Folgeschritt

90 % voll erklärt die Ursache nicht. 80 % Version Store verlangt Transaktionsprüfung; 80 % Internal Objects einer Session verlangt Request- und Plananalyse. Dateidesign über `USP_TempDBConfiguration` prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche TempDB-Komponente verbraucht Platz, und welche Session/Task treibt den Verbrauch?

### Technischer Hintergrund

TempDB speichert User Objects, Internal Objects für Sort/Hash/Spool/Worktables, Version Store sowie freie/ungeordnete Bereiche. Datei-Space-DMVs und Session-/Task-Space-Usage besitzen unterschiedliche Aggregation. Version Store wird durch zeilenversionsbasierte Isolation und weitere Enginefeatures erzeugt.

### Datenkette

`sys.database_files`, `sys.dm_db_session_space_usage`, `sys.dm_exec_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Datei-/Datenbankzustand; Session-/Taskzähler seit Request/Sessionaktivität. Version Store kann nach Transaktionsende verzögert bereinigt werden.

### Bewertung und Gegenprobe

Zuerst Belegungsart trennen, dann Verbraucher und Wachstum prüfen. Internal Objects plus Spillwarnung führt zum Plan; Version Store plus alte Snapshottransaktion zur Transaktionsanalyse; User Objects zu Tempobjekten.

### Typische Fehlinterpretation

Hohe Gesamtbelegung oder eine große Datei nennt keine Ursache. Freier Platz innerhalb TempDB und freier Volumeplatz sind verschiedene Größen.

### Folgeanalyse

`USP_CurrentRequests`, `USP_CurrentTransactions`, `USP_TempDBConfiguration`, Showplan.

[Technische Detailbeschreibung](../02_Current_State.md#7-monitorusp_currenttempdb)
