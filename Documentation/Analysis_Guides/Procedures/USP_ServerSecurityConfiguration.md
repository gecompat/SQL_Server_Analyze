# [monitor].[USP_ServerSecurityConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Erzeugt Sicherheits-Reviewbefunde zu relevanten Serveroptionen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche ausgewählten Serveroptionen, SQL-Dienste und Servereigenschaften verdienen eine gezielte Sicherheitsprüfung?** Sie inventarisiert keine Prinzipale, Berechtigungen oder Endpoints. Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration]
      @ResultSetArt = 'CONSOLE';
```

Die Parameterhilfe ohne Datenerhebung zeigt `EXEC [monitor].[USP_ServerSecurityConfiguration] @Hilfe = 1;` an.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@PrintMeldungen` | `bit` | `1` | 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst. |
| `@Hilfe` | `bit` | `0` | 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Bindung an varchar(16): CONSOLE gibt ausschließlich die Sicherheitskonfiguration unter dem Label ServerSecurityConfiguration aus; bei leerer Konfiguration liefert der Helfer eine Leerzeile; Quellenstatus, Dienste und Eigenschaften stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur configuration; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen configuration erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst. |
| `@JsonErzeugen` | `bit` | `0` | 1 erstellt JSON mit meta, sources, configuration, services, properties und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung. NULL wirkt wie 0; numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei Erfolg, PARTIAL bei gemischter Quellenverfügbarkeit, INVALID_PARAMETER bei ungültiger ResultSetArt. Bei Gesamtausfall gilt der alphabetisch erste Quellenfehler: DENIED_PERMISSION (229/297/300/371), TIMEOUT (1222) oder ERROR_HANDLED (sonst). Ein ungültiger Modus wird durch Quellenfehlerstatus ersetzt. Zuweisung nach Quellenversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 für invaliden Modus oder mindestens einen ausgefallenen Quellzweig. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des alphabetisch ersten ausgefallenen Quellenzweigs, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Fehlermeldung des alphabetisch ersten ausgefallenen Quellenzweigs, Validierungstext oder NULL bei Erfolg. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL. |

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt = 'RAW';
```

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ServerSecurityConfiguration]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;
SELECT @Json AS [Json];
```

