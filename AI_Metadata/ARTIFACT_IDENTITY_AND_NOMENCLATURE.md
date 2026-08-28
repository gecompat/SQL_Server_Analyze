# Kennungs- und Nomenklaturrichtlinie

**Status:** verbindlich
**Geltungsbereich:** dauerhafte Planungs-, Governance-, Qualitäts-, Betriebs- und Forschungsartefakte dieses Repositorys

## Zweck

Diese Richtlinie legt fest, wie dauerhafte Artefakte referenziert, registriert und miteinander verknüpft werden. Sie ergänzt die Foundation-Identitäts- und Registrierungsrichtlinien und ist die projektspezifische Quelle für deren Anwendung in `SQL_Server_Analyze`.

Der SQL-Server-Begriff `Task` bezeichnet weiterhin eine SQLOS-Ausführungseinheit in der Kette Session, Request, Task, Worker und Scheduler. Er ist keine kanonische Bezeichnung für ein Planungsartefakt. Planungsarbeit wird im Deutschen als Arbeitselement bezeichnet und verwendet im maschinenlesbaren Modell `kind: work_item`.

## Übernahmemodus und Historie

Dieses Repository verwendet ab Foundation Ruleset 1.4.0 für neu veröffentlichte dauerhafte Artefakte den Modus `ADOPT_FORWARD`.

- Alle vor dieser Übernahme veröffentlichten Referenzen bleiben unverändert gültig. Dazu gehören insbesondere `DIAG-003`, `SQL25-004`, `SC-023`, `OPS-005`, `RQ-001`, `RUNTIME-001` und ihre bereits dokumentierten Erweiterungen.
- Eine Foundation-Übernahme ist keine Umbenennung, Migration oder Neuinterpretation historischer Referenzen. Historische Präfixe und Referenzen werden nicht wiederverwendet.
- Eine bestehende Referenz darf ihren Inhalt, Status, Owner, Pfad, Parent, Phase oder Welle ändern, ohne dass ihre Identität geändert wird.
- Referenzen sind keine Berechtigungen und enthalten keine Zugriffsrechte.

## Begriffe und Modell

Jedes neu erstellte dauerhafte Artefakt besitzt eine persistente Maschinenkennung und kann zusätzlich eine lesbare Referenz erhalten. Die Maschinenkennung ist ein UUIDv7-URN. UUIDv4 ist nur zulässig, wenn die Abweichung beim betroffenen Artefakt dokumentiert wird.

Die lesbare Referenz hat das Format `<PREFIX>-<SEQUENCE>`. Die Sequenz verwendet für neue Referenzen mindestens vier Ziffern. Sie beschreibt weder Priorität noch Reihenfolge, Welle, Phase, Status, Owner, Repositorypfad oder Parent.

| Präfix | `kind` | Einsatz ab Übernahme |
|---|---|---|
| `CAP` | `capability` | Dauerhaftes Ergebnis oder Fähigkeit |
| `REQ` | `requirement` | Dauerhafte Anforderung oder Einschränkung |
| `WI` | `work_item` | Allgemeines Arbeitselement, einschließlich Feature, Bug, Task oder Spike |
| `DEC` | `decision` | Neue dauerhafte Entscheidung |
| `GATE` | `gate` | Sicherheits-, Freigabe- oder Readiness-Gate |
| `RISK` | `risk` | Risikoeintrag |
| `EXP` | `experiment` | Evidenzerzeugender Versuch oder Spike |
| `INC` | `incident` | Incident-Eintrag |
| `REL` | `release` | Release-Eintrag |
| `TEST` | `test` | Eigenständig referenzierter Testvertrag |

`OPS` wird für neue Referenzen nicht vergeben, weil das bestehende dreistellige `OPS`-Register historisch erhalten bleibt. Neue betriebliche Arbeitselemente verwenden `WI` mit einer entsprechenden Klassifikation.

Eine Welle ist eine veränderbare Planungs- und Gruppierungseigenschaft. Deutsche Freitexte verwenden `Welle`; maschinenlesbare Artefakte verwenden das Feld `wave`. Eine Welle ist nicht Teil einer kanonischen Referenz. Benötigt eine Welle selbst eine dauerhafte Referenz, erhält sie ein `WI-####` mit `subtype: wave`.

