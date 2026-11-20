---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalyseAccessCurrent"
schema_name: "monitor"
object_name: "VW_AnalyseAccessCurrent"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Zeigt für jede Katalogklasse den aus den aktuellen Login- und Policyinformationen abgeleiteten IsAllowed-Wert und den Grund."
source_path: "Code/01_Common/040_VW_AnalyseAccessCurrent.sql"
---

# monitor.VW_AnalyseAccessCurrent

## Zweck und Einsatz

Zeigt für jede Katalogklasse den aus den aktuellen Login- und Policyinformationen abgeleiteten IsAllowed-Wert und den Grund.

## Voraussetzungen und Rechte

Der Aufruf braucht SELECT auf [monitor].[VW_AnalyseAccessCurrent] im vorgesehenen Datenbankkontext. Die View verbindet Analyseklassen, aktive AccessPolicy und den sichtbaren `sys.login_token` des aktuellen Kontextes; fehlende Token-Sicht ist kein positiver Gruppennachweis.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

AnalysisClass (varchar(64)), AnalysisLevel (varchar(16)), RequiresGroupGate (bit), OriginalLoginName und EffectiveLoginName (nvarchar(128)), IsSysadmin (bit), ActivePolicyCount, RelevantPolicyCount und MatchedGroupCount (bigint), IsAllowed (bit) sowie AccessReason (varchar(20)).


## Beispiel

```sql
SELECT [AnalysisClass], [AnalysisLevel], [RequiresGroupGate], [OriginalLoginName], [EffectiveLoginName], [IsSysadmin], [ActivePolicyCount], [RelevantPolicyCount], [IsAllowed], [AccessReason], [MatchedGroupCount] FROM [monitor].[VW_AnalyseAccessCurrent] WITH (NOLOCK) ORDER BY [AnalysisLevel], [AnalysisClass];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalyseAccessCurrent
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Zeigt für jede Katalogklasse den aus den aktuellen Login- und
               Policyinformationen abgeleiteten IsAllowed-Wert und den Grund.
Parameter    : Keine. Die Login- und Tokenwerte beziehen sich auf den Aufruf.
Ausgabe      : AnalysisClass (varchar(64)), AnalysisLevel (varchar(16)),
               RequiresGroupGate (bit), OriginalLoginName und EffectiveLoginName
               (nvarchar(128)), IsSysadmin (bit), ActivePolicyCount,
               RelevantPolicyCount und MatchedGroupCount (bigint), IsAllowed
               (bit) sowie AccessReason (varchar(20)).
Policy       : Aktiv sind Zeilen mit IsEnabled=1, ValidFromUtc NULL oder nicht
               später als SYSUTCDATETIME(), ValidToUtc NULL oder später als
               SYSUTCDATETIME() sowie nichtleeren, getrimmten Klassen- und
               Gruppennamen. Gespeicherte Zeichenfolgen werden dadurch nicht
               getrimmt. Sobald mindestens eine solche Zeile global aktiv ist,
               kann eine geschützte Klasse ohne relevante Regel gesperrt sein.
               Eine Regel für '*' gilt zusätzlich für jede geschützte Klasse.
Abgleich     : Windows-Gruppen aus sys.login_token werden nach Typfilter und
               case-insensitivem Vergleich unter Latin1_General_100_CI_AS
               abgeglichen. Login-Token-Paare werden je Klasse und Gruppe
               dedupliziert; IS_MEMBER zählt nur bei Rückgabewert 1, NULL gilt
               nicht als Treffer. Der Gruppenabgleich ist keine Live-Abfrage
               beim Active Directory und belegt keine SQL-Berechtigung.
Reihenfolge  : Die fachliche Fallauswahl lautet: ungeschützte Klasse,
               sysadmin, keine aktive Policy, Treffer über Login-Token,
               IS_MEMBER-Treffer, sonst NO_MATCH. AccessReason liefert dazu
               NOT_REQUIRED, SYSADMIN, OPEN_POLICY, LOGIN_TOKEN, IS_MEMBER oder
               NO_MATCH. Priority wird zwar aus der Policy mitgeführt, sortiert
               oder priorisiert die Freigabe derzeit aber nicht. Die logische
               Fallreihenfolge garantiert keine physische Kurzschlussauswertung
               durch den SQL-Server.
Zählung      : MatchedGroupCount summiert Treffer je Analyseklasse über die
               spezifische und die '*' Regel. Deshalb kann dieselbe Gruppe bei
               einer passenden spezifischen und globalen Regel mehrfach in der
               Summe erscheinen; die Zahl bezeichnet keine eindeutigen Personen
               oder Active-Directory-Mitglieder.
Berechtigung : Für den Aufruf sind Leserechte auf die verwendeten Framework-
               Views und verfügbare Tokeninformationen erforderlich. Die View
               vergibt oder beweist keine SQL-Rechte. sys.login_token wird mit
               NOLOCK gelesen; daraus folgt weder ein Live-AD-Nachweis noch ein
               Nachweis für GRANT-, DENY- oder Objektberechtigungen.
Beispiel     : SELECT [AnalysisClass], [AnalysisLevel], [RequiresGroupGate],
                      [OriginalLoginName], [EffectiveLoginName], [IsSysadmin],
                      [ActivePolicyCount], [RelevantPolicyCount], [IsAllowed],
                      [AccessReason], [MatchedGroupCount]
               FROM [monitor].[VW_AnalyseAccessCurrent] WITH (NOLOCK)
               ORDER BY [AnalysisLevel], [AnalysisClass];
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
```

