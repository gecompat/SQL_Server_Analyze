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

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Nicht angegeben oder NULL, N'' und ausschließlich äußere U+0020-Leerzeichen bedeuten keine Einschränkung; interne Leerzeichen bleiben Bestandteil der Eingabe. Andernfalls eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: \| trennt außerhalb von [...], innerhalb ist es Inhalt, ]] maskiert dort ]. Der Parser trimmt Segmentränder, prüft rohe Segmente bis 4000 Zeichen; danach verlangt die Namensprüfung PARSENAME-Teil 1 ≠ NULL, Teil 2 = NULL und LEN(Teil 1) ≤ 128. Teile 3/4 werden nicht separat geprüft. Exakte Namen werden case-sensitive verglichen. Mit aktivem nichtleerem Listenfilter muss @DatabaseNamePattern NULL sein; case-sensitive doppelte Listennamen werden als INVALID_PARAMETER zurückgewiesen. Ungültige Listenelemente werden als INVALID_PARAMETER zurückgewiesen. Syntaktisch gültige, aber nicht verfügbare explizite Namen erscheinen als Auswahlwarnungen; sie beweisen nicht, dass eine Datenbank fehlt. Ohne Filter gilt die Kandidatenauswahl nach sichtbaren, ONLINE- und zugänglichen Nicht-Snapshot-Datenbanken. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 lässt Datenbank-IDs bis 4 aus; 1 erlaubt Systemdatenbanken. NULL wird vor dem regulären Auswahlpfad als INVALID_PARAMETER abgewiesen. Auch mit 1 bleiben Sichtbarkeit, ONLINE-Zustand und HAS_DBACCESS=1 Voraussetzungen; die Auswahl ist kein vollständiger Datenbankkatalog. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL bedeutet kein Pattern. Sonst trimmt der Parser äußere Leerzeichen und erkennt case-insensitive die Präfixe LIKE:, REGEX: und REGEXI:; ohne Präfix gilt LIKE. Nach dem Präfix wird nicht erneut getrimmt. Leerer Inhalt oder nur U+0020-Leerzeichen einschließlich leerem Präfixinhalt ist ungültig. Aktive nichtleere @DatabaseNames und ein nicht-NULL-Pattern sind unvereinbar. LIKE wird case-sensitive mit SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel) ausgewertet. REGEX übergibt das Muster an REGEXP_LIKE mit Flag c, REGEXI mit Flag i; beides verlangt SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank. Parservalidierung prüft weder Regexsyntax noch Treffer; Ausführungsfehler werden in der jeweiligen Quell-/Auswahlbehandlung sichtbar. |
| `@ServerrechteEinbeziehen` | `bit` | `1` | 1 ruft sys.fn_my_permissions(NULL,N'SERVER') im tatsächlich aktiven Kontext auf; 0 überspringt nur diese Quelle und trägt für SERVER_CURRENT_PERMISSIONS den Quellstatus SKIPPED ein. NULL wird in der Parameterprüfung als INVALID_PARAMETER zurückgewiesen. Das Abschalten der Serverquelle verhindert nicht die getrennten Datenbankquellen und macht die Gesamtausgabe nicht automatisch zu einer Fehlerausgabe. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1. |
| `@MaxZeilen` | `int` | `1000` | NULL oder 0 bedeutet unbegrenzt; negative Werte sind INVALID_PARAMETER. Ein positiver Wert begrenzt die Serverrechtemenge global und separat jede Datenbankrechtemenge global über alle gewählten Datenbanken. Gekürzt wird nach EntityName, SubentityName, PermissionName (Datenbankmenge zusätzlich zuerst DatabaseId); für identische Sortierschlüssel ist keine weitere Tie-Break-Reihenfolge zugesichert. Die native Quelle wird zuvor vollständig aufgenommen; das Limit reduziert weder Zielauswahl noch Funktionsaufrufe. ObservedRows bleibt die aufgenommene Menge, ReturnedRows zeigt die Ausgabe, IsLimited markiert eine Kürzung. Kontext-, Status- und Warnungszeilen werden nicht gekappt. |
| `@LockTimeoutMs` | `int` | `0` | Gültig sind 0 bis 60000 Millisekunden einschließlich beider Grenzen; NULL, negative Werte und größere Werte werden als INVALID_PARAMETER abgewiesen. Der Wert wird für die dynamischen fachlichen Quellenbatches als LOCK_TIMEOUT verwendet; 0 bedeutet NOWAIT. Eigene vorbereitende Temp-DDL erhält bei eingehendem Caller-LOCK_TIMEOUT 0 separat bis zu 1000 ms pro Statement. Die Procedure stellt den eingehenden LOCK_TIMEOUT am regulären Ende und im äußeren CATCH wieder her. Dies ist keine Gesamtzeitgrenze und kein atomarer Snapshot. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | NULL und leer normalisieren zu leer und sind ungültig. Nach LTRIM/RTRIM äußerer U+0020-Leerzeichen und UPPER sind ausschließlich CONSOLE (ein fachliches, beschriftetes Ergebnis über Console-Helper), RAW (sechs getrennte Resultsets), TABLE (angeforderte benannte Mengen in lokale Temp-Ziele), NONE (keine fachlichen Resultsets) zulässig. Bei CONSOLE wird keine eigene Modulstatusmenge ergänzt; leere Console-Ansicht erhält die Helper-Zeile. JSON ist davon unabhängig. Außerhalb TABLE muss @ResultTablesJson NULL, leer oder nur U+0020-Leerzeichen sein; sonst INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen zulässig; anderer Inhalt wird als INVALID_PARAMETER mit Fehler 51011 abgelehnt. In TABLE muss die gemeinsame Vorprüfung ein JSON-Objekt mit mindestens einer Zuordnung aus den exakten Schlüsseln moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings erhalten. Schlüssel dürfen nicht doppelt vorkommen; Zielnamen dürfen nicht mehrfach vorkommen (case-insensitive). Werte müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte und höchstens 116 Zeichen bezeichnen. ##-Ziele und reservierte #Monitor*-Ziele sind unzulässig. Die Vorprüfung erfolgt vor Quellzugriff; der Helper wird mit ThrowOnError=0 aufgerufen. Bei abgelehntem Ziel löst die Procedure selbst ihren äußeren CATCH aus; dieser setzt ERROR_HANDLED, Partialität und Diagnose-OUTPUTs und liefert für die TABLE-Vorprüfung RETURN 51011. Jede Zuordnung schreibt nur die entsprechende Menge; nicht angeforderte Mengen werden nicht geschrieben. Die Schlüssel bedeuten: moduleStatus Modulstatus, callerContexts aktive Ausführungskontexte, serverPermissions native SERVER-Rechte, databasePermissions native DATABASE-Rechte, sourceStatus Quellenstatus und warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von der ResultSetArt; 0 oder NULL erzeugt keines (NULL aktiviert die IF-Bedingung nicht). Bei erfolgreichem regulärem Pfad enthält es meta mit resultName, schemaVersion=1, generatedAtUtc, statusCode, isPartial=1, errorNumber und errorMessage sowie die sechs Arrays moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings; NULL-Felder bleiben enthalten. Ein äußerer Fehler lässt @Json NULL. Die Dokumenterzeugung vereinigt die getrennten zeitlichen Quellen nicht zu einem Snapshot. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger des JSON-Dokuments: zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; Argument kann ausgelassen werden. Die Procedure setzt @Json beim Eintritt auf NULL, setzt es nur bei aktiviertem @JsonErzeugen im regulären Pfad und lässt es bei Hilfe, Validierungsfehler und gefangenem äußerem Fehler NULL. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen. |
| `@PrintMeldungen` | `bit` | `1` | 1 erlaubt die vorgesehenen Meldungen niedriger Severity: bei @Hilfe werden die Hilfetexte unabhängig von diesem Schalter ausgegeben; bei ungültigen Parametern, Quellenfehlern mit ermitteltem Fehler und äußerem Fehler kann RAISERROR Severity 10 mit NOWAIT folgen. 0 unterdrückt diese Diagnosemeldungen, nicht Resultsets oder OUTPUTs. NULL löst die IF-Bedingung für 1 nicht aus. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1. |
| `@Hilfe` | `bit` | `0` | 1 druckt die eingebaute Parameterhilfe und Beispiele und setzt @StatusCodeOut=AVAILABLE sowie @IsPartialOut=0; anschließend RETURN 0, ohne reguläre Eingabeprüfung, Kandidatenauswahl oder Quellenlesung. Die beim Eintritt bereits auf NULL gesetzten @Json- und Fehler-OUTPUTs bleiben NULL. Vor diesem Zweig läuft keine TABLE-Vorprüfung: diese erfolgt erst nach Hilfe, während ungültige Nicht-TABLE-Mappings ebenfalls erst danach geprüft werden. 0 oder NULL führt zum normalen Pfad. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger varchar(40); binde eine Variable mit OUTPUT. Alle Statuswerte und ihre Priorität: Hilfe setzt AVAILABLE (vor Quellenprüfung). Parameterprüfung setzt INVALID_PARAMETER und RETURN 51011. Fehler der Kandidatenvorbereitung werden als deren Status weitergegeben: INVALID_PARAMETER (ungültige Auswahl), INTERNAL_ERROR (interner Schemafehler), UNAVAILABLE_FEATURE (Regexvoraussetzung fehlt) oder STATUS_UNAVAILABLE als Fallback; äußerer CATCH setzt dazu den passenden Fehlercode. Im regulären Bericht gilt AVAILABLE_LIMITED, sobald mindestens eine native SERVER-/DATABASE-Rechtemenge nichtleer erfolgreich aufgenommen wurde. Andernfalls hat EMPTY_UNPROVEN Vorrang, sobald mindestens eine erfolgreiche native Menge leer ist. Wenn keine erfolgreiche leere Menge existiert, wird der nach DatabaseId und SourceKey erste native Fehlerstatus gewählt: DENIED_PERMISSION (Enginefehler 229, 297, 300, 371 oder 916), TIMEOUT (1222), DATABASE_UNAVAILABLE (konkret erkannte Kontext-/DB-Fehler) oder ERROR_HANDLED (sonstiger abgefangener Quellenfehler). Gibt es auch keinen solchen Fehler, gilt NO_TARGETS (z.B. keine Ziele oder nur übersprungene Quellen). Kandidatenfehler geben den gesetzten Helferstatus weiter. TABLE-Vorprüfungs- oder Schreibfehler setzen dagegen keinen FailureStatus und ergeben im äußeren CATCH ERROR_HANDLED mit vorbereitetem Diagnosecode; Schreibfehler verwenden den Helpercode oder 51010. Andere äußere Fehler ergeben ebenfalls ERROR_HANDLED, sofern kein Kandidaten-FailureStatus gesetzt wurde. Reguläre Fachquellenfehler ändern RETURN 0 nicht; Status, Fehler-OUTPUTs und sourceStatus getrennt prüfen. Beim Eintritt wird ein vorhandener Empfänger zurückgesetzt; Hilfe überschreibt Status/Partial, lässt die übrigen Fehler-OUTPUTs NULL. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger bit; eine Variable mit OUTPUT binden. Bei Eintritt NULL, bei Hilfe 0, bei ungültiger Eingabe, regulärem Bericht und äußerem Fehler 1. Auch AVAILABLE_LIMITED ist immer partiell: leere Quellen beweisen keine Abwesenheit, Sichtbarkeit ist begrenzt, und getrennte Aufnahmen sind nicht atomar. RETURN 0 kann trotz Quellenfehler auftreten. Beim Eintritt wird ein anfänglicher Empfängerwert zurückgesetzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler int-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung 51011; im regulären Bericht Nummer der fehlerhaften Quelle mit der ersten Sortierung nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH Fehlercode des vorbereiteten Fehlerpfads, andernfalls ERROR_NUMBER(); erfolgreicher Hilfspfad lässt NULL. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler nvarchar(2048)-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung feste Diagnose; im regulären Bericht Meldung der ersten fehlerhaften Quelle nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH abgefangene Meldung; Quellen-/Enginefehler bleiben diagnostisch erhalten. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON und Diagnose-OUTPUTs

```sql
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_CurrentCallerPermissionAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#CurrentCallerPermissionAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"databasePermissions":"#CurrentCallerPermissionAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#CurrentCallerPermissionAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @Hilfe=1;
```

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
