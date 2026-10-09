# Regelkontext und Analyseverfügbarkeit

**Dauerhafte Entscheidung:** [DEC-0002](../Metadata/Governance/Artifact_Registry.json)

## Standard: sessionlokale Wiederverwendung

Die [Foundation-Effizienzpolicy](../.ai/foundation/PROCESSING_EFFICIENCY_POLICY.md) definiert den Standard. Die native Discovery der geltenden globalen und projektspezifischen `AGENTS.override.md`/`AGENTS.md`-Kette erfolgt bei jedem neuen Lauf und Scopewechsel. Aktuelle Benutzer-, Plattform- und Runtimeanweisungen gelten unmittelbar. Vor einer weiteren Welle werden die aktuelle Autorität, effektive Discovery-Konfiguration, ausgewählten Working-Tree-Quellen und transitiven semantischen Abhängigkeiten lokal geprüft.

Wiederverwendbar ist ausschließlich tatsächlich in derselben Session vorhandene Analyse unter ihrem exakten Autoritäts-, Inhalts-, Scope- und Abhängigkeitsschlüssel. Geänderte Regeln invalidieren ihre Analyse und transitive Abhängige. Geänderte Anweisungen oder Discovery-Einstellungen verhindern die Wiederverwendung betroffener Analysen. Commit- oder Worktreewechsel erfordern eine neue Bindungsprüfung; identische Analyse bleibt bei nachgewiesen gleicher Repositoryidentität, Autorität, Konfiguration und semantischem Scope verfügbar. Eine neue Session oder verlorene Analyse verlangt das erneute Lesen. Fingerprints rekonstruieren keine Analyse.

Der [Projektadapter](../Code/Tools/Rule_Context_Cache.py) bietet dafür `SessionRuleContext` auf dem unverändert installierten [Core-Runtime](../.ai/foundation/runtime/processing_efficiency.py). Dieser Weg benötigt weder den optionalen persistenten Planner noch einen Record oder ein Cacheverzeichnis. Der Aufrufer liefert `repository_identity`, einen aktuellen `authority_key` über die vertrauenswürdig festgestellte geordnete Anweisungskette und effektive Clientkonfiguration sowie `discovery_complete`. Ein beliebiger Digest ist kein Discoverynachweis. `capture` liest die ausgewählten Quellen lokal; `check` liefert `READ`, `PARTIAL` oder `REUSE`. `acknowledge` übernimmt tatsächlich ausgeführte Analysen nach erneuter Prüfung des erfassten Quellstands. `analysis_for` gibt ausschließlich unter dem aktuellen Schlüssel vorhandene Analyse zurück. Der Aufrufer prüft die native Autoritätsbindung erneut, wenn sie sich während der Analyse geändert haben kann; der Adapter attestiert keine Clientkonfiguration.

Unbekannte effektive Clientkonfiguration wird nicht durch angenommene Defaults ersetzt. Sie deaktiviert Wiederverwendung. Die fehlende Einstellung wird einmal je unverändertem Zustand benannt; anschließend gilt der aufgabenbezogene vollständige Leseweg. Eine erneute Konfigurationsprüfung erfolgt bei einem tatsächlichen Wechsel oder einer neuen Session. Globale Clientkonfiguration wird durch diesen Ablauf nicht geändert.

## Discovery und Leseumfang

Der [Scopeindex](Rule_Context_Cache_Scope.json) Version 2 trennt `discovery_sources` von `scopes` und `semantic_dependencies`. Der Discoverybestand erhält die Auffindbarkeit; ein Verweis ist keine automatische Leseverpflichtung. Die ausgewählte Quellenmenge wird um ihre transitiven semantischen Abhängigkeiten erweitert. Das Entwicklungsprofil enthält nach Abhängigkeitserweiterung acht Grundquellen einschließlich der maßgeblichen CI-Teststrategie. Dokumentations-, SQL-, Planungs-, Foundation-Upgrade-, persistente Cache- und Orchestrierungsarbeit wählen den passenden zusätzlichen Scope. Fachliche Quellen außerhalb eines vorhandenen Profils werden vor Wiederverwendung ausdrücklich aufgenommen und ihre Abhängigkeiten geprüft; bis dahin gilt der vollständige Leseweg des betroffenen Umfangs.

