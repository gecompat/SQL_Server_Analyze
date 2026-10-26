# Priorisierte Entwicklungswellen vom 25. Oktober 2026

**Status:** aktiver Entwicklungsauftrag.
**Artefakt-UID:** `urn:uuid:01a1715c-d9ba-770c-9e71-a8a4e9f45e38`.
**Registrierung:** `DEFERRED`; die Rangnummern sind veränderbare Planung und
keine neuen Arbeitselementkennungen.

## Auftrag und maßgebliche Quellen

Der Benutzer hat diese Priorisierung am 25. Oktober 2026 zur autonomen
Umsetzung übernommen. Konsistente Entwicklungswellen werden nach unabhängigem
Review und bestandenen erforderlichen Tests regulär über Pull Requests nach
`origin/main` integriert. Eine Planungszeile ist kein Implementierungsnachweis.
Produktstatus und offene Evidenz bleiben in
[Implementation_Status.csv](../../../Metadata/Quality/Implementation_Status.csv)
und den zugehörigen Fachverträgen maßgeblich.

Diese Planung ist über [Next Steps](Next_Steps.md) und die
[langfristige Roadmap](../Architecture/Long_Term_Development_Roadmap.md)
erreichbar. Sie ersetzt deren ältere allgemeine Arbeitsreihenfolge für den
beauftragten Umfang. Sicherheits-, Datenschutz-, Lizenz-, Identitäts-,
Laufzeit- und Liefergrenzen bleiben verbindlich. Neue öffentliche Verträge
werden vor der Implementierung im jeweiligen Dossier konkretisiert; eine
noch erforderliche konkrete Freigabe bleibt als Grenze sichtbar.

## Zuständigkeit und Reihenfolge

Die ersten fünf Ränge bleiben vollständig beim bereits gestarteten separaten
SSIS-Chat. Dort gelten dessen bestehender Wellenumfang, Reviewbudgets und
Ressourcenentscheidungen. Der Gesamtauftrag bearbeitet eigenständig Rang 6
und folgende. Die Security-Analyse beginnt unabhängig vom abgeschlossenen
SSIS-Umfang. Gemeinsame Änderungen werden vor PR-Integration gegen
aktuelles Remote-main abgeglichen; fremde Arbeit wird nicht übernommen.

Der Abgleich beruht auf dem öffentlichen Main-Stand nach PR #430 und der
anschließenden Integration von SSIS-PR #428. Statusänderungen der ersten fünf Ränge werden weiterhin
im SSIS-Abschnitt von Next Steps gepflegt.

