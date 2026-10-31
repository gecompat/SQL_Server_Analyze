# [monitor].[USP_SchemaDesignAnalysis]

**Bereich:** Object und Index<br>
**Zweck:** Erzeugt normalisierte Findings zu Constraints, Foreign Keys, Indizes und Identity-Risiken.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Schemamuster verdienen ein fachliches Designreview?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Die Procedure prüft ihren gesamten Ausführungspfad als `CATALOG_DEEP`. Die Bestätigung ist daher bereits für eine einzelne Datenbank nötig und ersetzt weder den engen Scope noch die Prüfung der Datenbankgröße.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Eingabe ist eine Pipe-Liste einteiliger Datenbanknamen. &#124; trennt nur außerhalb von [ ]; ]] maskiert ] innerhalb einer Klammerung. Äußere U+0020-Elementleerzeichen werden entfernt. Jedes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten haben; leere Elemente, fehlerhafte Klammerung, ungültige PARSENAME-Namen über 128 Zeichen und case-sensitive Duplikate machen die Liste ungültig. NULL, leer oder nur äußere U+0020-Leerzeichen bedeutet keine exakte Einschränkung; ausgelassen = NULL. Eine wirksame Liste ist exklusiv zu @DatabaseNamePattern. Ungültige Liste ergibt INVALID_PARAMETER. Namen ohne passende Kandidaten erzeugen Warnungen statt eines Filterfehlers. Ohne wirksame Liste werden alle sichtbaren, online befindlichen Benutzerdatenbanken berücksichtigt, vorbehaltlich Systemdatenbank-Opt-in und Pattern. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | Bit-Eingabe 0 oder 1; 0 schließt master, tempdb, model und msdb aus, 1 lässt sie in die Kandidatenauswahl zu. NULL ist INVALID_PARAMETER; ausgelassen = 0. Wirkt auch auf Warnungen zu explizit angeforderten, ausgeschlossenen Systemdatenbanken. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ein LIKE-Muster (einschließlich SQL-LIKE-Wildcards %, _ und [...]) oder ein Pattern mit Präfix like:, regex: oder regexi:. Präfixerkennung ist ohne Beachtung der Großschreibung; äußere U+0020-Leerzeichen werden entfernt, der Rest nach Präfixentfernung nicht nochmals getrimmt. LIKE verwendet SQL_Latin1_General_CP1_CS_AS. regex: verwendet Flag c, regexi: Flag i; Regex-Syntax wird nicht vorgeprüft. Regex erfordert SQL Server 2025 (Major-Version 17) und Compatibility Level mindestens 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. Regex filtert Kandidaten nach deren Ermittlung. NULL/ausgelassen bedeutet kein Pattern. Leer, nur U+0020-Leerzeichen oder ein leeres Präfixergebnis ist ungültig; jedes nicht-NULL Pattern zusammen mit einer wirksamen @DatabaseNames-Liste ist INVALID_PARAMETER. |
| `@HighImpactConfirmed` | `bit` | `0` | Bit-Eingabe 0 oder 1. Die Procedure prüft den Analysepfad CATALOG_DEEP; dessen Katalogeintrag hat RequiresGroupGate=1. Bei einem tatsächlich aktivierten, gruppengeschützten Pfad führt 0 zum Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt nur diese Anforderung und erteilt keine Freigabe. Die aktuelle Pfadfreigabe wird separat geprüft und kann DENIED_GROUP ergeben. NULL ist INVALID_PARAMETER, auch wenn kein Pfad freigegeben ist; ausgelassen = 0. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1. |
| `@IdentityWarnPercent` | `decimal(5,2)` | `80.00` | Prozentschwelle nach Bindung an decimal(5,2), zulässiger Bereich 0 bis 100; außerhalb INVALID_PARAMETER. Ausgelassen = 80.00. Identity-UsedPercent nutzt den vollen Typbereich: tinyint 0–255, smallint −32768–32767, int −2147483648–2147483647, bigint −9223372036854775808–9223372036854775807. Bei Inkrement größer oder gleich 0 wird ab Typminimum, bei negativem Inkrement ab Typmaximum gemessen. Seed, Reseed und fachlicher Wertebereich sind darin nicht berücksichtigt. Sequence-UsedPercent nutzt dagegen die konfigurierten minimum_value und maximum_value mit gleicher Richtungsunterscheidung. Findings entstehen ab UsedPercent &gt;= Schwelle; is_exhausted=1 erzeugt ein Sequence-Finding unabhängig von der Schwelle. HIGH gilt ab 95 Prozent oder bei erschöpfter Sequence, sonst MEDIUM. NULL passiert die Bereichsprüfung: Identity-Schwellenvergleiche liefern damit kein Finding; erschöpfte Sequences können weiterhin Findings liefern. Leertext muss vor Ausführung numerisch konvertierbar sein; NULL deaktiviert keine anderen Designregeln. |
| `@MaxZeilen` | `int` | `1000` | Ganzzahliger Zeilenhöchstwert im int-Bereich: 0 bis 2147483647. NULL oder 0 bedeutet unbegrenzt; ausgelassen = 1000; negative Werte sind INVALID_PARAMETER. Nur RAW und JSON begrenzen Findings nach Priorität (HIGH, MEDIUM, übrige), DatabaseId, SchemaName, ObjectName und FindingCode. CONSOLE zeigt und TABLE schreibt alle Findings; NONE gibt keine Resultsets aus. Warnungen werden durch diesen Grenzwert nicht beschränkt. Das TOP-Limit begrenzt weder Katalogjoins, Findingregeln noch vorgelagerte Quellarbeit. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach LTRIM/RTRIM von U+0020-Leerzeichen und UPPER ausgewertet. Zulässig sind RAW (Status-Resultset, auf @MaxZeilen begrenzte Findings, danach alle Warnungen), CONSOLE (ein lesbares Resultset mit allen Findings, bei leerer Quelle eine verständliche Leerzeile; kein separates Status- oder Warnungsresultset), TABLE (schreibt alle Findings in das erforderliche Ziel und gibt kein Resultset aus) und NONE (keine Resultsets). NULL, Leerwert und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. @JsonErzeugen wirkt unabhängig davon. TABLE benötigt ein gültiges @ResultTablesJson-Mapping; außerhalb TABLE löst ein nach Trim von U+0020 nicht leerer Mappingwert THROW 51011 aus. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Für TABLE ein JSON-Objekt mit genau dem Schlüssel findings und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, z. B. N'{"findings":"#SchemaDesignAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen; das Mapping darf keine fremden Namen/Ziele enthalten. NULL oder nach Trim von U+0020 leere Eingabe eignet sich nur außerhalb TABLE; bei TABLE schlägt der Preflight fehl. Bei RAW, CONSOLE oder NONE werden NULL/nach Trim von U+0020 leere Werte ignoriert; ein nicht leerer Wert löst Fehler 51011 aus. Ausgelassen = NULL. |
| `@JsonErzeugen` | `bit` | `0` | Bit-Schalter: 1 erzeugt unabhängig von @ResultSetArt ein JSON-Dokument in @Json; 0 erzeugt keines. NULL wird nicht als ungültig abgewiesen und erfüllt die IF-Bedingung nicht; ausgelassen = 0. Leere Texteingabe ist nicht sinnvoll; eine explizite Nicht-Bit-Angabe muss bereits bei Parameterbindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Reiner OUTPUT-Parameter; Eingabewert ist nicht maßgeblich. Wird bei jedem Aufruf vor der Hilfe- und Parameterprüfung auf NULL gesetzt. Wenn @JsonErzeugen=1, enthält er ein Objekt mit meta, findings und warnings; Findings unterliegen @MaxZeilen, Warnings nicht. Sonst bleibt er NULL. Zum Empfang eine nvarchar(max)-Variable mit OUTPUT binden; bei Auslassen existiert kein empfangbarer Aufrufwert. |
| `@PrintMeldungen` | `bit` | `1` | Unbenutzter bit-Parameter: 0, 1 und NULL beeinflussen weder Meldungen noch Resultsets; ausgelassen = 1. Konvertierbare numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Nicht konvertierbare Eingaben scheitern bei der Parameterbindung. |
| `@Hilfe` | `bit` | `0` | Bit-Eingabe. 1 gibt die Hilfe per PRINT aus und kehrt vor Analyse, regulären Statuszuweisungen und Resultsetausgabe zurück; allerdings laufen vorher Modus-/Mappingprüfungen und @Json wird bereits auf NULL gesetzt. Andere OUTPUT-Parameter werden im Hilfezweig nicht zugewiesen. NULL wird nicht gesondert geprüft und nimmt wie 0 den normalen Analysepfad; ausgelassen = 0. 0 führt den normalen Pfad aus. Leere Texteingabe ist nicht sinnvoll; explizite Werte müssen bei Bindung in bit konvertierbar sein. SQL Server bindet numerische 0 als bit 0 und von 0 verschiedene konvertierbare Zahlen als bit 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte: AVAILABLE (Kandidatenlauf ohne Findings und Teilwarnungen), AVAILABLE_WITH_FINDING (Findings ohne Teilwarnungen), AVAILABLE_LIMITED (Warnungen oder Teilergebnisse), DATABASE_UNAVAILABLE (keine Kandidatendatenbank), INVALID_PARAMETER (ungültige lokale oder vorbereitete Eingabe), HIGH_IMPACT_CONFIRMATION_REQUIRED (erforderliche Bestätigung fehlt), DENIED_GROUP (Pfad nicht freigegeben), UNAVAILABLE_FEATURE (benötigtes Feature fehlt), INTERNAL_ERROR (interner Vorbereitungsvertrag verletzt). DENIED_PERMISSION und ERROR_HANDLED gehören zu datenbankweisen Warnzeilen und sind keine StatusCodeOut-Werte. Die reguläre Zuweisung erfolgt nach Vorbereitung und Statusaggregation. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung wird kein Wert empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @IsPartialOut=@Partial OUTPUT mit einer bit-Variablen. 1 kennzeichnet lokale Parametervalidierungsfehler, Kandidatenwarnungen, datenbankweise Fehler oder fehlende Kandidatendatenbanken; im normalen Lauf ohne Teilfehler gilt 0. Ein abgewiesener delegierter Vorbereitungspfad, etwa HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP, kann 0 belassen, obwohl keine Analyse lief. Der Wert ist daher kein allgemeines Erfolgs- oder Vollständigkeitsbit. Die reguläre Zuweisung erfolgt erst nach Aggregation; Hilfe lässt die Variable unverändert und ein früher THROW umgeht die Zuweisung. Ausgelassen beziehungsweise NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @ErrorNumberOut=@ErrorNumber OUTPUT mit einer int-Variablen. Im aktuellen normalen Lauf bleibt die lokale Fehlernummer stets NULL; datenbankweise Fehlernummern stehen separat in warnings. Zuweisung am Ende der Vorbereitung und Aggregation, vor der Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler OUTPUT-Empfang, etwa @ErrorMessageOut=@ErrorMessage OUTPUT mit einer nvarchar(2048)-Variablen. Der normale Lauf liefert die globale Vorbereitungs-/Parameterfehlermeldung oder NULL bei erfolgreicher Vorbereitung; datenbankweise Meldungen stehen separat in warnings. Zuweisung nach Vorbereitung und Aggregation, vor Ausgabe. Hilfe lässt die Variable unverändert; ein früher THROW erreicht die Zuweisung nicht. Ausgelassen oder NULL als Anfangswert ist zulässig; ohne OUTPUT-Bindung kein Empfang. |

