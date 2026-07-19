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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Serveroptionen weichen von Default/Empfehlung ab und welche Werte sind tatsächlich aktiv?

### Technischer Hintergrund

`sys.configurations` besitzt configured `value` und `value_in_use`, Dynamic/Advanced Flags. Manche Änderungen greifen sofort, andere nach RECONFIGURE oder Restart. Optionen beeinflussen Parallelität, Memory, Security, Remotezugriff und Engineverhalten.

### Datenkette

`sys.configurations`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Aktueller Konfigurationsstand; einige `value`-Änderungen noch nicht in use.

### Bewertung und Gegenprobe

Configured/In Use, Is Dynamic, Is Advanced, Version/Edition, Workload und Changegrund gemeinsam lesen. Abweichungen priorisieren, aber nicht automatisch korrigieren.

### Typische Fehlinterpretation

Default ist nicht immer optimal; bekannte Empfehlung ist nicht universell. Mehrere Optionen interagieren, etwa MAXDOP/Cost Threshold oder Max Memory/OS Reserve.

### Folgeanalyse

Spezifische Topologie-/Memory-/Securitymodule und kontrolliertes Changeverfahren.

[Technische Detailbeschreibung](../08_Server_Health.md#5-monitorusp_serverconfiguration)
