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

### Folgeassessment: autonome Entwicklungsplanung vom 25. Oktober 2026

Der neue Gesamtauftrag verwendet die vorhandenen Selektoren und Gates. Die
Änderungen an Next Steps und der aktuellen Entwicklungsplanung aktivieren
weiterhin die vollständige statische Suite im Dokumentationsworkflow. Der
konservative Fallback bleibt wegen der nicht vollständig zugeordneten
Abhängigkeiten erhalten; lokal wird er erst am stabilen Lieferstand ausgeführt.
`SelfTestMode Changed` vermeidet unveränderte Werkzeugselbsttests. Der separate
Datenschutzscan und erforderliche Remotechecks bleiben verbindlich. Eine reine
Planungsänderung startet keine SQL-Instanz und keine Labmatrix.

Je kohärentem Schritt bleiben ein Implementierer und höchstens ein unabhängiger
Reviewer mit konkretem Befundfolgecheck vorgesehen. Logs werden lokal auf
Fehler, Mengen und Bindungen eingegrenzt; grüne Rohlogs lösen keine Modellarbeit
aus. Die neue stündliche Leerlauferkennung gilt nur für den Gesamtauftrag und
startet die separat laufenden SSIS-Wellen nicht erneut. Unveränderte Blocker
bleiben still, gemeinsame Grenzen werden nicht durch Timer zurückgesetzt.
Kosten- und Tokenmessung sind unbekannt; die
[Entwicklungsplanung](../Quality/Development_Waves_2026-10.md) begrenzt stattdessen
den fachlichen Umfang und die Zahl eigener PR-Schritte. Dieses Assessment
ändert weder Selektorcode noch vorgeschriebene Review-, Sicherheits- oder
Laufzeitgates. Eine Effizienzsteigerung in Tokens oder Laufzeit wird nicht
behauptet.

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


## Snapshot-Targetkontext und Verarbeitungsaufwand

Die Wait-Erweiterung konkretisiert den bereits separat installierten
Snapshot-Targetweg. Der allgemeine USE-Satz in Projektkontext und
Architekturentscheidung widersprach dem vorhandenen kanonischen Targetinstaller
und dem öffentlichen Paketvertrag. Dieser TARGET_INTERNAL_CONFLICT wird
eng auf dessen ausdrücklich eingebundene Targetquellen aufgelöst. Das erste
Targetskript prüft weiterhin tatsächliche Datenbankidentität, ONLINE-/
Schreibstatus und den Ausschluss von Systemdatenbanken. Gewöhnliche Framework-
quellen behalten ihren USE-Header; Source-Datenbankauswahl, Privacy und
Berechtigung werden nicht erweitert. Foundationdateien und installierte
Provenienz bleiben unverändert; diese Nachführung ist kein Foundationupgrade.

Die Erweiterung nutzt vorhandene statische, Snapshot-Installer- und funktionale
Selektoren. Lokal ist am kohärenten Stand eine vollständige statische Suite
mit SelfTestMode Changed vorgesehen; danach werden ausschließlich geänderte
Inputs oder fehlgeschlagene betroffene Gates nachgeprüft. Der konservative
Fallback für nicht vollständig zugeordnete Abhängigkeiten bleibt erhalten.
Der geänderte Installer verlangt das volle SQL2025-Gate und die direkten
Snapshotverträge. Die vorgeschaltete Schemawelle prüft nativ SQL2019 für die ältere
Metadaten-/CHECK-Kanonisierung; der spätere Collector prüft zusätzlich seine
Counter-/Berechtigungsgrenze. Eine zusätzliche pauschale Drei-Versionen-
Matrix ist nicht vorgesehen. Tatsächliche DBCC-Resetabnahme bleibt eine
getrennte eigene isolierte Laboperation mit ausdrücklichem Opt-in und wird
nicht in den allgemein ausführbaren SQL-Runner aufgenommen.

