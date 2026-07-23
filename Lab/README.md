# LAB-001 – Reproducible Diagnostic Lab

LAB-001 ist ein ausschließlich synthetisches und hardwareadaptives
SQL-Server-Diagnoselabor. Welle 0 stellt die statischen Verträge, Profile,
Kataloge und die vollständige geplante Procedure-Coverage bereit. Welle 1
implementiert den ausführbaren, read-only Preflight und den begrenzten
Orchestrator-Core.

Der Produktstatus ist `PARTIAL_PRODUCT_FUNCTION`. Der Preflight, die
Ausführungsmodus-Auflösung und die sichere lokale Zustandsverwaltung sind
nutzbar. Container, virtuelle Maschinen, SQL-Server-Topologien und Szenarien
werden erst ab Welle 2 implementiert und durch keine Welle-1-Funktion erzeugt.

## Verzeichnisvertrag

| Pfad | Inhalt |
|---|---|
| `Config` | Generische Beispielkonfigurationen und konservative Ressourcenprofile. |
| `Contracts` | JSON-Schemata für Konfiguration, Hostfähigkeiten, Topologien, Szenarien, Finding-Erwartungen und veröffentlichbare Evidenz. |
| `Orchestration` | Öffentliche CLI und PowerShell-Modul für Preflight, Status und begrenztes Cleanup. |
| `Scenarios/Catalog` | Maschinenlesbarer Szenariokatalog und Procedure-zu-Szenario-Coverage. |
| `Validation` | Statische, Parser-, Schema-, Hostadapter- und Cleanup-Negativprüfungen ohne SQL-Server-Workload. |
| `.artifacts`, `.cache`, `.secrets`, `.state` | Ausschließlich lokale, ignorierte Laufzeitpfade. |

Die geplante vollständige Verzeichnisstruktur ist im
[Architekturplan](../Documentation/Architecture/Reproducible_Diagnostic_Lab_Plan.md)
festgelegt. Verzeichnisse späterer Wellen werden erst mit einem fachlich
nutzbaren Artefakt versioniert; leere Platzhalter gelten nicht als
Implementierung.

## Preflight und Status

Vor dem ersten lokalen Lauf wird
`Lab/Config/lab.config.example.psd1` nach
`Lab/Config/lab.config.psd1` kopiert und ausschließlich lokal angepasst. Die
lokale Datei ist ignoriert. Storage-Ziele, Remote-Endpunkte, Benutzernamen und
lokale Pfade dürfen nicht in die Beispielkonfiguration übernommen werden.

```powershell
.\Lab\Orchestration\Invoke-DiagnosticLab.ps1 -Action Preflight
```

Ohne lokale Konfiguration wird der sichere Beispielvertrag ausgewertet. Das
Ergebnis lautet dann `NOT_EXECUTABLE` mit dem Reason Code
`LOCAL_CONFIG_REQUIRED`; es wird keine lokale Ressource ausgewählt.

Der Preflight ermittelt:

- Betriebssystemfamilie, x86-64-Architektur, CPU und Speicher;
- ausschließlich explizit freigegebene logische Storage-Ziele;
- Hyper-V und PowerShell Direct auf Windows;
- Docker, Podman, Compose, cgroups und `tc` auf Linux;
- die konservative Hostklasse `HC1_COMPACT`, `HC2_STANDARD`,
  `HC3_EXTENDED` oder `UNCLASSIFIED`;
- verfügbare Ausführungsmodi und die deterministische `AUTO`-Auflösung;
- gebundene Image-/Medien-Locks sowie Konflikte des lokal konfigurierten
  privaten Labnetzes;
- die Verfügbarkeit logisch benannter Secrets, ohne Secretwerte zu
  protokollieren.

`DISTRIBUTED` wird nur aufgelöst, wenn mindestens ein Windows-Hyper-V- und ein
Linux-Container-Host vorhanden sind, mindestens ein Host remote ist und die
Remote-Ausführung mit `-AllowRemoteExecution` ausdrücklich freigegeben wurde.

Die Run-ID aus der Preflight-Ausgabe wird für Statusabfragen verwendet:

