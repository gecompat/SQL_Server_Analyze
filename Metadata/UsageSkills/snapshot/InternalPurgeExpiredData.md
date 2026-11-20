---
skill_format_version: "1.0.0"
name: "snapshot.InternalPurgeExpiredData"
schema_name: "snapshot"
object_name: "InternalPurgeExpiredData"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Löscht Snapshotdaten in begrenzten Batches."
source_path: "Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql"
---

# snapshot.InternalPurgeExpiredData

## Zweck und Einsatz

Löscht Snapshotdaten in begrenzten Batches. Ablaufzeiten gelten für Messwerte, Payloads und zugehörige Läufe; verwaiste Scopes ungleich SERVER werden ohne Altersprüfung entfernt.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalPurgeExpiredData]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[RetentionPolicy]`, `[snapshot].[PurgeRun]`, `[sys].[database_files]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxBatches | int | ja | kein Default |
| @Force | bit | ja | kein Default |
| @PurgeRunIdOut | bigint OUTPUT | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @BudgetExceededOut | bit OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @ContractOnly | bit | nein | 0 |
| @RetentionContractVersionOut | int OUTPUT | nein | NULL |
| @ExpectedTargetDatabaseId | int | nein | NULL |
| @ExpectedTargetDatabaseName | sysname | nein | NULL |
| @ExpectedTargetCreateDate | datetime | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@MaxBatches:** - @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.

**@Force:** - @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.