```sql
CREATE TABLE [#ServerSecurityConfiguration_HelpExample]([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_ServerSecurityConfiguration]
          @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"configuration":"#ServerSecurityConfiguration_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE [#ServerSecurityConfiguration_HelpExample];
    THROW;
END CATCH;
DROP TABLE [#ServerSecurityConfiguration_HelpExample];
```

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration] @Hilfe = 1;
```

## Resultsets und Leserichtung

Der TABLE-Vertrag exportiert configuration. Bei RAW steht das Modulstatusresultset vor den Fachergebnissen; CONSOLE liefert nur die jeweilige lesbare Fachansicht und TABLE schreibt nur das benannte Ziel. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Alle vierzehn Textspalten der lokalen Quellenstatus-, Konfigurations-, Dienst-
und Eigenschaftstabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.
Der TABLE-Export `configuration` übernimmt diese Frameworkcollation für
Optionsname und Befund auch bei abweichender Server- oder `tempdb`-Collation.
Die konfigurierten und aktiven Optionswerte bleiben als `sql_variant` erhalten;
JSON stellt dieselben Werte als Text dar.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Sicherheitskonfiguration oder einem normalisierten Reviewfinding.

## So lesen

Berücksichtigen Sie Scope, aktuellen Wert, Exposition, Severity, Evidence und `EvidenceLimit` gemeinsam.

## Warum kann das problematisch sein?

Unsichere Optionen können Angriffsfläche oder unerwünschte Rechtepfade eröffnen.

## Wann ist es kein Problem?

Ein Feature kann betrieblich erforderlich und durch Berechtigungen, Audit oder andere Kontrollen abgesichert sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** `xp_cmdshell` aktiviert ist ein Reviewbefund, aber die reale Gefährdung hängt von Berechtigungen, Nutzung und Kompensationskontrollen ab. Prüfen Sie Sicherheitskonzept und Audit.

**Ähnlich aussehender Gegenfall:** Ein Feature kann betrieblich erforderlich und durch Berechtigungen, Audit oder andere Kontrollen abgesichert sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für USP_ServerSecurityConfiguration weist SourceStatus die Verfügbarkeit von sys.configurations, sys.dm_server_services und SERVERPROPERTY getrennt aus. Mindestens eine erfolgreiche und eine fehlgeschlagene Quelle ergibt PARTIAL; ohne erfolgreiche Quelle gilt der alphabetisch erste Fehlerstatus. Ein leeres Teilresultat ist zusammen mit dem Quellenstatus zu lesen. NULL bedeutet nicht, dass eine Option oder Eigenschaft den Wert 0 hat; die Procedure hat kein Zeilenlimit.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest sieben fest benannte sicherheitsrelevante Serveroptionen, SQL-Dienste sowie vier `SERVERPROPERTY`-/Rollenwerte. Jede Teilquelle schreibt eigenen Status. |
| Teuerster Pfad | Es gibt keinen erweiterten Modus; RAW/JSON zeigen nur mehr Projektionen derselben kleinen Quellen. Die Procedure enumeriert keine Logins, Berechtigungen, Credentials, Endpoints oder Datenbankbenutzer. |
| Haupttreiber | Feste Konfigurationsliste und Zahl der SQL-Dienste. Resultgröße ist unabhängig von Datenbanken und Loginanzahl. |
| Skalierung | Praktisch konstant. Finding-CASE-Auswertung und Sortierung sind gering; Sourcefehler werden isoliert statt durch teure Fallbacks kompensiert. |
| Ressourcen | Ein kleiner `sys.configurations`-Filter, `sys.dm_server_services`, `SERVERPROPERTY`/`IS_SRVROLEMEMBER` und Temp-Tabellen. Kein Registry-, Netzwerk- oder Dateisystemscan. |
| Begrenzungswirkung | Kein `@MaxZeilen`, weil jede Konfigurations-/Dienstzeile Teil des Security-Snapshots ist. `NONE` spart Ausgabe, nicht die Quellprüfung. |
| Locking und Nebenwirkungen | Read-only. Es werden keine Features, Logins oder Dienste geändert; konfigurierte und aktive Werte beziehungsweise Dienststatus können sich zwischen den drei Teilabfragen ändern. |
| Schutzmechanismus | Kein Gate und kein Teil-Scope. Der Sicherheitsvertrag ist fest auf sieben benannte Konfigurationen, SQL-Dienste und vier Server-/Rollenwerte begrenzt; Login-, Benutzer- und Berechtigungsinventare werden nicht geöffnet. |
| Sicherer Einsatz | CONSOLE direkt nutzen; Server-/Maschinenname und Dienstkonten aus RAW/JSON/TABLE als sensible Betriebsmetadaten behandeln. |
| Aussagegrenze | Die Auswertung ist ein enger Konfigurationscheck, kein Berechtigungs- oder Angriffsflächen-Audit. `OK_OR_CONTEXT_DEPENDENT` bestätigt weder Least Privilege noch sichere Proxy-/Credential-/Endpointkonfiguration. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sicherheitsrelevanten Servereinstellungen und Prinzipal-/Endpointmuster verdienen ein Securityreview?

### Technischer Hintergrund

Server Principals, Roles und Permissions, Authentication, Endpoints, Service Accounts und Konfigurationsoptionen bilden mehrere Sicherheitsebenen. Metadata Visibility begrenzt die Sicht. Frameworkbefunde sollen die Konfiguration inventarisieren und keine Credentials oder Secrets ausgeben.

### Datenkette

`sys.configurations`, `sys.dm_server_services`.

### Source Select

Der Konfigurationszweig liest ausschließlich die sicherheitsrelevanten Optionsnamen:

```sql
SELECT
      [c].[name]
    , [c].[value]
    , [c].[value_in_use]
    , [c].[is_dynamic]
FROM [sys].[configurations] AS [c] WITH (NOLOCK)
WHERE [c].[name] IN
      (N'xp_cmdshell',
       N'Ole Automation Procedures',
       N'clr enabled',
       N'clr strict security',
       N'external scripts enabled',
       N'remote admin connections',
       N'contained database authentication');
```

**Wichtig für die Eigenlast:** Die Quellen sind klein. Dienststatus und Instant File Initialization kommen separat aus `sys.dm_server_services`; die Procedure ändert keine Konfiguration und keine Dienstkonten.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Metadaten-/Konfigurationsstand.

### Bewertung und Gegenprobe

Verbinden Sie Finding, Scope, Severity und Confidence, die betroffene Option oder Rolle sowie die dokumentierte Policy. Prüfen Sie insbesondere `sysadmin`, `CONTROL SERVER`, unsichere Optionen und exponierte Endpoints zusammen mit dem zuständigen Owner und der fachlichen Notwendigkeit.

### Typische Fehlinterpretation

Technischer Befund ist kein vollständiges Berechtigungsaudit und keine Aussage über organisatorische Genehmigung. Fehlende Sicht darf nicht als fehlende Berechtigung interpretiert werden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Formales Security-/Identityreview, Audit und Change Governance.

## Primärquellen

- [SQL Server security best practices](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-server-security-best-practices?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#9-monitorusp_serversecurityconfiguration)
