# Caller-sichtbares Inventar datenbankweiter DDL-Trigger

**Stand:** 14. November 2026.  
**Status:** V1-Source-Entwurf; unabhängiger Source-Review bestanden, native SQL-Server-2025-Qualifikation ausstehend.  
**Artefakt-UID:** `urn:uuid:01a1da17-ef4f-7acd-bb41-dda47ed2c251`.  
**Registrierung:** `DEFERRED`; keine lesbare Arbeitselementkennung vergeben.

## Diagnosefrage und Evidenzgrenze

`[monitor].[USP_DatabaseDdlTriggerInventory]` beantwortet, welche datenbankweiten DDL-Trigger ein Caller in ausgewählten ONLINE-Datenbanken als Katalogzeilen sehen kann. Der P2-Eintrag `DDL_LOGON_TRIGGERS` stand im qualifizierten Main-Ausgangsstand auf `RESEARCHED_NOT_IMPLEMENTED`. Der begrenzte V1-Source-Slice setzt den Eintrag in dieser Änderung auf `PARTIAL_PRODUCT_FUNCTION`; die native Abnahme steht noch aus. Der Deployment-Preflight liest Triggerkataloge nur, um aktive DDL-Trigger im Installationsziel abzulehnen; `USP_SchemaDesignAnalysis` und `USP_SpecialFeatureInventory` liefern kein caller-sichtbares Triggerinventar. Der V1-Slice erhält daher einen eigenen öffentlichen Endpunkt. Die verbleibende serverweite DDL- und Logon-Trigger-Oberfläche bleibt ausdrücklich offen.

Eine Zeile belegt lediglich sichtbare Katalogmetadaten zum Lesezeitpunkt. `IsDisabled=0` bedeutet nicht deaktiviert und beweist keine Ausführung, Ereigniszuordnung, Transaktionsrücknahme, Sicherheit oder Gesundheit. Eigentümerschaft und effektive Rechte werden nicht aus den Katalogfeldern abgeleitet. V1 führt kein DDL aus und liest keine Triggerdefinitionen oder Ereignisinhalte.

## Quelle, Auswahl und Schema

Für jede ausgewählte, caller-sichtbare und zugreifbare ONLINE-Datenbank liest der Endpunkt `sys.triggers WITH (NOLOCK) WHERE parent_class=0`. Die Standardauswahl umfasst Benutzerdatenbanken ohne Snapshots; Systemdatenbanken bleiben opt-in. Exakte bracket-aware Pipe-Listen und `like:`, `regex:` und `regexi:`-Pattern folgen `USP_PrepareDatabaseCandidates` und dürfen nicht kombiniert werden. Vor und nach dem Datenbankbatch werden ID, Name und `create_date` gegen `master.sys.databases` geprüft. Die Aufnahme ist datenbankübergreifend nicht atomar.

Das Fachresultset `ddlTriggers` enthält genau `DatabaseId`, `DatabaseName`, `TriggerObjectId`, `TriggerName`, `ParentClass`, `ParentClassDesc`, `TriggerType`, `TriggerTypeDesc`, `IsDisabled`, `CreateDate`, `ModifyDate` und `MetadataVisibility`. `ParentClass` ist aufgrund des Filters 0; der native Beschreibungstext bleibt erhalten. `TriggerType` und `TriggerTypeDesc` bleiben native SQL-Server-Werte, einschließlich eines möglichen CLR-Typs `TA`. `MetadataVisibility='VISIBLE_ONLY'` ist eine Aussagegrenze pro Zeile, keine Vollständigkeitsgarantie. Zeitwerte bleiben native `datetime`-Katalogwerte ohne UTC-Interpretation.

`sys.sql_modules`, `sys.server_sql_modules`, `sys.trigger_events`, `sys.server_triggers`, `EVENTDATA()` und `OBJECT_DEFINITION()` werden nicht gelesen. Es gibt keine Text-, Längen- oder Hashabfrage für Definitionen oder Ereignisnutzdaten. DML-Trigger mit `parent_class=1` werden ausgeschlossen.