Es arbeiten ein Implementierer und ein unabhängiger Reviewer. Vorvertrag
und Produkt besitzen verschiedene Abnahmefragen; Folgechecks betreffen nur
konkrete geänderte Befunde. Ganze grüne Logs und Reviewberichte lösen keine
weiteren Modelle aus. Der vorhandene gemeinsame Rahmen von 40 PR-Schritten
und sein Checkpoint bei 30 bleiben unverändert. Kosten-/Tokenmessung ist
unbekannt. Die tatsächliche Gateausführung und verbleibende Evidenz werden
am Lieferstand nachgeführt; dieses Assessment behauptet noch keine fertige
Runtime- oder Effizienzqualifikation des neuen Collectors.


Für die Schema-2-Vorbereitung wird der direkte Target-Prüfblock aus demselben
kanonischen Tabellenmodell wie die Gesamtdeploymentprüfung abgeleitet. Der
Builder prüft den markierten erzeugten Bereich deterministisch und entfernt
nur dessen read-only Duplikat aus dem bereits vollständig geprüften Gesamt-
deploymentbatch. Es gibt keinen Runtime-Skip-Schalter. Unbekannte Zustände,
Schemaabweichungen und Sicherheitsgates bleiben fail-closed. Die begrenzte
Transformation erhält negative Parser- und native Zustandstests; eine pauschale
zweite vollständige Vorprüfung am gleichen Binding wird nicht hinzugefügt.

Dieser Änderungsschritt liefert ausschließlich den Vorvertrag und die enge
Kontextausnahme. Er ändert keinen ausführbaren Installer oder Workflow und
benötigt deshalb keine SQL-Engine. Die oben benannten Produktgates gelten
für die folgende Implementierung. Die direkte Route muss vollständigen
Preflight und Migration in derselben Transaktion binden. Der zunächst
vorgeschlagene Daten-S-Lock belegt keinen Zwischenfehler und wurde durch
die Anforderung einer separat nativ bestätigten Sch-S-only-Probe ersetzt.
Ihre Ausführung und die eigentliche Migrationsabnahme sind noch offen.

Der unabhängige Vertragsreview hat außerdem die Standalone-Batchgrenze
benannt: Entferntes ON ERROR EXIT darf einen abgewiesenen Preflight nicht
von späteren CREATE-OR-ALTER-Quellen entkoppeln. Der folgende Produktdiff
muss einen gemeinsamen abbrechenden Rahmen und einen negativen Erhaltungs-
nachweis für diesen konkreten Weg liefern. Bestehende eigene Caller-
transaktionen werden vor Veränderung der Transaktionsoptionen abgelehnt.


### Schema-2-Implementierung und begrenzte native Prüfung

Die privilegierte Targetvorprüfung wird aus demselben nativen Referenzmodell
wie das Gesamtdeployment erzeugt. Der Metadatenvalidator prüft diesen einen
markierten Block auf exakte Synchronität, bevor er ihn von den allgemeinen
Analyse-NOLOCK-Regeln ausnimmt. Außerhalb dieses Blocks und in sämtlichen
Analysepfaden bleiben diese Regeln erhalten. CONTROL DATABASE und VIEW ANY
DEFINITION sind ausdrückliche Installationsvoraussetzungen.

Die native Strukturprüfung darf committed Katalogmetadaten mit maximal
10000 ms Sperrwartezeit je Statement lesen. Sie hält die geprüften Tabellen
bis zum Abschluss derselben Transaktion; die anschließende eigene DDL
verwendet weiterhin LOCK_TIMEOUT 0. Ein erster negativer Lauf mit Wartezeit 0
brach bereits vor der Migration mit 1222 ab; eine Sperrursache ist nicht
belegt. Dieser begrenzte Installerpfad verwendet deshalb die bestehende
Wartegrenze des Gesamtdeployments, ohne eine globale Lockerung für Analysen.
Die Fälle müssen weiterhin den vorgesehenen Strukturkonflikt und unveränderte
Daten nachweisen; ein beliebiger Timeout wird nicht als passende Ablehnung
gewertet.