Parent/Child, Abhängigkeit, Implementierung, Verifikation, Blockierung, Governance und Ablösung werden durch explizite Relationen wie `parent`, `depends_on`, `implements`, `verifies`, `blocks`, `governed_by` und `supersedes` dargestellt. Sie werden nicht ausschließlich aus Präfix, Nummer, Dateipfad oder Wellenüberschrift abgeleitet.

## Registration Authority

[`Metadata/Governance/Artifact_Registry.json`](../Metadata/Governance/Artifact_Registry.json) ist die projektweite Registration Authority für die in dieser Richtlinie definierten neuen Präfixe. Sie verwendet das Profil `foundation-artifact-registry/v2`. Das Präfixregister und die vollständigen Datensätze unter `artifacts` sind die maßgebliche Vergabeinformation. Der kanonische Human-Reference-Wert ist jeweils der Objektschlüssel und wird nicht als veränderbares Feld im Datensatz wiederholt.

Der Maintainer, der eine Registry-Änderung nach `main` übernimmt, führt die finale Vergabe aus. Menschen und KI-Systeme dürfen keine finale Sequenz allein aus Markdown, Dateinamen, Git-Historie oder einer Unterhaltung ableiten.

- `DIRECT` ist nur zulässig, wenn die Registry-Änderung auf dem aktuellen Git-Commit- beziehungsweise Blobstand basiert, die nächste freie Sequenz als Maximum der vorhandenen kanonischen Referenzen plus eins ableitet, den vollständigen Artefaktdatensatz speichert und serialisiert nach `main` übernommen wird.
- Für parallele Branches, Offline-Arbeit oder nicht atomare Vergabe ist `DEFERRED` der Standard. Das Artefakt erhält seine UUID, aber noch keine finale lesbare Referenz.
- Bei einem Registry-Konflikt wird kein Wert wiederverwendet. Die anfragende Änderung wird gegen die aktuelle Registry aktualisiert und erhält durch die Authority eine neue, freie Referenz.
- Die optionale Capability `artifact-registry-github` ist installiert. Ihr Workflow prüft Registrystruktur, Kennungs- und Relationsintegrität, parallele Pull-Request-Kollisionen, den semantischen Drei-Wege-Merge und die Übereinstimmung mit dem tatsächlichen Git-Merge-Ergebnis. Die optionalen v1-Referenzclients bleiben nicht installiert.

## Anwendung in vorhandenen Registern

Bestehende Felder wie `WorkItemId`, `EnhancementId`, `GapId` oder `BacklogId` bleiben aus Kompatibilitätsgründen unverändert. Sie bezeichnen die dort jeweils verwendete historische lesbare Referenz und bilden kein neues, konkurrierendes ID-System.

Neue registrierte Artefakte verwenden das v2-Schema unter `.ai/foundation/schemas/artifact-registry-v2.schema.json`. Der Objektschlüssel unter `artifacts` ist die kanonische lesbare Referenz. Der Datensatz speichert mindestens `artifact_uid`, `kind`, `title` und `registration_state`; Status, Welle und Beziehungen bleiben getrennte Metadaten.

## Validierung

Die Foundation-Prüfung validiert nur die bereitgestellten Richtlinien und Schemas (`FOUNDATION_INTEGRITY`). Für diese Projektrichtlinie gilt zusätzlich `PROJECT_SEMANTIC`: Präfixe dürfen nicht neu definiert, finale Referenzen und Maschinenkennungen nicht doppelt vergeben und registrierte oder stillgelegte Referenzen nicht entfernt oder wiederverwendet werden. `parent`- und `depends_on`-Relationen dürfen keine Zyklen bilden. Der Workflow `.github/workflows/artifact-registry-integrity.yml` prüft diese Eigenschaften für Pull Requests. Das aktive GitHub-Ruleset `Artifact Registry Integrity` verlangt den strikten Statuscheck `registry-integrity` für den Default-Branch und bindet ihn an die GitHub-Actions-App. Änderungen an dieser administrativen Durchsetzung sind als eigenständige Governance-Änderung zu behandeln.
