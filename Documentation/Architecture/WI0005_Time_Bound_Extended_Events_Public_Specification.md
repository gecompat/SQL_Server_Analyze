# WI-0005: Zeitbegrenzte Extended-Events-Sessions – Freigabevorlage

**Status:** APPROVED; am 13. Oktober 2026 unmittelbar durch den Benutzer freigegeben. Implementierung und Laufzeitabnahme sind in Bearbeitung.
**Referenz:** WI-0005.
**Basis:** Integrierter Stand vom 13. Oktober 2026.

## Zweck und bestehende Lücke

`monitor.USP_ExtendedEventsSessions` inventarisiert Sessiondefinitionen und
Runtimezustände, liest aber keine maximale Sessionlaufzeit. WI-0005 ergänzt
diese vorhandene Procedure; eine zusätzliche öffentliche Procedure ist
nicht erforderlich. Das Framework bleibt lesend und führt keine Session-
oder Targetaktion aus.

## Öffentliche Änderung zur Freigabe

Ein neuer Parameter `@MitZeitgrenzen bit = 0` aktiviert die zusätzliche
Analyse. Der Default erhält die bisherigen RAW-Resultsets, JSON-Schemaversion
und CONSOLE-Projektion. Bei aktivierter Analyse wird das benannte Resultset
`timeBounds` nach den bestehenden RAW-Detailresultsets ausgegeben. JSON
enthält zusätzlich `timeBounds` und kennzeichnet den aktivierten Vertrag
mit `schemaVersion = 2`. Die bestehende JSON-Version 1 bleibt bei deaktivierter
Analyse erhalten. TABLE akzeptiert zusätzlich das Ziel `timeBounds`; das
bestehende Ziel `sessions` und sein Schema bleiben unverändert. CONSOLE
behält seine einzelne vorhandene Sessionübersicht.

Die neue Menge übernimmt ausschließlich die bereits ausgewählten Sessions.
Namensfilter, `@NurLaufend` und `@MaxZeilen` gelten für dieselbe Auswahl;
ein zusätzlicher unbeschränkter Serverlauf ist ausgeschlossen. Bei
deaktiviertem Zeitgrenzenpfad bleibt ein ausdrücklich angefordertes neues
TABLE-Ziel leer und besitzt das festgelegte Schema.

| Feld | Nativer SQL-Typ | Bedeutung |
|---|---|---|
| `EventSessionId` | `int NOT NULL` | Identität derselben ausgewählten Session. |
| `SessionName` | `sysname NOT NULL` | Name derselben ausgewählten Session. |
| `MaxDurationSeconds` | `bigint NULL` | Native konfigurierte Dauer; 0 bedeutet unbegrenzt, NULL eine nicht verfügbare Quelle. |
| `IsTimeBound` | `bit NULL` | Nur bei verfügbarer Konfiguration aus der positiven Dauer abgeleitet. |
| `RuntimeState` | `varchar(40) NOT NULL` | RUNNING, STOPPED, NOT_COLLECTED oder SOURCE_UNAVAILABLE. |
| `RunningSince` | `datetime NULL` | Unveränderter nativer Runtime-Startzeitwert, sofern er erfasst wurde. |
| `RemainingSecondsEstimate` | `bigint NULL` | Begrenzte Schätzung für eine laufende zeitgebundene Session; keine garantierte Stopfrist. |
| `SourceStatus` | `varchar(40) NOT NULL` | AVAILABLE, UNAVAILABLE_VERSION, SOURCE_UNAVAILABLE, DENIED_PERMISSION oder ERROR_HANDLED. |
| `ErrorNumber` | `int NULL` | Tatsächlicher isolierter Quellenfehler. |
| `ErrorMessage` | `nvarchar(2048) NULL` | Tatsächliche Quellenfehlermeldung nach bestehendem Frameworkvertrag. |
| `CollectionTimeUtc` | `datetime2(3) NOT NULL` | Erfassungszeit dieses Aufrufs. |
| `EvidenceLimit` | `nvarchar(1000) NOT NULL` | Grenze zwischen Konfiguration, beobachtetem Runtimezustand und Schätzung. |

Textvergleiche und exportierte Textfelder verwenden die bestehende explizite
Frameworkcollation. Ein STOPPED-Wert wird nur aus einer tatsächlich erfassten
Runtimequelle abgeleitet; `@MitLaufzeitstatus = 0` liefert NOT_COLLECTED.
Eine fehlende oder verweigerte Runtimequelle erzeugt keine behauptete
Restlaufzeit.

## Gemeinsamer Quellenstatus und Partialität

Konfigurations- und Runtimeverfügbarkeit werden unabhängig erhoben. Bereits
verfügbare Konfigurationswerte bleiben bei einem Runtimefehler erhalten;
`RuntimeState = SOURCE_UNAVAILABLE` und eine NULL-Restzeit kennzeichnen die
fehlende Runtimequelle. Bei `@MitLaufzeitstatus = 0` wird keine Runtimequelle
als erforderlich behandelt; NOT_COLLECTED ist kein Fehler.