**RAW:**
```sql
EXEC [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

**JSON:**
```sql
DECLARE @SchemaDesignJson nvarchar(max);
EXEC [monitor].[USP_SchemaDesignAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @JsonErzeugen = 1,
      @Json = @SchemaDesignJson OUTPUT;
SELECT @SchemaDesignJson AS [SchemaDesignJson];
```

**TABLE:**
```sql
DROP TABLE IF EXISTS [#SchemaDesignAnalysis_HelpExample];
CREATE TABLE [#SchemaDesignAnalysis_HelpExample] ([SeedValue] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_SchemaDesignAnalysis]
          @DatabaseNames = N'[ExampleDatabase]',
          @HighImpactConfirmed = 1,
          @ResultSetArt = 'TABLE',
          @ResultTablesJson = N'{"findings":"#SchemaDesignAnalysis_HelpExample"}';
    DROP TABLE [#SchemaDesignAnalysis_HelpExample];
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'tempdb..#SchemaDesignAnalysis_HelpExample') IS NOT NULL
        DROP TABLE [#SchemaDesignAnalysis_HelpExample];
    THROW;
END CATCH;
```

**Hilfe:**
```sql
EXEC [monitor].[USP_SchemaDesignAnalysis] @Hilfe = 1;
```

Alle `Example*`-Namen sind synthetisch. Der TABLE-Aufruf setzt voraus, dass der Analysepfad freigegeben ist; die Bestätigung erteilt keine Freigabe.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Designfinding für ein betroffenes und gegebenenfalls verwandtes Objekt.

## So lesen

Berücksichtigen Sie `FindingCode`, Severity, Objekt, Related Object, Metrik, Evidence und `EvidenceLimit` gemeinsam.

## Warum kann das problematisch sein?

Nicht vertrauenswürdige Constraints, fehlende FK-Unterstützung oder fast erschöpfte Identitybereiche können Optimierung, DML und Verfügbarkeit beeinträchtigen.

## Wann ist es kein Problem?

Disabled oder ähnlich wirkende Objekte können Teil eines Lade-, Deployment- oder Constraintdesigns sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein FK ohne passenden Index ist besonders relevant, wenn Parent-Änderungen große Childscans und Blocking erzeugen. Bei statischen Tabellen kann die Priorität niedriger sein. Prüfen Sie Usage, Pläne und Änderungsrisiko.

**Ähnlich aussehender Gegenfall:** Disabled oder ähnlich wirkende Objekte können Teil eines Lade-, Deployment- oder Constraintdesigns sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_SchemaDesignAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Ohne wirksame Datenbankliste oder Pattern werden alle sichtbaren, online befindlichen Benutzerdatenbanken geprüft; Systemdatenbanken sind standardmäßig ausgeschlossen. Eine explizite Liste oder ein Pattern kann den Scope eingrenzen. Einen Objektfilter besitzt die Procedure nicht. |
| Teuerster Pfad | Ohne wirksamen Datenbankfilter über alle sichtbaren Benutzerdatenbanken mit sehr vielen Objekten, FK- und Indexspalten. Findings sind in RAW/JSON bei `@MaxZeilen = NULL` oder `0` unbegrenzt; CONSOLE und TABLE erhalten unabhängig von diesem Wert alle Findings. Warnmengen bleiben ungekürzt. Einen VOLL-Schalter gibt es nicht; jeder fachliche Lauf fordert `CATALOG_DEEP` an. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte sowie Foreign Keys und -Spalten, Check-/Default-Constraints, Indizes und Identitymetadaten. Jeder Datenbankscope wird dynamisch katalogseitig ausgewertet; Benutzertabellenzeilen werden nicht gescannt. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_SchemaDesignAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Eine Datenbankliste begrenzt die ausgewählten Datenbanken; LIKE-Pattern wirken bei der Kandidatenauswahl, Regex filtert nach der Kandidatenermittlung. `@MaxZeilen` wirkt nach Katalogjoins, Signaturbildung und Findingregeln und begrenzt Findings nur in RAW und JSON; CONSOLE zeigt und TABLE schreibt alle Findings. Warnungen und Quellarbeit bleiben von diesem Grenzwert unberührt. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Mit genau einer `ExampleDatabase` starten, deren Objekt-/Indexanzahl vorab bekannt ist. Da kein Objektfilter existiert, große Datenbanken und mehrere Datenbanken nur nacheinander außerhalb der DDL-Spitze prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Schemamuster verdienen ein fachliches Designreview?

### Technischer Hintergrund

Die Procedure leitet normalisierte Findings aus Katalogmerkmalen ab, etwa Datentyp-, Schlüssel-, Index-, Nullable-, LOB- oder Constraintkonstellationen. Solche Regeln erkennen technische Gerüche, nicht die vollständige fachliche Semantik.

### Datenkette

`sys.check_constraints`, `sys.foreign_key_columns`, `sys.foreign_keys`, `sys.identity_columns`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sequences`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Der Foreign-Key-Kern verbindet Constraint, Parent-/Referenztabelle, Schema und Spaltenzuordnung:

```sql
SELECT
      [ps].[name] AS [ParentSchema]
    , [pt].[name] AS [ParentTable]
    , [fk].[name] AS [ForeignKeyName]
    , [rs].[name] AS [ReferencedSchema]
    , [rt].[name] AS [ReferencedTable]
    , [fkc].[constraint_column_id]
    , [fkc].[parent_column_id]
    , [fkc].[referenced_column_id]
FROM [sys].[foreign_keys] AS [fk] WITH (NOLOCK)
JOIN [sys].[tables] AS [pt] WITH (NOLOCK)
  ON [pt].[object_id] = [fk].[parent_object_id]
JOIN [sys].[schemas] AS [ps] WITH (NOLOCK)
  ON [ps].[schema_id] = [pt].[schema_id]
JOIN [sys].[tables] AS [rt] WITH (NOLOCK)
  ON [rt].[object_id] = [fk].[referenced_object_id]
JOIN [sys].[schemas] AS [rs] WITH (NOLOCK)
  ON [rs].[schema_id] = [rt].[schema_id]
JOIN [sys].[foreign_key_columns] AS [fkc] WITH (NOLOCK)
  ON [fkc].[constraint_object_id] = [fk].[object_id]
WHERE [ps].[name] = N'ExampleSchema'
  AND [pt].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Legen Sie Datenbank und Objekt vor Index-, Constraint-, Identity- und Sequence-Gegenprüfungen fest. Der breite High-Impact-Pfad liest mehrere Katalogbereiche; Findings entstehen erst danach und sind kein DDL-Auftrag.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Metadatenstand; sie enthält keine Runtime- oder Workloadhistorie, sofern diese nicht ausdrücklich angereichert wurde.

### Bewertung und Gegenprobe

Betrachten Sie Severity/Confidence, Objektgröße, Workload, Datenqualität, Abhängigkeiten und Migrationsaufwand zusammen. Ein Finding mit hoher technischer Plausibilität kann fachlich bewusst sein.

### Typische Fehlinterpretation

Heuristik ist kein Beweis. Breite Spalten, fehlender PK oder bestimmter Datentyp können durch externe Verträge oder Stagingzweck begründet sein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Object Inventory, Querypläne, Datenprofiling und fachliches Schemaowner-Review.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../03_Object_Index.md#11-monitorusp_schemadesignanalysis)
