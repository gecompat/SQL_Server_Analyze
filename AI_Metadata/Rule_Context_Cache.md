# Regelkontextcache für Entwicklungswellen

**Dauerhafte Entscheidung:** [DEC-0002](../Metadata/Governance/Artifact_Registry.json)

## Verbindlicher Ablauf

Die [Foundation-Cachepolicy](../.ai/foundation/RULE_CONTEXT_CACHE_POLICY.md) bleibt maßgeblich. Die native Discovery der geltenden globalen und projektspezifischen `AGENTS.override.md`/`AGENTS.md`-Kette erfolgt bei jedem neuen Lauf. Aktuelle Benutzeranweisungen werden unmittelbar angewendet. Vor jeder weiteren Entwicklungswelle wird der Regelstand deterministisch geprüft.

Der [Projektadapter](../Code/Tools/Rule_Context_Cache.py) verwendet den unverändert installierten [Foundation-Planner](../.ai/foundation/rule_context_cache/rule_context_cache.py). Der [Scopeindex](Rule_Context_Cache_Scope.json) enthält die Quellen des Entwicklungsprofils und ausdrücklich eingeordnete Verweise auf Produktdokumentation, historische Kontexte oder optionale technische Verträge. Der Index enthält keine Regeltexte und ersetzt weder den kanonischen Backlog noch die Projektregeln. Neue, nicht eingeordnete Verweise verlangen `CACHE_MISS`; der Scope wird dann geprüft und bei Bedarf erweitert. Für Arbeiten außerhalb dieses Profils ist der vollständige Leseweg maßgeblich, bis deren zusätzliche Quellen aufgenommen und unabhängig geprüft wurden.

Der Aufrufer stellt die effektive Discovery-Konfiguration einschließlich Profilen, projektbezogenen Einstellungen und Laufzeitüberschreibungen fest. Er übergibt das tatsächliche Bytebudget, die geordnete Liste der Fallback-Dateinamen und eine eindeutige Konfigurationskennung. Unbekannte Einstellungen erlauben keinen Cachebetrieb. Ohne Überschreibungen gelten für Codex 32.768 Byte und keine Fallback-Dateinamen. Eine Änderung globaler Einstellungen ist dafür nicht erforderlich.

Die folgenden Befehle verwenden ausschließlich synthetische Pfade. Der Cache liegt außerhalb des Repositorys innerhalb der zulässigen lokalen Datenhaltung. In PowerShell wird der konfigurierte Python-Aufruf verwendet; `python3` bezeichnet hier Python ab Version 3.11.

```sh
python3 Code/Tools/Rule_Context_Cache.py check \
  --codex-home /local/agent-home \
  --cache-dir /local/rule-cache \
  --project-doc-max-bytes 32768 \
  --effective-config-tag codex-default-discovery-v1
```

Ein Check erzeugt keine Datei. Die Ausgabe enthält `snapshot_digest`, `analysis_keys`, `reanalyze` und `reuse`. Nur für tatsächlich vorhandene Sessionanalysen übergibt der Aufrufer deren exakten Schlüssel mit wiederholtem `--available-analysis-key`. Ohne diese Schlüssel verlangt auch ein Fingerprint-Hit das erneute Lesen der zusätzlichen Quellen. Die semantischen Analysen bleiben ausschließlich in der Session; eine neue Session erhält sie nicht aus der Cachedatei.

Bei `CACHE_MISS` wird der relevante Regelkontext neu aufgebaut. Bei `PARTIAL_INVALIDATION` werden geänderte Regeln und deren transitive Abhängige vollständig gelesen und analysiert. Erst nach erfolgreicher Analyse des geprüften Stands wird dessen exakter Digest aufgezeichnet:

```sh
python3 Code/Tools/Rule_Context_Cache.py record \
  --codex-home /local/agent-home \
  --cache-dir /local/rule-cache \
  --project-doc-max-bytes 32768 \
  --effective-config-tag codex-default-discovery-v1 \
  --analyzed-snapshot-digest DIGEST_FROM_PREVIOUS_CHECK
```

Ein Recordaufruf bestätigt, dass der Aufrufer diesen exakten Stand analysiert hat. Der Adapter prüft ihn erneut unter einer exklusiven Sperre und schreibt atomar. Eine zwischen Analyse und Aufzeichnung geänderte Quelle verhindert den Record. Nach Commit, Integration oder Synchronisierung wird erneut geprüft; Git-Zustände sind Teil der Fingerprints. Cachedateien werden weder versioniert noch als Validierungsevidenz veröffentlicht.

## Grenzen und Fehlerbehandlung

Der Cache enthält ausschließlich Fingerprints, relative Quellpfade, Git-Zustände, Abhängigkeiten und Analysekennungen. Er speichert keine Regeltexte, Zusammenfassungen, Prompts, Secrets oder absoluten Hostpfade. Adapter-, Planner-, Scopeindex- und Konfigurationsänderungen verhindern die Wiederverwendung des vorherigen Discovery-Stands. Unklare Verweise, fehlerhafte Records und konkurrierende Änderungen führen zum vollständigen Leseweg. Unbekannte Sperren werden nicht aufgebrochen.

Die [Vertragsprüfung](../Code/Tests/Static/Validate_Rule_Context_Cache.py) prüft Discovery, Invalidierung, Sessionverfügbarkeit, Analysebindung und lesende Checks mit synthetischen Git-Repositories. Sie ersetzt keine Projektvalidierung und keine Laufzeitabnahme der Analysefunktionen.
