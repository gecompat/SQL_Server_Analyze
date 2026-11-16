# OPS-006: Persisted-SKU-Feature-Runtimeevidenz

**Stand:** 16. November 2026  
**Status:** historischer `LOCAL_WORKTREE_EVIDENCE`-Teil; separater gebundener Remote-Nachtrag unten  
**Datenbasis:** ausschließlich synthetische Fixtures

## Ausgeführter Nachweis

Der folgende lokale Bericht stammt vom 19. September 2026 und behält den damaligen Status `LOCAL_WORKTREE_EVIDENCE`.

Der fokussierte OPS-006-Runtimevertrag lief auf den vorhandenen Linux-Umgebungen mit SQL Server 2019, 2022 und 2025. Jeder Lauf installierte den aktuellen Frameworkstand in eine ausschließlich für den Test verwendete Datenbank und entfernte sie nach dem Vertragstest.

Der Vertrag erzeugte die synthetische Datenbank `ExampleOps006Feature`, eine Tabelle mit einem PAGE-komprimierten Clustered Index und einer synthetischen Zeile. `USP_DatabasePortabilityAnalysis` lieferte für diesen Scope mindestens eine Zeile vom Typ `PERSISTED_SKU_FEATURE`. Der bestehende Leer-, Uncontained-, Missing- und eingeschränkte Berechtigungspfad blieb Teil desselben erfolgreichen Vertragslaufs.

## Aussagegrenze

Dieser Nachweis belegt den kontrollierten positiven Featurepfad auf SQL Server 2019, 2022 und 2025 unter Linux. Er belegt keine Zieledition oder Restorefähigkeit. Der Nachweis für eine tatsächlich nicht unterstützte Quelle bleibt offen.

## Gebundener Remote-Nachtrag vom 16. November 2026

Der [SQL-Server-2019-Nativlauf 43643920546](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43643920546), Job 132597678295, checkte den exakten Head `cecde05f9b592881cdee7e820ffb7b39434ed0fe` aus und bestand im Modus `FULL_RELEASE` auf Linux mit Compatibility Level 150. Der vollständige Release-Gate-Schritt bestand; `Run_Release_Gate.sql` band Fixture 121 genau einmal ein. Quelle 200 (`c8d53d2ae93cc03cdbed5074d83a66350e4c4e5f`) und Fixture 121 (`57a046384c96b9b9f8329d0a4b1796e869b4d546`) sind am Head und im aktuellen Stand bytegleich. Die Fixture erzeugt ohne Skip-Zweig eine eigene Datenbank mit PAGE-komprimiertem Clustered Index und fordert in ihrer positiven JSON-Prüfung `PERSISTED_SKU_FEATURE` an; andernfalls wirft sie Fehler 54865. Der erfolgreiche Gate-Schritt belegt diesen begrenzten positiven Fall. Ein eigener Fixture-121-SQL-stdout-Marker wurde nicht ausgewertet.

Die obigen lokalen Angaben zu SQL Server 2022 und 2025 bleiben historische lokale Evidenz und werden durch diesen Nativlauf nicht zu Remote-Qualifikationen. Eine tatsächlich nicht unterstützte Quelle, die Akzeptanz einer Zieledition und die Restorefähigkeit bleiben unbewiesen.
