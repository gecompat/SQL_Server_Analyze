# Datenbankprincipals, direkte Rechte und sichtbare Loginbindungen

**Stand:** 25. Oktober 2026.
**Status:** erster Datenbank-Implementierungskandidat; Produktreview und abschließende native Abnahme offen.
**Artefakt-UID:** `urn:uuid:01a171d2-85e1-7474-be43-b3173fc4df92`.
**Registrierung:** `DEFERRED`; keine zusätzliche lesbare Kennung vergeben.
**Arbeitselement:** weiterer Teil von `WI-0012`; kein zusätzliches Arbeitselement für denselben Principal-Scope.
**Planung:** weiterer Teil von Rang 6 der
[Entwicklungswellen](../Quality/Development_Waves_2026-10.md), ergänzend zum
[Serverprincipal-Dossier](Server_Principal_Analysis_Dossier.md).

## Diagnosefrage und bestehende Abdeckung

Der Bericht soll für die ausgewählten Datenbanken sichtbare
Benutzer und Rollen, direkte Rollenmitgliedschaften, explizite Rechte und
Ownership zeigen. Ein getrennter Bindungsbefund soll erkennen lassen, ob ein
instanzgebundener SQL-Benutzer einen sichtbaren Login mit gleicher SID besitzt.
Ein fehlender sichtbarer Treffer ist kein Beweis eines verwaisten Benutzers.

Die Serverprincipal-Analyse betrifft Servermetadaten. Die vorhandenen
External-Runtime- und CLR-Berichte verwenden Datenbankprincipals nur zur
optionalen Auflösung einzelner Owner- oder EXECUTE-AS-Namen. Daraus entsteht
kein eigenständiger Datenbankprincipal-/Rollenbericht. Der neue Vorschlag
ändert diese bestehenden Berichte nicht.

Der übernommene Benutzerauftrag autorisiert die fachliche Konkretisierung und
anschließende autonome Umsetzung. Die Implementierung beginnt nach unabhängigem
Review des konkretisierten Vertrags. Rechteerweiterungen, externe
Identitätsabfragen und Eingriffe in bestehende Benutzer oder Logins gehören
nicht zu diesem lesenden Bericht.

## Datenbankgrenze und Quellen

Vorgeschlagen wird `[monitor].[USP_DatabasePrincipalAnalysis]` mit dem festen
frameworkweiten Auswahlvertrag: Ohne Filter werden alle sichtbaren
Online-Benutzerdatenbanken verarbeitet. `@DatabaseNames nvarchar(max)=NULL`
verwendet exakte bracket-aware Pipe-Listen; der getrennte Parameter
`@DatabaseNamePattern nvarchar(4000)=NULL` verwendet den vorhandenen
LIKE-/versionsabhängigen Regexvertrag. Systemdatenbanken bleiben über
`@SystemdatenbankenEinbeziehen bit=0` ausgeschlossen und sind ausdrücklich
opt-in. CURRENT-Scope und @MaxDatenbanken werden nicht eingeführt. Die
vorhandene Kandidatenvorbereitung wird wiederverwendet.

Intern wird jeder Kandidat einzeln in seinem Zielkontext gelesen und erhält
einen eigenen Status. Der jeweilige Datenbankname wird als Bezeichner mit
QUOTENAME verarbeitet; fachliche Werte werden parametrisiert. Der Bericht verwendet
ausschließlich den Caller-Kontext und ändert weder Datenbankzugriff noch
TRUSTWORTHY, Cross-Database-Chaining oder Besitzketten.

Fehlende Metadatensicht und tatsächliche Abwesenheit können zusammenfallen.
Ein nicht auflösbarer Datenbankname erhält deshalb einen entsprechenden
begrenzten Befund; es wird kein sicherer NOT_FOUND-Nachweis behauptet.
Offlinezustand, fehlender Zugriff und ein während der Aufnahme veränderter
Datenbankzustand bleiben von einem erfolgreich gelesenen Leerfall getrennt.
Die späteren konkreten Statuswerte werden vor Implementierung mit dem
bestehenden Modulstatusvertrag abgeglichen.