Der Index unterscheidet bekannte Governancequellen von Produktreferenzen, historischen Kontexten und optionalen technischen Verträgen. Neue nicht eingeordnete lokale Verweise verhindern Wiederverwendung. Bei einer fachlichen Änderung werden die semantischen Abhängigkeiten mitgeprüft; der Index ist keine zweite Regelquelle. Historische Assessments und Laufzeitnachweise aktivieren keine aktuellen Pflichten. Das vollständige Discoveryinventar bleibt maschinell prüfbar, ohne alle enthaltenen Dokumente in den Modellkontext zu laden.

## Optionaler persistenter Cache

Nur bei ausdrücklicher Nutzung von `check` und `record` gilt zusätzlich die [Foundation-Cachepolicy](../.ai/foundation/RULE_CONTEXT_CACHE_POLICY.md). Der unverändert installierte [Foundation-Planner](../.ai/foundation/rule_context_cache/rule_context_cache.py) behält das Profil `foundation-rule-context-cache/v1`, seine exakten Git-/Worktree-/Discoverybindungen und die Statuswerte `CACHE_HIT`, `PARTIAL_INVALIDATION` und `CACHE_MISS`. Ein persistenter Miss wird nicht als Hit umgedeutet. Die sessionlokale Standardverfügbarkeit ist davon unabhängig.

Der Aufrufer stellt die tatsächliche Discovery-Konfiguration einschließlich Profilen, projektbezogenen Einstellungen und Runtimeüberschreibungen fest. Er übergibt das bestätigte Bytebudget, die geordnete Liste der Fallback-Dateinamen und eine eindeutige Konfigurationskennung. Die folgenden synthetischen Werte sind ausschließlich ein Befehlsbeispiel und keine Annahme über einen unbekannten Client. `python3` bezeichnet den projektspezifischen Python-Aufruf ab Version 3.11.

```sh
python3 Code/Tools/Rule_Context_Cache.py check \
  --codex-home /local/agent-home \
  --cache-dir /local/rule-cache \
  --scope persistent-cache \
  --project-doc-max-bytes 32768 \
  --effective-config-tag verified-synthetic-discovery-v1
```

Ein Check erzeugt keine Datei. Die Ausgabe enthält `snapshot_digest`, `analysis_keys`, `reanalyze` und `reuse`. Nur für tatsächlich vorhandene Sessionanalysen übergibt der Aufrufer deren exakte Schlüssel mit wiederholtem `--available-analysis-key`. Ohne diese Schlüssel verlangt auch ein Fingerprint-Hit das erneute Lesen der ausgewählten Quellen. Scopeindex Version 1 bleibt als bisheriges vollständiges Entwicklungsprofil kompatibel; das Repository verwendet Version 2.

Bei `CACHE_MISS` wird der ausgewählte Regelkontext neu aufgebaut. Bei `PARTIAL_INVALIDATION` werden geänderte Regeln und deren transitive Abhängige vollständig gelesen und analysiert. Erst nach erfolgreicher Analyse wird der exakte geprüfte Digest aufgezeichnet:

```sh
python3 Code/Tools/Rule_Context_Cache.py record \
  --codex-home /local/agent-home \
  --cache-dir /local/rule-cache \
  --scope persistent-cache \
  --project-doc-max-bytes 32768 \
  --effective-config-tag verified-synthetic-discovery-v1 \
  --analyzed-snapshot-digest DIGEST_FROM_PREVIOUS_CHECK
```

Der Adapter prüft diesen Stand erneut unter einer exklusiven Sperre und schreibt atomar. Eine zwischen Analyse und Aufzeichnung geänderte Quelle verhindert den Record. Nach Commit, Integration oder Synchronisierung wird der persistente Stand erneut geprüft. Records bleiben außerhalb von Git, enthalten nur Fingerprints, relative Quellpfade, Git-Zustände, Abhängigkeiten und Analysekennungen und sind keine Validierungsevidenz. Regeltexte, Zusammenfassungen, Prompts, Secrets und absolute Hostpfade werden nicht gespeichert. Unklare Discovery, fehlerhafte Records und konkurrierende Änderungen verlangen den vollständigen Leseweg; unbekannte Sperren werden nicht aufgebrochen.

Die [Vertragsprüfung](../Code/Tests/Static/Validate_Rule_Context_Cache.py) prüft beide Wege mit synthetischen Git-Repositories. Sie ersetzt keine fachliche SQL-Projektvalidierung.
