# Nächste Arbeitsschritte

**Stand:** 6. November 2026  
**Zweck:** aktueller Auftragsstatus und Einstieg in die erhaltene Entwicklungshistorie für `gecompat/SQL_Server_Analyze`.

## Aktuelle Orchestrierung

Die [Entwicklungsplanung](Development_Waves_2026-10.md) ist die einzige maßgebliche Quelle für Reihenfolge, Zuständigkeit und nächste ausführbare Welle. Dieser kurze Einstieg hält den aktuellen Stand, seine Evidenzgrenzen und die wichtigsten Fortsetzungsregeln fest. Abgeschlossene Planungs- und Ausführungsnachweise bleiben im [Historienarchiv](Next_Steps_History_2026-11-05.md).

## NULL-Guards der internen Plananalyse

PR #640 ist einschließlich der erforderlichen Head- und Main-Gates, der nativen SQL-Server-2025- und Standalone-Verträge sowie Cleanup integriert.

Die fachliche Prüfung belegt sechs fehlende NULL-Ablehnungen. InternalCollectExecutionPlanMetadata weist NULL für QuellumgebungBestaetigt, MitPredicateHistogramMap und HighImpactConfirmed jetzt vor seinen Temp-Tabellenprüfungen als INVALID_PARAMETER zurück. InternalAnalyzeExecutionPlan lehnt NULL für PlanSource, RuntimeCounterScope und MitThreadRuntime vor Profilzugriff und Temp-Tabellenprüfungen ab. Insbesondere darf ein fehlender Thread-Schalter nicht entgegen dem Default 0 Threadzeilen erhalten. Die absichtlichen NULL-Fallbacks für Modi und die optionalen Kontextwerte bleiben erhalten; der ausdrückliche Scope UNKNOWN bleibt gültig.