| Quelle | Benötigter Inhalt | Grenze |
|---|---|---|
| `sys.databases` | Sichtbare Zielidentität, Zustand, Containment und Ownerbindung | Die Sichtbarkeit einer Zeile beweist keinen Zugriff auf die Zielkataloge. Eine Owner-SID ist keine Loginfähigkeitsprüfung. |
| Ziel-`sys.database_principals` | Principal-ID, Name, Typ, Authentifizierungstyp, Standardschema, Zeitfelder, Rollenownership und feste Rollen | Sichtbare Principals sind keine vollständige Identitätsinventur. Enthaltene Benutzer und NONE-/WINDOWS-/EXTERNAL-Authentifizierung werden getrennt behandelt. |
| Ziel-`sys.database_role_members` | Direkte Rollen- und Mitglied-ID | Verschachtelung bleibt als einzelne Kante sichtbar; transitive oder effektive Rechte werden nicht berechnet. |
| Ziel-`sys.database_permissions` | Grantee, Grantor, Klasse, Major-/Minor-ID, Recht und Zustand | Implizite Rechte fester Rollen fehlen. Spaltenausnahmen einschließlich REVOKE bleiben eigenständige native Zeilen. |
| Ziel-`sys.schemas` | Schema-ID, Name und expliziter Schemaowner | Schemaownership beweist keine vollständige effektive Berechtigungskette. Abweichende Objektowner bleiben ein späterer Teilumfang. |
| `sys.server_principals` | Sichtbare lokale Loginidentität und interne SID-Bindung | Fehlende Zeile kann eingeschränkte Sicht bedeuten. Externe Gruppen und Loginberechtigung werden nicht ausgewertet. |

Die Quellen erhalten getrennte Zeitklammern und Statuszeilen. Ihre Aufnahmen
sind keine atomare Sicherheitstransaktion. Native IDs sind nur innerhalb der
angegebenen Instanz, Datenbank und Aufnahme interpretierbar. Unbekannte
Securityklassen werden mit ihren nativen Identitätsfeldern erhalten und nicht
durch geratene Objektnamen ersetzt.

Die fachlichen Datenbanksets enthalten jeweils Datenbank-ID und Namen als
Bindung ihrer lokalen Principal-, Schema- und Securable-IDs. Sichtbare
Rollenkanten und Berechtigungen bleiben bei fehlendem Namenslookup erhalten.
Die Serverprincipalsicht wird einmal je Aufruf materialisiert, während die
Datenbankquellen je Kandidat isoliert werden. Ein erfolgreicher Bericht bleibt
AVAILABLE_LIMITED mit IsPartial=1 und einer VISIBLE_ONLY-Grenze; ein Ausgabelimit
oder eine erfolgreiche leere Sicht beweist keine Vollständigkeit.

SID-Werte werden ausschließlich intern zum Vergleich verwendet und nicht
ausgegeben. Passwortwerte, Passwort-Hashes, Credentialinhalte, Schlüssel,
Tokens und Anwendungsdaten werden nicht gelesen. Sichtbare Namen bleiben in
der diagnostischen Laufzeitausgabe erhalten; versionierte Beispiele und Tests
verwenden ausschließlich synthetische Werte.

## Vorgesehene Bindungsbefunde

Ein positiver SID-Vergleich bedeutet nur MATCHED_VISIBLE_LOGIN. Der Bericht
bestätigt damit weder eine erfolgreiche Anmeldung noch gültige Gruppenauflösung,
CONNECT-Rechte oder wirksame Passwortregeln. Ein instanzgebundener SQL-Benutzer
ohne sichtbaren Treffer erhält NO_VISIBLE_LOGIN_MATCH und eine ausdrückliche
Vollständigkeitsgrenze. Der Bericht repariert keine Bindung.

Der Vergleich betrifft ausschließlich INSTANCE-authentifizierte SQL_USER und
sichtbare SQL_LOGIN-Principals. Scheitert eine erforderliche Quelle, wird
SOURCE_UNAVAILABLE ausgewiesen; der Fehlschlag wird nicht in einen fehlenden
sichtbaren Login-Treffer umgedeutet.

