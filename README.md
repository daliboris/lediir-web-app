# LeDIIR Web Application

Projekt „Elektronická lexikální databáze indoíránských jazyků. Pilotní modul perština“, který je realizován s podporou Technologické agentury ČR ([TAČR](https://www.tacr.cz)) pod reg. č. [TL03000369](https://www.isvavai.cz/cep?ss=detail&n=0&h=TL03000369).

## Prerekvizity

### Vývojářské prostředí

- oXygen XML Editor
- [Visual Studio Code](https://code.visualstudio.com/download)
  - doplněk [existdb-vscode](https://marketplace.visualstudio.com/items?itemName=eXist-db.existdb-vscode); slouží k synchronizaci změn kódu v úložišti a na serveru eXist-db (pouze jednosměrně: souborový systém => databáze)
- [eXist-db](https://exist-db.org)
  - verze [6.0.1](https://github.com/eXist-db/exist/releases/tag/eXist-6.0.1)
  - balíček [atom-editor](https://github.com/eXist-db/atom-editor-support/releases/);  slouží k synchronizaci změn kódu v úložišti a na serveru eXist-db (viz doplněk _existdb-vscode_)

### Aktualizace eXist-db

- přechod ze starší verze, např. [5.3.1](https://github.com/eXist-db/exist/releases/tag/eXist-5.3.1) na verzi aktuální, např. [6.0.1](https://github.com/eXist-db/exist/releases/tag/eXist-6.0.1)
- před aktualizací zálohovat databázi (<http://localhost:8080/exist/apps/dashboard/admin#>)
- uložit vygenerovaný ZIP do složky (`V:\Projekty\Temp\LeDIIR\Zaloha\full20220301-1001.zip`)
- odinstalace eXist-db
  - z kontextové nabídky ikony eXist-db zvolit `Uninstall Service`
  - z kontextové nabídky ikony eXist-db zvolit `Stop and Quit`
  - (z nabídky Windows: `eXist-db XML Database 5.3.1\Uninstall eXist-db`)
  - zvolit `Force the deletion of D:\eXist-db`
- instalace eXist-db do složky `D:\eXist-db`
- nastavení hesla administrátora
- spuštění eXist-db
  - nastavení parametrů spuštění (RAM ap.)
- z kontextové nabídky ikony eXist-db zvolit `Start Server`
- otevření Package Manageru (<http://localhost:8080/exist/apps/dashboard/admin#>)
  - aktualizace balíčků (`eXist-db HTML Templating Library`, `eXide - XQuery IDE`)
  - instalace balíčku [atom-editor](https://github.com/eXist-db/atom-editor-support/releases/)
  - instalace balíčku `TEI Publisher`
    - doinstalovalo se `TEI Publisher: Processing Model Libraries` a `Open API Router library for eXist`
- ve `Visual Studiu Code` sestavit balíček z aktuálního zdrojového kódu
  - nahrát vytvořený balíček (např. `lediir-0.6.xar`) pomocí správce balíčků (<http://localhost:8080/exist/apps/dashboard/admin#>)
  - ve správci uživatelů (<http://localhost:8080/exist/apps/dashboard/admin#>) nastavit uživateli `redaktor` heslo
  - ověřit funkčnost balíčku
    - spustit aplikaci <http://localhost:8080/exist/apps/lediir/index.html>
    - přihlásit se jako redaktor
    - nahrát slovník s daty a doprovodným materiálem, tj. `LeDIIR-fa.xml` a `LeDIIR-about.xml`

## Vývoj

### Webcomponents

Při aktualizaci verze webových komponent je potřeba změnit verzi v souboru `config.xql`, např. na `declare variable $config:webcomponents :="1.25.0";`. Zároveň (?; možná je potřeba přegenerovat aplikaci) je potřeba změnit verzi v soboru `package.json`, např. na

```json
"dependencies" : {
    "@teipublisher/pb-components" : "1.25.0"
  }
```