| Rang | Entwicklung und vorhandene Zuordnung | Nächster abgegrenzter Abschluss |
|---|---|---|
| 1 | Fachliche SSIS-Paketsichten, `SSIS-001` | PR #425 ist integriert; keine erneute Umsetzung. |
| 2 | Objektbezogene SSIS-Regeln, `SSIS-001` | PR #426 ist integriert; keine erneute Umsetzung. |
| 3 | Modellherkunft und Paketversionsbindung, `SSIS-001` | PR #427 ist integriert; keine erneute Umsetzung. |
| 4 | Design-/Laufzeitkorrelation, `SSIS-001` | PR #428 ist einschließlich nativer Quellenabnahme sowie Head-/Main-Gates abgeschlossen; der SSIS-Abschnitt von Next Steps führt den Abschlussstand. |
| 5 | Optionale SQL-Metadatenprüfung, `SSIS-001` | PR #429 ist integriert; keine erneute Umsetzung. |
| 6 | Berechtigungen und Login-Lifecycle, Intake `PRINCIPALS_ROLE_PERMISSIONS` und `AUTHENTICATION_LOGIN_LIFECYCLE` | Das Serverprincipal-Dossier und das [Datenbankprincipal-Dossier](../Architecture/Database_Principal_Analysis_Dossier.md) grenzen sichtbare Principals, Rollen, explizite Rechte, Ownership und Loginzustände ab. Effektive Berechtigungen und unsichtbare Metadaten werden nicht aus unvollständigen Katalogen behauptet. |
| 7 | TLS und Endpoints, Intake `TLS_NETWORK_ENDPOINTS` | SQL-sichtbare Verbindungsverschlüsselung und Endpointzustände getrennt von Host-, Zertifikats- und externen Verbindungsnachweisen spezifizieren und implementieren. |
| 8 | Weitere SSIS-Laufzeitdiagnosen, `SSIS-001` | Die separat beauftragte SSIS-Welle 6 ergänzt iterationsgebundene Korrelation; ihr Abnahmestand steht im SSIS-Abschnitt von Next Steps. Weitere Task-, Buffer-, Provider-, Checkpoint- und Loggingpfade benötigen einen eigenen freien Scope. |
| 9 | SSIS-Laufvergleiche, `SSIS-001` | Vergleichbare explizite Ausführungen mit Paketrevision, Loggingabdeckung, Mengenbasis, Stichprobengröße und Ausschlüssen gegenüberstellen. |
| 10 | Snapshot- und Baseline-Ausbau, `SC-023-EXPANSION` | Die Schema-2-Vorbereitung ist mit PR #447 integriert. Der genaue Wait-Kontextvertrag ist unabhängig geprüft. Als Nächstes folgen Wait- und Datei-I/O-Differenzkandidaten mit ausdrücklich begrenztem Kontinuitätsnachweis. Kapazität, Ressourcendruck, Rollups und Scheduler folgen getrennt. |
| 11 | Upgrade- und Plattformdiagnostik, Intake `DEPRECATION_BREAKING_CHANGE` und `LINUX_CONTAINER_LIMITS` | Veraltete Nutzung und Zielversionsrisiken von Linux-/Containergrenzen trennen; Hostinformationen nur über einen ausdrücklich begrenzten Adapter erfassen. |
| 12 | Collation-Härtung, `COLL-001` | Verbleibende betroffene Quelldateien und Consumer gezielt härten und prüfen. Die garantierte Collation wird ohne vollständigen Nachweis nicht erweitert. |
| 13 | msdb-, Agent- und Mail-Diagnostik, `OPS-008` | Verbleibende Retention-, Status-, Datum-/Dauer- und Wartungsfälle abschließen; vorhandenen SMTP-Erfolg nicht erneut qualifizieren. |
| 14 | External-Data-, Runtime- und CLR-Abnahmen, `WI-0009` und `RUNTIME-001` | Eigene positive External-Table-Quellen, aktivierte Runtimes und synthetische SAFE-Assembly-Nachweise getrennt abnehmen. Fehlende Infrastruktur bleibt externe Evidenz. |
| 15 | Eigene SSIS-Kennzahlen, `SSIS-001` | Den optionalen Produzentenvertrag für DELTA, CUMULATIVE, GAUGE und FINAL mit Einheiten, Epochen, Duplikaten und Sequenzlücken spezifizieren; keine automatische Paketinstrumentierung. |
| 16 | Übrige Reifeabschlüsse, `OPS-005`, `OPS-006`, `OPS-007`, `OPS-009` | Nur noch fehlende Provider-, Portabilitäts-, Cursor- und Systemdatenbankfälle anhand des aktuellen OpenScope abnehmen. |
| 17 | Weitere Sicherheits- und Spezialdiagnosen, `WI-0010` | RLS/Maskierung, Klassifikation, Agent-Proxies, MSDTC und Legacy-Mirroring einzeln abgrenzen und nach Überschneidungsprüfung in konkrete Dossiers überführen. |
| 18 | Restore-/Hostnachweise und Fleet-Korrelation, `SC-025` und `SC-024` | Eigene isolierte Restore-/CHECKDB-Nachweise und den externen Fleet-Vertrag getrennt bearbeiten. Externe Infrastruktur, Transport, Mandantenisolation und Betriebsmodell sind eigene Grenzen. |

Die [Abdeckungsmatrix](../../../Metadata/Quality/Diagnostic_Coverage_Landscape.csv)
ist ein Intake. Ältere Kandidatenstatus überstimmen keine inzwischen gelieferte
Funktion. Vor Auswahl eines Kandidaten werden aktueller Code, Inventare und
OpenScope geprüft. Bestehende Kennungen bleiben erhalten; neue Dossiers
erhalten zunächst eine UUID und bei paralleler Arbeit `DEFERRED`, bis die
projektweite Registration Authority eine finale Referenz vergibt.