Der vorhandene Deploymentregressionstest erhält drei tatsächliche Routen,
je ein gefülltes V1-Upgrade und eine Wiederholung sowie 19 gezielte negative
Zustände. Die bestehenden Binärvergleiche und gemeinsamen Targetfixtures
werden wiederverwendet. Lokale Befundkorrekturen verwenden danach den
fokussierten Snapshotumfang; der vollständige SQL2025-Abschluss bleibt für
den stabilen Lieferstand erforderlich. Die gemeinsame native Source-DDL wird
im erzeugten Test einmal als eigener Input gespeichert, statt große identische
Installertexte für jeden Negativfall erneut einzubetten. Der gesonderte
Sch-S-Fall benötigt ausschließlich eine eigene Labinstanz und prüft die
unveränderte kanonische SUT einschließlich erstem DDL-Abschluss, Rollback und
Recovery. Ausgeführt und qualifiziert wird nur der später tatsächlich belegte
Umfang; diese Beschreibung ist keine Erfolgsbehauptung.


Der Produktreview bleibt auf einen Reviewer und einen gebündelten
Korrekturpass begrenzt. Die erforderlichen Gegenfälle betreffen frühe
Versionssperrung, Standalone-Kompilationsoptionen und Erhaltung einer
abgelehnten Callertransaktion. Die vollständige lokale Suite mit 74
Validatoren besteht am ersten Kandidaten; nach dessen Korrektur werden nur
die tatsächlich betroffenen Installer-, Grammar-, Privacy-, Stil- und
Regelkontextprüfungen wiederholt. Die regulären erforderlichen Head-Checks
und die native Risikoprüfung bleiben am Liefercommit bestehen.


### Ausdrückliche native Snapshot-Risikoabnahme

Zwei native Vollpässe standen späteren Legacy-TABLE-Timeouts gegenüber.
Der aktuelle Volllauf und sein einmaliger begrenzter Wiederlauf scheiterten
vor Snapshot in Legacy202 an verschiedenen lokalen TABLE-Resultsets;
die isolierte unveränderte 202-Abnahme auf SQL2019 bestand. Eine Sperrursache
ist nicht belegt. Zusätzlich scheiterte eine SQL2025-Vollprüfung im bestehenden
Standalone-Plan-Test mit 1222. Diese Ergebnisse bleiben FAILED beziehungsweise
UNKNOWN und werden nicht zu Infrastrukturfehlern oder Erfolgen umklassifiziert.

Die kanonische Strategie und die maschinenlesbare Policy verlangen beim
zusätzlichen nativen Versionsrisiko betroffene Tests mit Smoke, während das
volle primäre SQL2025-Gate und der Release-Candidate-Umfang erhalten bleiben.
Der unabhängige Scopecheck bestätigt daher einen ausdrücklich ausgewählten
SNAPSHOT_SCHEMA_RISK-Modus für genau eine Engine. FULL_RELEASE bleibt Default.
Die vorbereitete Paketinstallation, Native-Metadaten-/CHECK-Migrationen,
Erhaltung, Caller- und gezielte Berechtigungsfälle sowie Snapshot-/Concurrency-
Verträge und Cleanup bleiben Pflicht. Das Paket wird am tatsächlichen Commit
und Digest gebunden; ein fehlender Vertrag oder abweichender Scope verhindert
Aggregaterfolg. Der neue Modus weist den nicht ausgeführten Core-Vollumfang
aus und erhält ein eigenes Artefaktlabel. Die alte Matrix kann daraus keinen
Full-Release-Erfolg ableiten.

Snapshot ruft PerformanceCounters und seine öffentlichen Ausgabehelper auf;
die installierte Legacy-SSIS-Analyse wird nicht fachlich ausgeführt. Der
unveränderte gemeinsame TABLE-Helper wird durch den erforderlichen Snapshot-
TABLE-Consumer geprüft. Keine Legacy-Implementierung wird in dieser Welle
geändert; die drei Sourceheaderkorrekturen sind als identische SQL-Tokenströme
belegt. Die isolierte Core-/Planzuverlässigkeit bleibt als konkreter späterer
Qualitätsscope sichtbar. Eine unerfüllte Snapshot- oder primäre SQL2025-
Prüfung wird durch den Modus nicht übersprungen.

