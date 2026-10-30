# [monitor].[USP_ServerVersionInformation]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Ordnet Instanzbuild, Servicing-Zweig und Microsoft-Lifecycle anhand eines versionierten Offline-Katalogs ein.<br>
**Beobachtungsart:** aktueller Instanzsnapshot plus Frameworkkatalog<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure beantwortet: **Welche technische SQL-Server-Version läuft, wie lässt sich der Build im offline mitgelieferten Microsoft-Katalog einordnen und in welcher Lifecycle-Phase befindet sich die Hauptversion?** Sie ist der leichte Einstieg vor versionsabhängigen Diagnosepfaden und benötigt keinen Plan-Cache-, Query-Store- oder Benutzerdatenzugriff.

Build, Katalogtreffer und Lifecycle werden getrennt ausgegeben. Eine operative Patchentscheidung braucht zusätzlich die aktuelle Microsoft-Buildseite, die organisationsspezifische Freigabe und gegebenenfalls Security Advisories. Die Procedure führt keinen Onlinezugriff aus und verändert keine Instanzeinstellung.

## Nicht beantwortete Fragen

Die Ausgabe beweist weder vollständige Security-Patches noch Verwundbarkeit, ausstehenden Neustart, Lizenzkonformität oder betriebliche Freigabe einer CU. `SERVERPROPERTY('LicenseType')` und `NumLicenses` werden bewusst nicht als Lizenznachweis verwendet. Ein unbekannter Build ist nicht automatisch veraltet; er kann neuer als der Offline-Katalog, ein Preview-/On-Demand-Build oder ein nicht katalogisierter Servicing-Zweig sein.

Die normale CONSOLE-Ausgabe enthält keine Server-, Host-, Instanz-, Konto- oder Pfadidentität. Optional ausgegebene Datenbanknamen stammen nur aus dem ausdrücklich aktivierten Resultset `databaseCompatibility`.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerVersionInformation]
      @ResultSetArt = 'CONSOLE';