Für das gemeinsame `SourceStatus`- und Fehlerpaar gilt folgende feste
Reihenfolge. Tatsächlich beobachtete Quellenfehler haben Vorrang vor einem
erwarteten Versionsfallback. Bei zwei tatsächlichen Fehlern bleibt der erste
in der festgelegten Quellenfolge Konfiguration, danach Runtime erhalten.
Ein beobachteter Berechtigungsfehler liefert DENIED_PERMISSION. Ein nativer
Locktimeout mit Fehler1222 und andere beobachtete Quellenfehler liefern
ERROR_HANDLED mit ihrer tatsächlichen Fehlernummer. Ein nur im Client
abgebrochener Aufruf wird nicht als erfolgreicher SQL-Quellenstatus
qualifiziert.

Ohne tatsächlichen Fehler liefert eine fehlende erwartete Spalten- oder
Quellenverfügbarkeit SOURCE_UNAVAILABLE. Der ausdrücklich erwartete
SQL-Server-2019-/2022-Konfigurationsfallback liefert UNAVAILABLE_VERSION;
sonst gilt AVAILABLE. Bei Versionsfallback und tatsächlichem Runtimefehler
bleiben Dauer und IsTimeBound NULL, der Runtimefehler bestimmt das Fehlerpaar
und SourceStatus; EvidenceLimit benennt zusätzlich die Versionsgrenze.

Ein tatsächlicher Quellenfehler oder eine unerwartet fehlende Quelle setzt
bei aktiviertem Pfad IsPartial=1. Eine zuvor verfügbare Modulstatuszeile
wechselt dabei nach dem bestehenden Frameworkmodell zu AVAILABLE_LIMITED; bereits
vorhandene frühere Modulfehler bleiben erhalten. Erwarteter Versionsfallback,
bewusst deaktivierte Runtimeerfassung und eine fachlich nicht ableitbare
Restzeitschätzung erzeugen allein keine neue Partialität. Die bisherigen
Sessiondaten werden durch den Zusatzpfad nicht gelöscht. Der Default mit
`@MitZeitgrenzen = 0` erhält alle bisherigen Statusregeln.

## Quellen, Versionen und Kosten

Die Konfiguration stammt aus `sys.server_event_sessions.max_duration`.
SQL Server 2019 und 2022 erhalten `UNAVAILABLE_VERSION`. SQL Server 2025
prüft zusätzlich die tatsächliche Spaltenverfügbarkeit vor dynamischem
Zugriff. Eine fehlende sichtbare Spalte wird als SOURCE_UNAVAILABLE gemeldet;
fehlende Berechtigung wird nur bei einem tatsächlich beobachteten
Berechtigungsfehler behauptet.

Der Runtime-Startwert stammt aus `sys.dm_xe_sessions.create_time`. Für die
Restschätzung werden auf derselben Serveruhr erfasste Werte verwendet. Die
native Zeitbasis wird vor Qualifikation geprüft. Unbekannte Zeitbasis,
negative verstrichene Zeit, deaktivierte Runtimeerfassung, unbegrenzte Dauer
und fehlender Runtimewert liefern NULL statt einer erfundenen Restfrist.
Eine Schätzung von 0 bei weiterhin beobachtetem RUNNING beweist keine
überschrittene Stopgarantie. Die Momentaufnahme kann mit Sessionende oder
Neustart konkurrieren.

Der Pfad liest lediglich begrenzte Katalog-/Runtimewerte. Er benötigt kein
High-Impact-Gate und liest keine Targetdaten, Eventpayloads oder Dateien.
Berechtigungen werden nicht verändert. Ein neuer Teilquellenfehler darf die
bereits erfassten alten Sessiondaten nicht verwerfen; Partialität und
Quellenstatus werden nach dem bestehenden Frameworkmodell getrennt geführt.

## Umsetzung und verpflichtende Abnahme

Die vertikale Änderung umfasst Procedure, Parameter- und Resultsetinventare,
Systemquellen, Hilfe, Dokumentation, generierte Installer und betroffene
Consumer. Eine gemeinsame Quellenmaterialisierung verhindert eine zweite
unabhängige Auswahlmenge. Die Prüfung umfasst insbesondere:

- unverändertes Defaultverhalten und alte Session-/TABLE-Schemas;
- endliche, unbegrenzte, gestoppte und neu gestartete eigene Sessions;
- die Unterscheidung deaktivierter Runtimeerfassung und tatsächlich gestoppter Session;
- Namensfilter, Grenzen 1/0/NULL sowie ungültige Parameter;
- RAW-/TABLE-/JSON-Parität des neuen Resultsets und erhaltene CONSOLE-Ausgabe;
- Permission-, Quellenfehler- und fehlende Spaltenpfade;
- echte automatische Beendigung einer eigenen endlichen Session, ohne aus einem früheren Snapshot eine Garantie abzuleiten;
- versionssichere Fallbacks und bestehende Consumer.

Die Testauswahl folgt `Documentation/Quality/CI_Test_Strategy.md`: primär
SQL Server 2025/CL170, zusätzliche native Engines nur für den konkret
betroffenen Versionsfallback und ein abschließender Release-Nachweis.
Eigene Fixtures bleiben synthetisch und werden ausschließlich im eigenen
isolierten Lab erstellt und entfernt. Imagebeschaffung, Builds oder Zugriff
auf fremde Instanzen sind durch diese Vorlage nicht autorisiert.

## Primärquellen

- [sys.server_event_sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-event-sessions-transact-sql?view=sql-server-ver17).
- [sys.dm_xe_sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-xe-sessions-transact-sql?view=sql-server-ver17).
- [CREATE EVENT SESSION](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-event-session-transact-sql?view=sql-server-ver17).