Der Modus wird vor seiner ersten Ausführung in Strategie, Workflow,
Scope-/Evidenzvalidator und dieser Bewertung festgelegt. Ein vorhandener
Reviewer prüft nur die Auswahl-/Aggregationsgrenze und die neuen gezielten
Rechtefälle. Die lokalen Scope- und Evidenztests benötigen keine SQL-Instanz;
der zusätzliche native Lauf führt vier ausdrücklich benannte Vertragsgruppen
aus. Ganze grüne Logs und unveränderte Blocker erzeugen keine Folgearbeit.
Notwendige Required Checks am neuen Lieferhead laufen weiterhin regulär.


Die erste tatsächliche Risikoqualifizierung am Liefercommit `459c19ae`
besteht als Lauf 40211873213 mit den vier Vertragsgruppen FRAMEWORK_SMOKE,
SNAPSHOT_SCHEMA_MIGRATION_AND_PERMISSION, SNAPSHOT_BASELINE_195 und
SNAPSHOT_CONCURRENCY_196_197. Die gezielten Rechtefälle gehören zur zweiten
Gruppe. Das vollständige SQL2025-Head-Gate 40211876502 und der getrennte
Main-Nachlauf 40212817038 bestehen ebenfalls. Zusätzliche Wiederholungen
bestandener lokaler Prüfungen oder eine erneute allgemeine native Matrix
waren für diesen Risikoscope nicht erforderlich; frühere Vollrunfehler
werden dadurch nicht geschlossen.


### Retentionspatch vor Wait-Aktivierung

Der neu konkretisierte Retentionsschutz ändert den gemeinsamen Purge und die
bekannte Target-Patchversion. Deshalb läuft das unveränderte vollständige
SQL2025-Gate einschließlich der erweiterten tatsächlichen 195-Fixture; die
drei realen Installationswege prüfen zusätzlich das gefüllte 1.1.0-Target.
Der Versionsvergleich führt keine neue native API oder Engineverzweigung ein;
eine weitere ältere Versionsmatrix ist für diesen Patch nicht ausgewählt.
Die frühere native Risikoabnahme wird nicht als Patchabnahme wiederverwendet.
Ein Implementierer und der vorhandene unabhängige Reviewer prüfen diese
abgegrenzte Welle. Lokale Gegenproben und Required Head-/Main-Checks bleiben
getrennte Nachweise. Die vollständige gemeinsame Qualitäts- und Privacy-CI
bleibt erhalten; unveränderte erfolgreiche Einzelprüfungen werden lokal
nicht ohne neuen Auslöser wiederholt.


Die lokale Retentionsprüfung und die native Gegenprobe mit ursprünglichem
Helper sind getrennte notwendige Oracles. Zwei konkrete Upgradeoraclebefunde
erforderten gezielte Folgechecks desselben Reviewers und geänderte native
Inputs. Ein Zwischenlauf ohne den echten alten Helper qualifiziert kein
vollständiges Upgrade; der parserbereinigte direkte Testpfad scheiterte mit
137 und nachgewiesenem Cleanup. Diese Korrekturversuche bleiben verbraucht.
Es beginnt keine allgemeine neue Reviewkette und keine zusätzliche Engine.


### Internes Wait-Target vor öffentlicher Aktivierung

Die Targetwelle ergänzt Persistenz, Seeds, Abschlussmarker und die internen
Aufrufverträge. Ein Implementierer und derselbe unabhängige Reviewer prüfen
den Algorithmus und anschließend die getrennten Installations-/Legacyrisiken.
Gezielte Folgeprüfungen schließen tatsächliche Befunde; es beginnt keine
weitere Reviewkette. Die statische Gesamtsuite und das vollständige SQL2025-
Head-/Main-Gate bleiben erforderlich. Die zunächst nicht ausgewählte zusätzliche Engineprüfung wird durch den
nativ beobachteten Unterschied der gespeicherten Modulform konkret:
SQL2019 qualifiziert deshalb zusätzlich den begrenzten Snapshot-/Migrations-
und Berechtigungsscope. Core-Vollrelease und allgemeine native Rechtematrix
bleiben dort NOT_EXECUTED. SQL2025 behält sein vollständiges Gate. Eine
zusätzliche SQL2022-Matrix ist für dieses konkrete Risiko nicht ausgewählt;
die spätere native DMV-Aktivierung erhält eine eigene Auswahl.