```

Verwenden Sie mit folgendem Aufruf einen optionalen, synthetischen Datenbankkontext:

```sql
EXEC [monitor].[USP_ServerVersionInformation]
      @MitDatenbankKompatibilitaet = 1,
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'RAW';
```

### JSON-, TABLE- und OUTPUT-Beispiele

CONSOLE zeigt die verdichtete Build-/Lifecyclezeile; RAW enthält sieben Resultsets. JSON ist unabhängig von ResultSetArt. Die vier Status-/Fehler-OUTPUT-Parameter werden nur bei normalem Abschluss beschrieben; beim frühen Help-Return bleiben sie unverändert, während @Json auf NULL gesetzt ist. Der Help-Return liegt vor TABLE-Mapping und -Preflight:

```sql
DECLARE @VersionJson nvarchar(max), @Status varchar(40), @Partial bit, @ErrNo int, @ErrMsg nvarchar(2048);
EXEC [monitor].[USP_ServerVersionInformation] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@VersionJson OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@ErrNo OUTPUT, @ErrorMessageOut=@ErrMsg OUTPUT;
```

TABLE akzeptiert eine eindeutige Teilmenge der sieben Resultsetnamen. databaseCompatibility bleibt opt-in. Ein leeres lokales Einspalten-Dummyziel reicht; der gemeinsame Writer passt es an, eine Seed-Zeile ist nicht erforderlich:

```sql
CREATE TABLE #ServerVersionInformation_HelpExample (Placeholder int NULL);
EXEC [monitor].[USP_ServerVersionInformation] @MitDatenbankKompatibilitaet=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databaseCompatibility":"#ServerVersionInformation_HelpExample"}';
```

T-SQL konvertiert den numerischen Wert 0 zu bit 0 und von 0 verschiedene numerische Werte zu bit 1. Übergeben Sie diese Parameter als 0 oder 1. Wenn @MitDatenbankKompatibilitaet=0 bleibt die Procedure beim Instanz-/Build-/Lifecyclepfad; @DatabaseNames und @DatabaseNamePattern müssen NULL bleiben, sonst folgt INVALID_PARAMETER. @SystemdatenbankenEinbeziehen muss im normalen Pfad auch dann nicht-NULL sein, wenn Compatibility deaktiviert ist. Ein negatives @MaxZeilen bleibt unabhängig davon ungültig.

## Parametervertrag

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MitDatenbankKompatibilitaet` | `bit` | `0` | Ausgelassen = 0. 1 aktiviert databaseCompatibility. 0 überspringt dessen Kandidatenpfad; dann müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben, sonst INVALID_PARAMETER. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen = NULL. Nur bei aktivierter Compatibility-Ausgabe ausgewertet; NULL bedeutet keine Listenbegrenzung, sonst bracket-aware Pipe-Liste einteiliger SQL-Namen (Pipe trennt nur außerhalb von [...], ]] maskiert ]). Wenn Compatibility deaktiviert ist, muss der Parameter NULL sein. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ausgelassen = NULL. Nur bei aktivierter Compatibility-Ausgabe; alternativ zur Liste. Äußere Leerzeichen werden entfernt, Präfixe sind case-insensitiv: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE verwendet %, _ und SQL-Zeichenklassen [...] unter SQL_Latin1_General_CP1_CS_AS. Leerer Patterninhalt ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Bei deaktivierter Compatibility-Ausgabe muss der Wert NULL sein. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Ausgelassen = 0. Nur bei aktivierter Compatibility-Ausgabe bewirkt 0 den Ausschluss und 1 die Zulassung von master, tempdb, model und msdb. NULL ist auch bei deaktivierter Compatibility-Ausgabe im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@MaxZeilen` | `int` | `2000` | Ausgelassen = 2000. NULL oder 0 bedeutet unbegrenzt; positiv begrenzt nur databaseCompatibility nach der Auswahl; negativ setzt INVALID_PARAMETER, auch wenn Compatibility deaktiviert ist. |
| `@ResultSetArt` | `varchar(16)` | `CONSOLE` | Ausgelassen = CONSOLE. Äußere Leerzeichen entfernen, großschreiben. Die vollständigen Werte sind CONSOLE (verdichtete Consolezeile), RAW (alle sieben technischen Resultsets), TABLE (gemappte Ziele) und NONE (keine fachlichen Resultsets). NULL, leer und andere Werte sind im normalen Pfad INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Ausgelassen = NULL. Nur TABLE erlaubt; ein JSON-Objekt mit eindeutiger Teilmenge der sieben exakten Schlüssel serverVersion, buildAssessment, lifecycle, instanceFeatures, databaseCompatibility, references und warnings. Jeder Schlüssel erhält ein vorhandenes lokales #Temp-Ziel; alle Ziele sind eindeutig und leer und die JSON-Zuordnung ist vor Quellenzugriff geprüft. Eine leere Einspalten-Dummytabelle kann der Writer an das Quellschema anpassen. Nicht-TABLE mit nichtleerem Mapping ist INVALID_PARAMETER. Der Help-RETURN liegt vor diesem Mapping-Preflight. |
| `@JsonErzeugen` | `bit` | `0` | Ausgelassen = 0. 1 erzeugt JSON unabhängig von ResultSetArt; 0 lässt JSON aus. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter. Mit OUTPUT binden. Der Eingabewert wird gleich bei Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält JSON meta und die benannten Ergebnisarrays. Hilfe lässt @Json bei NULL, nachdem es geleert wurde. |
| `@PrintMeldungen` | `bit` | `1` | Ausgelassen = 1. 1 gibt normale Warnmeldungen bei Status ungleich AVAILABLE aus; 0 unterdrückt sie. NULL ist im normalen Pfad INVALID_PARAMETER. Hilfe-PRINT bleibt aktiv. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@Hilfe` | `bit` | `0` | Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor Bewertung, normaler Parameter-/Filtervalidierung und TABLE-Mapping-Preflight zurück; 0 und NULL führen normal weiter. @Json ist davor bereits NULL; die Status-/Fehler-OUTPUT-Werte bleiben beim Help-RETURN unverändert. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Wird im normalen Abschluss mit dem tatsächlichen Modulstatus belegt. Die Procedure setzt unter anderem AVAILABLE, AVAILABLE_LIMITED und INVALID_PARAMETER; abgefangene Quellenfehler behalten ihren jeweiligen tatsächlichen Status. Beim Help-RETURN bleibt der übergebene Wert unverändert. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert im normalen Abschluss 0 für vollständige bzw. 1 für partielle Ausgabe. Beim Help-RETURN bleibt der übergebene Wert unverändert. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert die tatsächlich abgefangene Fehlernummer oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert den tatsächlich erfassten Fehlertext oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert. |

