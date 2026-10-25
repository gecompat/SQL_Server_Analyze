# [monitor].[USP_CurrentCallerPermissionAnalysis]

**Bereich:** Server Health und Berechtigungsdiagnostik.
**Zweck:** Zeigt native SERVER- und DATABASE-Rechte des aktuellen Ausführungskontexts.
**Beobachtungsart:** getrennte native Berechtigungsaufnahmen.
**Kostenklasse:** LOW_MEDIUM.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, welche Rechte sys.fn_my_permissions im aktiven
Sicherheitskontext auf SERVER- und DATABASE-Ebene meldet. Die Engine bewertet
dabei auch implizite und über Rollen vermittelte Rechte. Die Ausgabe enthält
die nativen Namen, getrennte Quellenzustände und numerische Kontext-IDs.
Sie ergänzt die [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md)
und die [Serverprincipal-Analyse](USP_ServerPrincipalAnalysis.md).

## Nicht beantwortete Fragen

Ein Datenbank-SELECT beweist keinen Zugriff auf jedes einzelne Objekt.
Objekt- oder Spalten-DENYs und ein konkreter Statementpfad benötigen eine
Zugriffsprüfung auf dem betroffenen Securable. Der Bericht liefert keinen
vollständigen Berechtigungsgraph, keine Directoryauflösung und keine
Anmeldeprüfung. Er wechselt keine Identität und erweitert keine Rechte.
Ein vom Caller aktivierter Ausführungskontext und zusätzliche Modulidentitäten
gehören zur tatsächlichen Enginebewertung. Das Ergebnis gilt nicht pauschal
für den ursprünglich verbundenen Login oder andere Principals.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentCallerPermissionAnalysis]
    @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=200,
    @ResultSetArt='CONSOLE', @PrintMeldungen=0;
```

Passen Sie den synthetischen Namen an das gewünschte Ziel an. Ohne Filter
werden alle sichtbaren und zugänglichen Online-Benutzerdatenbanken untersucht.
Systemdatenbanken bleiben opt-in. @ServerrechteEinbeziehen=0 schaltet die
zusätzliche Serverquelle ab. Der Bericht verwendet keinen impliziten
CURRENT-Scope und keine vorgezogene Datenbankanzahlbegrenzung.

## Resultsets und Leserichtung

RAW und TABLE liefern sechs benannte Mengen. JSON enthält dieselbe
Materialisierung und ein meta-Objekt mit SchemaVersion 1. NONE kann JSON und
Status über OUTPUT liefern. CONSOLE führt die beiden Rechtemengen mit einer
Scope-Spalte über den gemeinsamen CONSOLE-Renderer in einer fachlichen
Übersicht zusammen. SOURCE-, WARNING- und
INFO-Zeilen zeigen auch bei vorhandenen Rechtezeilen die Quellenprobleme,
Limits und Aussagegrenzen. SourceKey und WarningCode bleiben dafür getrennt
erkennbar; RowCount zählt ausschließlich die beiden Rechtemengen.

| Menge | Bedeutung |
|---|---|
| moduleStatus | Gesamtstatus und Summe der ausgegebenen Zeilen beider Rechtemengen. |
| callerContexts | Ziel, tatsächliche Kontextdatenbank-ID und native Principal-IDs je erfolgreicher Funktionsaufnahme. |
| serverPermissions | Native EntityName-, SubentityName- und PermissionName-Werte der SERVER-Quelle. |
| databasePermissions | Native Rechte mit zusätzlicher Datenbank-ID und Name. |
| sourceStatus | Quellart, Zeitklammer, Status, Sichtbarkeitsgrenze, Mengen und konkrete Fehlerdaten. |
| warnings | Auswahl-, Quellen-, Limit- und fachliche Aussagegrenzen. |

Die verbindlichen Feldfolgen, Typen und Nullbarkeiten stehen im
[Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv). Lesen Sie
zuerst Quelle und Warnung, danach die betreffende Rechtezeile.

## Eine Zeile bedeutet

Ein Recht gehört zum benannten Securabletyp und zum bei der Aufnahme aktiven
Kontext. ContextDatabaseId bildet den Namespace der lokalen DatabasePrincipalId,
auch beim Serverbefund. Eine fehlende ServerPrincipalId ist in einem lokalen
Benutzerkontext zulässig. PARTIAL_CURRENT_IDS kennzeichnet diese begrenzte
Kontextbeschreibung; CAPTURED_CURRENT_IDS beweist keine vollständige Tokenidentität.

EntityName und SubentityName bleiben als native Werte erhalten. NULL oder eine
leere Zeichenfolge in diesen Feldern ist kein Quellenfehler. Ein unbrauchbarer
PermissionName verwirft die betreffende Quellenmenge. Das Ausgabelimit wirkt
getrennt global auf Server- und Datenbankrechte. Kontext, Status und Warnungen
bleiben erhalten; ObservedRows und ReturnedRows unterscheiden Aufnahme und Ausgabe.

## So lesen

AVAILABLE_LIMITED mit IsPartial=1 zeigt mindestens eine nichtleere erfolgreiche
Rechtequelle. EMPTY_UNPROVEN kennzeichnet ausschließlich leere erfolgreiche
Mengen und beweist keine fehlenden Rechte. NO_TARGETS bedeutet, dass keine
Rechtequelle ausführbar war. Fehler und SKIPPED bleiben davon unterscheidbar.
Sind alle Rechtequellen fehlgeschlagen, verdecken erfolgreiche Kontextmetadaten
den konkreten Fehlerstatus nicht.

Native Fehlerdaten bleiben diagnostisch vollständig. Lokale Diagnosen 51012,
51013 und 51014 kennzeichnen dagegen Zieldrift, geänderte Kontext-IDs oder eine
unbrauchbare native Berechtigungszeile. Sie sind keine nativen Enginefehler.
Ein Fehler erhält unbekannte Mengen statt künstlicher Nullcounts.

## Warum kann das problematisch sein?

Aufnahmen verschiedener Datenbanken und Quellen sind kein atomarer
Sicherheitssnapshot. Rechte, Rollen und Modulidentitäten können sich ändern,
ohne dass sich die erfassten IDs ändern. IDs sind außerdem keine dauerhaften
Identitäten nach Drop oder Wiederanlage. Die Ausgabe darf deshalb nicht als
Freigabe für einen späteren Zugriff oder für einen fremden Principal dienen.

## Wann ist es kein Problem?

Ein bewusst deaktivierter Serverpfad hat SKIPPED als erwarteten Zustand.
Eine leere Servermenge bei einem lokalen Benutzerkontext ist ein begrenzter
nativer Befund. Sie bestätigt keinen vollständigen Entzug sämtlicher Rechte.
Ein Ausgabelimit ist erkennbar und ändert nicht die zuvor beobachtete Quellenmenge.

## Beispiele und Gegenbeispiele

```sql
DECLARE @Payload nvarchar(max), @Status varchar(40), @Partial bit,
        @Error int, @Message nvarchar(2048), @Return int;
EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis]
    @DatabaseNames=N'[ExampleDatabase]', @ServerrechteEinbeziehen=0,
    @MaxZeilen=0, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Payload OUTPUT,
    @PrintMeldungen=0, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT,
    @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT;
SELECT @Return AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial],
       @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Payload AS [Payload];
```

Ein über eine Rolle wirksames Datenbank-SELECT kann gleichzeitig mit einem
DENY auf einem bestimmten Objekt bestehen. Die DATABASE-Rechtezeile wird
dadurch nicht zum Nachweis eines erfolgreichen SELECT auf diesem Objekt.
Für TABLE verwenden Sie ausschließlich die gemeinsame benannte
[Mehrfachzuordnung](../../Reference/Procedure_Reference.md).

## Leere oder partielle Ausgabe

Ein regulär materialisierter Bericht kehrt mit RETURN 0 zurück, auch wenn eine
fachliche Quelle scheitert. Prüfen Sie deshalb Status, Error-OUTPUT und
sourceStatus. Parameter-/TABLE-Ablehnungen und gefangene äußere Fehler liefern
einen Diagnosecode als RETURN-Wert und JSON-NULL. Optionale Meldungen mit
Schweregrad 10 ersetzen diese Prüfung nicht. Der Caller behält seine Optionen,
seine Transaktion und den Datenbankkontext; nicht gefangene Verbindungs- oder
Engineabbrüche besitzen keine solche Rückgabegarantie.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | LOW_MEDIUM beschreibt native Metadatenfunktionen ohne Nutzdatenzugriff. |
| Standardpfad | Die Serverquelle und jede ausgewählte Datenbank werden getrennt gelesen. |
| Teuerster Pfad | Viele zugängliche Datenbanken erhöhen die Zahl nativer Funktionsaufrufe. |
| Haupttreiber | Datenbankanzahl und nativer Berechtigungsraum bestimmen die Aufnahme. |
| Skalierung | MaxZeilen begrenzt die Ausgabe nach der Aufnahme und spart keine Datenbankaufrufe. |
| Ressourcen | CPU, tempdb und optionales JSON werden für die kanonischen Mengen verwendet. |
| Warteverhalten | Der validierte LockTimeoutMs von 0 bis 60000 steht im jeweiligen Quellenbatch; eigene Vorbereitungen besitzen ihren getrennten begrenzten Schutz. |
| High-Impact-Gate | Der leichte Standardpfad benötigt keine Bestätigung. |

## Technische Vertiefung

### Leitfrage

Welche effektiven Rechte bewertet die Engine jetzt für den aktiven Kontext
auf den explizit benannten SERVER-/DATABASE-Ebenen?

### Technischer Hintergrund

sys.fn_my_permissions bewertet die aktive Sicherheitssituation der Engine.
Der Bericht addiert keine sichtbaren Grant-/Deny-Katalogkanten selbst.
Numerische Kontextfunktionen werden ohne Namensargumente verwendet; es
werden keine SID-Katalogspalten oder Tokenlisten abgefragt.

### Datenkette

Nach API- und TABLE-Vorprüfung verwendet die Procedure die gemeinsame
Datenbankauswahl. Kontext und Rechte werden je Quelle materialisiert,
geprüft und erst danach begrenzt. Quellenfehler verwerfen nur ihre Teilmenge,
sofern die Engine die übrige Aufnahme weiter zulässt.

### Source Select

Diese repräsentative native Abfrage gehört in den ausgewählten Zielkontext:

```sql
SELECT [entity_name], [subentity_name],
       CONVERT(nvarchar(128),[permission_name]) AS [PermissionName]
