# [monitor].[USP_ServerPrincipalAnalysis]

**Bereich:** Server Health
**Zweck:** Zeigt sichtbare Serverprincipals und direkte Berechtigungsevidenz.
**Beobachtungsart:** getrennte lokale Katalogmomentaufnahmen
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, welche Serverprincipals, direkten Rollenmitgliedschaften,
expliziten Serverrechte und SQL-Login-Policyflags im aktuellen Caller-Kontext
sichtbar sind. Sie ergänzt die Serverkonfiguration um zusammenhängende
Identitätsmetadaten. Der Aufruf ist lesend und erteilt keine Berechtigungen.

## Nicht beantwortete Fragen

Die Ausgabe ist keine vollständige effektive Berechtigungsanalyse. Implizite
Rechte fester Rollen, verschachtelte Rollen als effektive Gruppen, Windows-/Entra-
Gruppen, Datenbankprincipals und enthaltene Benutzer bleiben eigenständige
Fragen. Ein deaktivierter Login beweist keinen vergangenen Missbrauch; ein
aktivierter Policyflag beweist weder Passwortstärke noch erfolgreiche Anmeldung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerPrincipalAnalysis]
    @MaxZeilen=200, @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Beginnen Sie mit sourceStatus und den Aussagegrenzen. V1 verwendet bewusst
