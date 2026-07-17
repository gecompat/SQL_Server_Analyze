# [monitor].[USP_ServerSecurityConfiguration]

**Bereich:** Server Health  
**Zweck:** Erzeugt Sicherheits-Reviewbefunde zu relevanten Serveroptionen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Sicherheitskonfiguration oder einem normalisierten Reviewfinding.

## So lesen

Scope, aktuellen Wert, Exposition, Severity, Evidence und `EvidenceLimit` gemeinsam lesen.

## Warum kann das problematisch sein?

Unsichere Optionen können Angriffsfläche oder unerwünschte Rechtepfade eröffnen.

## Wann ist es kein Problem?

Ein Feature kann betrieblich erforderlich und durch Berechtigungen, Audit oder andere Kontrollen abgesichert sein.

## Beispiel und Folgeschritt

`xp_cmdshell` aktiviert ist ein Reviewbefund, aber die reale Gefährdung hängt von Berechtigungen, Nutzung und Kompensationskontrollen ab. Sicherheitskonzept und Audit prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#9-monitorusp_serversecurityconfiguration)
