# [monitor].[USP_LogShippingStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Backup-, Copy- und Restorefortschritt von Log Shipping.<br>
**Beobachtungsart:** lokaler Konfigurations- und Monitorstatus-Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_LogShippingStatus]
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameterverträge

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MaxZeilen` | `int` | Default: `5000` | Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen `INVALID_PARAMETER`; NULL oder 0 werden als unbegrenzte Obergrenze interpretiert. Ein positiver Wert wird getrennt als TOP-Grenze auf Primary- und Secondary-Resultat angewandt, nicht als gemeinsames Gesamtlimit; nach der jeweiligen Sortierung können später eingeordnete Konfigurationen fehlen. Die Eingabe begrenzt nur die ausgegebenen lokalen Konfigurations-/Monitorzeilen, nicht Backup- oder Jobhistory, da solche Quellen nicht abgefragt werden. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultSetArt` | `varchar(16)` | Default: `'CONSOLE'` | Nach Trim und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` gültig; NULL und andere Werte erzeugen `INVALID_PARAMETER`. CONSOLE liefert ausschließlich eine formatierte Primary-Ausgabe ohne zusätzliches Modulstatus- oder Secondary-Resultset; bei leerer Primary-Menge erscheint eine verständliche Hinweiszeile, RAW liefert technische Resultsets, TABLE schreibt das registrierte `primary`-Resultset, NONE unterdrückt Resultsets. CONSOLE und TABLE setzen den internen Resultsetpfad zunächst auf NONE und laufen danach über ihren Ausgabeadapter. Diese Auswahl steuert JSON nicht. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@ResultTablesJson` | `nvarchar(max)` | Default: `NULL` | Bei `TABLE` ist ein nichtleeres JSON-Objekt erforderlich, in der Form {"primary":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit einem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Unbekannte oder doppelte Resultsetnamen, doppelte Ziele, globale/reservierte Ziele, ungültige Namen/Schemas oder fehlende Ziele lösen den TABLE-Preflightfehler 51011 aus. Der Preflight fügt dem Ziel vorübergehend eine Marker-Spalte hinzu und entfernt sie wieder. Außerhalb von TABLE sind NULL und Leer-/Whitespacewerte zulässig; ein nichtleeres Mapping löst 51011 aus. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@JsonErzeugen` | `bit` | Default: `0` | 1 erzeugt JSON; 0 oder NULL lässt `@Json` nach der initialen Rücksetzung NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage), `primary` und `secondary`. Die JSON-Ausgabe ist unabhängig von der Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Json` | `nvarchar(max) OUTPUT` | Default: `NULL` | OUTPUT-Empfangsparameter für das erzeugte JSON. Zu Beginn wird er auf NULL gesetzt; nur bei `@JsonErzeugen = 1` weist die Procedure den JSON-Text zu. Die Struktur ist im Vertrag von `@JsonErzeugen` beschrieben. Bei HELP oder deaktivierter JSON-Erzeugung bleibt der Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben. |
| `@PrintMeldungen` | `bit` | Default: `1` | 1 lässt bei einem behandelten Lesefehler eine Severity-10-Informationsmeldung mit `RAISERROR ... WITH NOWAIT` ausgeben; 0 unterdrückt diese Meldung. NULL wird durch `IF @PrintMeldungen = 1` nicht aktiviert. Der Schalter ändert weder Status noch Resultset-/JSON-Ausgabe. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |
| `@Hilfe` | `bit` | Default: `0` | 1 gibt die Hilfe mit PRINT aus und kehrt vor Quellenverfügbarkeitsprüfung, Primary-/Secondary-Abfrage und Resultset-/JSON-Erzeugung zurück; 0 führt den normalen Ablauf aus. NULL aktiviert die Hilfe nicht. Die Prüfung von @ResultTablesJson sowie der TABLE-Zielpreflight liegen vor dem Hilfezweig. Ein ungültiges Mapping kann deshalb auch mit @Hilfe=1 Fehler 51011 auslösen; ein gültiges TABLE-Ziel wird bereits vor dem Hilferücksprung durch temporäres Hinzufügen und Entfernen einer Marker-Spalte geprüft. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default. |

## Aufrufbeispiele zu den Parameterverträgen

Die Beispiele verwenden synthetische Namen. Die TABLE-Ziele dürfen vor dem Beispiel noch nicht existieren; sie werden leer mit einer Seed-Spalte angelegt und nach dem Aufruf oder einem Aufruffehler entfernt. Eine positive Zeilengrenze ist kein gemeinsames Gesamtlimit und begrenzt keinen vorherigen Historyscan.

```sql
EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;

EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='RAW';

DECLARE @LogShippingJson nvarchar(max); EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@LogShippingJson OUTPUT; SELECT @LogShippingJson AS [Json];

CREATE TABLE #LogShippingStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"primary":"#LogShippingStatus_HelpExample"}'; SELECT * FROM #LogShippingStatus_HelpExample; DROP TABLE #LogShippingStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #LogShippingStatus_HelpExample; THROW; END CATCH;
```

## Resultsets und Leserichtung

RAW liefert zuerst den Modulstatus und anschließend Primary- und Secondary-Zeilen. CONSOLE liefert ausschließlich eine Primary-Ausgabe; bei leerer Menge erscheint eine Hinweiszeile. Der typisierte TABLE-Vertrag exportiert nur `primary`. JSON enthält `meta`, `primary` und `secondary`; eine separate Warningsammlung gibt es nicht. Die beiden fachlichen Mengen besitzen getrennte Zeilengrenzen und dürfen nicht ungeprüft vereinigt werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Primary-/Secondary-Konfiguration, Datenbankbeziehung oder Überwachungszeile.

## So lesen

Vergleichen Sie die Zeitpunkte des letzten Backups, Kopierens und Restores sowie den Schwellenstatus, den Restore Delay und die Metadatenverfügbarkeit.

## Warum kann das problematisch sein?

Eine wachsende Differenz zeigt, ob Backup-, Transport- oder Restorephase zurückfällt.

## Wann ist es kein Problem?

Ein geplanter Restore Delay erzeugt absichtlich Verzögerung.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Backups aktuell, Copy 90 Minuten zurück, Restore ebenfalls zurück: Transportpfad wahrscheinlicher als Backupjob. Prüfen Sie Jobhistorie, Netzwerk, Share und Secondary.

**Ähnlich aussehender Gegenfall:** Ein geplanter Restore Delay erzeugt absichtlich Verzögerung. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Fehlende Primary-/Secondary-Konfigurationen oder Monitorzeilen können eine deaktivierte Komponente, unvollständige Konfiguration oder einen anderen lokalen Scope bedeuten; sie belegen keine erfolgreiche Ausführung.

Bei `USP_LogShippingStatus` setzt ein ungültiger Parameter `INVALID_PARAMETER` mit `IsPartial=1`; ein abgefangener Lesefehler ergibt `ERROR_HANDLED` mit `IsPartial=1`. Fehlen erforderliche Log-Shipping-Tabellen, lautet der aktuelle Status dagegen `UNAVAILABLE_FEATURE`, während `IsPartial=0` bleibt. Status, Fehlerangaben und sichtbarer Scope sind daher zusammen zu lesen; das Partialflag allein belegt keine Verfügbarkeit. Es gibt keine separate Warningausgabe und keinen automatischen Kürzungsnachweis.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast ist gering.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Aktueller lokaler msdb-Snapshot der konfigurierten Primary- und Secondary-Monitorzeilen, jeweils bis zum Defaultlimit 5000. |
| Teuerster Pfad | `@MaxZeilen = 0` bei sehr vielen Log-Shipping-Konfigurationen. Die Procedure liest keine frei wählbare Job- oder Backuphistorie und besitzt keinen Datenbankfilter. |
| Haupttreiber | Zahl lokaler Primary-/Secondary-Konfigurationen und Monitorzeilen in msdb. Backup- oder Jobhistory wird nicht geöffnet; deshalb wächst der Pfad mit konfigurierten Log-Shipping-Beziehungen, nicht mit dem frei wählbaren Historienalter. |
| Skalierung | Nahezu linear mit den lokalen Primary-/Secondary-Monitorzeilen; Ergebnisbreite enthält auch konfigurierte Datei-/Sharefelder, bleibt aber gewöhnlich klein. |
| Ressourcen | Geringe CPU- und msdb-I/O-Last für Konfigurations-/Monitorjoins und Sortierung; keine Remoteabfrage und kein Logdateizugriff. |
| Begrenzungswirkung | `@MaxZeilen` wird als TOP in Primary- und Secondarypfad getrennt angewandt. Es ist keine gemeinsame Gesamtgrenze und kann relevante später sortierte Konfigurationen ausblenden. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein Gate und kein Datenbankfilter. Das endliche Defaultlimit wird getrennt auf Primary- und Secondary-Monitorzeilen angewandt; der Quellpfad bleibt auf aktuelle lokale Log-Shipping-Konfiguration beschränkt und öffnet keine Job- oder Backuphistorie. |
| Sicherer Einsatz | CONSOLE zeigt nur Primary-Zeilen. RAW und JSON enthalten die getrennt begrenzten Primary-/Secondary-Mengen ohne Vollständigkeitsmarker. Für einen größeren Ausschnitt kann `@MaxZeilen` erhöht oder mit 0 aufgehoben werden; erwarteten Scope und aktuelle Änderungen unabhängig gegenprüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf den aktuellen lokalen msdb-Konfigurations-/Monitor-Snapshot, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?

### Technischer Hintergrund

Log Shipping besteht aus Backupjob auf Primary, Copy-/Restorejobs auf Secondary und optional Monitorserver. Monitor-/Primary-/Secondarytabellen halten letzte Datei-/Zeit-/Schwellenwerte. Jede Stufe kann unabhängig zurückliegen.

### Datenkette

`msdb.dbo.log_shipping_monitor_primary`, `msdb.dbo.log_shipping_monitor_secondary`, `msdb.dbo.log_shipping_primary_databases`, `msdb.dbo.log_shipping_secondary_databases`.

### Source Select

Der Primary-Pfad verbindet Konfiguration und Monitorstatus über `primary_id`:

```sql
SELECT
      [p].[primary_database]
    , [p].[backup_directory]
    , [m].[last_backup_date]
    , [m].[last_backup_file]
    , [m].[backup_threshold]
    , [m].[threshold_alert_enabled]
FROM [msdb].[dbo].[log_shipping_primary_databases] AS [p] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[log_shipping_monitor_primary] AS [m] WITH (NOLOCK)
  ON [m].[primary_id] = [p].[primary_id]
WHERE [p].[primary_database] = N'ExampleDatabase';
```

**Wichtig für die Eigenlast:** Filtern Sie die Primary- beziehungsweise Secondary-Datenbank vor der jeweiligen Monitoransicht. Primary und Secondary sind getrennte Zeilengranularitäten und werden nicht über Namen zu einer vermeintlich atomaren Kette verschmolzen.

### Zeit- und Scope-Modell

Die Auswertung verwendet aktuelle lokale Konfigurations- und Monitor-Metadaten mit ihren gespeicherten Zeitwerten; sie liest keine Jobhistorie. Zeitabweichungen und veraltete Monitordaten beeinflussen die Interpretation.

### Bewertung und Gegenprobe

Bewerten Sie Backup-, Copy- und Restorelatenz getrennt. Korrelieren Sie die letzten Dateinamen und Zeiten mit Threshold, Alertstatus, Jobzustand und Monitoraktualität. Restore Mode und Delay können eine beabsichtigte Verzögerung verursachen.

### Typische Fehlinterpretation

Ein grüner Monitor kann stale sein. Eine alte Restorezeit ist bei konfiguriertem Delay nicht automatisch Fehler. Dateinamen allein beweisen keine lückenlose LSN-Kette.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Agent Jobs, Backup Chain und Secondary-/Shareprüfung.

## Primärquellen

- [Überwachen von Log Shipping](https://learn.microsoft.com/en-us/sql/database-engine/log-shipping/monitor-log-shipping-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#6-monitorusp_logshippingstatus)
