# Teoriakysymykset -- Azure IaC ja Bicep

Vastaa seuraaviin kysymyksiin omin sanoin. Vastausten ei tarvitse olla pitkiä -- muutama lause riittää, kunhan osoitat ymmärryksesi.

---

## Osa 1: Infrastructure as Code

### Kysymys 1: IaC:n perusidea

Selitä omin sanoin, mitä Infrastructure as Code tarkoittaa ja miksi sitä käytetään. Anna esimerkki tilanteesta, jossa IaC on hyödyllisempi kuin resurssien luominen käsin Azure Portalissa.

> IaC tarkoittaa infrastruktuurin luomista ja hallintaa koodin avulla. Käytännössä tämä tarkoittaa infran määrittelyä koodilla, jonka ajaminen luo tarvittavat resurssit esim. Azuren pilviympäristöön. 
Mitä monimutkaisempi ja suurempi toteutus on, sitä suuremmiksi kasvavat myös IaC:n hyödyt, kuten toistettavuus, versionhallinta sekä automatisointi.

### Kysymys 2: Deklaratiivinen vs. imperatiivinen

Selitä ero deklaratiivisen ja imperatiivisen IaC-lähestymistavan välillä. Kumpaan kategoriaan Bicep kuuluu?

>Deklaratiivisessa lähestymistavassa kerrotaan mihin lopputulokseen halutaan päästä ja työkalu (esim.Bicep) laskee itse mitä sen on luotava ja toteuttaa tämän.
Imperatiivisessa lähestymistavassa on kerrottava jokainen askel, minkä haluaa suoritettavan.

### Kysymys 3: Idempotenssi

Mitä tarkoittaa, kun sanotaan, että IaC on **idempotenttia**? Miksi tämä ominaisuus on hyödyllinen?

>Idempotentti käsitteenä tarkoittaa että samalla funktiolla (koodilla tms.) suoritettu toimenpide tuottaa saman tuloksen riippumatta siitä, kuinka monta kertaa se suoritetaan.
IaC -työkaluissa tämä on tärkeää, sillä näin esim. päivitetyn deploy -scriptin uudelleen ajaminen on turvallista, eikä se uudelleen luo tai riko jo olemassa olevai resursseja.

### Kysymys 4: Konfiguraation ajautuminen (drift)

Selitä, mitä "configuration drift" tarkoittaa. Miten IaC auttaa estämään sitä?

>Configuration driftillä tarkoitetaan ympäristöjen eroamista toisistaan, vaikka tarkoituksena on pystyttää sama ympäristö. IaC estää tämän tapahtumista, sillä samalla koodilla saadaan pystytettyä aina sama ympäristö.
---

## Osa 2: Bicep

### Kysymys 5: Bicep vs. ARM

Miksi Bicep kehitettiin ARM JSON -templatejen tilalle? Mainitse vähintään 2 etua.

>Bicep on helppolukuisempi ja näin helpompi oppia kuin ARM-template.
Bicepin kanssa voidaan käyttää myös IntelliSenseä ja tyyppivalidointia, mikä parantaa koodin laatua ja turvallisuutta.

### Kysymys 6: Parametrit ja `@secure()`

Miksi tietokantasalasana merkitään `@secure()`-dekoraattorilla Bicepissä? Mitä tapahtuisi ilman sitä?

>@secure() -dekoraattori piilottaa sillä merkatut parametrit lokeista ja deployment historiasta. Ilman tätä, salaisuudet ovat suoraan näistä luettavissa.

### Kysymys 7: Moduulit

Miksi infrastruktuurikoodi jaettiin tässä tehtävässä kolmeen erilliseen moduuliin (`acr.bicep`, `postgresql.bicep`, `appservice.bicep`) yhden ison tiedoston sijaan? Mainitse vähintään 2 syytä.

>Moduulien käyttö mahdollistaa koodin helpomman hallittavuuden ja uudelleenkäytön. Ilman tätä, kaikki koodi olisi yhdessä isossa tiedostossa, johon resurssin lisäämien tai niiden poistaminen on hankalaa. Mikäli tulevaisuudessa tulee tarve luoda esim. toinen vastaava postgresql-tietokanta, on koodi jo valmiina. Myös mahdollinen debuggaus helpottuu, kun koodi on jaettu loogisiksi kokonaisuuksiksi.

