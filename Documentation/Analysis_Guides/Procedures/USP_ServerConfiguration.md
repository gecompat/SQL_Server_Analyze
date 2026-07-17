# [monitor].[USP_ServerConfiguration]

**Bereich:** Server Health  
**Zweck:** Zeigt konfigurierte und aktive Serveroptionen mit Bewertungscontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerConfiguration]
      @NurKernparameter = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Serverkonfigurationsoption.

## So lesen

Configured Value, Run Value, Dynamic/Advanced-Status, Default und Beschreibung vergleichen.

## Warum kann das problematisch sein?

Abweichende Run Values können ausstehendes Reconfigure/Restart anzeigen; extreme Werte können Ressourcen falsch begrenzen.

## Wann ist es kein Problem?

Abweichung vom Default ist kein Fehler. Produktive Systeme benötigen oft bewusste Anpassungen.

## Beispiel und Folgeschritt

Niedriges max server memory kann absichtlich Speicher für andere Dienste reservieren. Erst OS-, Workload- und Memorykontext prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#5-monitorusp_serverconfiguration)