Benutzer mit DATABASE-Authentifizierung sind enthaltene Benutzer und benötigen
für diese Einordnung keinen Serverlogin. NONE, WINDOWS und EXTERNAL werden
nicht pauschal als verwaiste SQL-Benutzer behandelt. dbo, guest, sys,
INFORMATION_SCHEMA, Rollen, Zertifikats- und asymmetrische Schlüsselbenutzer
erhalten keinen solchen Fehlbefund. Externe Identitäten und Gruppen bleiben
ohne Directoryabfrage nur Katalogmetadaten.

## Vorgeschlagene Ausgabe und Fehlerbehandlung

Die gemeinsame Ausgabe übernimmt CONSOLE, RAW, TABLE und NONE sowie getrenntes
optionales JSON. Vorgesehen sind neun benannte Resultsets:

| Resultset | Fachlicher Inhalt |
|---|---|
| `moduleStatus` | Zielbezug, Aufnahmezeit, Status, Partialität und Grenze des Berichts. |
| `databaseContext` | Sichtbare Zielidentität, Zustand, Containment und begrenzte Ownerzuordnung. |
| `principals` | Lokale Principal-ID und sichtbarer Name, Typ, Authentifizierungstyp, Standardschema, Zeitfelder, feste Rolle und OwningPrincipalId. |
| `roleMemberships` | Direkte Rollen-/Mitglied-IDs und optional sichtbare Namen. |
| `permissions` | Grantee-/Grantor-IDs, optionale Namen, native Klasse, Major-/Minor-ID, Recht und Zustand einschließlich R. |
| `schemaOwners` | Schema-ID, sichtbarer Name und Owner-ID mit optionalem Namen. |
| `loginBindings` | Datenbankprincipal, begrenzter Bindungsbefund und gegebenenfalls sichtbare Serverprincipal-ID und Name; keine rohe SID. |
| `sourceStatus` | Quellschlüssel, Zeitklammer, Sichtbarkeitsgrenze, beobachtete und ausgegebene Menge sowie native Fehlerdaten. |
| `warnings` | Quellen-, Sichtbarkeits-, Ausgabelimit- und fachliche Aussagegrenzen. |

Der Vorschlag verwendet `@MaxZeilen int=1000` je fachlichem Mengenset; 0 oder
NULL bedeutet unbegrenzt. Das Limit gilt global je principals,
roleMemberships, permissions, schemaOwners und loginBindings über die gewählten
Datenbanken, mit deterministischer Reihenfolge nach Datenbank-ID und nativen
Fachschlüsseln. Kontext-, Status- und Warnsets bleiben ungekürzt. Namens- und
SID-Bindungen entstehen vor Kürzung,
damit ein Ausgabelimit keine falschen fehlenden Bindungen erzeugt. Das Limit
begrenzt die Ausgabe, nicht die vorgelagerte Katalogarbeit.

Der technische V1-Vertrag steht in den kanonischen Inventaren für
[Parameter](../../../Metadata/Inventory/Parameters.csv) und
[Resultsets](../../../Metadata/Inventory/ResultSets.csv). Die neun benannten
Mengen besitzen dort feste Feldfolge, native Typen, Nullbarkeit und explizite
Textcollations. Die 15 Parameter umfassen die drei Auswahlparameter sowie den
bestehenden MaxZeilen-, Locktimeout-, Ausgabe-, JSON-, Hilfe-, Print- und
Status-/Fehlervertrag. LockTimeoutMs bleibt 0 und ist von 0 bis 60000 zulässig;
NULL ist ungültig. Diese Konkretisierung ist vor Implementierung unabhängig
geprüft. Einzelquelle, Installer, Inventare, Navigator, Procedure-Seite und
Vertrag 136 bilden nun den Produktkandidaten; seine abschließenden Gates bleiben
erforderlich. Die bestehende Serverprocedure erhält im selben Principal-Scope
eine Korrektur des positiven Locktimeoutpfads: SET und fachlicher Zugriff müssen
im selben dynamischen Batch liegen. Ein vorher separat ausgeführtes SET wirkt
nicht auf den anschließend ausgeführten Quellbatch.

