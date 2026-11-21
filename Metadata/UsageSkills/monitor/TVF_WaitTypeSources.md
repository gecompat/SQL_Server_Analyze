---
skill_format_version: "1.0.0"
name: "monitor.TVF_WaitTypeSources"
schema_name: "monitor"
object_name: "TVF_WaitTypeSources"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Gibt Quellenbelege und deren vorgesehenen Aussagebereich für einen"
source_path: "Code/01_Common/075a_TVF_WaitTypeSources.sql"
---

# monitor.TVF_WaitTypeSources

## Zweck und Einsatz

Gibt Quellenbelege und deren vorgesehenen Aussagebereich für einen

## Voraussetzungen und Rechte

Der Aufruf braucht SELECT auf [monitor].[TVF_WaitTypeSources] im vorgesehenen Datenbankkontext. Die Funktion liest nur `WaitTypeCatalogSource`; sie erfasst keine Live-Waits.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @WaitType | nvarchar(120) | ja | kein Default |

**@WaitType:** Pflichtwert nvarchar(120), kein Default. Ein einzelner Wait-Type-Schlüssel. Exakte Katalogquellen haben Vorrang; bei einem nicht NULL-Schlüssel ohne Treffer entstehen generische Quellenhinweise, die keine wait-spezifische Verifikation belegen. NULL liefert keine Zeile.

## Resultate und Ausgabe

WaitType und SourceOrdinal ordnen die Zeile; SourceType, Publisher, SourceTitle und SourceUrl beschreiben den Quellenverweis. SupportsFields benennt die vorgesehenen Felder, EvidenceLevel die Quellenklasse und SourceNotes den begrenzten Aussagezweck. CatalogMatchType unterscheidet gespeicherte von generischen Zeilen; LastVerifiedUtc stammt nur aus dem Katalog und ist beim generischen Fallback NULL. [monitor].[WaitTypeCatalogSource]. Fehlt eine solche Zeile, wird der Fallback unabhängig von einem Eintrag in [monitor].[WaitTypeCatalog] erzeugt. Daher bedeutet ein Quellenfallback nicht, dass der Wait Type unbekannt ist; umgekehrt belegt ein exakter Quellenzeileneintrag nicht die Richtigkeit oder Aktualität des verlinkten Inhalts. Die NOLOCK- Lesevorgänge können uncommittete oder inkonsistente Katalogstände erfassen. Die Funktion misst keine Laufzeitwerte und lädt keine Seiten aus dem Netzwerk.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_WaitTypeSources](N'LCK_M_S');
SELECT * FROM [monitor].[TVF_WaitTypeSources](NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