Die [Entwicklungsplanung](Development_Waves_2026-10.md#null-guards-der-internen-plananalyse) bindet die Quellen, die Verhaltenstests und die Grenzen der öffentlichen Aufrufer. DDL-Kommentare, Objektreferenz, betroffene öffentliche Hilfetexte und ihre Guides sind abgeglichen. Die begrenzte Korrektur der öffentlichen Datenschutzgrenzen umfasst folgende Regeln: NULL bei SensitiveDataConfirmed gilt nur auf angeforderten sensiblen Pfaden als unbestätigt; MitSqlText=NULL wird als INVALID_PARAMETER abgewiesen. Nicht-sensitive NULL-Aufrufe und absichtliche Modus-/Kontextfallbacks bleiben erhalten. HighImpactConfirmed und weitere öffentliche Bestätigungsschalter bleiben ein separater Folgeschritt. Unabhängiger Review, erforderliche Remote-Tests, Cleanup und Main-Nachprüfung sind Integrationsbedingungen dieser Korrektur.

## Phasenbezogene File-IO-Fehlerausgänge

Die beiden File-IO-Fehlerausgänge sind in ihren Einzelparameterverträgen nach Prüfphase und Finalisierungspfad beschrieben. Sourcefehler können nach validierter Source auch bei einem Backendfehler einschließlich NULL oder Leertext erhalten bleiben; ein Fehler der inneren Finalisierung kann stattdessen seine eigene Diagnose ausgeben. Die SQL-Logik des Helpers bleibt unverändert; seine kommentarabhängige Fingerprintbindung im abgeleiteten Snapshot-Preflight ist nachgeführt. Die [Entwicklungsplanung](Development_Waves_2026-10.md#phasenbezogene-file-io-fehlerausgänge) bindet den Quellstand und hält die verbleibenden Evidenzgrenzen fest. Die erforderlichen Review- und Remote-Gates bleiben Voraussetzung für die Integration.

Die damals folgende fachliche NULL-Guard-Prüfung ist im aktuellen Abschnitt abgegrenzt; die öffentlichen Bestätigungs- und Datenschutzgrenzen bleiben ein eigener Folgeschritt. Fehlende Plattform- und Transaktionsevidenz bleibt ausdrücklich unbelegt.

## Snapshot-Target-Diagnose 53781

Fehler 53781 nennt nun das vom FILE_IO-Guard tatsächlich verlangte Target 1.3.1 mit Schema 3. Fehlernummer, Status und Guard bleiben unverändert; DDL-Kommentar und Objektreferenz sind abgeglichen. Die [Entwicklungsplanung](Development_Waves_2026-10.md#snapshot-target-diagnose-53781) bindet den neuen Quellstand und trennt ihn vom historischen Blobnachweis. Die erforderlichen Remote-Gates bleiben Voraussetzung für die Integration.

Die damals folgenden File-IO-Einzelverträge sind im aktuellen Abschnitt präzisiert. Die nachfolgende NULL-Guard-Prüfung steht im aktuellen Abschnitt; nicht vorhandene Plattform- und Transaktionsevidenz wird nicht als erbracht behandelt.

## SSIS-Referenzabgleich vom 6. November 2026

Der ergänzende Abgleich beschreibt alle vier zuvor offenen SSIS-Helfer mit zusammen 42 Einzelparameterverträgen. Die bezeichnete interne Kohorte umfasst damit 25 Prozeduren mit 238 Parametern; beim SSIS-Abgleich waren die bisherigen 21 Quell-Blobs und das gebundene Inventar unverändert. PR #635 und PR #636 sind einschließlich Main-Nachprüfung integriert. Die vorliegende Änderung ergänzt InternalSsisExecutionMetrics; Review und erforderliche CI-Gates bleiben die Integrationsbedingung. Es handelt sich um einen begrenzten Kommentar- und Referenzabgleich, keine allgemeine Laufzeitqualifikation. Die öffentliche Kohorte und die Nichtprozedurkohorte behalten ihre separat bezeichneten Evidenzgrenzen.

Die [Entwicklungsplanung](Development_Waves_2026-10.md#ssis-referenzabgleich-vom-6-november-2026) bindet die vier Quellen und hielt die damals belegten Lücken fest: Snapshot-Diagnosetext 53781, phasenbezogene Fehlerausgänge bei File-IO sowie die getrennte fachliche Prüfung dokumentierter NULL-Guard-Verhaltensweisen. Fehlende Windows-/Mirroring- und MSDTC-Topologieevidenz bleibt offen. Die modulare Kerninstallation ohne obligatorische LLM-Komponenten bleibt unverändert.

## Quellenstand nach PR #633

Dieser Abschnitt ist der historische Ausgangsstand; der aktuelle Folgeabgleich steht unter [SSIS-Referenzabgleich vom 6. November 2026](#ssis-referenzabgleich-vom-6-november-2026).

**Stand:** 6. November 2026.

Die interne Prozedurprüfung umfasst 21 von 25 Inventareinträgen mit 196 Parameterzeilen; die vier SSIS-Referenzeinträge sind noch nicht einzeln gegen Parameterverträge geprüft. Die bisherige öffentliche Kohorte umfasst 121 Procedures mit 2.167 Parameterzeilen. Die getrennte Nichtprozedurkohorte umfasst 57 TABLE-, VIEW- und FUNCTION-Objekte aus 47 Quelldateien. Diese Zählungen gelten jeweils nur für die gebundenen Kohorten und belegen keine globale Fehlerfreiheit oder allgemeine Laufzeitqualifikation.

Die PRs #631 bis #633 wurden mit den erforderlichen Head- und Main-Prüfungen, der vollständigen statischen Vertragssuite mit 80 Validatoren und Selbsttestauswahl `Changed`, Adapterparität und erfolgreichem TestLab-Cleanup-Vertrag integriert. Native SQL-Läufe wurden wegen reiner Kommentaränderungen übersprungen; daraus entsteht keine neue Laufzeitqualifikation. Die ausführbare Reihenfolge und der Objektstatus stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md#quellenstand-nach-pr-633).

## Aktueller Stand nach Schritt 178

Der folgende Abschnitt dokumentiert den Quellenstand vom 5. November 2026 nach Schritt 178. Er bleibt als Historie erhalten; maßgeblich für den aktuellen Stand ist [NULL-Guards der internen Plananalyse](#null-guards-der-internen-plananalyse).

Die Hilfeprüfung der bisherigen Inventarkohorte erfasst 121 Procedures mit 2.167 Parameterzeilen; PR #610 bis PR #612 sind integriert. Die Nichtprozedurkohorte umfasst 57 TABLE-, VIEW- und FUNCTION-Objekte aus 47 Quelldateien. Die gebundenen DDL-Revisionen und Inventarzuordnung sind für diese Kohorte unabhängig geprüft. Diese Abschlüsse gelten ausschließlich für die bezeichneten Inventare und belegen weder globale Fehlerfreiheit noch allgemeine Laufzeit- oder Plattformqualifikation. Positive Windows-/Mirroring-Topologie, MSDTC-Dienst, externe Teilnehmer sowie Commit-/Recovery-Evidenz sind nicht belegt.

Die aktuelle Obergrenze beträgt 200 eigene PR-Schritte; bei Schritt 190 wird der Restumfang neu bewertet. Frühere Grenzen und Checkpoints setzen den aktuellen Verbrauch nicht zurück. Bestehende Einzelgrenzen und Sperren gelten fort; ein historischer Eintrag erteilt keine neue Ausführungsfreigabe. Der aktuelle Auftrag und die ausführbare Reihenfolge stehen in der [Entwicklungsplanung](Development_Waves_2026-10.md#aktueller-stand-nach-schritt-178).

## Vorheriger Checkpoint nach Schritt 43

Der vorherige integrierte Checkpoint und seine damaligen Prüfbelege sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#vorheriger-checkpoint-nach-schritt-43) erhalten.

## Aktueller Checkpoint nach PR #485

Der gebundene Checkpoint nach PR #485 und seine zugehörigen Head- und Main-Prüfungen sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#aktueller-checkpoint-nach-pr-485) erhalten. Neue Änderungen werden gegen den aktuellen Main-Stand und die maßgebliche Planung abgeglichen.

## Lesepfad und technische Evidenzgrenzen

Öffentliche Anwenderdokumentation bleibt der maßgebliche Ort für Produktverhalten und Bedienung; interne Pläne und Nachweisarchive ersetzen sie nicht. Inventarvollständigkeit gilt nur für die jeweils gebundene Kohorte. Produkt-, Plattform-, Berechtigungs-, Transaktions- und Laufzeitaussagen benötigen jeweils die passende unabhängige Evidenz. Fehlende Infrastruktur oder nicht ausgeführte Prüfungen bleiben ausdrücklich offen.

Installation und Ausführung folgen den modularen, dokumentierten Installationspfaden und ihren Voraussetzungen.

Die Kerninstallation muss ohne LLM-Komponenten und deren Berechtigungen oder Netzwerkzugriff funktionieren. Künftige LLM-Funktionen sind separat wählbare Zusatzmodule; fehlende oder unzulässige Voraussetzungen dürfen eine gültige Kerninstallation nicht abbrechen oder zurückrollen. Der Zusatzmodulstatus ist getrennt und ehrlich auszuweisen. Bei Einführung solcher Funktionen sind Kerninstallation ohne LLM und nicht verfügbare beziehungsweise nicht erlaubte Zusatzkomponenten gezielt remote abzunehmen. Die Inventuren installieren oder aktivieren keine externen Laufzeiten oder CLR-Komponenten; Analyze bleibt CLR-frei.

Für jeden einzelnen Parameter sind Datentyp und Eingabeform, ein ausdrücklich als Default bezeichneter Vorgabewert sowie die Bedeutung von NULL, Leerwerten und relevanten Grenzen zu erklären. Geschlossene Wertemengen werden taxativ mit sämtlichen erlaubten Werten und der Bedeutung jedes Werts beschrieben; Beispiele ersetzen diese Aufzählung nicht. Diese Abnahme gilt auch für die Nachprüfung bereits überarbeiteter Hilfen.

Für jede Regel gilt die aktuell ausgewählte maßgebliche Quelle samt ihren semantischen Abhängigkeiten; Discoverylinks allein aktivieren keine weiteren Verträge oder Prüfungen.


## Erhaltene Rückblicke auf frühere Abnahmen

Die folgenden Verweise bewahren die konkreten historischen Nachweisscopes. Sie beschreiben damalige Abnahmen und sind keine globale oder aktuelle Vollständigkeitsbehauptung.

- Der damalige Release-Nachweis umfasst alle 17 P0-, 40 P1- und 124 P2-Fälle; die abgeschlossene P0-, P1- und P2-Special-Case-Matrix gehörte zu diesem bestätigten Produktstand. Dies ist datierte, scopegebundene Release-Evidenz und keine Aussage über den heutigen Gesamtumfang. [Historischer Nachweis](Next_Steps_History_2026-11-05.md#aktueller-produktstand).
- Der archivierte Abschnitt [Abgeschlossen – SQL25-005](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005) enthält den damaligen Befund. Die dokumentierten Bereiche `ANALYZE-LAB-001`, `OPS-005`, `OPS-006`, `OPS-008` und `COLL-001` bleiben an ihre jeweiligen damaligen Scopes gebunden.
- Das Intake WI-0010 und sein dokumentierter Themenumfang sind in der [Diagnoseabdeckungs- und Gap-Matrix](../../../Metadata/Quality/Diagnostic_Coverage_Landscape.csv) nachgewiesen; der historische Planungsstand bleibt im [Archiv](Next_Steps_History_2026-11-05.md#aktueller-produktstand) erhalten.

## Historische Abschnitte und erhaltene Anker

Die folgenden Überschriften bewahren bislang veröffentlichte Abschnittsanker und führen zum unveränderten Originaltext im Archiv.

## Historischer SSIS-Auftrag: elfte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-elfte-paketwelle).

## Historischer SSIS-Auftrag: zehnte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-zehnte-paketwelle).

## Historischer SSIS-Auftrag: siebte Paketwelle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historischer-ssis-auftrag-siebte-paketwelle).

## Aktueller Gesamtauftrag: priorisierte Entwicklungswellen

Seit dem 26. Oktober 2026 bündelt dieser Auftrag die Weiterentwicklung einschließlich verbleibender SSIS-Themen als einziger Orchestrator. Die [Entwicklungsplanung](Development_Waves_2026-10.md) ist die maßgebliche Quelle für Zuständigkeit, Reihenfolge, Abschlussbedingungen und den nächsten ausführbaren Schritt. Bereits integrierte Wellen werden nicht wiederholt; neue SSIS-Schritte zählen im gemeinsamen Umfang mit. Die Obergrenze beträgt 200 eigene PR-Schritte, die Neubewertung erfolgt bei 190. Sicherheits-, Datenschutz-, Lizenz-, Identitäts-, Laufzeit- und Liefergrenzen bleiben verbindlich. Frühere Einzelaufträge und ihre damaligen Freigaben sind im [Historienarchiv](Next_Steps_History_2026-11-05.md#aktueller-gesamtauftrag-priorisierte-entwicklungswellen) dokumentiert.

## Abgeschlossen: fünf SSIS-Paketwellen vom 25. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-f%C3%BCnf-ssis-paketwellen-vom-25-oktober-2026).

## SSIS-Welle 6: iterationsgebundene Ausführungskorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ssis-welle-6-iterationsgebundene-ausf%C3%BChrungskorrelation).

## Separater Auftrag: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#separater-auftrag-stat-dominant-fehlerdiagnose-54901).

### Abgeschlossen: Diagnose aus PR #424

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-diagnose-aus-pr-424).

### Historische Freigabe und Abnahmegrenzen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-abnahmegrenzen).

#### Freigegeben: STAT-DOMINANT-Fehlerdiagnose (54901)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegeben-stat-dominant-fehlerdiagnose-54901).

## Integriert: SSIS-001-Pipeline-Phasenbeginnmeldungen (PR #421); Main-Abnahme offen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#integriert-ssis-001-pipeline-phasenbeginnmeldungen-pr-421-main-abnahme-offen).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme).

#### Freigegebener begrenzter SSIS-001-Schritt: Pipeline-Phasenbeginnmeldungen

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-begrenzter-ssis-001-schritt-pipeline-phasenbeginnmeldungen).

## Abgeschlossen: SSIS-001-Final-Commit-Meldungen (PR #419)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-final-commit-meldungen-pr-419).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-1).

## Abgeschlossen: SSIS-001-Zeilenfluss-Durchsatz (PR #417)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-zeilenfluss-durchsatz-pr-417).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-2).

## Abgeschlossen: SSIS-001-Schreibmengen (PR #415)

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-ssis-001-schreibmengen-pr-415).

### Historische Freigabe und lokale Abnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigabe-und-lokale-abnahme-3).

## Abgeschlossen: Release v1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen-release-v112).

## Historische Freigaben und Sperrstände

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-freigaben-und-sperrst%C3%A4nde).

### Freigegebener Folge-PR: FIND-CORE-Diagnose

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebener-folge-pr-find-core-diagnose).

### Gestoppte Lieferung: Release 1.1.2

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gestoppte-lieferung-release-112).

## Historische Welle: Release 1.1.0

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#historische-welle-release-110).

## OPS-005-Quellenabgleich vom 23. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ops-005-quellenabgleich-vom-23-oktober-2026).

## Erhaltener Stand: OPS-005-Lesepfad und Nachweishistorie

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltener-stand-ops-005-lesepfad-und-nachweishistorie).

### Dokumentationsaltlasten und Wiederaufnahme

Die drei damals bezeichneten Einstiege sind nachgeführt: Der Metadaten-Einstieg wurde mit PR #405 qualifiziert abgeschlossen. Das öffentliche TestLab-README trennt die OPS-005-Anleitung von der datierten Nachweischronologie. Der aktuelle Fortsetzungsstand ist mit dieser Migration von der erhaltenen Historie getrennt; die bisherigen Anker bleiben erreichbar. Diese Disposition betrifft ausschließlich die genannten Lesepfade und bestätigt keine vollständige Dokumentationskonformität. Die zuständigen Maintainer prüfen diese Einstiege erneut, wenn sich deren Verträge oder Pfadkonsumenten ändern. Der [damalige Altlastenstand](Next_Steps_History_2026-11-05.md#dokumentationsaltlasten-und-wiederaufnahme) bleibt historisch erhalten.

## Erhaltene Diagnosehistorie: OPS-005-Provider-Negativfall

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erhaltene-diagnosehistorie-ops-005-provider-negativfall).

### Geplanter Windows-Fixturepfad für OPS-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#geplanter-windows-fixturepfad-f%C3%BCr-ops-005).

#### Plattform und Zuständigkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#plattform-und-zust%C3%A4ndigkeit).

#### Voraussetzungen vor der Providerprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-vor-der-providerprobe).

#### Fachlicher Abnahmeblock

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fachlicher-abnahmeblock).

#### Cleanup, Nachweise und vorgeschlagene Freigabegrenze

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#cleanup-nachweise-und-vorgeschlagene-freigabegrenze).

#### Zulassung vor der Runanlage

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zulassung-vor-der-runanlage).

