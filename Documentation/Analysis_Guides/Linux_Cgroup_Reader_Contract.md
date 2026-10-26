# Linux-cgroup-Reader: Wire- und Native-Vertrag

**Status:** Implementierungskandidat; unabhängiger Review und erforderlicher Linux-CI-Lauf stehen aus. Dieser Vertrag definiert Schnittstelle und ABI, belegt aber keine bestimmte Host- oder cgroup-Grenze.

## Umfang und Python-API

`Code/Tools/Linux_Cgroup_Reader.py` stellt `collect_process(target_pid: int) -> dict[str, object]` bereit. Die API verlangt einen exakten positiven Python-`int` im unterstützten PID-Bereich. Sie beobachtet nur den ausdrücklich ausgewählten, für den Aufrufer sichtbaren Prozess. Prozesssuche, Namespacewechsel, freie Pfade, Umgebungsvariablen, Kommandozeilen, Remotezugriff und SQL-Server-Zuordnung gehören nicht zum Vertrag.

Jedes vollständige Ergebnis hat `partial=true`, `global_hierarchy="UNVERIFIED"`, `sql_binding="UNVERIFIED"` und `event_scope="UNVERIFIED"`. Die CLI akzeptiert ausschließlich `--target-pid <positive ASCII-Dezimalzahl>`. `--help` löst keine nativen Zugriffe aus. Exitcode 0 bedeutet, dass ein vollständiges JSON-Ergebnis geschrieben wurde, auch wenn es partiell oder ungebunden ist; 2 bezeichnet ungültige Argumente, 3 einen Fehler, der ein vertragsgemäßes JSON-Ergebnis verhindert. stderr enthält nur stabile Codes.

## JSON-Ergebnis

Die festen Top-Level-Schlüssel lauten `schema_version`, `target_pid`, `target_identity`, `partial`, `global_hierarchy`, `sql_binding`, `event_scope`, `selection_state`, `context_state`, `resources`, `hierarchy_metrics` und `issues`. Konstanten sind `schema_version="linux-cgroup-observation/1"` und `target_identity="CALLER_SELECTED_PROCESS"`. PID und Zahlen werden als Dezimalzeichenketten ausgegeben.

`selection_state` ist `SELECTED`, `MISSING_MEMBERSHIP`, `UNSUPPORTED_LAYOUT`, `AMBIGUOUS_MOUNT` oder `CONTEXT_UNBOUND`. `context_state` ist `BOUND` oder `CONTEXT_UNBOUND`. `BOUND` bedeutet, dass die vorgesehenen Identitäten an den beobachteten Fences übereinstimmten. Das ist weder ein atomarer Snapshot noch ein Schutz vor einem unbeobachteten ABA-Wechsel.

Jeder Ressourceneintrag enthält `source_ordinal`, `level_ordinal`, `observation_phase`, `source_key`, `read_state`, `parse_state`, `reason_code`, `byte_count`, `raw_value`, `parsed_value`, `native_errno`, `started_at_utc`, `completed_at_utc` und `duration_ns`. Ordinale, Bytezahlen, Dauer, Parserzahlen und errno sind Zeichenketten. Phasen sind `INITIAL_FENCE`, `MAIN_READ` und `CLOSING_FENCE`. Nicht versuchte Quellen haben für Bytezahl, Rohwert, Parsewert und errno `null`, `parse_state=NOT_ATTEMPTED` und `reason_code=null`.

Am Blatt werden `memory.max`, `memory.high`, `memory.current`, `memory.swap.max`, `memory.events`, `cpu.max`, `cpu.stat`, `cpuset.cpus.effective` und `cgroup.type` gelesen. Je sichtbarem Vorfahren werden `memory.max`, `memory.high`, `memory.swap.max`, `cpu.max` und `cgroup.type` gelesen. Es werden höchstens 64 Ebenen einschließlich Blatt beobachtet.

Read-Zustände sind `AVAILABLE`, `NOT_SELECTED`, `MISSING`, `PERMISSION_DENIED`, `READ_ERROR`, `CONTEXT_UNBOUND`, `LIMIT_REACHED` und `DEADLINE_REACHED`. Read-Erfolg und Parserzustand bleiben getrennt. Erfolgreiche cgroup-Reads bleiben `AVAILABLE`, wenn ein späterer Fence fehlschlägt; Gesamtcontext und abhängige Metriken werden dann ungebunden. Unvollständige Reads besitzen keinen Rohwert und werden nicht geparst. Procfs-Rohtexte, Prozess-`comm`, lokale Fehlertexte und Hostpfade werden nicht ausgegeben.

