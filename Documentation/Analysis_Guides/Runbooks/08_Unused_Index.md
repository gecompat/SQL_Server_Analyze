# Runbook: Ein Index scheint ungenutzt

## Erstaufrufe

```sql
EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames=N'[ExampleDatabase]',
      @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_ObjectInventory]
      @DatabaseNames=N'[ExampleDatabase]',
      @ResultSetArt='CONSOLE';
```

## Lesen

Resetzeit, Reads, Updates, letzte Nutzung, PK/Unique/Constraint, Indexdefinition, Größe und saisonalen Workloadkontext.

## Warum

Viele Updates ohne Reads können unnötige Write-/Log-/Lockkosten anzeigen. Das gilt nur über ein belastbares Beobachtungsfenster.

## Gegenprobe

Query Store, Plan Cache, Abhängigkeiten, Foreign Keys, Notfall-/Monatsreports und `USP_IndexOperationalStats`.

## Nicht tun

Keinen Index allein wegen `0 Reads` löschen.
