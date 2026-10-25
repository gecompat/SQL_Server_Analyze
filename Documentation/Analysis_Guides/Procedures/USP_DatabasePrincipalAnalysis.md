# [monitor].[USP_DatabasePrincipalAnalysis]

**Bereich:** Server Health und Datenbanksicherheit
**Zweck:** Zeigt sichtbare direkte Datenbankrechte und begrenzte Identitätsbindungen.
**Beobachtungsart:** getrennte lokale Katalogmomentaufnahmen
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, welche Datenbankprincipals, direkten
Rollenmitgliedschaften, expliziten Rechte und Schemaowner der Caller sieht.
Zusätzlich zeigt sie, ob ein sichtbarer instanzgebundener SQL-Benutzer einen
sichtbaren SQL-Login mit gleicher SID besitzt. Datenbankowner werden getrennt
über ihre erfasste Owner-SID und die sichtbare Serverprincipalsicht zugeordnet.

Der Bericht ist lesend. Er erweitert keine Rechte, aktiviert keine
Authentifizierung und repariert keine Benutzerbindung. Seine Befunde ergänzen
die [Serverprincipal-Analyse](USP_ServerPrincipalAnalysis.md), ersetzen aber
keine Prüfung einer tatsächlichen Anmeldung oder eines konkreten Zugriffspfads.

## Nicht beantwortete Fragen

Die Ausgabe berechnet keine vollständigen effektiven Berechtigungen. Implizite
Rechte fester Rollen, transitive Gruppenauflösung, Windows-/Entra-Verzeichnisse,
Besitzketten, Signaturen, EXECUTE AS und abweichende einzelne Objektowner werden
nicht zu einem gemeinsamen Zugriffsurteil verdichtet. Ein sichtbarer GRANT
oder DENY wird als native Katalogzeile erhalten. Spalten-REVOKE-Ausnahmen
werden nicht als DENY umgedeutet.

Ein fehlender sichtbarer Login-Treffer beweist keinen verwaisten Benutzer.
Ein positiver Treffer beweist weder CONNECT-Rechte noch gültige Credentials
oder eine erfolgreiche Anmeldung. Der Bericht prüft keine Passwortstärke.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis]
    @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
    @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Passen Sie den synthetischen Beispielnamen an das gewünschte Ziel an.
Ohne Namens- oder Patternfilter verwendet der Bericht die frameworkweite
Auswahl sichtbarer und zugreifbarer Online-Benutzerdatenbanken. Die Menge wird
nicht vorab durch eine Datenbankanzahl begrenzt. Systemdatenbanken bleiben
standardmäßig ausgeschlossen. Ein erfolgreicher privilegierter Aufruf bleibt
AVAILABLE_LIMITED mit IsPartial=1, weil die Procedure keinen vollständigen
Securitynachweis erbringt.

## Resultsets und Leserichtung

RAW und TABLE besitzen neun benannte native Mengen. JSON verwendet dieselben
materialisierten Zeilen mit getrennten Metadaten; NONE unterdrückt fachliche
Resultsets und kann JSON sowie Status über OUTPUT liefern. CONSOLE fasst die
Mengen in einer formatierten Übersicht zusammen.

| Resultset | Bedeutung |
|---|---|
| `moduleStatus` | Status, Aufnahmezeit und Summe der ausgegebenen Zeilen der fünf begrenzbaren Fachmengen. Die Summe ist keine Anzahl unterschiedlicher Identitäten. |
| `databaseContext` | Zielidentität, Zustand, Containment und begrenzte Ownerbindung je Kandidat. |
| `principals` | Sichtbare Datenbankprincipals mit Typ, Authentifizierung, Standardschema, Zeitfeldern und Rollenownership. |
| `roleMemberships` | Direkte Rollen-/Mitgliedkanten mit optional sichtbaren Namen. |
| `permissions` | Explizite native Rechte mit Klasse, Major-/Minor-ID, Grantee, Grantor und Zustand. |
| `schemaOwners` | Sichtbare Schemas und ihre Owner-ID mit optionalem Namen. |
| `loginBindings` | Begrenzter Bindungsbefund je sichtbarem Principal; keine rohe SID. |
| `sourceStatus` | Datenbankbezug, Quellschlüssel, SourceKind, Zeitklammer, Status, Sichtbarkeitsgrenze, Mengen und native Fehlerdaten. |
| `warnings` | Auswahl-, Quellen-, Limit- und fachliche Aussagegrenzen. |

