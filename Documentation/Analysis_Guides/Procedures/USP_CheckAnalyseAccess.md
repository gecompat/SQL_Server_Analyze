# [monitor].[USP_CheckAnalyseAccess]

**Bereich:** Common  
**Zweck:** Prüft, ob der aktuelle Sicherheitskontext eine Analyseklasse gemäß Framework-Policy ausführen darf.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckAnalyseAccess]
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Spalten `@ResultSetArt='RAW'`; für Parameterhilfe `@Hilfe=1`.

## Eine Zeile bedeutet

Eine Access-Zeile beschreibt das effektive Gate-Ergebnis für eine Analyseklasse. Policy-Zeilen beschreiben jeweils eine konfigurierte Gruppenregel.

## So lesen

Zuerst `IsAllowed`, danach `AccessReason`, `RelevantPolicyCount` und `MatchedGroupCount` lesen. Anschließend Original- und Effektivlogin vergleichen.

## Warum kann das problematisch sein?

`RelevantPolicyCount > 0` und `MatchedGroupCount = 0` bedeutet: Für die Analyseklasse existieren Regeln, aber keine passende Gruppenmitgliedschaft wurde erkannt. Die Sperre ist dann erwartbares Policyverhalten und kein DMV-Defekt.

## Wann ist es kein Problem?

`RelevantPolicyCount = 0` und `IsAllowed = 1` entspricht dem Frameworkvertrag: Ohne definierte Policy bleibt die Klasse offen.

## Beispiel und Folgeschritt

`IsAllowed=0` mit `AccessReason=NO_GROUP_MATCH` verlangt eine Prüfung der Gruppenpolicy, nicht das vorschnelle Erteilen zusätzlicher SQL-Rechte. Danach mit `USP_CheckFrameworkCapabilities` die technische Lesbarkeit prüfen.

## Leere oder partielle Ausgabe

Leere Accessdaten sind nur nach Prüfung von Status, Filter und Policyumfang interpretierbar. `PERMISSION_DENIED` oder `IsPartial=1` ist keine Entwarnung.

[Technische Detailbeschreibung](../01_Common.md#1-monitorusp_checkanalyseaccess)