## Begleitende Arbeiten

Die Planungskonsolidierung beginnt mit diesem aktuellen Einstieg. Historische
SSIS- und Laufzeitbelege bleiben in Next Steps zunächst unverändert erreichbar.
Eine spätere Auslagerung prüft alle Link-, Anker-, Validator- und
Fortsetzungskonsumenten gemeinsam und bewahrt historische Aussagen. Der
verbleibende historische Umfang ist eine konkrete Dokumentationsaltlast;
zuständig ist der Gesamtauftrag, Auslöser ist der Abschluss der Planintegration.

Die vorgeschlagene STAT-DOMINANT-Diagnose ist durch PR #424 und deren
Abschlussnachführung in PR #430 bereits geliefert. Sie wird nicht als offener
Implementierungsschritt gezählt. Die dort beschriebenen Grenzen und früheren
Fehlläufe bleiben erhalten; ein neuer fachlicher Fehler wäre ein neuer Auslöser.

## Ausführung, Review und endliche Grenzen

Je kohärentem Schritt arbeitet ein Implementierer mit höchstens einem
unabhängigen Reviewer. Ein begrenzter Folgecheck betrifft ausschließlich
konkrete Befunde an geänderten Inputs. Hashes, Mengen, Registrykollisionen,
Commitbindungen und CI-Ergebnisse werden lokal deterministisch geprüft.
Weitere fachliche Teilfragen erfordern einen neuen begründeten Schritt.

Der endliche Gesamtscope umfasst die 13 Ränge 6 bis 18, diese Planintegration
und die betroffene Dokumentationskonsolidierung. Als gemeinsame Obergrenze
gelten 40 eigene fachliche PR-Schritte einschließlich Korrekturlieferungen
und Koordination; der separate SSIS-Auftrag gehört nicht zu diesem Budget.
Pro Schritt sind ein Erstentwurf, ein gebündelter Korrekturpass und die
erforderlichen Gates vorgesehen. Neue fehlgeschlagene Tests werden zunächst
lokal eingegrenzt. Ein weiterer Versuch benötigt geänderte Inputs, neue
Evidenz oder ein bisher unerfülltes Gate. Tatsächlicher Verbrauch einschließlich
Reviewer und Wiederholungen wird privat je Checkpoint fortgeschrieben.
Token-, Kosten- und Kontingentmessung sind nicht verlässlich verfügbar.

Ein Checkpoint folgt nach jeder integrierten Lieferung. Bei 30 verbrauchten
PR-Schritten wird der verbleibende Umfang vor weiterer Arbeit neu bewertet;
bei 40 beginnen keine neuen Schritte. Offene Arbeit wird dann mit ihrer
tatsächlichen Grenze gesichert und nicht als abgeschlossen ausgegeben. Ein
Heartbeat oder Sessionwechsel setzt diese Grenzen nicht zurück.

Die Testauswahl folgt ausschließlich der
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md).
Dokumentation erhält die betroffenen statischen Gates ohne SQL-Instanz;
Produktänderungen erhalten die direkt und transitiv betroffene SQL2025-Prüfung.
Native ältere Engines, zusätzliche Compatibility Levels, Windows und externe
Features werden nur am konkreten Vertragsrisiko ergänzt. Keine bestandene
Prüfung wird allein wegen Zeitablaufs wiederholt. Offene Required Checks,
Reviews oder Cleanupnachweise verhindern die Abschlussbehauptung.

Eine Lieferung wird auf einem eigenen Branch gegen aktuelles `origin/main`
vorbereitet, unabhängig geprüft und nach erfolgreichen erforderlichen
Head-Checks regulär per PR integriert. Main-Nachläufe sind getrennte Evidenz.
Es gibt keinen direkten Main-Push, Force-Push, pauschalen Release oder
automatischen Eingriff in bestehende beziehungsweise fremde Systeme.
Ein blockierter Rang wird mit Ursache und Wiederaufnahmebedingung erhalten;
der nächste unabhängige autorisierte Rang kann währenddessen fortgesetzt werden.