## Ausgabe, Rechte und Eigenlast

Die vier RAW-Resultsets heißen `moduleStatus`, `ddlTriggers`, `sourceStatus` und `warnings`. `TABLE` schreibt angeforderte benannte lokale Temp-Ziele, `CONSOLE` eine formatierte Menge mit Leerhinweis, `NONE` keine Fachresultsets. Optionales JSON enthält `meta` und alle vier Arrays. Die 15 Parameter mit Defaults, NULL-, Leerwert- und Eingabeformen stehen in der [öffentlichen Procedure-Referenz](../../../Documentation/Analysis_Guides/Procedures/USP_DatabaseDdlTriggerInventory.md) und in der eingebauten Hilfe.

Ein erfolgreicher leerer Katalogbatch erhält `AVAILABLE_LIMITED`, `ObservedRows=0` und `ReturnedRows=0`; er belegt keinen globalen Nullbestand. Jeder normale Lauf bleibt `IsPartial=1`. V1 verlangt kein pauschales `VIEW DEFINITION` vor dem Quellenzugriff, weil SQL Server die Metadatensicht des Callers auf seine Rechte begrenzt. Ein echter nativer Berechtigungsfehler wird getrennt als `DENIED_PERMISSION` mit unbekannter Zeilenzahl ausgewiesen. Ein kontrolliert erzwungener nativer DENIED-Fall ist in der eigenen V1-Fixture nicht vorgesehen und bleibt unqualifiziert. Ein nicht verfügbares Ziel, Fehler 1222 und sonstige Quellenfehler bleiben unterscheidbar.

`@MaxZeilen` begrenzt nur die nach `DatabaseId, TriggerObjectId` geordnete Ausgabe. Datenbankauswahl, Kataloglesung und Sortierung werden dadurch nicht begrenzt. `@LockTimeoutMs` gilt pro Katalogbatch, nicht für Auswahlhelfer, TABLE-Writer oder den Gesamtlauf; der vorherige Sessionwert wird nach Erfolg und Fehler wiederhergestellt. `WITH (NOLOCK)` verringert Sperrkonflikte, kann jedoch eine inkonsistente Aufnahme liefern. Namen und IDs sind native Katalogmetadaten, keine anonymisierten Ergebniswerte.

## Umsetzung und Abnahme

Der kohärente Veröffentlichungsumfang umfasst Source, zentralen Installer und die daraus kanonisch abzuleitende Kopie, Navigator, Objekt-, Parameter-, Resultset-, Quellen-, Rechte- und Reifeinventare, öffentliche Lesepfade sowie den nativen Vertrag. Die eigene SQL-Server-2025-Fixture erzeugt kollisionsgeprüfte synthetische Datenbanken. In der positiven Datenbank legt sie nach eigener Schemaanlage zwei harmlose datenbankweite DDL-Trigger mit verschiedenen Disabled-Zuständen und einen DML-Trigger als ausgeschlossenen Gegenfall an; die zweite Datenbank bleibt ohne Trigger. Sie ruft keinen Trigger auf und erstellt keinen serverweiten oder Logon-Trigger. Direkter Katalog, typisiertes TABLE, JSON, Status, Leere, Kürzung, ungültige Eingaben, eingeschränkte Caller-Sicht, Caller-Optionen, unveränderte Katalogmetadaten und Cleanup werden strikt geprüft. Ein nativer Compiler- oder Setupfehler ist kein Produkt-PASS.

Die Änderung am zentralen Installer verlangt das vollständige funktionale SQL-Server-2025-Gate mit Compatibility Level 170. Betroffene statische API-, Navigator-, Dokumentations-, Datenschutz- und Packaging-Prüfungen kommen hinzu. Weitere native Engines und Compatibility Levels benötigen ein konkretes Versionsrisiko. `Module_Maturity` bleibt bis zu einer gesonderten Reifeabnahme `PLANNED`.
