# Generated installers

Der unveröffentlichte v1.2.0-Kandidat enthält nach Paketbau hier sechs
vorbereitete SQL-Installer. Ihre Verwendung setzt die gesonderte Releaseabnahme
voraus. Ihre Auswahl,
Datenbankkontexte und Ausführungsreihenfolge stehen in der
[Installations- und Upgradeanleitung](../../../Documentation/Reference/Installation.md).
Für die ZIP-Wege ist kein Neubau erforderlich.

Bei einem Quellcheckout legen die PowerShell-Builder unter `Code/Install` ihre
SQL-Artefakte standardmäßig in diesem Verzeichnis ab. Dateien mit der Endung
`.generated.sql` werden nicht in Git versioniert. Vor der Ausführung dürfen
ausschließlich die in der Anleitung bezeichneten Datenbankwerte angepasst
werden. Änderungen an der eingebetteten Produktlogik erfolgen in den
kanonischen SQL-Dateien; danach ist ein Neubau erforderlich.
