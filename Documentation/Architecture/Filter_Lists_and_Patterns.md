# Filter-, Listen- und Pattern-Konvention

Stand: 2026-07-15

## Exakte Listen

Mehrfachwerte werden mit `|` getrennt. Das Pipe-Zeichen trennt nur außerhalb von `[...]`; innerhalb bracket-quotierter Werte ist es Bestandteil des Namens. `]]` repräsentiert eine schließende Klammer.

Beispiele:

```sql
@SchemaNames = N'dbo|monitor'
@ColumnNames = N'[ColumnOne]|[Column With Spaces]|[Column|WithPipe]'
@ObjectNames = N'[Das ist | ein komischer Objektname]|[der auch]|[der_nicht]|der_auch_nicht'
@FullObjectNames = N'[DeineDatenbank].dbo.[IrgendeinObjekt]|und.noch.eines'
```

Punkte trennen bei `@FullObjectNames` nur außerhalb von Brackets. Unterstützt werden ein-, zwei- und dreiteilige Namen; Linked-Server-Namen sind ausgeschlossen. Validierte Namen werden für dynamisches SQL erneut mit `QUOTENAME()` aufgebaut.

## Patterns

Patternparameter sind keine Pipe-Listen. Unterstützt werden:

- ohne Präfix oder `like:`: SQL `LIKE` unter `SQL_Latin1_General_CP1_CS_AS`
- `regex:`: case-sensitive Regex
- `regexi:`: case-insensitive Regex

Regex wird ausschließlich versionsadaptiv und dynamisch auf SQL Server 2025 mit Compatibility Level 170 ausgeführt. Auf älteren Versionen wird `UNAVAILABLE_FEATURE` geliefert; es erfolgt keine unvollständige LIKE-Übersetzung.

Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.