AVAILABLE_LIMITED und IsPartial=1 auch für einen erfolgreichen privilegierten
Caller: Die Procedure qualifiziert ausschließlich sichtbare Metadaten und
berechnet keinen Vollständigkeitsnachweis. Dieser erwartete Zustand ist nicht
mit einem Quellenfehler gleichzusetzen.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MaxZeilen` | `int` | `1000` | Begrenzt jede der vier Fachmengen einzeln. NULL oder 0 bedeutet unbegrenzt; positive Werte sind je Menge die Höchstzahl. Negative Werte sind INVALID_PARAMETER. Das Limit greift nach vollständiger sichtbarer Katalogmaterialisierung und beschränkt nicht die Namensbasis oder Kataloglesearbeit. |
| `@LockTimeoutMs` | `int` | `0` | Millisekunden 0–60000; NULL und Werte außerhalb sind ungültig. 0 setzt NOWAIT für jede Quellenabfrage; sonst gilt der Wert je Quellbatch. Bei eingehendem @@LOCK_TIMEOUT=0 erhalten eigene Temp-DDL zunächst 1000 ms. Erfolg und gefangener äußerer Fehler stellen den Eingangswert wieder her. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Trimmen und Großschreibung normalisieren den einzelnen Modus: CONSOLE eine Übersicht; RAW sieben Sets in der Reihenfolge moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings; TABLE angeforderte Sets in lokale Seed-Temp-Tabellen; NONE keine Resultsets. NULL/Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur TABLE erlaubt eine nichtleere Zuordnung; sonst nur NULL/U+0020-Leerzeichen. TABLE verlangt ein gültiges, nichtleeres JSON-Objekt. Exakte Schlüssel: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings. Jeder Wert muss eine vorhandene, leere lokale #Temp-Tabelle (max. 116 Zeichen) mit einer Seed-Spalte benennen. Unzulässig: ##-/permanente/#Monitor*-Ziele, doppelte Schlüssel/Ziele, unbekannte Schlüssel, leere oder nicht-stringförmige Werte und nicht prüfbare Ziele. Helper-Preflight erfolgt vor Fachquellenzugriff; Writer ersetzt das Seed-Schema. Die Schlüssel bedeuten: moduleStatus Modulstatus, principals sichtbare Serverprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Serverrechte, loginPolicies SQL-Login-Policykennzeichen, sourceStatus Quellenstatus und warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | Bit: 1 erzeugt JSON unabhängig vom Ausgabemodus; 0/NULL nicht. Hilfe und Validierungsfehler erzeugen keines. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT, bei Eintritt NULL. Mit @JsonErzeugen=1 enthält es meta und sieben benannte Arrays. Hilfe, Validierungs- und gefangener äußerer Fehler lassen es NULL. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden. |
| `@PrintMeldungen` | `bit` | `1` | Bit: 1 sendet bei Validierungs-, Quellen- oder äußerem Fehler eine Zusatzmeldung mit Severity 10; 0/NULL unterdrückt sie. OUTPUT und RETURN sind weiter zu prüfen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | Bit: 1 druckt die eingebaute Parameterhilfe und Beispiele, setzt AVAILABLE/IsPartialOut=0 und kehrt vor Validierung und Quellenzugriff ohne Resultset zurück. JSON-/Fehler-OUTPUTs bleiben NULL. 0/NULL analysiert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Hilfe liefert AVAILABLE und IsPartialOut=0. Eingabevalidierung liefert INVALID_PARAMETER mit RETURN 51011. Regulär lautet der Status AVAILABLE_LIMITED, sobald mindestens eine der vier Quellen ohne ErrorNumber vorliegt. Schlagen alle vier Quellen fehl, gilt aus der alphabetisch ersten SourceKey-Zeile DENIED_PERMISSION bei verweigerter Quelle (Fehler 229, 297, 300, 371), TIMEOUT bei Sperrtimeout 1222 oder ERROR_HANDLED bei anderem abgefangenen Quellenfehler. Der äußere CATCH liefert ERROR_HANDLED. Reguläre Quellenfehler ändern RETURN 0 nicht; Diagnose-OUTPUTs sind getrennt zu prüfen. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT; Eintritt NULL. Hilfe 0; Analyse, Validierung und äußerer Fehler 1. Jede Analyse bleibt partiell, auch wenn alle Quellen lesbar sind. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT; Eintritt NULL. Validierung 51011; regulär Fehlernummer der alphabetisch ersten fehlerhaften SourceKey-Quelle, sonst NULL. Äußerer Fehler: TABLE-Fehlercode, sonst ERROR_NUMBER(). Quellenfehler allein ändern RETURN nicht. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT; Eintritt NULL. Validierung: feste Meldung; regulär: Meldung der alphabetisch ersten fehlerhaften Quelle, sonst NULL; äußerer Fehler: ERROR_MESSAGE(). Hilfe lässt NULL. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON und Diagnose-OUTPUTs

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_ServerPrincipalAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#ServerPrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"principals":"#ServerPrincipalAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#ServerPrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_ServerPrincipalAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

RAW liefert in dieser Reihenfolge moduleStatus, principals, roleMemberships,
permissions, loginPolicies, sourceStatus und warnings. TABLE verwendet genau
diese benannten Mengen; vorhandene lokale Seed-Temp-Tabellen werden durch den
Frameworkhelper vorbereitet. JSON hat SchemaVersion 1 und verwendet dieselben
materialisierten Zeilen. CONSOLE liefert genau eine formatierte Übersicht.
NONE unterdrückt sämtliche Resultsets, kann jedoch JSON und Status über
OUTPUT liefern. Die vollständigen nativen Schemas stehen im
[Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv).

@MaxZeilen begrenzt jedes der vier Fachresultsets getrennt. NULL und 0 liefern
alle sichtbaren Fachzeilen; negative Werte sind ungültig. moduleStatus,
sourceStatus und warnings bleiben als kleine Diagnosemengen erhalten, damit
ein Fachlimit keine Quellenfehler verdeckt. Beobachtete und zurückgegebene
Mengen sowie IsLimited stehen je Quelle im Quellenstatus.

## Eine Zeile bedeutet

Eine principals-Zeile ist eine sichtbare lokale Principal-ID. Eine
roleMemberships-Zeile ist genau eine direkte Mitgliedschaft; eine Rollenrolle
wird nicht automatisch auf ihre Mitglieder erweitert. Eine permissions-Zeile
ist ein expliziter GRANT-, DENY- oder GRANT_WITH_GRANT_OPTION-Katalogeintrag
mit Klasse und Major-ID. Eine loginPolicies-Zeile beschreibt die beiden
konfigurierten Policyflags eines sichtbaren SQL-Logins.

## So lesen

Lesen Sie erst StatusCode, Fehler und Zeitklammer jeder Quelle. VISIBLE_ONLY
bezeichnet eine sichtbare Teilmenge ohne Vollständigkeitsbeweis. UNPROVEN
bezeichnet eine nicht erfolgreich gelesene Quelle. ObservedRows ist dann
NULL; bei einem erfolgreichen Leerfall beträgt die Anzahl 0.

Principal- und Rollenkennungen sind lokale Momentaufnahmebindungen. Wenn ein
Name nicht sichtbar ist, bleibt die sichtbare Kante mit ihrer nativen ID
erhalten. Die Namensauflösung verwendet die vollständige materialisierte
Principalsicht vor einem Ausgabelimit. Die vier Aufnahmen haben getrennte
Zeitklammern und bilden keine atomare Berechtigungstransaktion.

## Warum kann das problematisch sein?

Katalogsichtbarkeit hängt vom Caller und einzelnen Rechten ab. Eine leere
Menge kann deshalb eine Sichtbarkeitsgrenze enthalten. Explizite Rechte lassen
außerdem implizite feste Rollenrechte und externe Gruppen offen. Werden diese
Grenzen ignoriert, kann eine unvollständige Inventur fälschlich als
Sicherheitsfreigabe erscheinen.

## Wann ist es kein Problem?

AVAILABLE_LIMITED mit METADATA_COMPLETENESS_UNPROVEN ist im ersten Vertrag
erwartet. Eine fehlende direkte explizite Berechtigung schließt ein implizites
Recht nicht aus. Ein deaktivierter Login oder eine deaktivierte Ablaufprüfung
ist zunächst eine Konfigurationsbeobachtung und benötigt den eigenen
Sicherheitsprozess als Gegenprüfung.

## Beispiele und Gegenbeispiele

```sql
DECLARE @ExampleJson nvarchar(max), @ExampleStatus varchar(40);
EXEC [monitor].[USP_ServerPrincipalAnalysis]
    @MaxZeilen=0, @ResultSetArt='NONE', @JsonErzeugen=1,
    @Json=@ExampleJson OUTPUT, @StatusCodeOut=@ExampleStatus OUTPUT,
    @PrintMeldungen=0;
