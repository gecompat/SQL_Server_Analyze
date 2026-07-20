# [monitor].[USP_CurrentOverview]

**Bereich:** Current State, Orchestrator  
**Zweck:** Führt mehrere leichte Live-Analysen in definierter Reihenfolge aus.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentOverview]
      @ResultSetArt = 'CONSOLE';
```

Der Default `@Detailgrad = 'SUMMARY'` liefert genau ein konsolidiertes
Modul-Summary. `RELEVANT` ergänzt nicht leere diagnostisch relevante Details;
`ALL` ergänzt alle nicht leeren aktivierten Childdetails. Sampling und
vollständige SQL-Texte nur gezielt aktivieren.

## Eine Zeile bedeutet

Im Summary entspricht eine Zeile einem Childmodul. Status, Partialität,
Zeilenanzahl und Dauer stammen aus dem expliziten Childvertrag. In den bewusst
aktivierten Detailgraden entspricht eine Detailzeile weiterhin Session, Request,
Blockingkante, Wait, Transaktion, Grant, TempDB-Verbrauch, Datei-I/O oder
Logzustand.

## So lesen

Zuerst Modulstatus, dann vom konkreten Symptom zum passenden Child wechseln. Resultsets nicht ungeprüft miteinander addieren.

## Warum kann das problematisch sein?

Ein Überblick verdichtet unterschiedliche Evidenzarten. Ein auffälliger Einzelwert ohne Childkontext kann zu einer falschen Ursache führen.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich. Ein leeres Child ist nur bei erfolgreichem Status als „aktuell nichts sichtbar“ interpretierbar.

## Beispiel und Folgeschritt

Blocking und hohe Logauslastung können dieselbe alte Transaktion als Ursache haben. Mit Blocking- und Transaktionsprocedure fokussiert nachprüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Current-State-Symptome verdienen als Erstes eine spezialisierte Analyse?

### Technischer Hintergrund

Der Orchestrator ruft jedes aktivierte Child genau einmal und niemals mit
CONSOLE auf. Der eine Childaufruf materialisiert das Primärergebnis und erzeugt
den JSON-/Statusvertrag. Summary, optionale Details, JSON und TABLE-Export nutzen
diese Materialisierung weiter. Das Ausbleiben eines SQL-Fehlers wird nicht als
`AVAILABLE` interpretiert; ein fehlender oder unvollständiger Statusvertrag wird
als `STATUS_UNAVAILABLE` partiell ausgewiesen.

TABLE verwendet ausschließlich `@ResultTablesJson`. Exportierbar sind
`moduleStatus`, `sessions`, `requests`, `blocking`, `waits`, `transactions`,
`memoryGrants`, `tempdbSessions`, `io`, `logs` und `warnings`.

### Datenkette

Frameworkinterne Orchestrierung/Filterlogik; keine eigenständige Systemquelle.

### Zeit- und Scope-Modell

Nahe beieinanderliegende, aber nicht atomare Momentaufnahmen; Samplingchildren können den Aufruf verlängern.

### Bewertung und Gegenprobe

Zuerst Modulstatus und Partialflags, dann nur auffällige Children vertiefen. Korrelation ist möglich, wenn dieselbe Session/DB/Datei in mehreren Children erscheint.

### Typische Fehlinterpretation

Ein unauffälliger Overview beweist nicht, dass zwischen Childaufrufen kein kurzer Vorfall auftrat. Resultsets dürfen nicht so behandelt werden, als stammten sie aus einer gemeinsamen Transaktion.

### Folgeanalyse

Betroffenes Childmodul mit engeren Filtern erneut ausführen.

[Technische Detailbeschreibung](../02_Current_State.md#10-monitorusp_currentoverview)
