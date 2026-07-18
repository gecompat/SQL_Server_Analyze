# Kuratierung des Wait-Type-Katalogs

Stand: 2026-07-18

## Ergebnis

`RQ-006` ist abgeschlossen. Alle 332 zuvor als `IMPORTED_REVIEW_REQUIRED` markierten Seed-Zeilen wurden gegen die primäre Microsoft-Referenz geprüft. Der resultierende Katalog enthält 347 eindeutige Wait Types; jeder Name besitzt einen exakten Eintrag in der geprüften Referenztabelle und trägt `DescriptionSource = FRAMEWORK_CURATED` sowie `DescriptionQuality = FRAMEWORK_CURATED`.

Die Kuratierung verändert keine Laufzeit-Resultsets und filtert keine Benutzer- oder Firmendaten. Sie betrifft ausschließlich die generischen, versionierten Katalog-Seeds und deren Qualitätsmetadaten.

## Primärquelle und reproduzierbare Evidenz

- Microsoft Learn: [sys.dm_os_wait_stats (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17)
- Unveränderlicher Dokumentstand: [MicrosoftDocs/sql-docs, Commit 75807aa](https://github.com/MicrosoftDocs/sql-docs/blob/75807aa4df3dc96ddaa7facd12916a6fb2f6ad1e/docs/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql.md)
- Maschinenlesbare Entscheidungsevidenz: `Metadata/Quality/Wait_Type_Curation_Evidence.json`
- Offline-Validator: `Code/Tests/Static/940_Validate_Wait_Type_Catalog.py`

Der festgehaltene Dokumentstand enthält 967 Wait-Type-Zeilen. Die sortierte Namensmenge und der finale Katalog sind jeweils über SHA-256 gebunden. Dadurch ist später erkennbar, ob die Quelle oder die kuratierte Namensmenge stillschweigend ausgetauscht wurde.

## Entscheidungen

| Entscheidung | Anzahl | Bedeutung |
|---|---:|---|
| Bereits kuratiert | 25 | Bestehende Frameworktexte wurden in den einheitlichen Qualitätsstatus übernommen. |
| Ohne Namensänderung geprüft | 318 | Name ist in der Primärquelle exakt belegt; die fachliche Katalogzeile bleibt erhalten. |
| Auf offiziellen Namen korrigiert | 4 | Die vier `LCK_M_RI_*`-Schreibweisen wurden auf `LCK_M_RIn_*` korrigiert und ihre zuvor teilweise abgeschnittenen Bedeutungen präzisiert. |
| Entfernt | 10 | Für den Zielscope nicht exakt belegte Alt-/Aliasnamen sowie das fehlerhafte Duplikat `LCK_MSCH_M` wurden nicht als kuratiert ausgegeben. |
| Finaler Katalog | 347 | Eindeutige und in der Primärquelle exakt enthaltene Wait-Type-Namen. |

Zusätzlich wurden drei erkennbar abgeschnittene Beschreibungen repariert. `SourceReference` verweist nun auf die Microsoft-Primärquelle; der SQLskills-Link bleibt ausschließlich als optionale `HelpUrl` bestehen und ist kein kopierter Beschreibungstext.

Beim Upgrade entfernt Seed-Teil 01 die zehn verworfenen und vier ersetzten Namen ausschließlich dann, wenn die Zeile weiterhin als `IsFrameworkDefault = 1` gekennzeichnet ist. Benutzerdefinierte Katalogzeilen bleiben unangetastet.

## Automatischer Vertrag

Lokaler Lauf:

```bash
python3 Code/Tests/Static/940_Validate_Wait_Type_Catalog.py --repository-root . --self-test
python3 Code/Tests/Static/940_Validate_Wait_Type_Catalog.py --repository-root .
```

Das Gate blockiert insbesondere:

- eine andere Anzahl oder doppelte Wait-Type-Namen,
- die Rückkehr entfernter, nicht belegter Namen,
- das Fehlen der vier korrigierten Lock-Waits,
- andere Qualitäts- oder Quellenstatuswerte,
- eine geänderte finale Namensmenge,
- eine fehlende oder veränderte Microsoft-Quellenreferenz sowie
- inkonsistente Entscheidungsevidenz.

Trefferberichte enthalten nur Regelcode, Pfad und Anzahl, niemals den Inhalt einer Seed-Zeile.