SELECT @ExampleStatus AS [StatusCode], @ExampleJson AS [Json];
```

Ein gleichnamiger Login auf einer anderen Instanz ist keine gleiche Identität.
Die Procedure öffnet keine externe Verbindung und übernimmt keine
Authentisierungsentscheidung. Laufzeitnamen bleiben diagnostisch erhalten;
persistierte Beispiele und eigene Fixtures verwenden ausschließlich
synthetische Example-Werte.

## Leere oder partielle Ausgabe

Jede Quelle wird einzeln isoliert. Berechtigungsfehler, Locktimeout und andere
Quellenfehler bleiben getrennt sichtbar; andere Fachmengen werden weiter
ausgegeben. Wenn die Principalsicht fehlt, werden sichtbare direkte Kanten
durch LEFT JOIN nicht entfernt. Fehlschläge einer Quelle erzeugen keine
künstlichen Fachzeilen. Ein Fachlimit erzeugt OUTPUT_LIMIT und dokumentiert
die beobachtete sowie ausgegebene Menge.

## Eigenlast und Grenzen

Die Procedure liest vier lokale Securitykataloge und materialisiert die
sichtbaren Zeilen jeweils einmal. @MaxZeilen begrenzt die Ausgabe, nicht die
vorherige Kataloglesearbeit. Die Principalsicht wird außerdem für die Namen der
direkten Kanten genutzt. Haupttreiber sind die Anzahl sichtbarer Principals,
Mitgliedschaften und expliziter Rechte sowie TempDB-Materialisierung und
optionale JSON-Serialisierung. Es werden keine Nutzdaten gelesen.

@LockTimeoutMs erlaubt 0 bis 60000 Millisekunden; NULL und negative Werte
werden vor Quellenzugriff abgelehnt. LOCK_TIMEOUT und XACT_ABORT werden nach
Erfolg sowie einem gefangenen Fehler auf den Callerwert zurückgesetzt. Die
Procedure beginnt, committet oder rollt keine Callertransaktion zurück.
Engineabbruch, Deadlockopfer oder Verbindungsabbruch bleiben außerhalb einer
Garantie des Callerzustands. NOLOCK bedeutet keine atomare oder unveränderliche
Sicherheitsaufnahme und schützt nicht vor allen Metadatenlocks.

Die Procedure setzt @Json, @StatusCodeOut, @IsPartialOut, @ErrorNumberOut und @ErrorMessageOut beim Eintritt auf NULL. Hilfe setzt anschließend AVAILABLE und IsPartialOut=0 und kehrt ohne Resultset und JSON zurück. Ungültige Parameter liefern INVALID_PARAMETER, Fehlernummer 51011, IsPartialOut=1 und RETURN 51011; optionale Meldungen haben Schweregrad 10.

Bei regulärer Analyse bleibt IsPartialOut stets 1. Quellenfehler werden einzeln in sourceStatus festgehalten; andere Quellen werden weiter ausgewertet und die Procedure kehrt regulär mit RETURN 0 zurück. Status und Fehler-OUTPUTs spiegeln die alphabetisch erste fehlerhafte SourceKey-Quelle wider. Sind alle vier Quellen fehlgeschlagen, entspricht der Status dem Status dieser Quelle; andernfalls lautet er AVAILABLE_LIMITED. Ohne Quellenfehler sind Fehlernummer und -meldung NULL.

Eine ungültige TABLE-Zuordnung setzt den äußeren Fehlercode auf 51011. Ein Schreibfehler verwendet den Helpercode, falls geliefert, sonst 51010. Gefangene äußere Fehler liefern ERROR_HANDLED, IsPartialOut=1 und den Diagnosecode als RETURN-Wert; @Json bleibt NULL. @PrintMeldungen=1 sendet zusätzlich eine Meldung der Schwere 10. OUTPUT-Werte sind an passende typisierte T-SQL-Variablen zu binden; ohne OUTPUT-Bindung empfängt der Caller keine Werte. Quellenfehler sind keine Procedurefehler und verursachen keinen nichtnulligen RETURN.

Die Procedure stellt nach Erfolg oder gefangenem Fehler den eingehenden LOCK_TIMEOUT-Wert wieder her. XACT_ABORT wird im geschützten Pfad ausgesetzt und nach Erfolg wiederhergestellt; im CATCH bleibt es bis zum Ende aus. Die Procedure beginnt oder beendet keine Callertransaktion. Nicht gefangene Engine- oder Verbindungsabbrüche haben keine OUTPUT- oder RETURN-Garantie.

Passwort-Hashes, Passwörter, Credentials, Tokens und Schlüssel werden nicht
ausgewählt. Es gibt keine Namensanonymisierung der tatsächlich zurückgegebenen
Fachmetadaten und keine automatische Änderung von Logins oder Rollen.

## Technische Vertiefung

### Leitfrage

Welche direkten sichtbaren Beziehungen sind in dieser Aufnahme belegt, und
welche entscheidende Aussage bleibt wegen Sichtbarkeit, indirekten Rechten
oder fehlender externer Identitätsinformationen offen?

### Technischer Hintergrund

SQL Server begrenzt Metadaten nach Eigentum und Berechtigungen. Ein erfolgreiches
SELECT ersetzt keine Vollständigkeitsqualifikation. Die vier Quellen werden
deshalb unabhängig im Caller-Kontext gelesen.

### Datenkette

sys.server_principals liefert die lokale Namensbasis. Direkte Rollen und
explizite Rechte werden mit LEFT JOIN an diese Basis gebunden. sys.sql_logins
liefert ausschließlich die ausgewählten Policyflags. Erst danach werden
Fachausgaben deterministisch begrenzt; Quellenstatus und JSON verwenden
dieselbe Materialisierung.

### Source Select

```sql
SELECT [p].[principal_id], [p].[name], [p].[type], [p].[is_disabled]
FROM [sys].[server_principals] AS [p] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Die sichtbare Katalogmenge wird vor dem
Ausgabelimit gelesen. Ein kleines Fachlimit ist keine Obergrenze der zuvor
gelesenen Metadaten oder der erforderlichen Namensbasis.

