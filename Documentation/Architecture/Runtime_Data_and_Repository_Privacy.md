# Datenschutzgrenze zwischen Laufzeitausgabe und Repository

**Status:** verbindliche Architekturentscheidung  
**Stand:** 17. Juli 2026  
**Geltungsbereich:** Quellcode, Dokumentation, Tests, Metadaten, Build- und Lieferartefakte sowie alle späteren Persistenz- oder Exportfunktionen

## 1. Entscheidung

Das Diagnoseframework darf in einer unmittelbar angeforderten Laufzeitausgabe die zur Diagnose erforderlichen Identitäts- und Umgebungsinformationen anzeigen. Dazu gehören beispielsweise Session- und Request-IDs, Login- und Benutzernamen, Host- und Anwendungsnamen, Server-, Datenbank-, Schema- und Objektnamen sowie SQL-Text.

Solche realen Werte dürfen jedoch niemals Bestandteil eines herunterladbaren oder versionierten Artefakts werden. Verboten sind insbesondere reale Benutzer-IDs, Benutzernamen, Firmennamen sowie benutzerdefinierte oder sonstige personen- beziehungsweise umgebungsbezogene Informationen in:

- Repositorydateien und Git-Commits,
- Dokumentation, Screenshots und Beispielausgaben,
- Testdaten, Fixtures und erwarteten Testergebnissen,
- CSV-, JSON-, XML-, Text-, Log- und Diagnoseexporten,
- Build-, Installations- und Lieferpaketen einschließlich ZIP-Dateien,
- Audit-, Forschungs- und Fehlerberichten,
- späteren Snapshot-, Baseline-, Retention- oder DWH-Daten, sofern diese als Projektartefakt exportiert werden.

Im Zweifel muss vor einer Aufnahme in ein Artefakt nachgefragt werden. Schweigen oder eine vermutete Harmlosigkeit gilt nicht als Freigabe.

## 2. Warum die frühere pauschale Formulierung falsch war

Die frühere Aussage, solche Informationen dürften grundsätzlich nie ausgegeben werden, vermischte zwei verschiedene Datenflüsse:

1. **Interaktive Diagnose:** Ein berechtigter Operator fragt den aktuellen Zustand des eigenen SQL Servers ab. Identitäts- und Umgebungswerte sind hier häufig fachlich notwendig, etwa um eine blockierende Session einem Login, Host oder Programm zuzuordnen.
2. **Persistierbares Projektartefakt:** Informationen werden gespeichert, weitergegeben, heruntergeladen oder versioniert. Hier besteht das Risiko, dass Betriebs-, Kunden- oder Personendaten dauerhaft im Repository oder in dessen Historie landen.

Ein pauschales Verbot in der ersten Ebene würde wesentliche Diagnosefunktionen unbrauchbar machen. Die verbindliche Grenze liegt deshalb beim Übergang von flüchtiger Laufzeitausgabe zu einem persistierbaren Artefakt.

## 3. Klassifikation der Datenflüsse

| Datenfluss | Reale Laufzeitwerte zulässig? | Regel |
|---|---:|---|
| Direktes SELECT-Resultset in SSMS/ADS | Ja | Nur im Rahmen der SQL-Server-Berechtigungen und des angeforderten Diagnosezwecks |
| CONSOLE- oder RAW-Resultset | Ja | Darf Identitäten und Umgebungsnamen diagnostisch anzeigen |
| JSON als OUTPUT-Parameter | Ja, solange nur flüchtig verwendet | Der aufrufende Consumer darf es nicht ungeprüft als Projektartefakt speichern |
| Vom Benutzer bewusst lokal gespeicherte Abfrageausgabe | Nicht Teil des Repositorys | Verantwortung und Speicherzweck müssen außerhalb des Projektpakets geklärt werden |
| Beispielausgabe in Dokumentation oder Issue | Nein | Ausschließlich synthetische Platzhalter verwenden |
| Testfixture, Snapshot oder Golden File | Nein | Ausschließlich synthetische, nicht rückführbare Daten verwenden |
| Repository, Commit, Pull Request oder Release | Nein | Keine realen Identitäts-, Unternehmens-, Kunden- oder Umgebungswerte |
| Downloadbares ZIP oder generierter Installer | Nein | Vor Auslieferung auf eingebettete Daten und unerwartete Dateien prüfen |
| Spätere interne Snapshotfunktion im Zielsystem | Nur nach eigenem Datenschutzkonzept | Zweck, Zugriff, Retention, Löschung und Exportgrenze müssen separat entschieden werden |

