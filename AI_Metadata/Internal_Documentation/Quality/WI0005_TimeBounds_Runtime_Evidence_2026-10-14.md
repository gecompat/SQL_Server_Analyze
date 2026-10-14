# WI-0005: Laufzeitabnahme der XE-Zeitgrenzen

**Stand:** 14. Oktober 2026  
**Umfang:** freigegebener opt-in-Vertrag von `monitor.USP_ExtendedEventsSessions`.

## Qualifizierter Umfang

SQL Server 2025 17.0.4075.5/CL170 bestätigt den Zeitgrenzenpfad einschließlich
elf TABLE-/JSON-Fällen, Neustart und automatischer Beendigung der eigenen
synthetischen Sessions. RAW, CONSOLE und NONE sind mit deaktiviertem und
aktiviertem Pfad geprüft. Der Default behält JSON-Schema 1; der aktivierte
Pfad verwendet Schema 2 mit `timeBounds`. Die Procedure verändert keine
Extended-Events-Session. SQL Server 2019 15.0.4480.2/CL150 bestätigt den
versionsadaptiven Fallback durch dieselbe Testdatei 112.

Der letzte SQL-2025-Lauf führt nur die fehlenden privaten Fehler- und
Uhrbasisproben aus. Bereits bestandene Einzeltests aus den ersten und vierten
Läufen werden über unveränderte Produktquellen, gemeinsame Abhängigkeiten,
Fixtures, Engine und gespeicherte Ausgaben gebunden wiederverwendet. Die
früheren Gesamtläufe behalten ihren Status `FAILED_NOT_QUALIFIED`.

Die privaten Procedurekopien erzeugen Fehler 1222 durch einen gehaltenen Lock
auf einer eigenen Tabelle und Fehler 229 durch einen verweigerten Zugriff.
Konfigurations- und Runtimefehler, kombinierte Fehler, fehlende Spalten sowie
unbekannte und zukünftige Uhrbasen sind geprüft. Ein zusätzlicher tatsächlicher
eingeschränkter Principal ruft die unveränderte Procedure auf. Die privaten
Quellenersetzungen belegen die Fehlerverarbeitung, keine allgemeine Möglichkeit,
diese Fehler an den echten XE-DMVs auszulösen. Restzeitschätzungen liefern
bei unbekannter Uhrbasis NULL und garantieren keinen Beendigungszeitpunkt.

## Evidenzbindung und Bereinigung

Der qualifizierte Produktstand ist `56d3f806904ed248f7775fd69a9d03de14f4114d`.
Die ausgeführte Produktquelle 010 besitzt SHA256
`8519B15DEEC6C8B7DA1E75B062F5CAF1D88542AEADCA3A786C717516F063357C`.
Der letzte Primärlauf besteht nach 37.1176913 Sekunden; der ältere
Enginefallback besteht nach 37.7060832 Sekunden. Beide Resultate bestätigen
unveränderte Quellenpins und Dockerbestände sowie die Abwesenheit des eigenen
States nach öffentlichem Cleanup mit null Fehlern. Das SQL-Cleanup bestätigt
null eigene Tabellen, Benutzer, Probes und XE-Sessions und den restaurierten
Caller. Native Resultsets werden vor Assertions privat gespeichert.

Die Resultat-SHA256 sind
`6D009429FD67F1B1D1C1A22834E6BEE75205B2C6AF3AD2F2AAEE4B20C1B5869C`
für den Primärlauf und
`5E9823AD16616E20185BF0EB3BCDE65E813D4DAB5AF791FB98E606FBFCC432F2`
für den Fallback. Laufzeitlogs, Identitäten und Quellenaufnahmen bleiben
privat. Das freigegebene Gesamtbudget umfasst acht tatsächliche Versuche:
sieben auf SQL Server 2025 und einen auf SQL Server 2019. SQL Server 2022
wird gemäß der impact-basierten Teststrategie nicht zusätzlich ausgeführt.

## Vorversuche und Aussagegrenzen

Die sechs nicht qualifizierten Primärversuche bleiben erhalten. Ihre
Adapter- und Orakelbefunde werden in [Next_Steps](Next_Steps.md) dokumentiert.
Der dritte Versuch begründet einen begrenzten Vorher-/Nachher-Vergleich mit
höchstens zehn Millisekunden Zeitabweichung bei exakter Sessionidentität,
Runtimeadresse, NULL-Semantik und gleichaufrufbezogener TABLE-/JSON-Parität.
Die Ursache des zweiten Versuchs bleibt unbekannt. Der sechste Versuch
zeigt mehrere Zeilen derselben eigenen Lockbindung; die spätere Mengenprüfung
bindet jede Zeile an unabhängig erhobene eigene Datenbank-, Objekt-, Session-
und Transaktionswerte und verlangt genau eine unterschiedliche Bindung.
Die konkrete Ursache der Mehrfachzeilen wird nicht behauptet.

Der implementierte öffentliche Vertrag steht in der
[Spezifikation](../../../Documentation/Architecture/WI0005_Time_Bound_Extended_Events_Public_Specification.md).
Der unabhängige Quellen- und Deltareview ist abgeschlossen. Die reguläre
Lieferung setzt zusätzlich die betroffenen lokalen Gates und exakte Head-CI
voraus; dieser Laufzeitnachweis ersetzt diese Integrationsgates nicht.