### Zeit- und Scope-Modell

Alle Quellen sind serverweit. StartedAtUtc und CompletedAtUtc klammern jeweils
eine Quelle ein. Die JSON-Erzeugungszeit ist keine atomare Aufnahme aller
Rechte. Zeilen können zwischen den vier Leseschritten geändert werden.

### Bewertung und Gegenprobe

Vergleichen Sie einzelne direkte Zuordnungen im gleichen Caller-Kontext mit
den nativen Katalogen. Die Bewertung effektiver Rechte und externer
Gruppenmitgliedschaften benötigt einen gesonderten qualifizierten Weg.

### Typische Fehlinterpretation

Eine fehlende explizite GRANT-Zeile ist kein Beweis fehlender effektiver Rechte.
IsPolicyChecked=1 ist kein Nachweis eines starken Passworts oder einer
erfolgreichen Anmeldung.

### Folgeanalyse

Nutzen Sie die vorhandene [Sicherheitskonfiguration](USP_ServerSecurityConfiguration.md)
für Serveroptionen, die [Auditkonfiguration](USP_AuditConfigurationAnalysis.md)
für Auditabdeckung und den verantwortlichen Securityprozess für effektive
Rechte, Datenbankbindungen und externe Identitätsprüfung.

## Primärquellen

- [Serverprincipals](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-principals-transact-sql?view=sql-server-ver17).
- [Rollenmitgliedschaften](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql?view=sql-server-ver17).
- [Explizite Serverberechtigungen](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-permissions-transact-sql?view=sql-server-ver17).
- [SQL-Login-Policies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-logins-transact-sql?view=sql-server-ver17).

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_serverprincipalanalysis)
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