#### Wiederaufnahme nach Integration der Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-integration-der-lab-korrektur).

#### Windows-Abbruch am Aktivierungsintent

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-abbruch-am-aktivierungsintent).

#### Zusatzrun endet an der Lab-Collation-Gastprobe

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zusatzrun-endet-an-der-lab-collation-gastprobe).

#### Nachabnahme mit qualifizierter Lab-Korrektur

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#nachabnahme-mit-qualifizierter-lab-korrektur).

#### Markerkorrektur bestätigt; Installation am Kommentar-GO blockiert

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#markerkorrektur-best%C3%A4tigt-installation-am-kommentar-go-blockiert).

#### Installation bestätigt; Guardzustand 54890 unbekannt

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#installation-best%C3%A4tigt-guardzustand-54890-unbekannt).

#### Windows-Providerabnahme vom 22. Oktober 2026 bestanden

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#windows-providerabnahme-vom-22-oktober-2026-bestanden).

### Autorisierter Foundation-Folgeauftrag

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#autorisierter-foundation-folgeauftrag).

## Abgeschlossene Findings-Stabilisierung vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-findings-stabilisierung-vom-20-oktober-2026).

## Frühere Nichtqualifikation und integrierter OPS-005-Prüfschritt vom 20. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#fr%C3%BChere-nichtqualifikation-und-integrierter-ops-005-pr%C3%BCfschritt-vom-20-oktober-2026).

