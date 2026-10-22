# Foundation 1.25.0: Dokumentationspfade und semantische Übernahme

Stand: 22. Oktober 2026. Dieses Upgrade folgt auf die qualifizierte Integration
von OPS-005 mit PR #403 und eigenem Branch- und Worktree-Cleanup.

## Quelle, Featureumfang und Auswahl

Die kanonische Quelle ist [Foundation 1.25.0](https://github.com/gecompat/AI_Repository_Foundation/tree/9e1b9974de58ea775d40c7c6045cd5057ba8b30c)
am exakten Commit `9e1b9974de58ea775d40c7c6045cd5057ba8b30c`.
Die Version stammt aus dem Manifest dieses Commits; ein GitHub-Releaseobjekt
ist nicht veröffentlicht. Ausgang ist die installierte Version 1.24.0.
Die [maschinenlesbare Bewertung](Foundation_1_25_Upgrade_Assessment.json)
erfasst den vollständigen Featureunterschied: `human-documentation-paths`
wird genau einmal als `APPLY_DEFAULT` eingeordnet. Es gibt keine offene
Featureentscheidung und keinen festgestellten Required-Konflikt.

Die drei bisherigen Adapter und die beiden Capabilities
`artifact-registry-github` und `rule-context-cache` bleiben ausgewählt.
Neue ausführbare Capabilities, Scheduler, Modelle oder Laufzeitrechte werden
nicht aktiviert. Die projektgeführte Registry, ihre Workflowanpassung,
SQL-Verträge und bisherigen Kennungen bleiben erhalten. Die Root-Bridge
übernimmt den neuen Dokumentationsauftrag; die projektspezifischen Regeln
bleiben außerhalb des verwalteten Blocks bestehen.

## Dokumentationspfade und tatsächliche Prüfung

Die neue Regel verlangt verständliche vollständige Lesepfade, erkennbare
Verzeichniszwecke und einen ausdrücklich bezeichneten KI-Einstieg.
Verhaltens-, Konfigurations-, Schema-, Generator- und Pfadänderungen erhalten
auch ohne Markdownänderung eine Dokumentationswirkungsprüfung. Auswahl,
notwendige Folgeseiten und Abhängigkeiten werden lokal bestimmt. Geänderte
Abhängigkeiten entwerten betroffene Analysen; unveränderte verfügbare
Analyse wird unter aktueller Quellenbindung wiederverwendet.

Der Autor prüft folgende zentrale Pfade anhand der aktuellen Dateien:

| Leseraufgabe | Geprüfter Pfad und Ergebnis |
|---|---|
| Installation und erster Aufruf | Root-README, Installation beziehungsweise Gesamtdeployment, Startseite und Navigator erklären Voraussetzungen, begrenzte Aufrufe, Ergebnisse und Rechte. Historische Testnachweise werden von garantierten Grenzen getrennt. |
| Befund vertiefen | Startseite, Navigatorreferenz und Blocking-Runbook führen von einer Beobachtung zur Folgeanalyse und Gegenprobe. Fehlende Treffer, Partialität und Aussagegrenzen werden erläutert. |
| KI- und Maschinenquellen untersuchen | Der neue ausdrücklich benannte README-Link führt zu AGENTS, Projektregeln und Kennungsrichtlinie. Registry, v2-Schema und Prüfworkflow bleiben von dort erreichbar. Upgradebewertung und Installationsprovenienz sind getrennte Nachweise. |

Dies ist eine semantische Leseprüfung, keine neue Ausführung der dokumentierten
SQL-Aufrufe. Der zusätzliche README-Absatz verändert ausschließlich den
KI-Einstieg. Die Fehlerhilfe der Installationsanleitung wird an die vorhandene
informative Collationwarnung des Preflight angeglichen: kontrollierte Prüfung
der Zielkombination statt einer widersprüchlichen Abbruchanweisung; die
Garantiegrenze bleibt erhalten. Der Regelkontext verweist auf die aktuelle
Quellenauswahl statt einer veränderlichen Anzahl. Der vollständige geschützte
Präfix vor „Überblick“ einschließlich beider Lizenzabschnitte bleibt bytegleich;
die Lizenzdatei bleibt unverändert.

Die vorhandene interne Ablage trennt Planungs- und Entstehungsnachweise von
öffentlicher Anwenderdokumentation. Sie darf keine fachlich notwendige
Ist-Dokumentation ersetzen. Noch nicht behoben sind der mit Fehlerchronologien
vermischte öffentliche TestLab-Pfad, die umfangreiche Historie im aktuellen
Fortsetzungsdokument und der fehlende kurze Einstieg für die Metadatenablage.
Die [konkreten Folgeumfänge](../Quality/Next_Steps.md#dokumentationsaltlasten-und-wiederaufnahme)
haben jeweils Maintainerrolle und Trigger. Die Übernahme erklärt deshalb
keine vollständige Dokumentationskonformität. Breite Migrationen und
historische Umbenennungen sind nicht Teil dieses Upgrades.

## Semantische Erhaltung und Verarbeitungsaufwand

| Tatsächlicher Weg | Disposition und begrenzte Begründung |
|---|---|
| Regel- und Quellenauswahl | Die neue Dokumentationsregel und ihre semantischen Abhängigkeiten werden im bestehenden Regelkontext erfasst. Aktuelle Autorität und tatsächliche Quelldateien bleiben erforderlich; ein Hash erzeugt keine verlorene Analyse. Ein neuer persistenter Cache wird nicht verwendet. |
| Statische Testauswahl | Der vorhandene Dokumentationsworkflow wählt bei Root-README und Next Steps die vollständige statische Suite. Dieser konservative Fallback bleibt erhalten: Der engere Foundation-Scope deckt öffentliche README-/Navigatorgrenzen nicht ab; eine vollständige Abhängigkeitszuordnung ist nicht implementiert. Der breitere Abschluss läuft am stabilen Lieferstand und am erforderlichen Main-Stand, nicht nach jedem redaktionellen Zwischenschritt. |
| Selbsttests und doppelte Gates | Die geänderte Regelkontextauswahl verlangt ihre bestehenden Selbsttests. `SelfTestMode Changed` begrenzt weitere Selbsttests. Die Suite schließt den separat ausgeführten Datenschutzscan und Impact-Selector aus; identische Prüfungen werden nicht zusätzlich direkt wiederholt. |
| Funktionale Prüfung | Produkt-SQL, Installer und Runtimeinfrastruktur bleiben unverändert. Das Upgrade löst keine SQL-, Compatibility-Level-, Plattform- oder Labmatrix aus. FOUNDATION_INTEGRITY und semantische Dokumentationsprüfung ersetzen keine spätere fachliche Runtimeprüfung. |
| Externe Links | Neue Quellenlinks aktivieren die vorhandene Netzwerkprüfung. Die breite Auswahl bleibt als bestehendes Gate erhalten; transiente Warnungen werden mit ihrer Grenze berichtet. Linkerfolg wird nicht als Lesbarkeitsnachweis verwendet. |
| Logs und Modellkontext | Vorhandene Runner und lokal ausgewertete Findings werden verwendet. Rohlogs und Laufzeitdaten bleiben privat; Modelle erhalten betroffene Änderungen und notwendige Umgebung statt des Dokumentationskorpus oder vollständiger grüner Logs. Token- und Geldverbrauch sind nicht verlässlich gemessen. |
| Review und Wellenumfang | Ein Implementierer und ein unabhängiger Reviewer bearbeiten dieses eine Upgrade. Eine zweite Prüfung benötigt einen konkreten Befund. Mechanische Mengen-, Hash-, Manifest- und Bindungsnachweise bleiben lokal; ein Review des Reviews ist nicht vorgesehen. |
| Fortsetzung und Heartbeat | Der vorhandene 30-Minuten-Heartbeat enthält den menschlichen Folgeauftrag und bleibt bei unverändertem Zustand still. Er erweitert keine Grenzen. OPS-005 bleibt mit sieben Windows-Runs, neun Reviews sowie seinem PR-CI- und Main-Nachlauf abgeschlossen; das Upgrade startet diese Prüfungen nicht erneut. |

Datenschutz, garantierte Collationgrenzen, erforderliche unabhängige Reviews,
frische Head-Gates und Cleanup bleiben kompatible stärkere Projektregeln.
Sprache, Verzeichnisnamen und bestehende Capabilityauswahl bleiben
Projektentscheidungen. Die neue Dokumentationspflicht ergänzt diese Regeln;
sie verlangt weder ein zusätzliches Register noch einen neuen Validator,
Pflichtfelder pro Seite oder eine automatische Reviewkette.

## Validierung und offene Liefergates

Die offizielle vollständige Foundationprüfung meldet 85 Informationen,
keine Warnung und keinen Fehler. Der lokale Transferabgleich bestätigt mit
108 Assertions die Featuredeckung, Schemafelder, Auswahl, Provenienz und
den bytegleichen geschützten README-Präfix. Die 23 Regelkontext- und
14 Deployment-Selbsttests bestehen; die statischen Repositoryverträge
bestehen bis auf einen anschließend gezielt korrigierten README-Befund.
Die öffentliche Wortwahl verwendet jetzt „AI-Systeme“ und erfüllt damit
den bestehenden Navigatorvertrag sowie die ausdrücklich benannte
Foundation-Discovery. Die gezielte Navigatornachprüfung besteht;
Assertions und öffentliche Dokumentationsgrenzen bleiben unverändert.

Der Datenschutzscan besteht für 1173 versionierte Dateien ohne Befund,
die Stilprüfung für 784 ausgewählte Dateien. Die externe Linkprüfung
besteht bei 498 Referenzen, 355 eindeutigen Links und 295 Netzwerkzielen.
85 transiente Warnungen erlauben keine Aussage, dass jedes Netzwerkziel
erreichbar war. Unabhängiger semantischer Review und aktuelle Head- und
Main-Gates werden getrennt am Liefercommit im PR nachgewiesen.
SQL-/Lab-Läufe bleiben in dieser Welle `NOT_EXECUTED`, weil keine
zugehörigen ausführbaren Verträge geändert werden. Diese Ergebnisse
qualifizieren weder die gesamte Dokumentationsablage noch neue Laufzeitpfade.

<!-- artifact_uid: urn:uuid:01a1624c-dcca-759f-bf6a-6641b749903f; registration_state: DEFERRED -->