FROM [sys].[fn_my_permissions](NULL,N'DATABASE');
```

Die Funktion benötigt die public-Rolle. Frameworkausführung und Zielzugang
bleiben separate Voraussetzungen. sourceStatus benennt tatsächlich
fehlgeschlagene Quellen; der Bericht gewährt keine zusätzlichen Rechte.

**Wichtig für die Eigenlast:** Ein kleines MaxZeilen kürzt erst die
materialisierte Ausgabe. Es reduziert weder die Datenbankauswahl noch die
Anzahl der nativen Berechtigungsaufrufe.

### Zeit- und Scope-Modell

StartedAtUtc und CompletedAtUtc klammern Quellen ein. Ziel-ID, Name und
create_date werden vor und nach lokalen Reads geprüft. Beobachtete Zieldrift
verwirft die Menge; unveränderte IDs sind keine Garantie eines unveränderten
Rechte- oder Sicherheitszustands.

### Bewertung und Gegenprobe

Prüfen Sie einen betroffenen Scope im gleichen aktiven Kontext mit der
Nativefunktion. Ein konkreter Objektzugriff benötigt eine getrennte, dafür
autorisierte Gegenprobe. Übertragen Sie Ergebnisse nicht auf andere Principals.

### Typische Fehlinterpretation

Eine Datenbankrechtezeile beweist weder den Zugriff auf jedes Objekt noch
eine vollständige Beschreibung aller wirksamen Rollen und Modulidentitäten.
Eine leere native Menge beweist keinen vollständigen Rechteentzug.

### Folgeanalyse

Verwenden Sie die [Datenbankprincipal-Analyse](USP_DatabasePrincipalAnalysis.md)
für sichtbare direkte Rollen und Katalogrechte. Die
[Serverprincipal-Analyse](USP_ServerPrincipalAnalysis.md) ergänzt deren
getrennte Servermetadaten. Konkrete Zugriffs- und Anmeldepfade bleiben eigene Prüfungen.

## Primärquellen

- Microsoft Learn: [sys.fn_my_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-my-permissions-transact-sql).
- Microsoft Learn: [Berechtigungsprüfung](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine?view=sql-server-ver17).
- Microsoft Learn: [SUSER_ID](https://learn.microsoft.com/en-us/sql/t-sql/functions/suser-id-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [DATABASE_PRINCIPAL_ID](https://learn.microsoft.com/en-us/sql/t-sql/functions/database-principal-id-transact-sql?view=sql-server-ver17).

[Technische Detailbeschreibung](../../Reference/Procedure_Reference.md#monitorusp_currentcallerpermissionanalysis)
[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