Issues enthalten nur `scope`, `reason_code` und optional `source_ordinal`. Scopes sind `SELECTION`, `ABI`, `CONTEXT`, `RESOURCE`, `BUDGET` und `OUTPUT`. Codes umfassen `UNSUPPORTED_ABI`, `ABI_MISMATCH`, `SYSCALL_UNAVAILABLE`, `FILESYSTEM_MISMATCH`, `NAMESPACE_MISMATCH`, `PID_EXITED`, `STARTTIME_CHANGED`, `MEMBERSHIP_CHANGED`, `MOUNT_CHANGED`, `PIDFD_PROCFS_MISMATCH`, `DIRECTORY_CHANGED`, `SYMLINK_REJECTED`, `CROSS_MOUNT_REJECTED`, `PERMISSION_DENIED`, `READ_ERROR`, `RESOURCE_MISSING`, `LIMIT_REACHED`, `DEADLINE_REACHED`, `CONFIGURATION_CHANGED`, `CLOCK_CHANGED` und `OUTPUT_ERROR`. Parsefehler verwenden die Reason-Codes der jeweiligen Parser-API. errno ist, falls vorhanden, eine Dezimalzeichenkette ohne Systemmeldung.

## Sichtbare Hierarchiemetriken

`hierarchy_metrics` enthält `visible_memory_max_ceiling_bytes`, `visible_swap_max_ceiling_bytes` und `visible_cpu_quota_ratio`. Jedes Element hat `state`, `value` und `source_ordinals`; die CPU-Ratio enthält zusätzlich exakte `ratio_numerator` und `ratio_denominator`. Zustände sind `AVAILABLE`, `NO_FINITE_VISIBLE_LIMIT` und `UNAVAILABLE`.

Speicher und Swap sind jeweils das Minimum der endlichen, erfolgreich gelesenen und stabilen sichtbaren `memory.max`- bzw. `memory.swap.max`-Werte. Die CPU-Ratio ist die kleinste endliche exakte `cpu.max`-Quote der sichtbaren Ebenen. Zähler und Nenner sind gekürzte Dezimalzeichenketten; bei CPU bleibt `value=null`. `cpuset.cpus.effective` wird als Konfigurations-Fence gelesen, aber nicht als Hostkapazitätsmultiplikator verwendet. Sind alle sichtbaren Werte unbegrenzt, lautet der Zustand `NO_FINITE_VISIBLE_LIMIT`. Lücken, ungültige Werte, nicht unterstützte Layouts, geänderte Konfiguration oder ungebundene Fences unterdrücken die betroffene Metrik. `memory.high` bleibt separat.

`memory.events` bleibt eine Einzelbeobachtung mit `event_scope="UNVERIFIED"`. Counter werden weder differenziert noch als Ursache oder Rate interpretiert. Unbekannte `memory.events`- und `cpu.stat`-Schlüssel bleiben als `UNMAPPED_KEY` sichtbar, ohne erfundene Einheit oder Aggregation.

## Quellen- und Identitätsfences

Zulässige Procfs-Quellen sind `/proc/<pid>/stat` nur für PID und Startticks, `/proc/<pid>/cgroup`, `/proc/self/mountinfo`, die PID-/Mount-/cgroup-Namespaceeinträge von Aufrufer und Ziel sowie `/proc/self/fdinfo/<pidfd>` nur für die Ziel-PID. Es gibt weder `/proc/<pid>/root`-Fallback noch `setns`.

PID-, Mount- und cgroup-Namespaces von Aufrufer und Ziel müssen übereinstimmen. Ein pidfd wird vor und nach der Aufnahme auf Liveness geprüft. Seine Procfs-`fdinfo`-PID muss mit dem Procfs-Prozessdatensatz übereinstimmen; Startticks, Membership, Mounts, Mount-IDs und Verzeichnis-FD-Identitäten werden erneut geprüft. Der cgroup2-Mount wird als eindeutiger längster komponentenweiser Treffer gewählt. Gleichstand und unsichere Pfade werden abgewiesen. Namespace-FDs werden erst nach Prüfung des Procfs-Ankers ausschließlich über `pid`, `mnt` und `cgroup` geöffnet und gegen nsfs sowie den erwarteten Namespace-Typ geprüft.

Verzeichnisse und Dateien werden relativ zu geprüften FDs geöffnet. `openat2` verwendet `BENEATH`, `NO_SYMLINKS` und `NO_MAGICLINKS`; Nachfahren zusätzlich `NO_XDEV`. Nur der erste `/proc`- oder cgroup2-Mountanker darf von einem identitätsgeprüften Root-FD einen Mountübergang vollziehen; Dateisystemtyp und Mount-ID werden vor Nutzung geprüft. Die festen Namespace-FDs und der Procfs-Link `self` werden separat und eng begrenzt geprüft. Stringpräfixe ersetzen keine Pfadbindung.

## ABI- und Plattformgrenze