Die verbindlichen Feldfolgen, Typen und Nullbarkeiten stehen im
[Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv). Lesen Sie
zuerst die Status- und Warnmengen, dann die betroffenen Fachzeilen.

## Eine Zeile bedeutet

Principal-, Schema-, Objekt- und Rollen-IDs sind lokale Bindungen. Die
Datenbank-ID und der Datenbankname gehören deshalb zur Interpretation jeder
Fachzeile. Die gleiche Principal-ID in zwei Datenbanken bezeichnet nicht
dieselbe Identität. Ein Grantor ist der erfasste Grantor der expliziten
Katalogzeile, kein Nachweis des gesamten Berechtigungsursprungs.

SourceKind=NATIVE bezeichnet eine Katalogaufnahme, DERIVED eine daraus
abgeleitete Bindungsmenge und SELECTION einen Auswahlbefund. Die interne
Serverprincipalsicht besitzt eine beobachtete Menge, aber mangels eigenem
Server-Fachresultset keine vorgetäuschte ReturnedRows-Menge. Ein fehlgeschlagener
nativer Zugriff besitzt unbekannte Mengen statt künstlicher Nullcounts.

## So lesen

MATCHED_VISIBLE_LOGIN bedeutet einen sichtbaren SID-Treffer für einen
INSTANCE-authentifizierten SQL_USER gegen SQL_LOGIN. NO_VISIBLE_LOGIN_MATCH
erhält ausdrücklich die Möglichkeit eingeschränkter Serversicht.
SOURCE_UNAVAILABLE unterscheidet einen Quellenfehler von einem fehlenden
sichtbaren Treffer. DATABASE_AUTHENTICATED kennzeichnet enthaltene Benutzer;
NOT_APPLICABLE erfasst ausgeschlossene Authentifizierungstypen und eingebaute
beziehungsweise nicht loginbasierte Principals.

OwnerBindingStatus unterscheidet Quellenfehler, fehlende Owner-SID, mehrdeutige
Treffer, einen eindeutigen sichtbaren SQL-/Windows-Login, einen anderen
Principaltyp und keinen sichtbaren Treffer. Bei mehrdeutigen oder fehlenden
Treffern werden keine ID und kein Name geraten. Ein eindeutiger unbekannter
Typ bleibt mit seiner Identität sichtbar, ohne dessen Ownereignung zu bestätigen.
Die erste zutreffende Bedingung dieser Reihenfolge entscheidet:

| Status | Bedingung |
|---|---|
| SOURCE_UNAVAILABLE | Zielkontext oder benötigte Serverquelle ist fehlgeschlagen; Identitätsfelder bleiben NULL. |
| OWNER_SID_UNAVAILABLE | Die Quellen wurden gelesen, owner_sid ist aber NULL oder leer. |
| AMBIGUOUS_VISIBLE_OWNER_MATCH | Mehrere sichtbare Principals passen; es wird keine Identität ausgewählt. |
| MATCHED_VISIBLE_OWNER | Genau ein Treffer ist SQL_LOGIN oder WINDOWS_LOGIN; ID, Name und Typ werden ausgegeben. |
| UNSUPPORTED_PRINCIPAL_TYPE | Genau ein Treffer hat einen anderen Typ; seine Identität bleibt sichtbar, ohne Ownereignung zu behaupten. |
| NO_VISIBLE_OWNER_MATCH | Es gibt keinen sichtbaren Treffer; unvollständige Sicht oder Windowsgruppen bleiben mögliche Ursachen. |

## Warum kann das problematisch sein?

Eine unvollständige Metadatensicht kann zusätzliche Benutzer, Rollen, Rechte
oder Logins verbergen. Ein innerer Namensjoin würde sichtbare Kanten verlieren;
der Bericht erhält deshalb deren IDs auch bei fehlenden Namen. Eine während
der Aufnahme geänderte Datenbank oder Berechtigung kann außerdem zwischen
getrennten Quellen unterschiedliche Zustände erzeugen. Die Zeitklammern sind
kein atomarer Sicherheitssnapshot.

Spaltenausnahmen und Rechte fester Rollen verhindern eine einfache Addition
der Zeilen zu einem Zugriffsurteil. Prüfen Sie einen konkreten Zugriff mit
einem dafür berechtigten, ausdrücklich festgelegten Actor und Ziel getrennt.
Leiten Sie aus diesem Bericht keine automatische DDL-Reparatur ab.

