# Analyse-Dokumentation validieren

## Ausführung

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Optional kann der Repositoryroot übergeben werden:

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1 -RepositoryRoot 'C:\Example\SQL_Server_Analyze'
```

Der Beispielpfad ist synthetisch.

## Geprüft wird

- Referenzmenge gegen Procedure-Seiten,
- erwartete Gesamtzahl 79,
- Seitentitel,
- Pflichtüberschriften,
- technische Detaillinks,
- interne relative Markdownlinks.

## Nicht geprüft wird

- fachliche Richtigkeit jeder Aussage,
- Aktualität externer Links,
- tatsächliche Runtime-Resultsets,
- Datenschutz als beweisbarer Automatismus.

Vor Merge bleibt eine manuelle fachliche und datenschutzbezogene Diffprüfung erforderlich.