## Heartbeat und Fortsetzung

Der stündliche Heartbeat dieses Gesamtauftrags ist die letzte Instanz zur
Leerlauferkennung. Bei aktiver Umsetzung, eigenen Prozessen oder laufenden
Review-, Test- und CI-Schritten startet er keine parallele Arbeit. Nur bei
unerwartetem Leerlauf und ausführbarem verbleibendem Scope setzt dieser Chat
nach einem knappen aktuellen Zustandsabgleich fort.

Unveränderte Blocker und nicht handlungsfähige Zustände bleiben still.
Benachrichtigt werden wesentliche Änderungen, Abschlüsse, Fehler und notwendige
Benutzereingriffe. Der Heartbeat erweitert keine Berechtigung, übernimmt keinen
fremden Chat und beginnt nach Ende oder Stopp des Auftrags keine neue Arbeit.
Automationskennung, Chatkennung und private Runtimebelege bleiben außerhalb
des Repositorys.

## Aktueller Checkpoint

Die Planung ist über PR #431 nach unabhängigem Review, dem konkreten
Regelkontextfolgecheck und vier erfolgreichen Head-Prüfungen regulär integriert.
Der erste lokale statische Lauf meldete ausschließlich die fehlende Einbindung
der neuen Seite; die korrigierte Bindung und alle 23 vorhandenen Selbsttests
bestehen. Die übrigen statischen Prüfungen und der Datenschutzscan bestehen.
Der getrennte Main-Nachlauf besteht für Dokumentation, Datenschutz und
Commitnachrichten ebenfalls.

Rang 6 begann mit dem
[Serverprincipal-Dossier](../Architecture/Server_Principal_Analysis_Dossier.md).
Der erste vorgeschlagene Slice betrifft lokale Serverprincipals, direkte
Rollenmitgliedschaften, explizite Serverberechtigungen und SQL-Login-Policies.
Die vorhandene Konfigurations-, Audit- und Verschlüsselungsabdeckung sowie
die offiziellen Katalog- und Sichtbarkeitsverträge sind abgeglichen. Das
Dossier konkretisiert die erste Schnittstelle und unabhängige Abnahme.
`WI-0012` enthält inzwischen den ersten Server-Produktkandidaten einschließlich
Installer, Navigator, sieben nativen Resultsets und synthetischen Tests.
Der unabhängige Produktreview meldete vier konkrete Befunde zu Callerfehlern,
Cleanupbindung, Schemafacetten und Quellenfehlerabnahme. Ein gebündelter
Korrekturpass ergänzt reguläre Status-/Diagnose-Rückgabe, Transaktionssentinels,
native ID-/SID-Bindungen, typisierte Schemaoracles und einen kontrollierten
SELECT-DENY-Fall. Die nativen Entwicklungsprüfungen erforderten zusätzlich
Master-Kontext, kollationsgebundene Sollwerte und eine reguläre Fehler-Rückkehr,
damit T-SQL-Caller ihre OUTPUT-Werte und committable Transaktion behalten.
Der erste Server-Slice ist über PR #434 als `8acbbfa3` regulär integriert.
Alle acht Head-Checks und das vollständige SQL2025-Gate bestehen. Die beiden
gezielten nativen Zusatzprüfungen bestätigen SQL2019 15.0.4500.2/CL150 und
SQL2022 16.0.4305.5/CL160 einschließlich Permissionmatrix und eigenem Cleanup
am selben Liefercommit `aabf9e0d`. Die genauen Nachweislinks und Grenzen stehen
im Serverprincipal-Dossier. Frühere Fehlläufe bleiben als solche erhalten;
Main-Nachläufe sind getrennte Evidenz. Es wird kein Reifeabschluss behauptet.