## Regelübernahme für Testbewertung vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#regel%C3%BCbernahme-f%C3%BCr-testbewertung-vom-19-oktober-2026).

## Freigegebene Lookup-/Cacheanalyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-lookup-cacheanalyse-vom-19-oktober-2026).

## Freigegebene Legacy-Lifecycle-Analyse vom 19. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-lifecycle-analyse-vom-19-oktober-2026).

## Lieferung der begrenzten Komponentenphasen-Erweiterung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#lieferung-der-begrenzten-komponentenphasen-erweiterung).

## Freigegebene PCT_EN_2-Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-pct_en_2-fortsetzung).

## Freigegebene Legacy-Komponentenphasenzeiten vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-komponentenphasenzeiten-vom-18-oktober-2026).

## Freigegebene ORPS_EN_2-Fortsetzung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-orps_en_2-fortsetzung-vom-18-oktober-2026).

## Freigegebene Legacy-Zeilenflusserweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-zeilenflusserweiterung-vom-18-oktober-2026).

## Freigegebene Legacy-Taskerweiterung vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-legacy-taskerweiterung-vom-18-oktober-2026).

## Abgeschlossene begrenzte Legacy-Providerabnahme vom 18. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossene-begrenzte-legacy-providerabnahme-vom-18-oktober-2026).

