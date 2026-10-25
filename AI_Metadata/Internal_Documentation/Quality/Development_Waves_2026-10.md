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
und folgende. Die noch offene SSIS-Integration verhindert eine unabhängige
Security-Analyse nicht. Gemeinsame Änderungen werden vor PR-Integration gegen
aktuelles Remote-main abgeglichen; fremde Arbeit wird nicht übernommen.

Der Abgleich beruht auf dem öffentlichen Main-Stand nach PR #430 und der
anschließenden Integration von SSIS-PR #428. Statusänderungen der ersten fünf Ränge werden weiterhin
im SSIS-Abschnitt von Next Steps gepflegt.

| Rang | Entwicklung und vorhandene Zuordnung | Nächster abgegrenzter Abschluss |
|---|---|---|
| 1 | Fachliche SSIS-Paketsichten, `SSIS-001` | PR #425 ist integriert; keine erneute Umsetzung. |
| 2 | Objektbezogene SSIS-Regeln, `SSIS-001` | PR #426 ist integriert; keine erneute Umsetzung. |
| 3 | Modellherkunft und Paketversionsbindung, `SSIS-001` | PR #427 ist integriert; keine erneute Umsetzung. |
| 4 | Design-/Laufzeitkorrelation, `SSIS-001` | PR #428 ist durch den separaten SSIS-Chat integriert; dessen Nachweise und verbleibende Abschlussarbeit bleiben dort. |
| 5 | Optionale SQL-Metadatenprüfung, `SSIS-001` | PR #429 ist integriert; keine erneute Umsetzung. |
| 6 | Berechtigungen und Login-Lifecycle, Intake `PRINCIPALS_ROLE_PERMISSIONS` und `AUTHENTICATION_LOGIN_LIFECYCLE` | Ein Dossier grenzt sichtbare Principals, Rollen, explizite Rechte, Ownership und Loginzustände ab. Effektive Berechtigungen und unsichtbare Metadaten werden nicht aus unvollständigen Katalogen behauptet. |
| 7 | TLS und Endpoints, Intake `TLS_NETWORK_ENDPOINTS` | SQL-sichtbare Verbindungsverschlüsselung und Endpointzustände getrennt von Host-, Zertifikats- und externen Verbindungsnachweisen spezifizieren und implementieren. |
| 8 | Weitere SSIS-Laufzeitdiagnosen, `SSIS-001` | Nur die nach Abschluss der fünf Paketwellen tatsächlich fehlenden Task-, Wiederholungs-, Buffer-, Provider-, Checkpoint- und Loggingpfade auswählen. Die Umsetzung benötigt einen freien eigenen Scope; der laufende SSIS-Chat bleibt unberührt. |
| 9 | SSIS-Laufvergleiche, `SSIS-001` | Vergleichbare explizite Ausführungen mit Paketrevision, Loggingabdeckung, Mengenbasis, Stichprobengröße und Ausschlüssen gegenüberstellen. |
| 10 | Snapshot- und Baseline-Ausbau, `SC-023-EXPANSION` | Zunächst reset-sichere Wait- und Datei-I/O-Deltas, danach Kapazität und Ressourcendruck; Rollups und Scheduler bleiben getrennte optionale Schritte. |
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

Die Planung und ihre Regelkontexteinbindung sind unabhängig ohne offene
Befunde geprüft. Der erste statische Lauf meldete ausschließlich die fehlende
Einbindung der neuen Seite im Regelkontextindex; die korrigierte Einbindung
und die 23 vorhandenen Selbsttests bestehen. Die übrigen statischen Prüfungen
und der Datenschutzscan bestehen. Aktuelle Head-Checks und die reguläre
PR-Integration bleiben vor Lieferung erforderlich. Danach beginnt Rang 6 mit
einem quellengestützten Security-Dossier. Zuerst werden die vorhandene
ServerSecurityConfiguration, die getrennte Audit-/Encryption-Abdeckung sowie
Katalogsichtbarkeit, Rechte- und Kostenverträge abgeglichen. Das Dossier
definiert den kleinsten nutzbaren Implementierungsschritt und dessen
unabhängige Abnahme, bevor ein Produktstatus geändert wird.
