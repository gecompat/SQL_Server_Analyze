# Linux-cgroup-Reader

Der optionale Reader beobachtet einen Prozess, den der Aufrufer auf demselben Linux-Host ausdrücklich auswählt. Er liest sichtbare cgroup-v2-Grenzen und Counter dieses Prozesses. Er verbindet den Prozess nicht mit einer SQL-Server-Instanz und belegt nicht, dass eine Grenze das Verhalten von SQL Server verändert hat.

Der Reader ist getrennt von [`monitor.USP_OSInformation`](Procedures/USP_OSInformation.md), das SQL-sichtbare Betriebssystem- und Prozessinformationen ausgibt. Beide Ausgaben sind eigenständige Beobachtungen. Ein gemeinsamer Prozessbezug setzt eine unabhängige Identitätsprüfung voraus.

## Voraussetzungen und Aufruf

Der Kandidat setzt Linux x86_64, Little Endian mit 64-Bit-Userspace und Python 3.11 oder neuer voraus. Der Aufrufer benötigt Leserechte auf die ausgewählten Prozess-, Namespace- und cgroup-Dateien. Der Reader fordert keine erhöhten Rechte an und wechselt keine Namespaces. Fehlt ABI-Unterstützung oder Zugriff, gibt er, soweit möglich, ein ungebundenes oder partielles Ergebnis aus.

Vom Repository-Hauptverzeichnis aus wird genau eine positive, für den Aufrufer sichtbare PID angegeben:

```text
python3 Code/Tools/Linux_Cgroup_Reader.py --target-pid 1234
```

`1234` ist durch die ausgewählte PID zu ersetzen. Weitere Kommandozeilenoptionen werden nicht akzeptiert. `--help` zeigt die Hilfe ohne Procfs- oder cgroup-Zugriff. stdout enthält genau ein kompaktes JSON-Objekt; stderr enthält nur stabile Fehlercodes.

## Ergebnis lesen

Beginnen Sie mit `selection_state`, `context_state`, `partial` und `issues`. Bei `selection_state="SELECTED"` und `context_state="BOUND"` stimmten die vorgesehenen PID-, Namespace-, Membership-, Mount- und Verzeichnisidentitäten an den beobachteten Fences überein. Das bleibt eine begrenzte Aufnahme, kein atomarer Snapshot. Bei ungebundenem Kontext können einzelne Readbeobachtungen erhalten bleiben; Hierarchiemetriken werden dann unterdrückt.

Jeder Eintrag in `resources` trennt `read_state` von `parse_state`. `AVAILABLE` bedeutet, dass die vollständige begrenzte Datei gelesen wurde; der Inhalt kann dennoch ungültig sein. `MISSING`, `PERMISSION_DENIED`, `READ_ERROR`, `LIMIT_REACHED` und `DEADLINE_REACHED` sind kein gemessener Nullwert. `UNLIMITED` wird nicht in einen numerischen Maximalwert umgewandelt. Ressourceneinträge können rohe cgroup-Dateiinhalte enthalten. Behandeln Sie das JSON daher wie andere Hostdiagnostik und teilen Sie es nur im dafür vorgesehenen geschützten Betriebskontext. Procfs-Rohtexte, Prozess-`comm`, Umgebungsvariablen, Kommandozeilen und Hostpfade werden nicht ausgegeben.

Hierarchiemetriken sind Minima aus erfolgreich gelesenen, stabilen sichtbaren cgroup-Ebenen. `NO_FINITE_VISIBLE_LIMIT` bedeutet, dass im sichtbaren Scope kein endlicher Wert beobachtet wurde; es beweist keine unbegrenzte Host- oder übergeordnete Grenze. `UNAVAILABLE` zeigt unvollständige, ungültige, geänderte oder ungebundene erforderliche Evidenz. `memory.events` bleibt kumulativ und hat `event_scope="UNVERIFIED"`; es ist weder eine Rate noch eine OOM-Ursachendiagnose.

`partial` ist immer `true`. `global_hierarchy`, `sql_binding` und `event_scope` bleiben `UNVERIFIED`. Das Ergebnis belegt keine Hostkapazität, keinen freien Speicher, keine SQL-Schedulerkapazität, keine Produktionshostqualifikation und keine Wirkung einer cgroup-Grenze auf SQL Server.

## Grenzen und nicht unterstützte Fälle

Der Reader beobachtet höchstens 64 sichtbare Ebenen, begrenzt jede cgroup-Datei auf 64 KiB, jede Procfs-Quelle auf 512 KiB, sämtliche tatsächlichen Reads zusammen auf 8 MiB und die Zulassung weiterer Reads auf zehn Sekunden. Am erreichten Limit wird kein zusätzlicher Read nur zur EOF-Prüfung ausgeführt. Ein bereits blockierter Systemaufruf wird durch das Zeitbudget nicht sicher unterbrochen.

Threaded- und ungültige cgroup-Layouts, mehrdeutige Mountauswahl, Namespaceabweichungen, Symlinks, unerlaubte Mountübergänge und nicht unterstützte native Schnittstellen werden fail-closed behandelt. Die genauen JSON-Felder, Statuswerte, Exitcodes, Fences und ABI-Anforderungen stehen im [Wire- und Native-Vertrag](Linux_Cgroup_Reader_Contract.md). Der Kandidat benötigt seinen Linux-CI-Lauf vor einer Nativequalifikation; auch ein bestandener Runner belegt weder eine konfigurierte cgroup-Grenze noch eine SQL-Server-Reaktion.
