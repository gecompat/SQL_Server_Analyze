# [monitor].[USP_SystemDatabaseObjectInventory]

Inventarisiert sichtbare, nicht von Microsoft gelieferte Objekte in `master`, `model` und `msdb`, ohne DDL auszuführen.

**Bereich:** Server Health, Wartbarkeit und Upgradevorbereitung
**Zweck:** Liefert ein sichtbares Kataloginventar benutzerdefinierter schema-gebundener Objekte in drei Systemdatenbanken.
**Beobachtungsart:** sequenzieller datenbanklokaler Katalogsnapshot
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet, welche sichtbaren, nicht als Microsoft-Objekt markierten Einträge in `master`, `model` und `msdb` einer Eigentümer-, Zweck-, Deployment- und Upgradeprüfung zugeordnet werden sollten. Sie ist für Bestandsaufnahme und Gegenprüfung vorgesehen. Sie liest keine Tabelleninhalte, Moduldefinitionen, Jobbefehle oder Identitätsdaten und führt keine DDL aus.

## Nicht beantwortete Fragen

`is_ms_shipped = 0` bedeutet nicht automatisch, dass ein Objekt unerlaubt, unsicher oder entbehrlich ist. Das Inventar kennt weder den fachlichen Eigentümer noch Deployment-, Backup-, Restore- oder Deinstallationsverträge. Interne Tabellen und Systembasisobjekte werden ausgeschlossen; serverweite Objekte wie Logins, Endpunkte und Linked Server gehören nicht zu diesem Resultset. Aufgrund der SQL-Server-Metadatensichtbarkeit kann ein eingeschränkter Benutzer weniger Objekte sehen als ein Administrator.

## Sicherer Einstieg

`EXEC [monitor].[USP_SystemDatabaseObjectInventory] @Hilfe = 1;` beschreibt alle Parameter, Ausgabeoptionen und Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Der Aufruf verwendet nur Systemkataloge. Führen Sie ihn zunächst unter dem vorgesehenen Diagnosekonto aus und vergleichen Sie einen eingeschränkten Lauf separat, wenn Vollständigkeit relevant ist. Ein Objekt wird erst nach dokumentierter Eigentümer- und Abhängigkeitsprüfung außerhalb dieser Procedure verändert.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MaxZeilen` | `int` | `2000` | NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach DatabaseName, SchemaName und ObjectName sortiert die ersten Zeilen. Begrenzung erfolgt nach vollständiger Katalogabfrage und reduziert deren Aufwand nicht; Status/ObjectCount beziehen sich auf den vollen Scope. Negative Werte ergeben INVALID_PARAMETER und keine Inventarzeilen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel systemDatabaseObjects und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | 0 lässt @Json NULL; 1 serialisiert die nach @MaxZeilen begrenzten LimitedRows sortiert nach den drei Namen. NULL aktiviert IF nicht; leere Auswahl wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben. |
| `@PrintMeldungen` | `bit` | `1` | 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (keine sichtbaren Inventarzeilen), AVAILABLE_LIMITED (fehlender Zugriff/Quellenfehler) und INVALID_PARAMETER (negative Grenze oder ungültige Ausgabeart). Zeilenstatus ist AVAILABLE, DENIED_PERMISSION oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Bei regulärem Abschluss eine Meldung bei ungültigen Parametern; sonst NULL. Fehler einzelner Datenbankquellen stehen in den Inventarzeilen, ohne automatische Übernahme. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert. |

### RAW-Ausgabe

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='RAW', @MaxZeilen=100;
```

### JSON-Ausgabe

