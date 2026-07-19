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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sicherheitsrelevanten Servereinstellungen und Prinzipal-/Endpointmuster verdienen ein Securityreview?

### Technischer Hintergrund

Server Principals/Roles/Permissions, Authentication, Endpoints, Service Accounts und Konfigurationsoptionen bilden mehrere Sicherheitsebenen. Metadata Visibility begrenzt die Sicht. Frameworkbefunde sollen Konfiguration inventarisieren, keine Credentials/Secrets ausgeben.

### Datenkette

`sys.configurations`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Aktueller Metadaten-/Konfigurationsstand.

### Bewertung und Gegenprobe

Finding, Scope, Severity/Confidence, betroffene Option/Rolle und dokumentierte Policy verbinden. Besonders sysadmin, CONTROL SERVER, unsichere Optionen und exponierte Endpoints mit Owner/Notwendigkeit prüfen.

### Typische Fehlinterpretation

Technischer Befund ist kein vollständiges Berechtigungsaudit und keine Aussage über organisatorische Genehmigung. Fehlende Sicht darf nicht als fehlende Berechtigung interpretiert werden.

### Folgeanalyse

Formales Security-/Identityreview, Audit und Change Governance.

[Technische Detailbeschreibung](../08_Server_Health.md#9-monitorusp_serversecurityconfiguration)