### Kysymys 8: `uniqueString()`

Miksi ACR:n ja PostgreSQL-palvelimen nimissä käytetään `uniqueString(resourceGroup().id)` -funktiota? Mitä tapahtuisi ilman sitä?

>Palvelimien nimien tulee olla globaalisti uniikkeja, jotta ne voidaan luoda. Tämä funktio generoi 13-merkkiä pitkän stringin syötteen perusteella (resourceGroup().id), jota voidaan käyttää palvelimien nimissä.

### Kysymys 9: `targetScope`

Mitä tarkoittaa `targetScope = 'subscription'` main.bicep-tiedostossa? Miksi emme käytä oletusarvoa `resourceGroup`?

>Deployment tehdään subscription -tasolla. Emme voi tehdä tätä resource group -tasolla sillä luomme myös resourceGroupin.

---

## Osa 3: Azure-resurssit

### Kysymys 10: Resource Group

Mikä on Azure Resource Groupin tarkoitus? Miksi kaikki sovelluksen resurssit kannattaa sijoittaa samaan resource groupiin?

>Resource Group:in tärkein tarkoitus on helpottaa sovelluksen eri resurssien hallintaa kokoamalla nämä saman resurssin alle. Tämä mahdollistaa mm. kaikkien resurssien samanaikaisen poistamisen.

### Kysymys 11: Ympäristömuuttujat ja Connection String

Selitä, miten sovelluksen tietokantayhteys konfiguroidaan eri ympäristöissä:
- Miten connection string asetetaan **Docker Composessa** (lokaalissa kehityksessä)?
    >Docker Compose hakee connection stringin .env -tiedostosta.
- Miten **sama** connection string asetetaan **Azure App Servicessä**?
    >Parametritiedostossa oleva *readEnvironmentVariable* lukee connection stringin AppServicen ympäristömuuttujista. 
- Miksi sovelluksen koodi ei muutu, vaikka ympäristö vaihtuu?
    >Kun connection string on asetettu AppServiceen oikein, sovellus osaa käyttää tätä automaattisesti.


### Kysymys 13: PostgreSQL Flexible Server -- Firewall

Miksi PostgreSQL-palvelimeen luodaan firewall-sääntö `AllowAzureServices` (IP-alue `0.0.0.0 - 0.0.0.0`)? Mitä tapahtuisi ilman sitä?

>Tämä sääntö antaa luvan sovelluksille Azuren sisällä ottaa yhteyttä luomaamme PostgreSql-palvelimeen. Ilman tätä sääntöä, AppService ei voi keskustella tietokannan kanssa.
---

## Osa 4: Deployment ja turvallisuus

### Kysymys 15: What-if

Miksi `what-if` on tärkeä vaihe ennen deploymenttia? Anna esimerkki tilanteesta, jossa what-if estäisi ongelman.

>`whati-if` -komennolla nähdään mitä deploymentissa tapahtuu, ilman että mitään vielä oikeasti tehdään. Mikäli tulosteessa on ylimääräisiä resursseja joita ei ole tarkoitus luoda, voidaan deployment-scriptiä muokata.

### Kysymys 16: Tagit

Miksi kaikkiin Azure-resursseihin lisättiin tagit (`Application`, `Environment`, `ManagedBy`)? Miten ne hyödyttävät käytännössä?

>Tagit ovat metatietoa, jonka avulla voidaan seurata mitä resursseja on luotu, mitä varten, mihin ympäristöön ja miten ne on luotu. Tämä auttaa isoissa projekteissa resurssien hallintaa.

### Kysymys 17: Siivous ja kustannukset

Miksi on tärkeää poistaa kehitysresurssit Azuresta kun niitä ei enää tarvita? Mikä on helpoin tapa poistaa kaikki tämän tehtävän resurssit kerralla?

>Vaikka resursseja ei aktiivisesti käytä, ne ovat silti olemassa ja todennäköisesti maksavat jotain. Mikäli kaikki resurssit on koottu saman Resource Groupin alle, Resource Group poistamalla poistetaan automaattisesti myös sen alla olevat resurssit.

---