Der erste Datenbankteil ist über [PR #438](https://github.com/gecompat/SQL_Server_Analyze/pull/438)
als `00f0056e` regulär integriert. Neun Resultsets, Installer, Navigator und
unabhängige native Schema- und Wertoracles gehören gemeinsam zur Lieferung.
Produktreview, gezielte Folgechecks und alle acht Head-Checks bestehen.
Der Liefercommit `6e41c9fe` besteht das vollständige SQL2025-Gate sowie gezielte
native 2019-/2022-Prüfungen einschließlich Permissionmatrix und eigenem Cleanup.
Der lokale kombinierte Lauf bestätigt zusätzlich abweichende Instanz- und
Frameworkcollations. Die genauen Nachweislinks und Grenzen stehen im
[Datenbankprincipal-Dossier](../Architecture/Database_Principal_Analysis_Dossier.md).
WI-0012 bleibt PARTIAL_PRODUCT_FUNCTION; die beiden Principalmodule erhalten
tatsächliche CI-Evidenz ohne pauschalen Reifeabschluss.

Der erste Caller-Slice ist über [PR #441](https://github.com/gecompat/SQL_Server_Analyze/pull/441)
als `33747f6d` regulär integriert. Der Liefercommit `ff8e2578` besitzt acht
bestandene Head-Checks, ein vollständiges SQL2025-Gate und gezielte native
SQL2019-Evidenz. Der lokale kombinierte Vertrag 137/189 bestätigt zusätzlich
den kanonischen Renderer, Quellenprobleme in CONSOLE und den begrenzten
loginlosen Kontext. SQL2022 wurde für diesen Slice nicht separat ausgeführt.
Der begrenzte Nachlauf nach einem unerfassten Timeout im älteren Namensfilter
und die übrigen Evidenzgrenzen stehen im
[Callerrechte-Dossier](../Architecture/Caller_Permission_Analysis_Dossier.md).

Damit ist der erste SQL-sichtbare Sicherheitsdurchstich von Rang 6 mit drei
vertikalen Grundlieferungen abgeschlossen. WI-0012 bleibt für konkrete Objekt-/
Spalten-/Statementrechte, fremde Principals und externe Identitätsprüfung offen.
Darauf folgte Rang 7 mit dem
[Endpoint-Dossier](../Architecture/Endpoint_Transport_Analysis_Dossier.md).
Sein SQL-Scope umfasst Katalogzustände und beobachtete Verschlüsselungsflags;
Hostkonfiguration, tatsächliche TLS-Version, Cipher und Zertifikatsvertrauen
bleiben getrennte offene Evidenz. Die konkreten Schemas und nativen Abnahmen
wurden nach unabhängigem Vertragsreview vor der Implementierung festgelegt.
Die bestehende funktionsbezogene autonome Freigabe wird nicht erneut angefragt.

Der erste SQL-sichtbare Endpoint-/Transport-Slice ist über PR #443 als
`52a699a6` integriert. Acht Head-Checks, das vollständige SQL2025-Gate und
gezielte native SQL2019-Evidenz bestehen am Liefercommit `b7498890`.
Das [Endpoint-Dossier](../Architecture/Endpoint_Transport_Analysis_Dossier.md)
führt die tatsächlichen Nachweise und erhaltenen Grenzen. TLS-Version,
Cipher, Zertifikatsvertrauen, externe Erreichbarkeit und positive HADR-/MARS-
Verbindungsfälle werden nicht als abgeschlossen ausgegeben.

Die separat aktive SSIS-Datenflusskorrelation bleibt bei ihrem Auftrag.
Ein zusätzlicher SSIS-Vergleich benötigt einen freien, mit dessen Producer-
und Consumerstand abgeglichenen Scope. Der nächste unabhängige Schritt ist
Rang 10 mit dem [Snapshot-Dossier](../Architecture/Snapshot_Expansion_Dossier.md).
Der Wait-Slice erhält native Rohwerte und ein ausdrücklich begrenztes
Kontinuitätsmodell; ein Engine-Startwert allein beweist keinen ausbleibenden
DBCC-Reset. Datei-I/O folgt mit eigener Identitätsabnahme. Vor Produktcode
werden Feld-, Policy-, Versions- und Migrationsvertrag unabhängig geprüft.


Die Schema-2-Vorbereitung ist über [PR #447](https://github.com/gecompat/SQL_Server_Analyze/pull/447)
als `ce8b5e30` integriert. Alle acht Head-Checks, die vollständigen SQL2025-
Head-/Main-Gates und die gezielte native SQL2019-Qualifizierung mit Scope
SNAPSHOT_SCHEMA_RISK bestehen. Diese zusätzliche native Prüfung qualifiziert
die betroffenen Snapshot-/Migrationsverträge; Core-Release und allgemeine
native Berechtigungsmatrix sind ausdrücklich NOT_EXECUTED. Das Snapshot-
Dossier führt Paketbindung, frühere Vollrunfehler und verbleibende Grenzen.
Der WAIT_CAPTURE_CONTEXT-v1-Feldvertrag ist einschließlich der gezielten
Retentionskorrektur unabhängig geprüft. Der Retentionsschutz mit Targetpatch 1.1.1 ist über
[PR #449](https://github.com/gecompat/SQL_Server_Analyze/pull/449) mit
vollständigen Head- und Main-Gates integriert. Das interne Wait-Target 1.2.0 ist über PR #451 einschließlich aller Head-/Main-Gates und gezielter nativer SQL2019-Snapshotprüfung integriert. Die öffentliche Aktivierung mit Targetpatch 1.2.1 bei unveränderter SchemaVersion 2 ist über PR #453 mit allen sieben Head-Checks und gezielter nativer SQL2019-Prüfung integriert; alle vier getrennten Main-Prüfungen einschließlich des vollständigen SQL2025-Gates bestehen. Der [Datei-I/O-Vorvertrag](../Architecture/File_IO_Snapshot_Dossier.md) ist über PR #454 mit allen Head-/Main-Gates integriert. Der [Feld- und Migrationsvertrag](../Architecture/File_IO_Snapshot_Field_Contract.md) ist über PR #455 mit allen Head-/Main-Gates integriert. Das interne Datei-I/O-Target 1.3.0 / Schema 3 ist über [PR #456](https://github.com/gecompat/SQL_Server_Analyze/pull/456) einschließlich aller sieben Head-Prüfungen, vollständigem SQL2025-Gate, gezielter nativer SQL2019-Risikoabnahme und aller vier Main-Gates integriert. Der erste Main-Legacy-SSIS-TABLE-Timeout bleibt ohne behauptete Ursache dokumentiert; ein begrenzter Wiederlauf der fehlgeschlagenen Jobs bestand. Die öffentliche native Datei-I/O-Aufnahme folgt als nächste kohärente Welle mit vorab geprüften Grenzen für erfolgreiche Reads, fatale Bindungen und unbestätigte Abschlüsse. Die SSIS-Datenflussarbeit bleibt
beim separaten Auftrag.

## Checkpoint der öffentlichen Datei-I/O-Welle

[PR #458](https://github.com/gecompat/SQL_Server_Analyze/pull/458) ist regulär
als 1a144251 integriert. Der Head 23730d1d besteht alle sieben Standardprüfungen,
das vollständige [SQL2025-Gate](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40271515196)
und die gezielte [native SQL2019-Snapshot-Risikoabnahme](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40271529655).
Der Mergebaum ist identisch zum geprüften Headbaum. Der getrennte vollständige
[SQL2025-Main-Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40273412551),
Dokumentation, Privacy und Commitprüfung bestehen. Targetpatch 1.3.1 / Schema 3
mit Retentionsvertrag 3 umfasst die öffentliche native Aufnahme, ehrliche späte
Read-/Zeitfehler, erhaltene Mehrfach-Issues und offene Vorgängergrenzen.

Der nächste unabhängige Rang 11 steht im
[Upgrade-Usage-Dossier](../Architecture/Upgrade_Feature_Usage_Dossier.md).
Vertrag und Fehleraggregation sind unabhängig geprüft. Die erste eigene
SQL2025-Quellenprobe bestätigt den nativen Deprecated-Counter und kontrollierten
Begegnungszuwachs; der Labcleanup besteht. Produktumsetzung und endgültige
Abnahme bleiben eigene Schritte. Der getrennte SSIS-Auftrag wird nicht übernommen.