Wichtig: Ein JSON-, CSV- oder Textwert ist nicht deshalb sicher, weil er technisch nur Ausgabe einer Procedure ist. Sobald er gespeichert oder weitergegeben wird, ist er ein Artefakt und unterliegt dem Verbot.

## 4. Betroffene Informationsklassen

Die folgende Liste ist bewusst weiter als klassische personenbezogene Daten. Ziel ist auch, versehentliche Betriebs- und Kundendaten aus dem Repository fernzuhalten.

### Identitäten und Akteure

- Login-, Benutzer-, Rollen-, Gruppen- und Dienstkontonamen,
- Benutzer-, Principal-, Session-, Request-, Connection- und Transaktions-IDs, sofern sie aus einer realen Umgebung stammen,
- E-Mail-Adressen, Operatoren, Empfänger und Ansprechpartner,
- Host-, Client-, Workstation-, Anwendungs- und Programmnamen,
- IP-Adressen, DNS-Namen, Domains und Verbindungsendpunkte.

### Organisation und Umgebung

- Firmen-, Kunden-, Mandanten-, Abteilungs- und Projektnamen,
- reale Server-, Instanz-, Cluster-, Availability-Group-, Listener- und Datenbanknamen,
- reale Schema-, Tabellen-, Spalten-, Index-, Job-, Queue-, Publication- und Subscription-Namen,
- Dateipfade, Laufwerksnamen, Freigaben, URLs und Cloud-Ressourcen aus realen Umgebungen.

### Benutzerdefinierte Inhalte

- SQL-Texte und Input Buffer mit Literalen oder Kommentaren,
- Planparameter, Parameterwerte und Query-Store-Texte,
- Fehlermeldungen, Error-Log-Text, Agent-Output und Extended-Events-Payloads,
- Service-Broker-Nachrichteninhalte,
- benutzerdefinierte Extended-Events-Felder, Tags und Freitext,
- fachliche Beispielwerte, die auf Personen, Kunden oder reale Vorgänge schließen lassen.

## 5. Was ausdrücklich nicht verboten ist

Die Regel darf nicht so ausgelegt werden, dass der Quellcode keine generischen Systembegriffe mehr verwenden dürfte.

Zulässig sind:

- technische SQL-Server-Spalten- und Parameternamen wie login_name, session_id oder database_id,
- synthetische Platzhalter wie BeispielLogin, BeispielFirma, BeispielServer oder BeispielDatenbank,
- generische Schema- und Objektbezeichner wie monitor, dbo oder BeispielObjekt,
- öffentliche Produkt-, Hersteller- und Projektnamen in fachlichen Quellenangaben,
- bewusst veröffentlichte Lizenz-, Urheber- und Attributionstexte,
- öffentliche Links und bibliografische Angaben zu verwendeten Primär- und Referenzquellen.

Öffentliche Attribution ist kein versehentlich aus einer Kundenumgebung extrahierter Firmen- oder Benutzerwert. Sie bleibt erhalten, weil Lizenz und Herkunft nachvollziehbar sein müssen. Neue personenbezogene oder organisationsbezogene Attribution darf dennoch nicht ohne fachlichen Grund ergänzt werden.

## 6. Regeln für Quellcode und Laufzeit

1. Die Procedures dürfen reale Werte selektieren, wenn diese für die angeforderte Diagnose relevant sind.
2. Der Code darf solche Werte nicht hart codieren.
3. Standardpfade bleiben zustandslos und speichern keine Resultsets.
4. SQL-Text, Input Buffer, Query-Store-Text, Planparameter, Error-Log-Text und Ereignispayloads gelten als besonders sensibel. Ihre Anzeige muss fachlich begründet, berechtigungsgebunden und bei teuren Quellen opt-in sein.
5. Ein späterer Exportmodus benötigt eine eigene Redaktions- oder Pseudonymisierungsentscheidung. Die bestehende Laufzeitausgabe ist keine Freigabe für einen Export.
6. Service-Broker-Nachrichtenkörper, Secrets, Kennwörter, Tokens, Schlüsselmaterial und Verbindungszeichenfolgen dürfen weder standardmäßig ausgegeben noch in Projektartefakte übernommen werden.
7. Fehlende Berechtigungen werden als Status ausgegeben; sie werden nicht durch zusätzliche Rechtevergabe umgangen.

