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

[Technische Detailbeschreibung](../02_Current_State.md#7-monitorusp_currenttempdb)
