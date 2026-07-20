# Installation

Für eine vollständige Schritt-für-Schritt-Installation in SSMS siehe
[`Documentation/Reference/Installation.md`](../../Documentation/Reference/Installation.md).

`Install_All.sql` ist ein schlanker SQLCMD-Installer und bindet die kanonischen Einzeldateien über `:r` ein.

Für einen eigenständigen, vollständig eingebetteten Installer:

```powershell
./Build-StandaloneInstaller.ps1
```

Die Quellen werden in exakt derselben, abhängigkeitssicheren Reihenfolge wie in
`Install_All.sql` eingebettet. Die erzeugte Datei `Install_All.generated.sql` ist
ein Build-Artefakt und wird nicht versioniert. Für die SSMS-Erstinstallation ist
dies der empfohlene Weg: Der Datenbankplatzhalter muss nur einmal ersetzt werden,
und die generierte Datei benötigt keinen SQLCMD-Modus.