Das lokal nach den konkreten Testinputbefunden neu begrenzte Budget umfasst
höchstens sechzehn native Entwicklungsversuche für
Compiler-, Mengen-, Kontext-, Caller- und reale Upgradeoracles. Fehlversuche
bleiben verbraucht. Die erste Quellenabnahme qualifiziert weder den
vollständigen Collector noch einen nativen DMV-Read. Eine leere Rohprojektion
und zwei konkrete Integrationsbefunde begründen korrigierte Testinputs.
Ein fehlerhafter Testdatenbankname und eine Klammer im Upgradeoracle sind
Testinputfehler und kein Produktnachweis. Der weitere native Befund zur
CRLF-Normalisierung betrifft den Erwartungsliteralvergleich; das Oracle
verwendet jetzt denselben kanonischen SHA256 wie der Installer. Der
Callerzustand wird gegen die tatsächlich gemessene Ausgangslage verglichen.
Die zusätzliche native Definitiondiagnose belegt außerdem, dass SQL Server
CREATE OR ALTER als CREATE mit erhaltenen Zwischenräumen speichert.
Generator und Upgradeoracle verwenden gemeinsam diese exakt bestätigte
Darstellung einschließlich Kommentarheader und unverändertem Modulrumpf.
Diese konkreten Befunde begründen vier zusätzliche Versuche innerhalb
des unveränderten gemeinsamen Wellenumfangs. Jeder eigene Lauf benötigt
belegtes Cleanup. Ganze grüne Logs werden nicht an Reviewer weitergereicht.
Messwerte für Token und Kosten liegen nicht vor; der gemeinsame endliche
PR-Umfang und ein Reviewer bleiben die Verbrauchsgrenzen.


Der erste vollständige SQL2025-Headlauf 40230389338 bestätigt die gesamte
native Deploymentregression, scheitert danach jedoch in Legacytest 202,
C016/Ordinal17, mit 51010/1222 beim TARGET_SCHEMA_ADAPT. Die vorhandene
Diagnostik meldet BLOCKER_NOT_CAPTURED; zehn vollständige Stichproben zeigen
keinen erfassten wartenden Request oder Blockierer. Die Ursache bleibt
UNKNOWN. Nach dieser begrenzten Auswertung ist genau ein Wiederlauf der
fehlgeschlagenen Jobs auf einer frisch erstellten CI-Instanz ausgewählt.
Es gibt keine Änderung am gemeinsamen TABLE-Helper oder am Testscope.
Der abschließende lokale Upgradeversuch scheiterte zuvor mit 547 an der
Anordnung eines ungültigen Case-Negativfalls unter dem vorhandenen CHECK.
Die korrigierte Anordnung und unveränderte Erhaltungsprüfung bestehen
bereits in der vollständigen nativen Deploymentregression der CI.

### Verarbeitungsaufwand der öffentlichen Waitaktivierung

Die Targetpatch-/Generatoränderung löst das vollständige SQL2025-Gate aus.
Die zusätzlichen nativen SQL2019-Prüfungen bleiben auf Snapshotmigration,
Quellrechte und Paketvertrag begrenzt; SQL2022 erhält ohne eigenes Risiko
keinen zusätzlichen Lauf. Die unveränderte Backendsemantik wird nicht erneut
breit reviewed. Derselbe unabhängige Reviewer prüft nur die neue öffentliche
Orchestrierung, Transaktionsgrenze, Fixtureoracles und betroffenen Lesepfade.
Konkrete Befunde werden gebündelt geschlossen; es gibt keinen Review des Reviews.