## Wann ist es kein Problem?

Enthaltene Benutzer benötigen für ihre Katalogklassifikation keinen Serverlogin.
Benutzer ohne Login, Rollen und Zertifikats- oder Schlüsselbenutzer sind
ebenfalls nicht pauschal verwaist. Ein eingeschränkter Caller kann gültige
Teilinformationen liefern, wenn deren Sichtbarkeitsgrenze erhalten bleibt.
Auch ein Outputlimit ist ein erwarteter Zustand, sofern die Diagnose den
beobachteten und ausgegebenen Umfang getrennt zeigt.

## Beispiele und Gegenbeispiele

Mehrere exakte Namen verwenden bracket-aware Pipe-Listen. Ein Pipe-Zeichen
innerhalb eines geklammerten Bezeichners trennt keine Datenbanken.

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis]
    @DatabaseNames=N'[ExampleDatabaseA]|[ExampleDatabaseB]',
    @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
```

Der getrennte Patternparameter unterstützt den vorhandenen LIKE- und
versionsabhängigen Regexvertrag. Exakte Liste und Pattern dürfen nicht gemeinsam
gesetzt werden. Systemdatenbanken werden nur ausdrücklich einbezogen:

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis]
    @DatabaseNames=N'master', @SystemdatenbankenEinbeziehen=1,
    @MaxZeilen=100, @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Ein Objekt-GRANT mit einer Spalten-REVOKE-Zeile ist kein Widerspruch in der
Inventur. Der Bericht erhält beide Zeilen mit MajorId und MinorId, anstatt
einen vermeintlich bereinigten effektiven Zustand zu erzeugen.

## Leere oder partielle Ausgabe

Eine erfolgreich gelesene leere Katalogsicht unterscheidet sich von einem
Zugriffsfehler. Quellenfehler erhalten Status und native Fehlerdaten; andere
gelesene Mengen bleiben auswertbar. Ein explizit angefordertes nicht
verfügbares Ziel erhält einen Auswahlbefund, der fehlende Sicht, fehlenden
Zugriff, Offlinezustand und tatsächliche Abwesenheit nicht unzulässig trennt.

@MaxZeilen gilt global je principals, roleMemberships, permissions,
schemaOwners und loginBindings über die gewählten Datenbanken. 0 oder NULL
bedeutet unbeschränkt. Kontext-, Status- und Warnmengen werden nicht gekappt.
Namens- und SID-Bindungen entstehen vor der Kürzung, damit ein Limit keine
falschen fehlenden Zuordnungen erzeugt. OUTPUT_LIMIT zeigt die Kürzung an.

## Eigenlast und Grenzen

Die Procedure liest lokale Metadaten und skaliert mit Datenbank-, Principal-,
Rollen- und Berechtigungsmenge. Ein Ausgabelimit begrenzt nicht die vorgelagerte
Katalogarbeit. Verwenden Sie bei großen Instanzen einen fachlich passenden
Namens- oder Patternfilter. Die Serverprincipalsicht wird einmal je Aufruf
materialisiert; die Datenbankquellen bleiben je Kandidat getrennt.

@LockTimeoutMs erlaubt 0 bis 60000 Millisekunden; NULL und negative Werte
sind ungültig. LOCK_TIMEOUT und XACT_ABORT bleiben am Procedureende auf dem
Callerwert. Commit und Rollback einer vorhandenen Transaktion gehören dem
Caller. Nicht gefangene Engine-, Deadlock- oder Verbindungsabbrüche besitzen
keine garantierte Rückgabe. NOLOCK macht die Quellen weder atomar noch frei
von allen Metadatenlocks.

## Technische Vertiefung

### Leitfrage

Welche direkten Katalogbeziehungen sind im jeweiligen Datenbank- und
Caller-Kontext tatsächlich belegt, und welche weitergehende Aussage bleibt
wegen unvollständiger Sicht oder fehlender externer Identitätsinformationen offen?

### Technischer Hintergrund

SQL Server begrenzt Metadaten nach Eigentum und Berechtigungen. Die Quelle
sys.database_permissions enthält explizite Rechte einschließlich besonderer
Spaltenausnahmen, aber keine vollständige Expansion der Rechte fester Rollen.
Deshalb bleibt der Bericht auch nach einem erfolgreichen SELECT begrenzt.

### Datenkette

Die gemeinsame Kandidatenvorbereitung löst Datenbankfilter auf. Eine einmal
materialisierte Serverprincipalsicht liefert die interne SID-Namensbasis.
Je Datenbank entstehen anschließend getrennte Kontext-, Principal-, Rollen-,
Rechte- und Schemaaufnahmen. Loginbindungen verwenden diese sichtbaren Quellen.
Erst danach werden die fünf Fachmengen global gekürzt. RAW, TABLE und JSON
verwenden dieselben materialisierten Werte.

### Source Select

Diese repräsentative Abfrage wird im berechtigten Zielkontext gelesen:

```sql
SELECT [p].[principal_id], [p].[name], [p].[type],
       [p].[authentication_type_desc], [p].[default_schema_name]
