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

## Automatische Ausführung

Der Workflow `.github/workflows/documentation-validation.yml` führt dieselbe Prüfung aus bei:

- relevanten Pull Requests,
- relevanten Änderungen an `main`,
- manueller Auslösung über `workflow_dispatch`.

Der Workflow benötigt nur lesenden Zugriff auf Repositoryinhalte.

## Geprüft wird

- Referenzmenge gegen Procedure-Seiten,
- erwartete Gesamtzahl von 80 Procedures in Referenz, kanonischen SQL-Quellen und Einzelseiten,
- Existenz der in der Referenz genannten SQL-Quelldateien,
- Procedure-Name der Quelldatei,
- Parameterreihenfolge, Parameternamen, Datentypen, Defaults und `OUTPUT`-Kennzeichnung gegen die kanonische SQL-Signatur,
- Parameternamen in dokumentierten `EXEC`-Beispielen,
- Seitentitel,
- Pflichtüberschriften,
- technische Detaillinks,
- interne relative Markdownziele,
- interne Markdown-Anker.

## Aussagegrenzen

Nicht automatisiert bewiesen werden:

- fachliche Richtigkeit jeder Aussage,
- Aktualität externer Links,
- tatsächliche Runtime-Resultsets,
- korrekte Kostenklassifizierung jeder Analyse,
- Datenschutz als beweisbarer Automatismus.

Vor Merge bleibt eine manuelle fachliche und datenschutzbezogene Diffprüfung erforderlich. Der statische Test ergänzt das SQL-Release-Gate, ersetzt es aber nicht.
