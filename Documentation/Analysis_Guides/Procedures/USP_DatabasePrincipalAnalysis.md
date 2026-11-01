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

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | NULL, N'' oder eine nur aus äußeren U+0020-Leerzeichen bestehende Eingabe schränken die Datenbankauswahl nicht ein. Andernfalls wird eine bracket-aware Pipe-Liste aus einzelnen Datenbanknamen erwartet; ein Pipe innerhalb eines geklammerten Namens ist Inhalt, und ]] maskiert dort eine schließende Klammer. Ungültige Elemente und doppelte gültige Namen führen zur Zurückweisung; Vorgesehen sind einteilige Namen. Der Parser übernimmt den letzten PARSENAME-Bestandteil, verlangt einen nichtleeren Wert bis 128 Zeichen und NULL für den zweiten Bestandteil; dritte und vierte Bestandteile werden nicht separat validiert. Ein rohes Listenelement ist auf 4.000 Zeichen begrenzt. Die exakten Namen werden case-sensitive verglichen. Nur eine aktive nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Ohne beide Filter wählt die gemeinsame Kandidatenvorbereitung alle für den Caller sichtbaren, zugreifbaren Online-Datenbanken ohne Datenbanksnapshots; Systemdatenbanken hängen zusätzlich von @SystemdatenbankenEinbeziehen ab. Nicht verfügbare explizit angeforderte Namen erscheinen als Auswahlwarnungen; daraus wird Abwesenheit nicht sicher abgeleitet. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Systemdatenbanken mit Datenbank-IDs bis einschließlich 4 aus; 1 erlaubt ihre Aufnahme. NULL wird vom Auswahlhelfer als ungültiger Parameter zurückgewiesen. Systemdatenbanken müssen mit 1 ausdrücklich einbezogen werden. Die Auswahl bleibt auf sichtbare, online befindliche und für den aktuellen Login zugreifbare Datenbanken begrenzt. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL bedeutet kein Patternfilter. Sonst werden äußere Leerzeichen entfernt und ein Präfix LIKE:, REGEX: oder REGEXI: ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der Inhalt nach einem Präfix wird nicht erneut getrimmt. Ein leerer oder nur aus Leerzeichen bestehender Wert sowie ein leeres Präfix-Ergebnis sind ungültig. Eine aktive nichtleere exakte Namensliste und ein nicht-NULL-Pattern sind unvereinbar. LIKE vergleicht case-sensitive. REGEX ist case-sensitive, REGEXI case-insensitive; Regexausführung verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Der Parser prüft keine Regexsyntax; ein ungültiges Regexmuster kann daher erst bei der Ausführung fehlschlagen. Der LIKE-Inhalt ist ein SQL-Server-LIKE-Muster: % steht für beliebig viele Zeichen, _ für ein Zeichen, [...] für Zeichenklassen. Die Abfrage definiert keine eigene ESCAPE-Klausel. REGEX/REGEXI-Inhalt wird unverändert an REGEXP_LIKE mit Flag c beziehungsweise i übergeben; Parservalidierung ersetzt keine Regexsyntaxprüfung. |
| `@MaxZeilen` | `int` | `1000` | NULL oder 0 bedeutet kein Ausgabelimit; ein negativer Wert ist ungültig. Ein positiver Wert begrenzt jeweils separat die fünf Fachmengen principals, roleMemberships, permissions, schemaOwners und loginBindings global über alle gewählten Datenbanken. Die Kürzung erfolgt nach der jeweiligen dokumentierten Sortierung; bei identischen Sortierschlüsseln ist keine zusätzliche Tie-Break-Garantie festgelegt. databaseContext, moduleStatus, sourceStatus und warnings werden nicht gekappt. Die vollständigen sichtbaren Quellmengen werden vor der Kürzung materialisiert; das Limit reduziert daher nicht die Kataloglesearbeit oder die zuvor gebildeten Namens- und SID-Zuordnungen. ObservedRows und ReturnedRows sowie IsLimited halten Quellmenge und Ausgabe auseinander. |
| `@LockTimeoutMs` | `int` | `0` | NULL, negative Werte und Werte über 60000 sind ungültig; 0 bis 60000 sind Millisekunden und der Vorgabewert 0 setzt NOWAIT für die dynamischen fachlichen Quellbatches. Ein positiver Wert erlaubt diesen Batches entsprechend viele Millisekunden auf eine Sperre zu warten. Bei eingehendem Caller-LOCK_TIMEOUT 0 verwendet die Procedure für eigene Temp-DDL-Statements bis zu 1000 ms je Statement; dies ist kein zusätzliches Quellzeitbudget. Am Ende wird der eingehende LOCK_TIMEOUT-Wert wiederhergestellt. Der Parameter ist keine Gesamtzeitgrenze für den Aufruf und begründet keine atomare Aufnahme. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | NULL oder ein anderer als die vier folgenden Werte ist ungültig. Groß-/Kleinschreibung und äußere Leerzeichen werden normalisiert. CONSOLE erzeugt eine formatierte Ergebnisübersicht; RAW liefert neun native Resultsets; TABLE schreibt die angeforderten Mengen in lokale Temp-Tabellen; NONE unterdrückt fachliche Resultsets. JSON kann unabhängig von dieser Auswahl zusätzlich über @Json ausgegeben werden. Bei jeder Auswahl außer TABLE muss @ResultTablesJson NULL, leer oder nur aus äußeren U+0020-Leerzeichen bestehen. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Außer bei ResultSetArt=TABLE muss der Wert NULL, leer oder nur aus äußeren U+0020-Leerzeichen sein; ein anderer Inhalt ist INVALID_PARAMETER. Im TABLE-Modus ist ein nichtleeres gültiges JSON-Objekt erforderlich, das mindestens eine Zuordnung von einem Resultsetnamen zu einem lokalen Temp-Tabellennamen enthält. Erlaubte Namen sind exakt moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus und warnings; jeder Name darf nur einmal, jedes Ziel nur einmal (case-insensitive) vorkommen. Jeder Wert muss eine nichtleere Zeichenfolge sein. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit höchstens 116 Zeichen und genau einer Seed-Spalte bezeichnen; ##-, #Monitor*- und permanente Ziele sind unzulässig. Die Vorprüfung erfolgt vor fachlichen Katalogzugriffen. Der Schreiber passt die Seed-Struktur beim Schreiben an die native Quellstruktur an. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext und Identitätsbindung, principals Datenbankprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Datenbankrechte, schemaOwners Schemaownership, loginBindings sichtbare Loginbindungen, sourceStatus Quellenstatus und warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von ResultSetArt; 0 erzeugt es nicht. NULL wird nicht gesondert zurückgewiesen und verhält sich im IF-Test wie nicht aktiviert. Die neun Arrays entsprechen den neun fachlichen Mengen, ergänzt um meta; Zeilen enthalten NULL-Felder. Bei einem gefangenen äußeren Fehler bleibt @Json NULL. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Als OUTPUT-Parameter muss die Variable des Aufrufers mit OUTPUT gebunden werden, damit das Ergebnis zurückgegeben wird. Zu Aufrufbeginn setzt die Procedure den Parameter auf NULL; bei @JsonErzeugen=1 enthält er nach erfolgreicher Verarbeitung meta und die neun geordneten JSON-Arrays mit INCLUDE_NULL_VALUES. Ohne Aktivierung und nach einem gefangenen äußeren Fehler bleibt der Wert NULL. Die JSON-Erzeugungszeit macht die getrennten Quellaufnahmen nicht atomar. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden. |
| `@PrintMeldungen` | `bit` | `1` | 1 (auch Vorgabewert) erlaubt die vorgesehenen PRINT- beziehungsweise RAISERROR-Meldungen mit Schweregrad 10 und NOWAIT: Die Hilfezeilen erscheinen bei @Hilfe=1 unabhängig von diesem Schalter; bei ungültigen Parametern, gefangenen äußeren Fehlern und Quellenfehlern mit ermitteltem ErrorNumber werden Diagnosemeldungen gesendet. 0 unterdrückt diese Meldungen. NULL wird nicht validiert und erfüllt die IF-Bedingung für 1 nicht. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 1 gibt die eingebaute Parameterhilfe und Beispiele aus und beendet die Procedure vor Parameterprüfung oder Katalogzugriff. Dabei werden @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 gesetzt; @Json sowie die Fehler-OUTPUTs sind zuvor beim Eintritt auf NULL zurückgesetzt. 0 führt den normalen Aufruf aus. NULL wird nicht zurückgewiesen und wirkt wie nicht aktiviert. Der Hilfestatus bestätigt weder Vollständigkeit noch vollständige Rechte. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Hilfe liefert AVAILABLE; Eingabevalidierung INVALID_PARAMETER. Kandidatenhelferfehler liefern INVALID_PARAMETER für ungültige Auswahl, INTERNAL_ERROR für ein internes Kandidatenschema oder UNAVAILABLE_FEATURE für nicht verfügbare Regex-Voraussetzungen, jeweils mit RETURN 51011. Regulär gilt AVAILABLE_LIMITED, sobald eine native DB-Quelle diesen erfolgreichen, aber unbewiesenen Metadatenstatus besitzt. Andernfalls wird der erste Status ungleich AVAILABLE_LIMITED/SKIPPED nach DatabaseName, SourceKey gewählt: DENIED_PERMISSION für verweigerte Quelle, TIMEOUT für Sperrtimeout, DATABASE_UNAVAILABLE für nicht verfügbaren Datenbankkontext, ERROR_HANDLED für andere behandelte Quellenfehler, STATUS_UNAVAILABLE als fehlende Statuskennung oder SYSTEM_DATABASE_EXCLUDED für einen ausgeschlossenen expliziten Systemnamen. DATABASE_UNAVAILABLE kann ebenso aus der Auswahl stammen. Sonstige äußere Fehler liefern ERROR_HANDLED. Fehlernummer/-meldung werden davon getrennt nach DatabaseId, SourceKey priorisiert. Reguläre Verarbeitung und Hilfe liefern RETURN 0; ein äußerer Fehler liefert seinen Diagnosecode. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Bei Eintritt wird der Empfänger auf NULL gesetzt. Die Hilfe setzt 0. Ungültige Eingaben, reguläre Fachverarbeitung und gefangene äußere Fehler setzen 1; auch AVAILABLE_LIMITED mit vollständig lesbaren angeforderten Quellen bleibt wegen des begrenzten Aussageumfangs partiell. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlercode ermittelt wurde. Ungültige Parameter liefern 51011; bei Quellenfehlern wird der erste vorhandene native ErrorNumber-Wert nach Datenbank-ID und SourceKey ausgewählt. Der äußere CATCH liefert den für den Fehlerpfad gesetzten Code oder den abgefangenen SQL-Fehlercode; TABLE-Fehler können dabei aus dem Vorbereitungs- oder Schreibhelfer stammen. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlertext ermittelt wurde. Bei ungültigen Parametern enthält sie die Validierungsdiagnose; bei regulärer Verarbeitung mit Quellenfehlern stammt sie aus dem ersten Fehler nach Datenbank-ID und SourceKey. Der äußere CATCH gibt die abgefangene Meldung auf höchstens 2048 Zeichen begrenzt zurück. Die OUTPUT-Diagnose ersetzt weder Statusprüfung noch RETURN-Code. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON und Diagnose-OUTPUTs

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_DatabasePrincipalAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#DatabasePrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"principals":"#DatabasePrincipalAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#DatabasePrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis] @Hilfe=1;
```

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

@LockTimeoutMs erlaubt 0 bis 60000 Millisekunden; NULL und negative Werte sind ungültig. Der Wert gilt in den dynamischen fachlichen Quellbatches. Bei eingehendem Caller-LOCK_TIMEOUT 0 erhalten die anfänglichen eigenen Temp-DDL-Anlagen bis zu 1000 ms je Anlage; dieses Zeitbudget ist keine Gesamtzeitgrenze. Die Procedure stellt LOCK_TIMEOUT und den eingehenden XACT_ABORT-Zustand am Ende wieder her. Commit und Rollback einer vorhandenen Transaktion gehören dem Caller. Nicht gefangene Engine-, Deadlock- oder Verbindungsabbrüche besitzen keine garantierte Rückgabe. NOLOCK macht die Quellen weder atomar noch frei von allen Metadatenlocks.

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
