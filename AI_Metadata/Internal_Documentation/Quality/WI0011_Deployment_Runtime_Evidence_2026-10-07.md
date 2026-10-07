# Laufzeitnachweis zum Gesamtdeployment

**Referenz:** EXP-0001

**Arbeitselement:** WI-0011

**Stand:** 7. Oktober 2026

**Status:** lokal ausgeführte und unabhängig geprüfte Evidenz; PR-Head-CI bleibt Liefergate

## Lieferumfang und Nachweisgrenze

Der [Deploymentvertrag](../../../Documentation/Architecture/Lossless_Deployment_Contract.md)
und die [Bedienungsreferenz](../../../Documentation/Reference/Deployment.md)
beschreiben den gelieferten Generator. Der geprüfte Core enthält 166 kanonische
Quellen, neun Tabellen und sechs mögliche Vorzustandsarchive. Mit SnapshotBaseline
sind es 176 Quellen, 20 Tabellen und sieben Archivpfade. Der SHA-256 des
abschließend geprüften optionalen Umfangs lautet
`15764b7c8c96c8752406c36d7603b6fa04775c5c03f66afe9b42c281e6a50c8a`;
der Core-Digest lautet
`5478244801824076fca17c14a4277ad8b2f245b7f5306945a365d5e7d81dc9ad`.
Die erzeugten SQL-Dateien bleiben ableitbare, nicht versionierte Artefakte.

Die nativen Läufe verwendeten ausschließlich neu erzeugte eigene lokale
Testressourcen und synthetische Daten. Die tatsächliche Engine war SQL Server
2025, Version 17.0.5005.3, Enterprise Developer Edition unter Linux. Server und
tempdb verwendeten Latin1_General_100_CS_AS; der Frameworkkontext verwendete
SQL_Latin1_General_CP1_CS_AS und der Snapshotkontext Latin1_General_100_CS_AS.
Diese gezielte Kombination erweitert keine allgemeine Collationgarantie.

## Tatsächlich ausgeführte Prüfungen

Die abschließende vollständige Deploymentregression bestand 58 Batches. Sie
prüfte Erstinstallation, Wiederholung, gefüllte 20 kanonische Tabellen,
Legacy- und Customdaten, lokale Policy, operatorverwaltetes IsEnabled,
Identity- und rowversion-Erhaltung, sieben typgetreue Archivpfade und die zwölf
bekannten additiven Wait-Ergänzungen. NULL, Unicode, nachgestellte Leerzeichen,
Binärwerte und native Zeittypen wurden als Fachwerte verglichen.

Negative Fälle bestätigten den Abbruch bei fehlenden, gleichen oder
Systemdatenbankkontexten, zusätzlichen Spalten, gebundenen Default- und
Indexnamensabweichungen, Customkonflikten und abweichenden markerlosen
Katalogwerten. Externe und implizite Callertransaktionen behielten ihren
vorherigen Transaktions- und Optionszustand. Ein injizierter später
Compilefehler rollte frühe Änderungen beider Datenbanken sowie Runbelege und
Vorzustände zurück.

Ein zusätzlicher unabhängiger Vergleich am vorherigen Produktstand prüfte
alle Werte von 20 kanonischen und drei Legacytabellen, native gruppierte
Constraint-, Index- und Foreign-Key-Zuordnungen, Spaltenfacetten,
Identityzähler und die lokale Policydefinition. Nach dem Konkurrenzabbruch
des Abschlussstands bestand derselbe Vergleich erneut unverändert. Dieser
ergänzende Vergleich wird nicht als frischer erfolgreicher Gesamtdeploymentlauf
des abschließenden Digests ausgewiesen.

Ein CONNECT-only-Grantee mit Metadatensicht wurde vor Produktänderungen mit
53901 abgewiesen. Ein gewöhnlicher CONTROL-Grantee ohne db_owner führte am
Abschlussstand Erstinstallation und Wiederholung erfolgreich aus; der
Wiederholungstest verlangte ausdrücklich einen nicht unbekannten Rollenwert
`0`. Die synthetischen Benutzer und Logins wurden danach entfernt.

Die Konkurrenzgegenprobe hielt die gemeinsame TempMetadata-Anwendungssperre
des Abschlussstands während eines eigenen laufenden Deployments. Ein zweiter
Lauf auf einem anderen Datenbankpaar brach nach dem vorgesehenen Timeout mit
53923 ab. Der erste Lauf schloss seine vollständige Regression erfolgreich
ab. Eine ausschließlich private Warteinstrumentierung ermöglichte die
deterministische Beobachtung; kanonische Produktbatches blieben unverändert.
Ein früherer Cross-Pair-Deadlock in tempdb-Metadaten führte zu dieser
instanzweiten Serialisierung. Der Abschlusslauf zeigte diesen Fehler nicht.

Das vollständige funktionale Core-Gate bestand auf Compatibility Level 170
in 130 Batches. Gezielt betroffene Smoke-, Versions- und Collationverträge
bestanden zusätzlich auf 150 und 160. Diese Läufe sind SQL-Server-2025-
Compatibility-Nachweise und keine nativen SQL-Server-2019-/2022-Nachweise.
Die statische Vertragssuite bestand mit 77 Prüfungen; die 14 Generatorfälle,
Python-Syntaxprüfung, beide Buildvarianten und der direkte Windows-PowerShell-
5.1-Builderlauf bestanden ebenfalls. Ein unabhängiger Abschlussreview hatte
keine offenen Befunde und verglich beide erzeugten SQL-Artefakte exakt mit
dem Generator.

## Verbleibende Grenzen und spätere Fortsetzung

Native ältere Engines, eine Windows-SQL-Engine, Produktionsvolumen sowie
Clientabbruch oder Verbindungsverlust rund um COMMIT wurden nicht geprüft.
Ein verlorener Commitbeleg bleibt bis zur beschriebenen Reconciliation
unbekannt. Unbekannte Strukturmigrationen bleiben kontrollierte Ablehnungen
und benötigen vor einer späteren Unterstützung einen konkreten Vertrag.
Die instanzweite Sperre koordiniert diesen Deploymentweg; fremde tempdb-DDL
oder normale externe DML werden dadurch nicht allgemein serialisiert.

Die repositorybezogene Security-Cloud-Abfrage lieferte keine Findings. Der
zuletzt sichtbare Scan war fehlgeschlagen und betraf einen früheren Commit;
ein erfolgreicher aktueller Sicherheitsnachweis wird daraus nicht abgeleitet.

Der Benutzer hat die Entwicklung nach dieser Lieferung einschließlich PR-
Merge nach origin/main pausiert. Die verbleibenden Reifeschritte und der
Wiedereinstieg stehen ausschließlich in [Next_Steps](Next_Steps.md) sowie den
dort referenzierten kanonischen Statusquellen. Eine Fortsetzung benötigt einen
erneuten Benutzerauftrag. Erforderliche erfolgreiche CI am exakten PR-Head,
Integration, Synchronisierung und eigener Cleanup werden im PR-Verlauf
belegt; sie werden hier nicht vor ihrer Ausführung behauptet.

Der eigene native Lauf wurde über den öffentlichen Lab-Cleanup abgeschlossen.
Eigener Container, eigenes Volume und Secretdatei sind entfernt. Der
geschützte Vorher-/Nachhervergleich bestätigte unveränderte bestehende
Ressourcen und deren Metadaten. Private Evidenz bleibt außerhalb des Repositorys erhalten.
