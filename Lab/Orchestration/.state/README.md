# Lokaler LAB-Laufzeitstatus

Dieses Verzeichnis ist der standardmäßige lokale State-Root des LAB-Orchestrators.
Für jeden Lauf wird ein Unterverzeichnis mit einer generierten `LabRunId` angelegt.
Darin können unter anderem folgende Laufzeitdateien entstehen:

- `run-state.json`
- `resource-registry.json`
- `events.jsonl`
- `run.lock`
- szenarioabhängige Arbeits- und Ergebnisdateien

Diese Inhalte sind ausschließlich lokaler Laufzeitstatus. Sie können Rechner-, Pfad-,
Container-, Netzwerk- oder Diagnosedaten enthalten und dürfen nicht versioniert werden.
Nur diese Dokumentation und die zugehörige `.gitignore` gehören in das Repository.
