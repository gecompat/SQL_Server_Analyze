# Metadaten untersuchen und pflegen

Diese Ablage enthält technische Inventare, maschinenlesbare Verträge,
Qualitätsnachweise und die Artefaktregistry des Projekts. Sie richtet sich an
Leser, die eine Schnittstelle nachschlagen, einen Prüfungsfehler untersuchen
oder eine Änderung an Quellen und Dokumentation gemeinsam pflegen müssen.
Zum Lesen und für die unten genannten statischen Prüfungen ist keine
SQL-Server-Verbindung erforderlich. Für die Nutzung des Frameworks führt die
[Dokumentationsübersicht](../Documentation/README.md) zu Installation und Analyse.

## Zweck und maßgebliche Quellen

| Bereich | Inhalt und fachlicher Einstieg |
|---|---|
| `Inventory/` | [Objects.csv](Inventory/Objects.csv) ordnet Objekte ihren kanonischen SQL-Dateien über `SourcePath` zu. [Parameters.csv](Inventory/Parameters.csv) beschreibt Signaturen, [ResultSets.csv](Inventory/ResultSets.csv) benannte Ergebnisse und native Exportschemas. Der [Ausgabevertrag](../Documentation/Architecture/Database_Console_Table_Contract.md) erklärt deren Bedeutung. Weitere Inventare ergänzen Quellen, Berechtigungen, Abhängigkeiten und Modulreife. |
| `Quality/` | [CI_Test_Policy.csv](Quality/CI_Test_Policy.csv) stellt die aktive [CI-Teststrategie](../Documentation/Quality/CI_Test_Strategy.md) maschinenlesbar dar; diese Strategie bestimmt den Testumfang. [Test_Matrix.csv](Quality/Test_Matrix.csv) und [Release_Gate_Evidence.csv](Quality/Release_Gate_Evidence.csv) enthalten historische, gebundene Ausführungsnachweise. Status- und Backlogdateien folgen dem [Implementierungsstatusmodell](../Documentation/Architecture/Implementation_Status_Model.md). |
| `Governance/` | [Artifact_Registry.json](Governance/Artifact_Registry.json) ist die Registration Authority für neue dauerhafte Referenzen. Der ausdrücklich benannte [Einstieg für AI-Systeme](../AGENTS.md) führt zur projektspezifischen Kennungsrichtlinie mit Vergabe, Historie und dem Standard `DEFERRED`; das zugeordnete [v2-Schema](../.ai/foundation/schemas/artifact-registry-v2.schema.json) beschreibt das Format. |
| `Packages/` | Paketbezogene Abhängigkeitslisten ergänzen die Installationsverträge. [SSIS_001_Dependencies.csv](Packages/SSIS_001_Dependencies.csv) gehört zum [öffentlichen SSIS-Vertrag](../Documentation/Architecture/SSIS_001_Phase0_Public_Contract.md). Ein Eintrag belegt weder die Installation noch einen erfolgreichen Paketlauf. |

Die CSV- und JSON-Dateien haben unterschiedliche Aufgaben; sie bilden kein
einheitliches Metadatenschema. Ein ausdrücklich zugeordneter Vertrag oder ein
Schema gilt für die betreffende Datei. Die öffentliche Ausgabe, technische
Bestandsdaten und Planungsstatus dürfen nicht gegeneinander ausgetauscht werden.

## Von einem Eintrag zur Prüfung

Für eine Procedure führt der Weg von `Objects.csv` und ihrem `SourcePath` zur
aktuellen SQL-Definition. Vergleichen Sie anschließend die Signatur mit
`Parameters.csv` und die benannten Ergebnisse mit `ResultSets.csv`.
Die [Procedure-Referenz](../Documentation/Reference/Procedure_Reference.md) und
die [Resultset-Konventionen](../Documentation/Reference/Resultset_Conventions.md)
erklären Aufruf und Interpretation. Bei einer Abweichung müssen Quelle,
betroffenes Inventar und fachliche Beschreibung gemeinsam geprüft werden.

Die vorhandenen Prüfer werden vom Repositoryroot aufgerufen. Python 3 und
PowerShell 7 werden für diese Beispiele benötigt:

```powershell
pwsh -NoLogo -NoProfile -File Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
python Code/Tests/Static/975_Validate_Roadmap_Status.py --repository-root .
python .ai/foundation/artifact_registry_github/registry_semantic.py validate --registry Metadata/Governance/Artifact_Registry.json
```

Der erste Aufruf prüft Dokumentations- und Inventarbeziehungen; der zweite
prüft Implementierungsstatus, Zukunftsplanung und Modulreife. Der dritte
validiert die Registrystruktur und Kennungsbeziehungen. Der zugehörige
[PR-Workflow](../.github/workflows/artifact-registry-integrity.yml) ergänzt
Kollisions- und Mergeprüfungen. Lokale Strukturprüfung ersetzt diese Gates
nicht. Für einzelne öffentliche JSON-Verträge sind zusätzlich deren fachliche
Beschreibung und zugeordneter Prüfer unter
[`Code/Tests/Static/`](../Code/Tests/Static/) heranzuziehen. Der erforderliche
Prüfumfang richtet sich nach der CI-Teststrategie.

## Ableitung, Ergebnisse und Fehlerbehandlung

Metadaten und Dokumentation werden bei einer fachlichen Änderung gemeinsam
mit den kanonischen Einzelquellen gepflegt. Generierte Installer entstehen
separat aus diesen Quellen und ihren Include-Listen; die
[Installationsanleitung](../Documentation/Reference/Installation.md) beschreibt
den Buildweg. Eine Korrektur ausschließlich in einer generierten SQL-Datei
aktualisiert weder die Quelle noch deren Metadatenvertrag.

Ein erfolgreicher statischer Prüfer bestätigt seinen jeweiligen aktuellen
Repositoryvertrag. Er führt keine Analyse aus und erzeugt keine fehlende
Laufzeitevidenz. Bei einem Fehler prüfen Sie zuerst den genannten Pfad und
Vertrag sowie den gebundenen Quellstand. Passen Sie einen erwarteten Status
oder ein Schema nicht allein an, um die Prüfung erfolgreich zu machen.

Für Laufzeitaussagen sind unter anderem Commit, Engine, Plattform,
Compatibility Level, Collation, ausgeführter Umfang und Ergebnis gemeinsam
zu betrachten. `NOT_EXECUTED` ist kein bestandener Test; ein historischer
PASS qualifiziert keine neuere Änderung. Die
[Nachweisübersicht](../Documentation/Quality/Test_Matrix.md) erklärt diese
Grenzen. Reale Umgebungsdaten, Rohlogs und Secrets gehören nicht in diese
Ablage; für Fehlerberichte gilt der [Beitragsweg](../CONTRIBUTING.md).

<!-- artifact_uid: urn:uuid:01a162b2-6185-7394-856b-9561c699a3cf; registration_state: DEFERRED -->
