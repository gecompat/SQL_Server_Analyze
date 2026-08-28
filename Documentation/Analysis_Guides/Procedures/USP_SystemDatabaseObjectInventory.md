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

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Der Aufruf verwendet nur Systemkataloge. Führen Sie ihn zunächst unter dem vorgesehenen Diagnosekonto aus und vergleichen Sie einen eingeschränkten Lauf separat, wenn Vollständigkeit relevant ist. Ein Objekt wird erst nach dokumentierter Eigentümer- und Abhängigkeitsprüfung außerhalb dieser Procedure verändert.

## Resultsets und Leserichtung

CONSOLE zeigt `systemDatabaseObjects`. RAW liefert den Modulstatus und danach das begrenzte Inventar. TABLE und JSON verwenden dieselbe lokale Materialisierung. Lesen Sie `DatabaseName`, `SchemaName`, `ObjectName`, `ObjectType`, `StatusCode` und `EvidenceLimit` zuerst. `CreateDate` und `ModifyDate` sind Katalogzeitpunkte; bei Tabellen und Views kann sich `ModifyDate` auch durch Indexänderungen verändern und ist deshalb kein verlässlicher Deploymentzeitpunkt.

## Beispiele und Gegenbeispiele

Eine leere synthetische Lab-Instanz kann `AVAILABLE_EMPTY` liefern. Drei explizit erzeugte Tabellen `ExampleOps009Object` in `master`, `model` und `msdb` bilden einen kontrollierten Positivfall und müssen nach dem Test exakt entfernt werden. Ein Gegenbeispiel ist die automatische Löschung eines sichtbaren administrativen Objekts. Ebenso darf eine Zeile in `model` nicht ohne Gegenprüfung als Fehler gelten, weil bewusst bereitgestellte Vorlagen existieren können.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet nur, dass im aktuellen Sicherheitskontext keine passenden Objekte sichtbar waren. Es beweist nicht, dass die Systemdatenbanken objektfrei sind. Eine Datenbank wird nur verarbeitet, wenn sie online und für den Aufrufer zugänglich ist. Scheitert ein datenbanklokaler Katalogzugriff, bleibt die Quellgrenze als `SOURCE_UNAVAILABLE` erhalten und der Gesamtstatus kann `AVAILABLE_LIMITED` werden.

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
| Begrenzungswirkung | `@MaxZeilen` begrenzt Ausgabe, nicht den Katalogselect |
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