## Resultsets und Leserichtung

Die sieben stabilen Resultsetnamen lauten `serverVersion`, `buildAssessment`, `lifecycle`, `instanceFeatures`, `databaseCompatibility`, `references` und `warnings`. CONSOLE verdichtet Build- und Lifecyclebewertung zu genau einem Grid. RAW liefert alle sieben Resultsets in dieser Reihenfolge. TABLE akzeptiert eine beliebige eindeutige Teilmenge der sieben Namen; JSON verwendet gleichnamige Arrays unter einer gemeinsamen `meta`-Hülle.

Die 64 Textspalten der sieben TABLE-Exporte und die übrigen lokalen
Textspalten verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Der Vergleich
der Instanzbuildnummer mit dem Offline-Katalog verwendet diese Collation
ebenfalls ausdrücklich. Eine abweichende Server- oder `tempdb`-Collation
verändert dadurch den Buildvergleich und die Exportcollations nicht.
Das vorhandene Zeilenlimit betrifft weiterhin ausschließlich
`databaseCompatibility`; bei einer exakten Liste erfolgt dessen Auswahl
zuerst nach der angeforderten Reihenfolge. Instanz-, Feature-, Referenz-
und Warnungszeilen werden durch dieses Datenbanklimit nicht entfernt.

Berücksichtigen Sie zuerst `warnings`, Modulstatus und `buildAssessment`. Prüfen Sie danach `lifecycle`, die technischen `serverVersion`-Eigenschaften und bei Bedarf `instanceFeatures`. `references` enthält ausschließlich öffentliche Microsoft-URLs und den Katalogstand.

## Eine Zeile bedeutet

`serverVersion`, `buildAssessment` und `lifecycle` enthalten je Aufruf höchstens eine Instanz-/Hauptversionszeile. Eine Zeile in `instanceFeatures` steht für genau ein `SERVERPROPERTY`-Flag. Eine Zeile in `databaseCompatibility` steht für den sichtbaren Katalogzustand einer ausgewählten Datenbank. Eine `warnings`-Zeile beschreibt eine fehlende Teilquelle oder eine nicht eindeutige Offline-Einordnung.

Die Granularitäten dürfen nicht ohne Resultsetname zusammengeführt werden. `CapturedAtUtc`, `SourceType`, `SourceObject`, `EvidenceScope` und `EvidenceLimit` bestimmen Herkunft und Aussagegrenze.

## So lesen

`AssessmentStatus` unterscheidet unter anderem `EXACT_MATCH`, `OLDER_KNOWN_BUILD`, `UNKNOWN_BUILD`, `BUILD_NEWER_THAN_OFFLINE_CATALOG`, `PREVIEW_BUILD` und `ON_DEMAND_BUILD`. `CatalogFreshnessStatus` bewertet ausschließlich das Alter des mitgelieferten Katalogs. Der Lifecycle-Status bezieht sich auf die Hauptversion, nicht auf Edition, ESU-Vertrag oder eine konkrete KB.

`LatestKnownBuildInBranch` ist nur bei eindeutig bekanntem Servicing-Zweig vergleichbar. `LatestKnownBuildForMajor` ist ein Navigationshinweis und keine universelle Upgradeempfehlung. Prüfen Sie bei einer unbekannten oder höheren Buildnummer zuerst die verlinkte Microsoft-Buildübersicht.

## Warum kann das problematisch sein?