Die vorige Welle erzeugte durch Ready-for-review einen zweiten vollständigen
Lauf desselben Heads. Nach Auswahl des aktuellen Ready-Laufs wurde ausschließlich
der überholte Duplikatlauf beendet. Ein vollständiger aktueller Head- und der
getrennte Main-Nachlauf blieben erforderlich und bestehen. Ein bereits lokal
geprüfter folgender Lieferkandidat wird regulär ohne zusätzliche Draft-/Ready-
Umschaltung veröffentlicht, sofern kein konkreter Draftgrund vorliegt.

Die lokale Entwicklung besitzt zwölf eigene native Versuche einschließlich
Fehlversuchen und Recoveryproben. Der gemeinsame private Wellenzähler bleibt
maßgeblich; ein Timer setzt ihn nicht zurück. Ganze grüne Logs werden nicht
an das Modell oder den Reviewer weitergereicht. Token- und Kostenmessung
bleiben UNKNOWN.

### Verarbeitungsaufwand der AgentHistory-CI-Erweiterung

Der aktuelle Kandidat führt die bisher nur im eigenen Lab ausgeführte
AgentHistory-Fixture einmal im bereits vorhandenen SQL2025-CI-Container aus.
Der Trigger ist die konkrete Fixture oder die eigene Verkabelung des
[funktionalen Workflows](../../../.github/workflows/ci-functional-impact.yml).
Der [kanonische Selector](../../../Code/Tests/Static/925_Select_CI_Impact.py)
setzt dafür `ops008_agent_history`. Eine reine Fixtureänderung wählt den
vorhandenen OPS-008-Vertrag 122 und den zusätzlichen Fixturelauf; Änderungen
am zentralen Workflow beziehungsweise Selector behalten das vollständige
SQL2025-Gate gemäß der kanonischen Strategie. Weitere native Engines oder
Compatibility Levels werden durch diesen neuen Pfad nicht angefordert.

Der Zusatzlauf erfolgt einmal nach dem bestehenden Installations- und
Compatibility-Level-Pfad auf dessen abschließender CL170-Datenbank und vor
der danach getrennten Standaloneprüfung. Deren unveränderter Neuaufbau und
Vertrag bleiben Pflicht. Der Zusatzlauf erzeugt weder einen weiteren Container
noch eine zweite Installation. Die feste
Datenbank-, Engine- und CL-Bindung, der Wegwerfmarker sowie die bestehenden
Leerstands-, Quell-, Caller- und Rollbackprüfungen bleiben Pflicht. Der
bestehende Cleanup entfernt den eigenen CI-Container auch bei Fehlern.
Die vollständigen zusätzlichen SQL-Logs bleiben ausschließlich temporär auf
dem Runner; ausgegeben werden feste Fehlerstufen und Fehlercodes mit
synthetischer Fallnummer sowie gegebenenfalls geschlossene Mengenkategorien,
Schlüsselstrukturstatus und eine validierte 17-Bit-Feldmaske. Zeilenwerte
bleiben ausgeschlossen. Der feste Erfolgsmarker folgt erst nach erfolgreichem
SQLCMD-Abschluss.

Die Selector-Selbsttests prüfen die positive Auswahl, einen unbeteiligten
Fixturepfad und den Workflow-Selbsttrigger. Sie werden lokal fokussiert geprüft;
die übrige statische Suite kann diesen unveränderten Selbsttest auslassen.
Ein Implementierer bearbeitet Fixture und Verkabelung. Derselbe unabhängige
Reviewer prüft jeweils nur neue fachliche Deltas und konkrete native Befunde.
Es gibt keinen Review des Reviews. Zwei lokale fehlgeschlagene Prüfungen
bleiben mit erfolgreichem Cleanup erhalten; ihre Ergebnisse ersetzen keinen
abschließenden nativen CI-Nachweis. Dieser Nachweis und die regulären
Head-/Main-Gates stehen beim aktuellen Kandidaten noch aus. Verlässliche
Token- oder Kostenmessungen liegen nicht vor.
