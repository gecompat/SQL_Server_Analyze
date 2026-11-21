---
skill_format_version: "1.0.0"
name: "snapshot.InternalFinalizeCollectionCycle"
schema_name: "snapshot"
object_name: "InternalFinalizeCollectionCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen."
source_path: "Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql"
---

# snapshot.InternalFinalizeCollectionCycle

## Zweck und Einsatz

Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalFinalizeCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @CaptureRunId | bigint | ja | kein Default |
| @StatusCode | varchar(40) | ja | kein Default |
| @IsPartial | bit | ja | kein Default |
| @ErrorNumber | int | ja | kein Default |
| @ErrorMessage | nvarchar(2048) | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@CaptureRunId:** `@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und ist nicht gleich NULL.

**@StatusCode:** `@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text, auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.

**@IsPartial:** `@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell, 1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL; keine Konsistenzprüfung mit StatusCode.

**@ErrorNumber:** `@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl. NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung gespeichert und nicht als SQL-Fehler ausgelöst.

**@ErrorMessage:** `@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert; Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Weder Fach-Resultset noch OUTPUT-Parameter. Die Procedure aktualisiert die vorhandene CaptureRun-Zeile mit StatusCode, IsPartial, ErrorNumber, ErrorMessage und Endzeit; fehlt der CaptureRun, werden null Zeilen aktualisiert und kein eigener Resultsetstatus geliefert. Die übergebenen Statuswerte werden nicht zu einer geschlossenen Fach-Wertemenge umgedeutet.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalFinalizeCollectionCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalFinalizeCollectionCycle] @CaptureRunId=NULL, @StatusCode=NULL, @IsPartial=NULL, @ErrorNumber=NULL, @ErrorMessage=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Zweck: Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen.

Schnittstelle und Parameter
---------------------------
`@CaptureRunId` bigint; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, einzelne
Lauf-ID; keine Positivitäts-/Existenzprüfung. NULL oder kein Treffer bewirkt
null aktualisierte Zeilen ohne expliziten Fehler oder Ausgabe. Beendete Zeile
darf erneut finalisiert werden. Fehlendes Argument scheitert beim Aufruf und
ist nicht gleich NULL.

`@StatusCode` varchar(40); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument, unveränderter, offener Statustext. CaptureRun hat keine CHECK-Wertemenge; jeder nicht-NULL-Text,
auch Leertext, ist speicherbar. NULL scheitert bei Treffer an NOT NULL mit
nativem SQL-Fehler. Keine Konsistenzprüfung mit IsPartial.

`@IsPartial` bit; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtschalter: 0 nicht partiell,
1 partiell. Leertext ist keine unterstützte Eingabe. Direkte Speicherung. NULL scheitert bei Treffer an NOT NULL;
keine Konsistenzprüfung mit StatusCode.

`@ErrorNumber` int; Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für Diagnosezahl.
NULL löscht den Wert; jede vorzeichenbehaftete int-Zahl wird ohne Validierung
gespeichert und nicht als SQL-Fehler ausgelöst.

`@ErrorMessage` nvarchar(2048); Default: Kein Default. Weglassen ist nicht zulässig. Pflichtargument für
Unicode-Diagnosetext. NULL löscht den Wert, Leertext wird gespeichert;
Unveränderter Unicode-Rohtext wird weder ausgeführt noch normalisiert.

Verhalten und Grenzen
---------------------
Aktualisiert die passende CaptureRun-Zeile: EndedAtUtc wird auf
SYSUTCDATETIME() gesetzt, StatusCode, IsPartial, ErrorNumber und ErrorMessage
übernommen. MetricSampleCount und PayloadCount werden mit COUNT_BIG aus den
zugehörigen Tabellen ermittelt. Keine Quellerfassung.

Keine OUTPUT-Parameter und kein Resultset. Kein Treffer aktualisiert null
Zeilen ohne explizite Meldung. Zwei Zählabfragen garantieren keine stabile
gemeinsame Momentaufnahme bei parallelen Änderungen. Keine eigene Transaktion
und kein CATCH; native Fehler werden nicht abgefangen. Wiederholtes Finalisieren
ist nicht gesperrt oder als einmalig abgesichert.
```