FROM [sys].[database_principals] AS [p] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Die benötigte sichtbare Katalogmenge entsteht
vor dem Ausgabelimit. Ein kleines MaxZeilen begrenzt weder die gelesene
Metadatenmenge noch die zur Namens- und SID-Auflösung benötigte Basis.

### Zeit- und Scope-Modell

StartedAtUtc und CompletedAtUtc klammern einzelne Quellen ein. Datenbank-ID
und Name binden lokale Principal- und Securable-IDs an ihren Aufnahmebereich.
Vor und nach jeder lokalen Katalogabfrage werden die aktuelle Datenbank-ID,
der Name und das beim Kontextlesen erfasste create_date geprüft. Eine Abweichung
verwirft die betroffene Quellenmenge und führt zu DATABASE_UNAVAILABLE mit dem
lokalen Diagnosecode 51012. Dieser Code stammt aus der Identitätsprüfung des
Berichts. Er ist kein nativer Enginefehler und beweist keine atomare Aufnahme.
ID, Name und create_date sind keine dauerhaften Identitäten nach Drop,
Wiederanlage oder Restore.
Die JSON-Erzeugungszeit macht aus den getrennten Quellen keinen atomaren
Sicherheitssnapshot.

### Bewertung und Gegenprobe

Vergleichen Sie eine betroffene direkte Kante im gleichen Caller-Kontext mit
dem nativen Katalog. Prüfen Sie bei einem fehlenden sichtbaren Login-Treffer
zuerst die Sicht auf die Serverquelle. Eine gezielt berechtigte unabhängige
Prüfung kann weitere Metadaten liefern; dieser Bericht erweitert dafür keine
Rechte und ersetzt keine konkrete Zugriffsprüfung.

### Typische Fehlinterpretation

Eine fehlende explizite GRANT-Zeile beweist keine fehlenden effektiven Rechte.
Ein fehlender sichtbarer SID-Treffer beweist keinen verwaisten Benutzer.
Eine Spalten-REVOKE-Zeile ist keine pauschale Zugriffsverweigerung durch DENY.

### Folgeanalyse

Verwenden Sie die [Serverprincipal-Analyse](USP_ServerPrincipalAnalysis.md)
für getrennte Servermetadaten und die
[Auditkonfiguration](USP_AuditConfigurationAnalysis.md) für sichtbare
Auditabdeckung. Effektive Rechte, abweichende Objektowner und externe
Identitätsinformationen benötigen einen gesondert qualifizierten Weg.

Parameter- und TABLE-Ablehnungen sowie gefangene äußere Fehler kehren regulär
mit Status, Diagnose-OUTPUT und Diagnosecode als RETURN-Wert zurück. JSON
bleibt dabei NULL. Der Caller muss Status und Rückgabecode prüfen; eine
optionale Meldung mit Schweregrad 10 ersetzt diese Prüfung nicht. Fehler einer
einzelnen fachlichen Quelle bleiben dagegen in sourceStatus und im begrenzten
Gesamtbefund erhalten.

SID-Werte werden ausschließlich intern verglichen. Der Bericht liest keine
Passwort-Hashes, Credentialinhalte, Schlüssel, Tokens, Directorydaten oder
Nutzdaten. Sichtbare Namen bleiben als Diagnoseinformationen erhalten. Er
verändert keine Principals, Grants, Datenbankoptionen oder Ownership.

## Primärquellen

- Microsoft Learn: [sys.database_principals](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_role_members](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-role-members-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [verwaiste Benutzerbindungen](https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server?view=sql-server-ver17).
- Microsoft Learn: [Datenbankowner und ALTER AUTHORIZATION](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-authorization-transact-sql?view=sql-server-ver17).

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_databaseprincipalanalysis)
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