**@PurgeRunIdOut:** - @PurgeRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich zu übergeben, auch wenn verworfen; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfänglich NULL. Bei normalem Lauf wird die Receipt-ID nach Vorprüfungen gesetzt; sie belegt keinen Erfolg. Bei Handshake, Skip oder frühem Abbruch bleibt sie NULL. MaxBatches= NULL kann nach Receipt-INSERT null Iterationen und AVAILABLE ergeben; ein Nicht-NULL-Bereichsfehler kehrt vor Receipt-Erstellung zurück. Empfang bigint oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs AVAILABLE, später ggf. dokumentierter Status. Ein regulär erfolgreicher Handshake belässt AVAILABLE; frühe Guards können andere Statuswerte setzen. Empfang varchar(40) oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@BudgetExceededOut:** - @BudgetExceededOut (bit OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs 0. Bei Handshake oder frühem ungültigem Abbruch kann 0 „nicht gemessen“ bedeuten. Beim normalen Abschluss bedeutet 1, dass die allokierte Typ-0-Dateikapazität nachher strikt über SoftBudgetMB liegt, sonst 0. Beim Intervallskip stützt sich 0 auf den Vorwert; im CATCH ist 1 konservativ und keine Messung. Empfang bit oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern Fehlernummer. Bei MaxBatches-Bereichsverletzung bleibt NULL. Empfang int oder kompatibel. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern SQL-Fehlertext oder Guard-Meldung. Empfang Unicode-Variable mit bis 2048 Zeichen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ContractOnly:** - @ContractOnly (bit; Default: 0): optional, auslassbar; Werte 0, 1 oder NULL; Leertext ist keine unterstützte Bit-Eingabe. 0 normaler Purge; NULL INVALID_PARAMETER und RETURN 51011. 1 nur Versions-Handshake: keine Löschung, kein PurgeRun-Receipt, keine Budgetgrößenmessung; liest PackageVersion und gegebenenfalls Identitätsmetadaten und setzt NOCOUNT sowie LOCK_TIMEOUT 0. Handshake erfordert IMPLICIT_TRANSACTIONS OFF. Kein @@TRANCOUNT-Guard für explizite Caller-Transaktionen.

**@RetentionContractVersionOut:** - @RetentionContractVersionOut (int OUTPUT; Default: NULL): optional, auslassbar oder zum Empfang bindbar. NULL-Eingabe erlaubt; Leertext ist keine unterstützte Zahleneingabe. Eingabewert ignoriert; zunächst 1, dann 3, wenn irgendeine PackageVersion-Zeile SchemaVersion 3 und PackageVersion 1.2.2, 1.3.0 oder 1.3.1 hat, sonst 1. Auslassen verwirft Ausgabe. Ausgabe 1 beweist nicht SchemaVersion 1; 3 keine vollständige Zielqualifikation. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ExpectedTargetDatabaseId:** - @ExpectedTargetDatabaseId (int): Default NULL; optional. Weglassen verwendet NULL. Erwartet eine ganze Datenbank-ID größer als 4, die DB_ID() der aktuell verbundenen Datenbank entspricht; Leertext ist keine vorgesehene Zahlenform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; sobald irgendein Feld gesetzt ist, müssen alle drei zur gleichen online und schreibbaren Zieldatenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Die Datenbank wird nicht gewechselt. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder irgendeinem gesetzten Identitätsfeld verlangt; für ContractOnly=0 mit allen drei NULL gibt es diesen Guard nicht.

**@ExpectedTargetDatabaseName:** - @ExpectedTargetDatabaseName (sysname): Default NULL; optional. Weglassen verwendet NULL. Erwartet den rohen Datenbanknamen als sysname-Wert, der ohne Trimmen oder Schreibweisennormalisierung binär mit master.sys.databases.name übereinstimmt; Leertext passt nicht. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei vorliegen und zur online und schreibbaren aktuellen Datenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.

**@ExpectedTargetCreateDate:** - @ExpectedTargetCreateDate (datetime): Default NULL; optional. Weglassen verwendet NULL. Erwartet den typisierten datetime-Wert von master.sys.databases.create_date der Zieldatenbank, ohne UTC-Konvertierung; Leertext ist keine vorgesehene Datumsform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei zur online und schreibbaren aktuellen Datenbank passen. Eine Abweichung ergibt TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Im Normalpfad wird kein fachliches Resultset ausgegeben. Die erforderlichen OUTPUT-Argumente melden `@PurgeRunIdOut` (bigint: Receipt-ID nach Vorprüfungen oder NULL bei Handshake, Skip und frühem Abbruch), `@StatusCodeOut` (varchar(40): Status, anfangs AVAILABLE), `@BudgetExceededOut` (bit: Budgetkennzeichen, bei frühem Abbruch nicht zwingend gemessen), `@ErrorNumberOut` (int) und `@ErrorMessageOut` (nvarchar(2048)) für erkannte Fehler. Das optionale `@RetentionContractVersionOut` (int OUTPUT) meldet zunächst 1 und bei den bekannten Schema-3-Paketständen 3; diese Zahl allein belegt keine vollständige Zielqualifikation. `@ContractOnly=1` ist ein Versions-Handshake ohne Löschung oder Purge-Receipt. Normale Läufe löschen in begrenzten Batches und können persistente Snapshotdaten ändern.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalPurgeExpiredData';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalPurgeExpiredData] @MaxBatches=NULL, @Force=NULL, @PurgeRunIdOut=NULL, @StatusCodeOut=NULL, @BudgetExceededOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

- @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.
- @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.
- @PurgeRunIdO

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : snapshot.InternalPurgeExpiredData
Version      : 1.1.0
Stand        : 2026-10-25
Zweck        : Löscht Snapshotdaten in begrenzten Batches. Ablaufzeiten gelten
               für Messwerte, Payloads und zugehörige Läufe; verwaiste Scopes
               ungleich SERVER werden ohne Altersprüfung entfernt.
===============================================================================

#### InternalPurgeExpiredData – Parameterverträge

Die ersten sieben Argumente müssen übergeben werden. OUTPUT-Argumente dürfen ohne OUTPUT-Kennzeichnung gebunden werden, wenn die Ausgabe verworfen wird; zum Empfang sind Variable und OUTPUT-Kennzeichnung erforderlich. Eingehende Werte aller OUTPUT-Parameter, auch NULL oder Leertext, werden ignoriert.

- @MaxBatches (int; Default: Kein Default): erforderliches Argument; Nicht-NULL als ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Falls keine frühere Rückkehr erfolgt, kann ein Receipt entstehen, die Schleife läuft nullmal und der Status kann AVAILABLE sein. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 setzt INVALID_PARAMETER; ErrorNumber bleibt NULL. Leertext ist keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen je Iteration. Bei ContractOnly=1 ignoriert, dennoch erforderlich.
- @Force (bit; Default: Kein Default): erforderlich; Werte 0 und 1, NULL wird nicht abgewiesen. Leertext ist keine unterstützte Bit-Eingabe. 0 überspringt nur, wenn zugeteilte Kapazität der Datenbankdateien Typ 0 innerhalb des Budgets liegt, ein früherer erfolgreicher Lauf AVAILABLE oder AVAILABLE_LIMITED existiert und sein Intervall noch läuft. 1 umgeht diese Überspringprüfung; NULL erfüllt Force=0 ebenfalls nicht und umgeht sie damit auch. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; die Scope-Bereinigung bleibt altersunabhängig.
- @PurgeRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich zu übergeben, auch wenn verworfen; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfänglich NULL. Bei normalem Lauf wird die Receipt-ID nach Vorprüfungen gesetzt; sie belegt keinen Erfolg. Bei Handshake, Skip oder frühem Abbruch bleibt sie NULL. MaxBatches= NULL kann nach Receipt-INSERT null Iterationen und AVAILABLE ergeben; ein Nicht-NULL-Bereichsfehler kehrt vor Receipt-Erstellung zurück. Empfang bigint oder kompatibel.
- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs AVAILABLE, später ggf. dokumentierter Status. Ein regulär erfolgreicher Handshake belässt AVAILABLE; frühe Guards können andere Statuswerte setzen. Empfang varchar(40) oder kompatibel.
- @BudgetExceededOut (bit OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs 0. Bei Handshake oder frühem ungültigem Abbruch kann 0 „nicht gemessen“ bedeuten. Beim normalen Abschluss bedeutet 1, dass die allokierte Typ-0-Dateikapazität nachher strikt über SoftBudgetMB liegt, sonst 0. Beim Intervallskip stützt sich 0 auf den Vorwert; im CATCH ist 1 konservativ und keine Messung. Empfang bit oder kompatibel.
- @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern Fehlernummer. Bei MaxBatches-Bereichsverletzung bleibt NULL. Empfang int oder kompatibel.
- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich zu übergeben; Der gebundene Anfangswert einschließlich NULL oder Leertext wird ignoriert; anfangs NULL, bei behandelten Fehlern SQL-Fehlertext oder Guard-Meldung. Empfang Unicode-Variable mit bis 2048 Zeichen.
- @ContractOnly (bit; Default: 0): optional, auslassbar; Werte 0, 1 oder NULL; Leertext ist keine unterstützte Bit-Eingabe. 0 normaler Purge; NULL INVALID_PARAMETER und RETURN 51011. 1 nur Versions-Handshake: keine Löschung, kein PurgeRun-Receipt, keine Budgetgrößenmessung; liest PackageVersion und gegebenenfalls Identitätsmetadaten und setzt NOCOUNT sowie LOCK_TIMEOUT 0. Handshake erfordert IMPLICIT_TRANSACTIONS OFF. Kein @@TRANCOUNT-Guard für explizite Caller-Transaktionen.
- @RetentionContractVersionOut (int OUTPUT; Default: NULL): optional, auslassbar oder zum Empfang bindbar. NULL-Eingabe erlaubt; Leertext ist keine unterstützte Zahleneingabe. Eingabewert ignoriert; zunächst 1, dann 3, wenn irgendeine PackageVersion-Zeile SchemaVersion 3 und PackageVersion 1.2.2, 1.3.0 oder 1.3.1 hat, sonst 1. Auslassen verwirft Ausgabe. Ausgabe 1 beweist nicht SchemaVersion 1; 3 keine vollständige Zielqualifikation.
- @ExpectedTargetDatabaseId (int): Default NULL; optional. Weglassen verwendet NULL. Erwartet eine ganze Datenbank-ID größer als 4, die DB_ID() der aktuell verbundenen Datenbank entspricht; Leertext ist keine vorgesehene Zahlenform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; sobald irgendein Feld gesetzt ist, müssen alle drei zur gleichen online und schreibbaren Zieldatenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Die Datenbank wird nicht gewechselt. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder irgendeinem gesetzten Identitätsfeld verlangt; für ContractOnly=0 mit allen drei NULL gibt es diesen Guard nicht.
- @ExpectedTargetDatabaseName (sysname): Default NULL; optional. Weglassen verwendet NULL. Erwartet den rohen Datenbanknamen als sysname-Wert, der ohne Trimmen oder Schreibweisennormalisierung binär mit master.sys.databases.name übereinstimmt; Leertext passt nicht. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei vorliegen und zur online und schreibbaren aktuellen Datenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.
- @ExpectedTargetCreateDate (datetime): Default NULL; optional. Weglassen verwendet NULL. Erwartet den typisierten datetime-Wert von master.sys.databases.create_date der Zieldatenbank, ohne UTC-Konvertierung; Leertext ist keine vorgesehene Datumsform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei zur online und schreibbaren aktuellen Datenbank passen. Eine Abweichung ergibt TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht.

#### InternalPurgeExpiredData – Ausführungsvertrag

Der normale Lauf liest die DEFAULT-Aufbewahrungsrichtlinie. Messwerte folgen CollectedAtUtc/RawRetentionDays, Payloads CapturedAtUtc/PayloadRetentionDays. ModuleStatus und CaptureRun folgen StartedAtUtc/RawRetentionDays, sofern Kinddatensätze fehlen. Der neueste finalisierte WAIT_STATS-Lauf und der neueste FILE_IO-Lauf bleiben erhalten; bei FILE_IO ist Finalisierung nicht nötig. Verwaiste Scopes ungleich SERVER werden ohne Altersprüfung gelöscht. Rollups werden nicht gelöscht.

Pro Iteration gilt PurgeBatchRows separat für jede Tabelle, nicht als Gesamtzeilenlimit. Jede Iteration führt BEGIN/COMMIT aus. Bei einer bestehenden Caller-Transaktion persistiert ein verschachteltes COMMIT die Iteration nicht unabhängig; ein CATCH-Rollback kann die gesamte äußere Transaktion zurückrollen. Ohne äußere Transaktion bleiben zuvor committete Iterationen bei einem späteren Fehler bestehen. Vorprüfungen, Richtlinien- und Größenlesung sowie Receipt-INSERT liegen außerhalb TRY. Das CATCH-Audit-UPDATE kann selbst fehlschlagen. Zähler können bei zurückgerollter fehlgeschlagener Iteration versuchte Zeilen enthalten.

Budgetmessung: Größen der Datenbankdateien Typ 0, Seiten zu MB umgerechnet; weder belegte Snapshot-/Payload-Bytes noch Logdateien. Kein Shrink; Budget kann nach Purge überschritten sein. Gleichheit mit SoftBudgetMB ergibt 0, nur strikt größer ergibt 1. Beim Überspringen bedeutet 0 „vorher innerhalb Budget“. CATCH setzt 1 vorsorglich, nicht als Messwert.

Status- und Fehlerwerte:
- AVAILABLE: Normaler Abschluss ohne Ausschöpfung des Batches-Limits durch einen Batch mit Löschungen; der reine gültige Handshake behält den anfänglichen Wert AVAILABLE. Ein früher ungültiger Handshake-Guard kann stattdessen INVALID_PARAMETER liefern. AVAILABLE belegt keine Löschung.
- INVALID_PARAMETER: ContractOnly=NULL oder anderer früher ungültiger Guard. Ein Nicht-NULL-MaxBatches außerhalb 1 bis 1000 führt ebenfalls zu diesem Status, ohne ErrorNumber zu setzen.
- TARGET_UNAVAILABLE: Identitätsgruppe unvollständig oder Datenbank-ID, roher Name, create_date, Onlinezustand oder Schreibbarkeit stimmen nicht; ErrorNumber 53764.
- SKIPPED_NOT_DUE: Force=0 und zugeteilte Kapazität nicht über Budget, erfolgreicher Vorgängerlauf vorhanden und Intervall nicht verstrichen.
- AVAILABLE_LIMITED: Batches-Limit erreicht und letzter Batch löschte mindestens eine Zeile; kein Beleg weiterer abgelaufener Zeilen.
- DENIED_PERMISSION: CATCH erfasste Fehlernummer 229, 262, 297, 300 oder 371.
- ERROR_HANDLED: anderer im CATCH erfasster Fehler. Nicht jeder Fehler liegt im TRY/CATCH; das CATCH-Audit-UPDATE kann selbst scheitern.
RUNNING ist nur Receipt-Zustand. Gelöschte-Zeilen-Zähler im CATCH bestätigen keinen Commit.
```

