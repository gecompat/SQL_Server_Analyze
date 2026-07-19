# [monitor].[USP_IndexUsage]

**Bereich:** Object und Index  
**Zweck:** Zeigt kumulative Read-/Write-Nutzung klassischer und optional In-Memory-Indizes.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index im sichtbaren DMV-Scope; XTP-Indizes erscheinen in einem separaten Resultset mit eigener Zählersemantik.

## So lesen

Resetzeit, Reads, Updates, letzte Nutzung und Schutzmerkmale wie PK, Unique oder Constraint gemeinsam lesen.

## Warum kann das problematisch sein?

Viele Updates ohne Reads bedeuten mögliche Schreib-, Log-, Lock- und Speicherlast ohne sichtbaren Lesebedarf.

## Wann ist es kein Problem?

Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung.

## Kommentiertes Beispiel

0 Reads, 8 Mio. Updates, 180 Tage Beobachtung: starker Reviewkandidat. 0 Reads, 40 Updates, zwei Stunden seit Restart: praktisch keine belastbare Aussage.

## Folgeschritt

Query Store, Abhängigkeiten, Constraints und `USP_IndexOperationalStats` prüfen. Niemals allein aus dieser DMV einen Index löschen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Reads und Writes wurden einem Index seit dem DMV-Reset zugerechnet?

### Technischer Hintergrund

`sys.dm_db_index_usage_stats` zählt user/system seeks, scans, lookups und updates sowie letzte Zeitpunkte. Ein einzelnes DML-Statement kann mehrere Indexupdates verursachen. Der Zähler erfasst nicht jede semantische Abhängigkeit, etwa Constraintwirkung oder seltene saisonale Reports.

### Datenkette

`sys.dm_db_index_usage_stats`, `sys.dm_db_xtp_index_stats`, `sys.dm_os_sys_info`, `sys.hash_indexes`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Kumulativ seit Engine-/Datenbank-/DMV-Lebenszyklus. Restart, Detach/Attach, Offline/Online und andere Ereignisse können den Beobachtungszeitraum verkürzen.

### Bewertung und Gegenprobe

Reads, Updates, letzte Nutzung, Uptime/Resetzeit, Indexgröße und Schutzstatus kombinieren. Viele Updates ohne Reads über ein ausreichend langes repräsentatives Fenster sind ein Reviewkandidat, kein Dropbefehl.

### Typische Fehlinterpretation

`0 Reads` bedeutet nur keine in dieser DMV sichtbare Nutzung im Fenster. Planforcing, Query Store, Wartung, FK/Unique/PK und Monats-/Jahresworkloads gegenprüfen.

### Folgeanalyse

`USP_IndexOperationalStats`, Query Store, Dependency-/Constraintreview.

[Technische Detailbeschreibung](../03_Object_Index.md#2-monitorusp_indexusage)
