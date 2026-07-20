# Parameter richtig lesen und sicher einsetzen

Exakte Signaturen und Defaultwerte stehen im [Procedure-Referenzhandbuch](../Reference/Procedure_Reference.md) und werden durch `EXEC [monitor].[Procedure] @Hilfe=1` ausgegeben.

## 1. Erst CONSOLE, dann RAW oder TABLE

- `CONSOLE`: sichere interaktive Orientierung.
- `RAW`: vollständige technische Spalten und stabiler Consumer-Vertrag.
- `TABLE`: semantisch benannte typisierte Ergebnisse zur SQL-internen Weiterverarbeitung in lokalen `#Temp`-Tabellen.
- `NONE`: keine fachlichen Resultsets, beispielsweise JSON-only.

## 2. Umfangsparameter

| Parametergruppe | Bedeutung | Sicherer Einstieg | Risiko |
|---|---|---|---|
| `@MaxZeilen` | Ausgabezeilen je Procedure/Child | positiven kleinen Wert verwenden | `0` oder `NULL` kann sehr große Ausgabe erzeugen |
| `@HighImpactConfirmed` | tatsächlich aktivierter Deep-Pfad | nur nach bewusster Scope-Prüfung auf `1` setzen | breite Katalog-, Cache- oder Forensikarbeit |
| `@MaxAnalyseobjekte` | XML-/Plantiefenanalyse | 1–5 Kandidaten | hohe CPU für Plan-XML |
| Zeitfenster | Query Store, XE, msdb | kurz beginnen | Retention- und Scanaufwand |
| `@SampleSeconds` | Deltaanalyse | 5–10 Sekunden | blockiert die aufrufende Session während WAITFOR |

## 3. Datenbankfilter

Frameworktypisch:

- `N''` oder `NULL`: alle sichtbaren Online-Benutzerdatenbanken,
- explizite Pipe-Liste: nur genannte Datenbanken.

Systemdatenbanken bleiben ohne ausdrückliches Opt-in ausgeschlossen. Immer Hilfe
und Status prüfen.

## 4. Exakte Listen und Pattern

- Exakte Listen sind pipe-getrennt und bracket-aware.
- Listen und Pattern derselben Eigenschaft sind häufig gegenseitig exklusiv.
- SQL-Identifier bleiben case-sensitiv.
- Regexpfade benötigen passende SQL-Server-Version und Compatibility.

## 5. Tiefenoptionen

Optionen wie Plan-XML, Event-XML, Lockdetails, Histogramme, Segmente, Dictionaries, Page Details oder breite Vollanalyse erhöhen CPU, I/O, Ausgabe und Laufzeit. Erst Kandidaten eingrenzen, dann Tiefenoption aktivieren.

## 6. Textparameter

Vollständiger SQL-Text, Batchtext und Input Buffer können große und sensible Runtimeinhalte liefern. Sie dürfen zur Diagnose ausgegeben werden, aber niemals als reale Beispiele in Repositorydateien übernommen werden.

## 7. Schwellenwerte

Jeden Schwellwert klassifizieren:

1. Repository-Default,
2. Microsoft-dokumentierte Produkteigenschaft,
3. betriebliche Heuristik,
4. keine universelle Grenze.

Ein Schwellwert priorisiert; er beweist keine Ursache.

## 8. Vor breiten Aufrufen

1. `USP_CheckAnalyseAccess` ausführen.
2. `USP_CheckFrameworkCapabilities` prüfen.
3. Zielscope explizit begrenzen.
4. CONSOLE verwenden.
5. Erst danach RAW/Deep-Optionen aktivieren.