Ein alter bekannter Build kann dokumentierte spätere Qualitäts- oder Security-Releases nicht enthalten. Ein abgelaufener Mainstream-Support verändert die Art der verfügbaren Wartung. Ebenso problematisch ist eine scheinbar präzise Bewertung mit einem veralteten Offline-Katalog: Sie kann neuere Builds nicht kennen.

Die Procedure verhindert diese Überinterpretation durch getrennte Build-, Katalog- und Lifecycle-Status sowie durch stabile Primärquellenlinks.

## Wann ist es kein Problem?

Ein `OLDER_KNOWN_BUILD` kann bewusst organisationsweit freigegeben und innerhalb eines unterstützten Wartungsplans liegen. `EXTENDED_SUPPORT` bedeutet nicht automatisch Betriebsstörung. Ein `UNKNOWN_BUILD` kann ein neuerer Build sein, den der lokale Katalog noch nicht enthält. Ohne Abgleich mit der aktuellen Primärquelle ist keine dieser Zeilen allein ein Änderungsauftrag.

## Beispiele und Gegenbeispiele

**Synthetischer Befund:** `ExampleInstance` meldet einen exakten Katalogtreffer, aber nicht den neuesten bekannten Build desselben Zweigs. Das ist ein Prüfauftrag für Release Notes, Testplan und Wartungsfenster, keine automatische Installationsanweisung.

**Gegenbeispiel:** Der laufende Build ist höher als jeder Katalogeintrag. `BUILD_NEWER_THAN_OFFLINE_CATALOG` bedeutet gerade nicht „veraltet“, sondern „lokal nicht abschließend klassifizierbar“.

**Nicht entscheidbar:** Fehlt der OS-/Startzeitkontext wegen Berechtigung, bleiben SERVERPROPERTY, Buildkatalog und Lifecycle weiterhin nutzbar; die Procedure kennzeichnet das Ergebnis als partiell.

## Leere oder partielle Ausgabe

Fehlen `serverVersion`, `buildAssessment` oder `lifecycle`, ist die technische Einordnung nicht vollständig. Ein leeres `databaseCompatibility`-Resultset ist bei `@MitDatenbankKompatibilitaet = 0` erwartungsgemäß. Explizit angeforderte, aber nicht sichtbare oder ausgeschlossene Datenbanken erscheinen in `warnings`.

`NULL` in einer Eigenschaft bedeutet nicht anwendbar, nicht verfügbar oder nicht lesbar und wird über Status/Evidenzgrenze eingeordnet. Ein `@MaxZeilen`-Limit betrifft nur den optionalen Datenbankkontext.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Eine SERVERPROPERTY-Materialisierung, zwei kleine Frameworkkataloge und isolierte Host-/Uptime-DMVs. |
| Teuerster Pfad | Optional alle sichtbaren Datenbanken aus `master.sys.databases` für den Compatibility-/Collation-Kontext. |
| Haupttreiber | Zahl sichtbarer beziehungsweise explizit ausgewählter Datenbanken. |
| Skalierung | Instanz- und Katalogteil konstant; Datenbankresultset linear zur Kandidatenzahl. |
| Ressourcen | Geringe CPU-, Katalog- und TempDB-Arbeitstabellenlast; kein Benutzerdaten-, Plan-Cache- oder Query-Store-Zugriff. |
| Begrenzungswirkung | `@DatabaseNames`/Pattern begrenzen früh; `@MaxZeilen` begrenzt die sichtbare Datenbankausgabe, nicht die Instanzbewertung. |
| Locking und Nebenwirkungen | Lesend, keine Konfigurations-, Netzwerk- oder Patchoperation; Kataloge werden nur bei der Installation aktualisiert. |
| Schutzmechanismus | Identitäts- und Pfadwerte fehlen in CONSOLE; Quellen sind isoliert und Partialstatus bleibt sichtbar. |
| Sicherer Einsatz | Zuerst ohne Datenbankkontext; anschließend bei Bedarf eine synthetisch benannte oder gezielt ausgewählte Datenbank. |
| Aussagegrenze | Offline-Einordnung und Produktlifecycle, kein Vulnerability-, Lizenz-, Neustart- oder Freigabenachweis. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie wird ein aktueller Instanzbuild ohne Internetzugriff reproduzierbar und ohne falsche Patchbehauptung eingeordnet?