sourceStatus unterscheidet NATIVE, DERIVED und SELECTION über SourceKind.
Die intern benötigte Serverprincipalsicht erhält ObservedRows, aber mangels
eigenem Server-Fachresultset keine vorgetäuschte ReturnedRows-Menge. Eine
ausgefallene Quelle besitzt unbekannte Mengen statt künstlicher Nullcounts.
Abgeleitete Loginbindungen und Auswahlwarnungen bleiben von tatsächlich
ausgeführten Katalogqueries getrennt. Nicht benötigte Quellen werden als
SKIPPED erkennbar, ohne einen Quellenzugriff zu behaupten.

Loginbindungen verwenden MATCHED_VISIBLE_LOGIN, NO_VISIBLE_LOGIN_MATCH,
SOURCE_UNAVAILABLE, DATABASE_AUTHENTICATED und NOT_APPLICABLE. Benutzer mit
DATABASE-Authentifizierung besitzen keinen fehlenden Login; andere vom
INSTANCE-/SQL_USER-Vergleich ausgeschlossene Typen sind NOT_APPLICABLE.
Der Ownerbefund ist ebenfalls nur eine sichtbare SID-Bindung und keine
Ownership- oder Loginfähigkeitsgarantie über die Katalogaussage hinaus.

OwnerBindingStatus folgt dieser Reihenfolge; die erste zutreffende Bedingung
entscheidet. OwnerPrincipalId, OwnerName und OwnerPrincipalType bleiben außer
bei den beiden ausdrücklich genannten einzelnen Treffern NULL.

| OwnerBindingStatus | Bedingung und ausgegebene Identität |
|---|---|
| SOURCE_UNAVAILABLE | Zielkontextquelle oder benötigte Serverprincipalsicht ist fehlgeschlagen. Ein Quellenfehler wird nicht als fehlender Owner interpretiert. |
| OWNER_SID_UNAVAILABLE | Beide Quellen wurden gelesen, aber owner_sid ist NULL oder leer; keine Identität wird geraten. |
| AMBIGUOUS_VISIBLE_OWNER_MATCH | Mehrere sichtbare Serverprincipals besitzen die erfasste owner_sid; es wird kein beliebiger Owner ausgewählt. |
| MATCHED_VISIBLE_OWNER | Genau ein sichtbarer SID-Treffer ist SQL_LOGIN (`S`) oder WINDOWS_LOGIN (`U`); seine ID, sein Name und sein Typ werden ausgegeben. |
| UNSUPPORTED_PRINCIPAL_TYPE | Genau ein sichtbarer SID-Treffer besitzt einen anderen Typ. ID, Name und Typ bleiben als Katalogbefund sichtbar; eine gültige Ownereignung wird nicht behauptet. |
| NO_VISIBLE_OWNER_MATCH | Kein sichtbarer SID-Treffer. Unvollständige Metadatensicht und Windowsbenutzer über Gruppen bleiben mögliche Ursachen; dies beweist keinen verwaisten oder ungültigen Owner. |

Dieser SQL-Server-Vertrag löst weder Windowsgruppen auf noch prüft er die
Ownereignung von Entra- oder anderen externen Identitäten. Die Bedingungen
für eine Änderung des Owners sind kein aus einer SID-Gleichheit abgeleiteter
Wirksamkeitsnachweis. Der Bericht führt selbst keine Owneränderung aus.

Erwartete Parameter-/TABLE-Ablehnungen und gefangene äußere Fehler sollen
regulär mit Status, Diagnose-OUTPUT und RETURN-Code zurückkehren; JSON bleibt
dabei NULL. Der Caller muss diese Werte prüfen. Die Procedure übernimmt weder
Commit noch Rollback einer vorhandenen Transaktion. Ein isolierter
Quellenfehler erhält die übrigen gelesenen Mengen, sofern die Engine die
Transaktion weiter zulässt. Nicht gefangene Engine- oder Verbindungsabbrüche
besitzen keine garantierte Rückgabe oder Wiederherstellung.

## Unabhängige Abnahme und Liefergrenze

