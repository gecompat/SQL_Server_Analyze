# Fehlerberichte und Pull Requests

Externe Fehlerberichte und Pull Requests sind für dieses Projekt vorgesehen.
Ein Beitrag beschreibt ein konkretes Problem und den überprüfbaren Nutzen
seiner Änderung. Die Aufnahme erfolgt nach Review im Repository; daraus
entsteht keine Zusage einer Bearbeitungsfrist oder einer Produktfreigabe.

## Fehler nachvollziehbar melden

Verwenden Sie die [GitHub-Issues](https://github.com/gecompat/SQL_Server_Analyze/issues).
Nennen Sie den Quellcommit, die betroffene Procedure oder Dokumentation,
das erwartete und beobachtete Verhalten sowie ein minimales synthetisches
Beispiel. Bei Laufzeitfehlern gehören Engine/Build, Plattform, Compatibility
Level, relevante Collations, Berechtigungsprofil und Ausgabeart zum
Prüfumfang. Nicht erhobene Angaben bleiben ausdrücklich unbekannt.

Repository und Issues dürfen keine realen Personen-, Firmen-, Kunden-,
Betriebs- oder Umgebungsinformationen, Zugangsdaten oder proprietären
Strukturen enthalten. Verwenden Sie ausschließlich generische synthetische
Werte. SQL-Texte, Input Buffer, Pläne und Diagnoseausgaben können sensible
Inhalte enthalten; übernehmen Sie keine ungeprüften Logs oder Screenshots.
Die [Datenschutzerklärung zu Laufzeitausgaben](Documentation/Architecture/Runtime_Data_Privacy.md)
erläutert die Trennung zwischen vollständiger Diagnose und zulässigen
Repositoryartefakten.

## Eine Änderung zur Prüfung vorlegen

Lesen Sie vor der Bearbeitung [AGENTS.md](AGENTS.md), die dort entdeckbaren
Regeln für den betroffenen Umfang. Dokumentationsänderungen
folgen dem [Schreibstil](Documentation/Quality/Documentation_Writing_Style.md).

Bearbeiten Sie die kanonische Quelle. Generierte Installer, Inventare und
Referenzen werden nur aktualisiert, wenn die Änderung deren Vertrag betrifft.
Beschreiben Sie öffentliche Signaturen, Ausgabe-, Status-, Berechtigungs-
oder Kostenänderungen ausdrücklich. Breite Umbauten benötigen einen
fachlichen Anlass und gehören nicht als Nebenänderung in einen Fehlerfix.

Die [CI-Teststrategie](Documentation/Quality/CI_Test_Strategy.md) bestimmt
funktionale Tests nach dem Modell 1+0+N. Eine Dokumentationsänderung verlangt
keine zusätzliche native SQL-Engine. Führen Sie die betroffenen statischen
Prüfungen aus; für Änderungen an gemeinsamen statischen Verträgen steht
folgender lokaler Einstieg zur Verfügung:

```powershell
pwsh -NoLogo -NoProfile -File ./Code/Tests/Static/Invoke-StaticContractSuite.ps1
python Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --self-test
python Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root .
```

Verwenden Sie für SQL-Tests ausschließlich autorisierte isolierte Ressourcen
mit synthetischen Daten. Ein geplanter Test bleibt `NOT_EXECUTED`; ein
Compatibility-Level-Lauf ersetzt keinen Nachweis einer nativen Engine.
Dokumentieren Sie ausgeführte Dateien, Quellbezug, Umgebung, Ergebnis und
Grenzen. Vollständige Laufzeitausgaben bleiben außerhalb der Lieferung.

Eröffnen Sie einen [Pull Request](https://github.com/gecompat/SQL_Server_Analyze/pulls)
aus einem eigenen Branch gegen `main`. Die Beschreibung nennt das Problem,
die resultierende Änderung, tatsächlich ausgeführte Prüfungen und offene
Punkte. Ein Draft eignet sich für noch unvollständige Beiträge. Berücksichtigen
Sie Reviewfeedback und die erforderlichen Repositorychecks vor der Aufnahme.

## Rechte und Lizenz

Lesen Sie [LICENSE.md](LICENSE.md) vor Nutzung und Weitergabe. Sie enthält
eine eigene Lizenz und bezeichnet das Projekt ausdrücklich nicht als Open
Source. Der Lizenztext und der geschützte Lizenzblock der Root-README
werden durch einen gewöhnlichen Beitrag nicht geändert.

Reichen Sie nur Inhalte ein, für die Sie die notwendigen Rechte besitzen.
Diese Anleitung führt keine neue Beitragslizenz und keine zusätzliche
Rechteübertragung ein. Wenn die Aufnahme fremder Inhalte besondere
Rechtebedingungen benötigt, sind diese vor der Integration ausdrücklich
zu klären.

<!-- artifact_uid: urn:uuid:01a1183e-8401-74f2-9ffd-a1d3a5832297; registration_state: DEFERRED -->