## Ergänzender abgeschlossener Mail-Retentionsnachweis

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#erg%C3%A4nzender-abgeschlossener-mail-retentionsnachweis).

## Zurückgestellter SSIS-Backlog vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#zur%C3%BCckgestellter-ssis-backlog-vom-16-oktober-2026).

## Aktuelle SSIS-Kataloglieferung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktuelle-ssis-kataloglieferung-vom-16-oktober-2026).

## WI-0009: qualifizierter portabler Kern und offenes Feature-Gate

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wi-0009-qualifizierter-portabler-kern-und-offenes-feature-gate).

## Aktueller WI-0005-Abschluss vom 14. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-wi-0005-abschluss-vom-14-oktober-2026).

## Aktueller Fertigstellungsauftrag vom 13. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-fertigstellungsauftrag-vom-13-oktober-2026).

## Wiederaufnahme nach der Entwicklungspause

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#wiederaufnahme-nach-der-entwicklungspause).

## Maßgeblichkeit

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#ma%C3%9Fgeblichkeit).

## Auftrag zur autonomen Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#auftrag-zur-autonomen-fortsetzung).

### Voraussetzungen und Abnahmen der Fortsetzung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#voraussetzungen-und-abnahmen-der-fortsetzung).

## Sessionwechsel bei langer autonomer Entwicklung

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#sessionwechsel-bei-langer-autonomer-entwicklung).

## Aktueller Produktstand

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#aktueller-produktstand).

### Abgeschlossen – SQL25-005

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#abgeschlossen--sql25-005).

## Nächste ausführbare Welle: Reifeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#n%C3%A4chste-ausf%C3%BChrbare-welle-reifeabschluss).

## Exit-Kriterien

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#exit-kriterien).

## Freigegebene SSIS-Legacy-Umsetzung vom 16. Oktober 2026

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-ssis-legacy-umsetzung-vom-16-oktober-2026).

## Begrenzte Taskerweiterung: lokaler Abnahmeabschluss

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#begrenzte-taskerweiterung-lokaler-abnahmeabschluss).

### Verarbeitungsaufwand der SSIS-Vertrauensausnahme

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#verarbeitungsaufwand-der-ssis-vertrauensausnahme).

## Gesondert freigegebene SSIS-Dataflowkorrelation

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#gesondert-freigegebene-ssis-dataflowkorrelation).

## Freigegebene neunte SSIS-Welle

Historischer Abschnitt: [Archiv öffnen](Next_Steps_History_2026-11-05.md#freigegebene-neunte-ssis-welle).
