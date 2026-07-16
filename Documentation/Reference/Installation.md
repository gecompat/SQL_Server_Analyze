# Installation und Inbetriebnahme

## Voraussetzungen

- SQL Server 2019 oder neuer.
- Datenbank `DeineDatenbank` ist vorhanden.
- Der ausführende Login darf im Schema `monitor` DDL ausführen.
- Das Framework vergibt keine Analyseberechtigungen und ändert keine Serverkonfiguration.

## Installation

1. ZIP entpacken.
2. Optional Manifest und SHA-256-Prüfsummen unter `00_Projektstart` kontrollieren.
3. In SSMS, Azure Data Studio oder `sqlcmd` mit der Zielinstanz verbinden.
4. `Code/Install/Install_All.sql` vollständig ausführen.
5. Versionszeile prüfen:

```sql
SELECT *
FROM monitor.FrameworkVersion;
```

6. Analysebereitschaft prüfen:

```sql
EXEC monitor.USP_CheckFrameworkCapabilities;
EXEC monitor.USP_CheckAnalyseAccess;
```

7. Optional den kompakten Smoke Test ausführen:

```text
18_Qualitaetssicherung/110_Smoke_Test.sql
```

## Upgrade

Den aktuellen Gesamtinstaller erneut ausführen. Die Fachobjekte verwenden `CREATE OR ALTER` beziehungsweise idempotente DDL/DML-Logik. Veraltete Zwischenstandsobjekte des früheren Production-Hardening-Ansatzes werden automatisch entfernt. Kundeneigene `WaitTypeCatalog`-Zeilen mit `IsFrameworkDefault = 0` bleiben erhalten.

## Mengenbegrenzung

Alle öffentlichen Mengenparameter folgen derselben Konvention:

- positiver Wert: Ausgabe wird begrenzt;
- `NULL` oder `0`: unbegrenzte Ausgabe beziehungsweise alle sichtbaren Datenbanken;
- negativer Wert: `INVALID_PARAMETER`.

Große oder unbegrenzte Plan-Cache- und Query-Store-Auswertungen können wegen ihrer Eigenlast eine Deep-Analyseklasse erfordern. Die Procedure unterstützt die Vollausgabe dennoch grundsätzlich.

## Erste Ad-hoc-Analyse

```sql
EXEC monitor.USP_CurrentOverview
     @MitSqlText = 0,
     @SampleSeconds = 0,
     @MaxZeilen = 100;
```

Für ein aktuelles Wait-Delta:

```sql
EXEC monitor.USP_CurrentWaits
     @SampleSeconds = 15,
     @TopWaitPercentage = 95,
     @MaxZeilen = 100;
```

## Abgrenzung

Es gibt bewusst keine persistente Installationshistorie, keinen Procedure-Vertragskatalog, keinen Deployment-Orchestrator und kein dauerhaftes Validierungsframework. Für Ad-hoc-Diagnoseobjekte wären diese Komponenten unverhältnismäßig. Ein realer Test auf der konkreten Zielversion und Berechtigungsstufe bleibt dennoch sinnvoll.

## Collation-Voraussetzung

Vor jeder Installation prüft `000_Preflight_und_Schema.sql` die Collation von Server, `tempdb` und `DeineDatenbank`. Alle drei müssen exakt `SQL_Latin1_General_CP1_CS_AS` verwenden. Eine Abweichung führt bewusst zum Abbruch, da das Framework Identifier und Named-Parameter-Aufrufe case-sensitiv auslegt und lokale temporäre Tabellen die `tempdb`-Collation verwenden.