```sql
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

### TABLE-Ausgabe

```sql
CREATE TABLE [#SystemDatabaseObjectInventory_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"systemDatabaseObjects":"#SystemDatabaseObjectInventory_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#SystemDatabaseObjectInventory_HelpExample];
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @Hilfe=1;
```

## Resultsets und Leserichtung

CONSOLE zeigt `systemDatabaseObjects`. RAW liefert den Modulstatus und danach das begrenzte Inventar. TABLE und JSON verwenden dieselbe begrenzte Mitgliedschaft. RAW-Inventar und JSON sind nach DatabaseName, SchemaName und ObjectName geordnet; CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Lesen Sie `DatabaseName`, `SchemaName`, `ObjectName`, `ObjectType`, `StatusCode` und `EvidenceLimit` zuerst. `CreateDate` und `ModifyDate` sind Katalogzeitpunkte; bei Tabellen und Views kann sich `ModifyDate` auch durch Indexänderungen verändern und ist deshalb kein verlässlicher Deploymentzeitpunkt.

`@MaxZeilen = NULL` und `0` geben das Inventar in CONSOLE, RAW, TABLE und JSON ohne Ausgabebegrenzung aus; positive Werte bestimmen dieselbe deterministisch nach DatabaseName, SchemaName und ObjectName ausgewählte Mitgliedschaft in allen vier Ausgabewegen. RAW und JSON sind nach diesen Spalten geordnet; CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Status und Teilsichtbarkeit beziehen sich weiterhin auf den vollständigen Bestand. Negative Werte setzen `INVALID_PARAMETER` und liefern keine Inventarzeilen. Die Ausgabegrenze reduziert den Katalogzugriff nicht.


## Beispiele und Gegenbeispiele

Eine leere synthetische Lab-Instanz kann `AVAILABLE_EMPTY` liefern. Drei explizit erzeugte Tabellen `ExampleOps009Object` in `master`, `model` und `msdb` bilden einen kontrollierten Positivfall und müssen nach dem Test exakt entfernt werden. Ein Gegenbeispiel ist die automatische Löschung eines sichtbaren administrativen Objekts. Ebenso darf eine Zeile in `model` nicht ohne Gegenprüfung als Fehler gelten, weil bewusst bereitgestellte Vorlagen existieren können.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet nur, dass im aktuellen Sicherheitskontext keine passenden Objekte sichtbar waren. Es beweist nicht, dass die Systemdatenbanken objektfrei sind. Eine nicht zugängliche Systemdatenbank bleibt als `DENIED_PERMISSION` sichtbar. Scheitert ein datenbanklokaler Katalogzugriff aus einem anderen Grund, bleibt die Quellgrenze als `SOURCE_UNAVAILABLE` erhalten; beide Fälle können `AVAILABLE_LIMITED` auslösen.

Für einen kontrollierten Positivtest werden feste Example-Namen vor der Erstellung auf Kollision geprüft. Das Cleanup entfernt nur genau diese leeren synthetischen Tabellen. Bereits vorhandene oder nicht eindeutig zuordenbare Objekte führen zum Abbruch und werden nicht überschrieben.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` |
| Standardpfad | Drei begrenzte Katalogzugriffe auf `sys.objects` und `sys.schemas` |
| Teuerster Pfad | Viele sichtbare benutzerdefinierte Objekte in allen drei Datenbanken |
| Haupttreiber | Anzahl sichtbarer schema-gebundener Objekte |
| Skalierung | Sequenziell für `master`, `model` und `msdb` |
| Ressourcen | Geringe Katalog-CPU und lokale Sortierung |
| Begrenzungswirkung | `@MaxZeilen` begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON, nicht den Katalogselect |
| Locking und Nebenwirkungen | Read-only mit `NOLOCK`; keine Objektmutation |
| Schutzmechanismus | Feste Datenbankliste, Katalogfilter und Fehlerisolation |
| Sicherer Einsatz | Inventar mit Eigentümer-, Deployment- und Upgradeunterlagen vergleichen |
| Aussagegrenze | Sichtbarkeit und Katalogklassifikation sind kein Löschurteil |

## Eine Zeile bedeutet

Eine Zeile beschreibt ein Benutzerobjekt mit Datenbank, Schema, Typ sowie Erstellungs- und Änderungszeit.

## So lesen

Ordnen Sie jedes Objekt einem Eigentümer und dokumentierten Betriebszweck zu.

## Warum kann das problematisch sein?

Undokumentierte Objekte können Upgrades, Betrieb, Berechtigungen oder neue Datenbanken aus `model` beeinflussen.

## Wann ist es kein Problem?

Freigegebene administrative oder Monitoringobjekte können betrieblich gewollt sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Benutzerobjekte benötigen Eigentümer-, Zweck- und Upgradeevidenz?

### Technischer Hintergrund

Die Procedure liest `sys.objects` mit `sys.schemas` in drei isolierten Datenbankkontexten.

### Datenkette

`master.sys.databases` → datenbanklokale `sys.objects` und `sys.schemas` → Inventar.

### Source Select

```sql
SELECT [s].[name], [o].[name], [o].[type_desc], [o].[create_date], [o].[modify_date]
FROM [sys].[objects] [o] WITH (NOLOCK)
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id] = [o].[schema_id]
WHERE [o].[is_ms_shipped] = 0;
```

**Wichtig für die Eigenlast:** Der Zugriff bleibt auf Systemkataloge begrenzt; Objektinhalte werden nicht gelesen.

### Zeit- und Scope-Modell

Die Datenbanken werden nacheinander gelesen; Berechtigungsgrenzen können eine partielle Momentaufnahme erzeugen.

### Bewertung und Gegenprobe

Vergleichen Sie Objekt, Eigentümer, Quellcode, Deploymentpfad, Backup und Upgradevertrag.

### Typische Fehlinterpretation

`is_ms_shipped = 0` bedeutet benutzererstellt, nicht automatisch unerlaubt.

### Folgeanalyse

Prüfen Sie Sicherheit, Abhängigkeiten und einen isolierten Upgrade- beziehungsweise Restoretest.

## Primärquellen

- [sys.objects](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-objects-transact-sql?view=sql-server-ver17)
- [System catalog views](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/230_USP_SystemDatabaseObjectInventory.sql)