```powershell
.\Lab\Orchestration\Invoke-DiagnosticLab.ps1 `
    -Action Status `
    -LabRunId LAB-<UTC>-<ID>
```

Die lokalen Dateien `run-state.json`, `host-capabilities.json`,
`preflight-summary.json`, `resource-registry.json` und `events.jsonl` liegen
unter `Lab/.state/<LabRunId>`. Sie werden nicht versioniert und sind keine
veröffentlichbare Evidenz.

## Begrenztes Cleanup

Welle 1 führt keine Infrastrukturressourcen ein. Die Cleanup-Registry steht
bereits als verbindlicher Sicherheitsvertrag für spätere Wellen bereit. Eine
Ressource kann nur über Provider, Typ, exakte Objekt-ID, exakten Locator und
übereinstimmende Owner-Run-ID registriert werden.

```powershell
.\Lab\Orchestration\Invoke-DiagnosticLab.ps1 `
    -Action Down `
    -LabRunId LAB-<UTC>-<ID> `
    -WhatIf

.\Lab\Orchestration\Invoke-DiagnosticLab.ps1 `
    -Action RecoveryCleanup `
    -LabRunId LAB-<UTC>-<ID>
```

Wildcard-Locators, fremde Run-IDs, nicht unterstützte Handler und Pfade
außerhalb der Run-Grenze werden vor der ersten Löschung abgewiesen. Cleanup
verwendet keine rekursive oder namensbasierte Suche. Nicht registrierte Dateien
bleiben unverändert.

## Validierung

Die repositoryunabhängige Prüfung läuft mit Python:

```text
python3 Code/Tests/Static/988_Validate_LAB001_Wave0_Contracts.py --repository-root .
python3 Code/Tests/Static/989_Validate_LAB001_Wave1_Orchestrator.py --repository-root .
```

Auf Systemen mit PowerShell 7 kann zusätzlich die JSON-Schema-Prüfung ausgeführt
werden:

```text
pwsh -NoLogo -NoProfile -File Lab/Validation/Invoke-LabValidation.ps1
pwsh -NoLogo -NoProfile -File Lab/Validation/Invoke-LabWave1Tests.ps1
```

Beide Prüfungen sind read-only. Sie prüfen insbesondere:

- syntaktisch gültige JSON- und CSV-Dateien;
- Referenzen zwischen Szenarien, Topologien und Coverage;
- genau eine Coverage-Zeile je öffentlicher Procedure aus
  `Metadata/Inventory/Objects.csv`;
- Beispielmanifeste gegen die zugeordneten JSON-Schemata;
- identische kanonische Coverage-Dateien;
- das Fehlen versionierter Laufzeitzustände, Medien, Secrets, Backups und
  Rohartefakte;
- Parser- und PSScriptAnalyzer-Verträge;
- Hostklassen- und Ausführungsmodusgrenzen;
- wiederholbaren Preflight und State Lock;
- `-WhatIf`, Idempotenz, fremde Owner, Wildcards und nicht registrierte
  Ressourcen als Cleanup-Negativfälle;
- den abgegrenzten Produktstatus ohne behauptete SQL-Server- oder
  Infrastruktur-Evidenz.

## Datenschutz- und Sicherheitsgrenze

Versionierte Dateien enthalten nur öffentliche Produktbezeichner sowie
synthetische oder logische Werte. Lokale Hostnamen, Benutzeridentitäten,
Endpunkte, IP-Adressen, Gerätebezeichnungen, Seriennummern, Pfade,
Kapazitätsmesswerte, Zugangsdaten und Rohresultate dürfen nicht übernommen
werden.

Die Konfiguration bindet lokale Ressourcen ausschließlich über logische
Referenzen. Geheimnisse werden nicht durch Beispieldateien modelliert.
Laufzeitevidenz bleibt unter den ignorierten Pfaden und ist kein
Repositoryartefakt.

Strukturierte Logs ersetzen sensitive Properties anhand ihres Schlüssels durch
`[REDACTED]`. Remote-Fehler werden ausschließlich als Reason Codes gespeichert;
Endpunkte und Fehlermeldungstexte werden nicht in veröffentlichbare
Zusammenfassungen übernommen.
