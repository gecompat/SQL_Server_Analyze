# Gate für einzeilige Commit Messages

**Stand:** 18. Juli 2026
**Anforderung:** `Documentation/Requirements/Requirements_and_Decisions.md`, Abschnitt 8
**Prüfskript:** `Code/Tests/Static/930_Validate_Commit_Message.py`
**Workflow:** `.github/workflows/commit-message-validation.yml`
**Status:** IMPLEMENTED_AUTOMATED_GATE
**Erster grüner Lauf:** [Run 29634126487](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29634126487)

## Vertrag

Jede neu in einen Pull Request oder in `main` eingebrachte Commit Message muss aus exakt einer nicht leeren Textzeile bestehen. Der technisch übliche abschließende LF- beziehungsweise CRLF-Terminator zählt nicht als zweite Zeile. Ein Message Body, eine zusätzliche Leerzeile, ein eingebettetes Carriage Return, eine leere oder nicht als UTF-8 lesbare Message blockiert das Gate.

Historische Commits werden weder umgeschrieben noch bei jedem Lauf vollständig neu bewertet. Ein Pull-Request-Lauf prüft alle durch `base..head` neu eingebrachten Commits; ein Push auf `main` prüft den Bereich `before..head`. Ein manueller Lauf ohne Basissha prüft nur `HEAD`.

## Lokale Prüfung

Generische Selbsttests:

```text
python3 Code/Tests/Static/930_Validate_Commit_Message.py --repository-root . --self-test
```

Letzten Commit prüfen:

```text
python3 Code/Tests/Static/930_Validate_Commit_Message.py --repository-root . --base-sha <BASIS-SHA> --head-sha <HEAD-SHA>
```

Die acht eingebauten Fälle decken gültige LF-, CRLF- und terminatorlose Einzeiler sowie leere, mehrzeilige, nachgestellte Leerzeilen, eingebettete Carriage Returns und nicht als UTF-8 lesbare Messages ab.

## Datenschutzkonforme Ausgabe

Bei einem Fehler werden ausschließlich Scope, stabiler Regelcode, Commit-SHA und Anzahl ausgegeben. Die Commit Message selbst wird niemals wiedergegeben oder als separates Prüfartefakt hochgeladen.