## 7. Regeln für Dokumentation, Tests und Forschung

- Alle Beispiele müssen synthetisch sein und erkennbar generische Bezeichner verwenden.
- Laufzeitausgaben dürfen nicht aus einer realen Umgebung kopiert und anschließend nur teilweise geschwärzt werden. Sicherer ist eine vollständig synthetische Rekonstruktion.
- Screenshots realer Verwaltungstools sind ohne vorherige vollständige Prüfung ungeeignet.
- Issues, Chatprotokolle und Reviewkommentare sind ebenfalls persistierbare Artefakte.
- Externe Beispielcodes werden nicht zusammen mit deren realen Umgebungswerten übernommen.
- Forschungsquellen werden verlinkt und zusammengefasst; fremder Code wird nicht ungeprüft kopiert.
- Prüfergebnisse nennen Regeln, Anzahl und Status, aber keine gefundenen sensitiven Werte.

## 8. Prüfvertrag vor Commit und ZIP

Vor jeder Lieferung sind mindestens folgende Prüfungen auszuführen:

1. Nur beabsichtigte Dateien befinden sich im Lieferumfang.
2. Der ZIP-Root ist ausschließlich SQL_Server_Analyze.
3. Git-Metadaten, temporäre Dateien, generierte Installer, Logs und lokale Abfrageergebnisse sind ausgeschlossen.
4. Neue oder geänderte Dokumente, Beispiele, Testdaten und Metadaten werden auf E-Mail-Adressen, IP-Adressen, Domains, lokale Pfade und realistisch wirkende Identitäts- oder Umgebungsnamen geprüft.
5. SQL-Dateien werden auf hart codierte Logins, Server, Datenbanken, Pfade, Endpunkte und fachliche Werte geprüft.
6. Synthetische Platzhalter werden manuell auf Eindeutigkeit und Nicht-Rückführbarkeit geprüft.
7. Treffer aus Lizenzen und Quellenangaben werden als beabsichtigte öffentliche Attribution klassifiziert; sie dürfen nicht stillschweigend entfernt werden.
8. Bei einem nicht eindeutig klassifizierbaren Treffer wird die Auslieferung angehalten und nachgefragt.

Automatische Musterprüfungen sind nur ein Filter. Sie können weder alle personenbezogenen Informationen erkennen noch entscheiden, ob ein Name real oder synthetisch ist. Deshalb bleibt eine kontextbezogene Review erforderlich.

## 9. Abnahmekriterien

Die Entscheidung ist erfüllt, wenn:

- interaktive Diagnoseausgaben weiterhin die für die Analyse notwendigen Identitäten und Umgebungsbezüge liefern können,
- keine reale Laufzeitausgabe als Repository-, Test-, Dokumentations- oder Lieferinhalt eingecheckt wird,
- Beispiele ausschließlich synthetische Werte enthalten,
- zukünftige Persistenz- und Exportfunktionen vor ihrer Implementierung ein eigenes Datenschutz-, Berechtigungs-, Retention- und Löschkonzept erhalten,
- ein uneindeutiger Datenfund die Fragepflicht auslöst,
- die Prüfung keine sensitiven Werte selbst in Auditmeldungen vervielfältigt.

## 10. Vorgehen bei einem Fund

Vor einem Commit wird die betroffene Datei nicht übernommen und durch eine synthetische Fassung ersetzt. Ist ein Wert bereits in Git veröffentlicht, genügt das Löschen in einem neuen Commit nicht, weil er in der Historie verbleiben kann. Dann sind Repositoryverantwortliche einzubeziehen und Reichweite, Historienbereinigung, bereits erzeugte Downloads sowie gegebenenfalls weitere Datenschutz- oder Sicherheitsmaßnahmen separat zu bewerten.