Das Native-Backend unterstützt ausschließlich Linux x86_64, Little Endian, 64-Bit-Pointer und 64-Bit-`long` sowie Python 3.11 oder neuer. Fehlende Syscalls, ABI-Merkmale, Pflichtbits oder Dateisystembelege führen fail-closed zu `UNSUPPORTED_ABI` oder `CONTEXT_UNBOUND`.

Die x86_64-Bindung nutzt `openat2`-Syscall 437 mit dem 24 Byte großen, 8-ausgerichteten `open_how` und den Feldern `flags`, `mode`, `resolve` an Offset 0, 8 und 16. `statx` nutzt Syscall 332 und die 256 Byte große, 8-ausgerichtete UAPI-Struktur. Geprüfte Offsets sind `mask=0`, `mode=28`, `inode=32`, `device major=136`, `device minor=140` und `mount ID=144`. Maske `0x1103` verlangt TYPE, MODE, INO und MNT_ID; zusätzliche Kernelbits werden ignoriert, fehlende Pflichtbits fail-closed behandelt. `AT_EMPTY_PATH=0x1000` wird für FD-Prüfungen verwendet. `fstatfs` nutzt das geprüfte 120-Byte-x86_64-Layout und prüft `PROC_SUPER_MAGIC=0x9fa0`, `CGROUP2_SUPER_MAGIC=0x63677270` bzw. `NSFS_MAGIC=0x6e736673`.

Resolve-Werte sind `NO_XDEV=0x01`, `NO_MAGICLINKS=0x02`, `NO_SYMLINKS=0x04` und `BENEATH=0x08`. Der Rootanker nutzt `O_PATH=0x200000`, `O_DIRECTORY=0x10000` und `O_CLOEXEC=0x80000`; Ressourcen werden nur lesend geöffnet. PID-Liveness verwendet `os.pidfd_open` und `select.poll`. Namespace-Typen werden über `NS_GET_NSTYPE=0xb703` gegen `CLONE_NEWPID=0x20000000`, `CLONE_NEWNS=0x00020000` und `CLONE_NEWCGROUP=0x02000000` geprüft. Jeder FD besitzt genau einen Owner; Handles sind nicht kopier- oder serialisierbar.

## Byte- und Zeitgrenzen

Jede Ressourcendatei ist auf 64 KiB, jede Procfs-Quelle auf 512 KiB begrenzt. Alle tatsächlichen Reads einschließlich Start-, Abschluss- und Konfigurations-Fences teilen sich 8 MiB und zehn Sekunden monotones Read-Zulassungsbudget. Fehler werden nicht wiederholt. Die pseudodateiinterne Größe gilt nicht als EOF-Beleg; nur ein beobachteter Null-Byte-Read beweist EOF. Am erreichten Limit wird kein Probe-Read hinzugefügt. Ohne beobachtetes EOF lautet das Ergebnis `LIMIT_REACHED`, ohne Rohtext und Parseversuch. Ein bereits blockierter Systemaufruf wird durch das Zeitbudget nicht sicher unterbrochen.

## CI- und Evidenzgrenze

Der bestehende Dokumentationsvalidierungs-Workflow führt einen getrennten Linux-x86_64-/Python-3.11-Job nur bei Änderungen an Reader, Native-Primitiven, Parserabhängigkeiten, Validator oder öffentlichem Vertrag aus. Er prüft Parser, portable Wirefälle, echte Native-Syscalls und eine read-only Beobachtung eines eigenen Kindprozesses. Unsupported-Ausführung lässt den Job scheitern. Der Job gehört nicht zur SQL-Compatibility-Level-Abdeckung und startet keinen SQL Server.

Portable Fake-Backend-Oracles belegen keine Nativequalifikation. Native CI prüft die auf ihrem Runner verfügbaren Syscalls und Beobachtungen, aber keine konfigurierte cgroup-Grenze, keinen Produktionshost, keine SQL-PID-Zuordnung und keine SQL-Reaktion. Diese Nachweise bleiben getrennt.

## Primärquellen

- [Linux-`openat2`-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/openat2.h) und [`openat2(2)`](https://man7.org/linux/man-pages/man2/openat2.2.html)
- [Linux-`statx`-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/stat.h), [generische `statfs`-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/statfs.h) und [`statfs(2)`](https://man7.org/linux/man-pages/man2/statfs.2.html)
- [Dateisystem-Magicwerte](https://github.com/torvalds/linux/blob/master/include/uapi/linux/magic.h), [Namespace-FD-UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/nsfs.h) und [`ioctl_ns(2)`](https://man7.org/linux/man-pages/man2/ioctl_ns.2.html)
- [Python-3.11-`os.pidfd_open`](https://docs.python.org/3.11/library/os.html#os.pidfd_open)
- [Kernel-Dokumentation zu cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
