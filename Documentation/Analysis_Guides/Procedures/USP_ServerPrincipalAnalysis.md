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

Parameter- und TABLE-Ablehnungen sowie gefangene äußere Fehler kehren regulär
mit Status, Diagnose-OUTPUT und dem Diagnosecode als RETURN-Wert zurück.
Ungültige Parameter verwenden INVALID_PARAMETER und 51011; eine abgelehnte
TABLE-Zuordnung verwendet ERROR_HANDLED und 51011. Schreibfehler behalten den
nativen Helpercode, soweit vorhanden, andernfalls 51010. Bei diesen Fehlern
bleibt JSON NULL. Der Caller muss Status und Rückgabecode prüfen; eine
optionale Meldung mit Schweregrad 10 ersetzt diese Prüfung nicht.

Die reguläre Rückkehr überträgt die OUTPUT-Werte auch an T-SQL-Caller. Im
gefangenen Fehlerpfad bleibt XACT_ABORT bis zum Procedureende deaktiviert;
die Proceduregrenze stellt den Callerwert wieder her. Der Caller behält die
Entscheidung über Commit oder Rollback seiner bestehenden Transaktion.
Fachliche Quellenfehler bleiben im sourceStatus isoliert. Nicht gefangene
Engine- oder Verbindungsabbrüche besitzen diese Rückgabegarantie nicht.

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