### Technischer Hintergrund

Die Procedure materialisiert `SERVERPROPERTY` einmal, ergänzt nach Möglichkeit `sys.dm_os_host_info` und `sys.dm_os_sys_info` und vergleicht die vollständige Buildnummer mit `monitor.SqlServerBuildCatalog`. Der Hauptversions-Lifecycle stammt getrennt aus `monitor.SqlServerLifecycleCatalog`. Beide Kataloge werden versioniert durch den Installer gepflegt.

### Datenkette

`SERVERPROPERTY` → `#ServerVersionInformation_ServerVersion` → `monitor.SqlServerBuildCatalog`/`monitor.SqlServerLifecycleCatalog` → benannte Ausgabe. Optional: `master.sys.databases` → `databaseCompatibility`. Die Ausgabe liest keine Primärquelle online.

### Source Select

Die lokale Buildnummer wird mit dem offline versionierten Build- und Lifecyclekatalog verbunden:

```sql
DECLARE @ProductVersion varchar(32) =
    CONVERT(varchar(32), SERVERPROPERTY(N'ProductVersion'));
DECLARE @ProductMajorVersion int =
    CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));

SELECT
      @ProductVersion AS [ProductVersion]
    , [b].[ReleaseName]
    , [b].[ServicingBranch]
    , [b].[ReleaseDate]
    , [l].[ProductName]
    , [l].[MainstreamEndDate]
    , [l].[ExtendedEndDate]
FROM [monitor].[SqlServerBuildCatalog] AS [b] WITH (NOLOCK)
LEFT JOIN [monitor].[SqlServerLifecycleCatalog] AS [l] WITH (NOLOCK)
  ON [l].[ProductMajorVersion] = @ProductMajorVersion
WHERE [b].[BuildVersion] = @ProductVersion;
```

**Wichtig für die Eigenlast:** Exakter Build- und Major-Key machen die Abfrage klein. Es erfolgt kein Onlinezugriff; unbekannte Builds bleiben unbekannt und müssen über die verlinkte Microsoft-Buildübersicht geprüft werden.

### Zeit- und Scope-Modell

Instanzeigenschaften und Datenbankkatalog sind ein aktueller Aufrufsnapshot; Build- und Lifecyclezeilen besitzen den expliziten Katalogstand 2026-07-21. Ein später veröffentlichter Build erfordert ein Katalogupdate oder den manuellen Abgleich über `references`.

### Bewertung und Gegenprobe

Berücksichtigen Sie die vollständige Buildnummer, den exakten Treffer, den Servicing-Zweig, das Katalogalter und die offizielle Buildübersicht gemeinsam. Verwenden Sie die aktuelle Microsoft-Buildseite der erkannten Hauptversion als Gegenprobe und prüfen Sie den Lifecycle separat auf der Microsoft-Lifecycle-Seite.

### Typische Fehlinterpretation

Die höchste numerische Buildnummer kann aus einem anderen Servicing-Zweig stammen. Deshalb darf eine CU-Differenz nur innerhalb eines eindeutig bekannten Zweigs interpretiert werden. Edition und Engine Edition sind ebenfalls kein Lizenznachweis.

### Folgeanalyse

Prüfen Sie vor einer Patchentscheidung Release Notes, Security Advisory, Backup- und Rollbackplan, Kompatibilitätstests sowie die organisationsspezifische Freigabe. Verwenden Sie anschließend `USP_ServerFeatureCapabilities`, um die Featurefähigkeit zu ermitteln.

## Primärquellen

- [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql?view=sql-server-ver17)
- [SQL Server 2019 builds](https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/build-versions)
- [SQL Server 2022 builds](https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/build-versions)
- [SQL Server 2025 builds](https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/build-versions)
- [SQL Server 2019 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2019)
- [SQL Server 2022 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2022)
- [SQL Server 2025 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2025)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#9-monitorusp_serverversioninformation)
