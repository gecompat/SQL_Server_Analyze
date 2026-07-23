# LAB-001 – Reproducible Diagnostic Lab

LAB-001 stellt die Verträge für ein ausschließlich synthetisches und
hardwareadaptives SQL-Server-Diagnoselabor bereit. Der aktuelle Stand umfasst
Welle 0: Schemata, Beispielmanifeste, Ressourcenprofile, Szenariokatalog,
Procedure-Coverage sowie statische Security-, Cleanup- und Privacy-Prüfungen.

Der Produktstatus bleibt `RESEARCHED_NOT_IMPLEMENTED`. Welle 0 enthält keine
ausführbare Host-Erkennung, erstellt keine Container oder virtuellen Maschinen
und führt keine SQL-Server-Workload aus. `Preflight` und der Orchestrator-Core
gehören zu Welle 1.

## Verzeichnisvertrag

| Pfad | Inhalt |
|---|---|
| `Config` | Generische Beispielkonfigurationen und konservative Ressourcenprofile. |
| `Contracts` | JSON-Schemata für Konfiguration, Hostfähigkeiten, Topologien, Szenarien, Finding-Erwartungen und veröffentlichbare Evidenz. |
| `Scenarios/Catalog` | Maschinenlesbarer Szenariokatalog und Procedure-zu-Szenario-Coverage. |
| `Validation` | Statische Vertragsprüfung ohne Zugriff auf SQL Server, Hyper-V oder eine Container-Runtime. |
| `.artifacts`, `.cache`, `.secrets`, `.state` | Ausschließlich lokale, ignorierte Laufzeitpfade. |

Die geplante vollständige Verzeichnisstruktur ist im
[Architekturplan](../Documentation/Architecture/Reproducible_Diagnostic_Lab_Plan.md)
festgelegt. Verzeichnisse späterer Wellen werden erst mit einem fachlich
nutzbaren Artefakt versioniert; leere Platzhalter gelten nicht als
Implementierung.

## Statische Validierung

Die repositoryunabhängige Prüfung läuft mit Python:

```text
python3 Code/Tests/Static/988_Validate_LAB001_Wave0_Contracts.py --repository-root .
```

Auf Systemen mit PowerShell 7 kann zusätzlich die JSON-Schema-Prüfung ausgeführt
werden:

```text
pwsh -NoLogo -NoProfile -File Lab/Validation/Invoke-LabValidation.ps1
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
- den unveränderten Produktstatus ohne behauptete Runtime-Evidenz.

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