Die synthetische Fixture benötigt eigene Ziel- und Frameworkbindungen, direkte
und verschachtelte Rollen, einen Loginbenutzer, einen absichtlich fehlenden
sichtbaren SID-Treffer, einen enthaltenen Benutzer beziehungsweise dessen
gesondert ausgewiesene Capabilitygrenze sowie einen Benutzer ohne Login.
Eigene Grants, DENYs, GRANT_WITH_GRANT_OPTION und eine native
Spalten-REVOKE-Ausnahme werden gegen unabhängig festgelegte Sollwerte geprüft.
Ein fehlender Login wird nur für eine eigene synthetische Identität hergestellt;
vorhandene Logins werden nicht verändert.

Weitere Pflichtfälle sind eingeschränkte Caller, nicht zugängliche oder nicht
sichtbare Ziele, getrennte Quellenfehler, Limits ohne verfälschte Bindungen,
leere Teilmengen, alle Ausgabemodi und JSON-Parität. Mehrere eigene Datenbanken
mit gleichen lokalen Principal-IDs prüfen die Datenbankbindung. Ungefilterte
Auswahl, Systemdatenbank-Opt-in, bracket-aware Namenslisten, getrennte Pattern
und ungültige Kombinationen prüfen den gemeinsamen Auswahlvertrag. Die native Schemaprüfung
vergleicht alle Feldfacetten gegen eigenständige typisierte Solltabellen.
Fehlerpfade prüfen OUTPUT, RETURN, JSON-NULL, LOCK_TIMEOUT, beide
XACT_ABORT-Zustände, committable Ambienttransaktion und einen unabhängigen
Sentinel. Erfolgs- und Fehlercleanup binden eigene Datenbanken, Principals,
Rollen und Berechtigungen an ihre erfassten nativen Identitäten.

Die Quellen prüfen ihre Zielbindung vor und nach jeder lokalen Abfrage anhand
von ID, Name und erfasstem create_date. Abweichungen verwerfen die jeweilige
Teilmenge mit DATABASE_UNAVAILABLE und dem lokalen Diagnosecode 51012. Die
Fixture prüft den tatsächlich verwendeten Guard separat mit gültiger Bindung
sowie abweichender ID, abweichendem Namen und abweichendem create_date. Dies
ist ein Stufentest des Guards; ein zeitgleicher Rename-/Drop-Rennfall der
vollständigen Procedure wird damit nicht als nachgewiesen ausgegeben.

Die Fixture sichert konfigurierte und laufende Werte ihrer beiden
Konfigurationsoptionen. Vorhandene ausstehende dynamische Änderungen führen
vor jeder Mutation zum Abbruch. Die dokumentierten Standardnormalisierungen
für min server memory (0/16) und max server memory (0/2147483647) gelten dabei
nicht als ausstehende Änderungen. Eigentumsflags werden nach sp_configure vor
RECONFIGURE gesetzt, damit auch dessen Fehler den Bereinigungsweg aktiviert.

SQL Server 2025 bleibt die primäre Engine. Konkrete Unterschiede der älteren
Securitykataloge und Berechtigungsmodelle werden gemäß
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md) auf den
betroffenen nativen Engines geprüft. Compatibility Levels ersetzen diese
Nachweise nicht. Windows-/Entra-Anmeldung, Directoryauflösung und externe
Gruppen werden mit einer Linux-Katalogfixture nicht als qualifiziert ausgegeben.

Zur Produktlieferung gehören Einzelquelle, Installer, Navigator, Inventare,
Procedure-Lesepfad und die betroffenen Tests gemeinsam. Dieser Entwurf ändert
noch keinen Produktstatus und schließt Rang 6 nicht ab. Effektive Rechte,
abweichende Objektownership, externe Identitätsprüfung und tatsächliche
Loginfähigkeit bleiben weitere ausdrücklich offene Teilumfänge.

## Primärquellen

- Microsoft Learn: [Serverkonfigurationswerte und Standardnormalisierungen](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/server-configuration-options-sql-server?view=sql-server-ver17).

- Microsoft Learn: [sys.database_principals](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_role_members](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-role-members-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.schemas](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/schemas-catalog-views-sys-schemas?view=sql-server-ver17).
- Microsoft Learn: [verwaiste Benutzerbindungen](https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server?view=sql-server-ver17).
- Microsoft Learn: [Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration?view=sql-server-ver17).
- Microsoft Learn: [ALTER AUTHORIZATION und Datenbankowner](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-authorization-transact-sql?view=sql-server-ver17).
