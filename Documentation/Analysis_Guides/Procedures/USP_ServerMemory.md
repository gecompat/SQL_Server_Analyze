# [monitor].[USP_ServerMemory]

**Bereich:** Server Health  
**Zweck:** Verknüpft OS-, SQL-Prozess-, Target-/Total-Memory- und Clerk-Evidenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerMemory]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memory-Zusammenfassung, Prozess-/OS-Signal oder einen Memory Clerk.

## So lesen

OS Available Memory, SQL Process Memory, Target/Total Server Memory, Pressure-Signale und größte Clerks gemeinsam lesen.

## Warum kann das problematisch sein?

OS- und SQL-Druck gleichzeitig kann Paging, Cacheverdrängung und Grantknappheit verursachen.

## Wann ist es kein Problem?

Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen.

## Beispiel und Folgeschritt

Total≈Target allein ist gesund. Total≈Target plus kaum OS-Reserve, Physical Memory Low und Grantwaits ist problematisch. Grants, Buffer Pool und max server memory prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#3-monitorusp_servermemory)
