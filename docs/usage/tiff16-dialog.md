# TIFF16-dialog för patchdefinitioner

Öppna i MATLAB efter `setupInkProf()`:

```matlab
window=inkprof.renderTarget();
% Alternativt med förvald fil:
window=inkprof.renderTarget(fullfile(paths.Projects,'chart.pxf'));
```

Dialogen är på engelska. Välj indatafil med **Browse…**: stödda RGB-varianter av TI1, TI2, PXF, TXF, CGATS/TXT och CxF hanteras av den befintliga importören. För generell CGATS/CxF väljs explicit RGB-skala när formatet kräver det. CMYK avvisas.

**A4 landscape**, 297 × 210 mm, och 300 dpi är förval. Välj ett annat standardformat eller ändra bredd/längd för **Custom**. Bredd inklusive marginaler får vara högst 320 mm. Längden bestäms av användaren, utan tidigare gräns på 280 mm; faktiskt möjliga bildstorlekar beror på tillgängligt minne och renderaren. DPI kan vara 72–1200.

Indatafilens basnamn plus `-TIFF16` föreslås som **Output package name**. **Generate and save…** öppnar en dialog där namn och överordnad mapp kan ändras. Namnet avser en ny paketmapp; inuti behålls standardnamnen `target*.tif`, `target.ti1`, `target.ti2` och JSON-filer. Befintliga paket skrivs inte över. Genereringen är synkron; vänta tills den avslutats innan fönstret stängs.

Efter generering stängs dialogen och en liten PNG av sida 1 visas i resultatfönstret. PNG-filer sparas också i paketet men är enbart förhandsvisningar. Utskriftsfilerna är RGB TIFF med 16 bitar per kanal utan inbäddad ICC-profil. Färgade kontrastmarkörer används. Patchdefinitionerna får en ny layout; även en importerad TI2 får nytt mätunderlag som hör till just de nya TIFF-sidorna. Originalet bevaras som källa. Den nya layouten ändrar inte RGB-definitionerna utöver TIFF16-kvantiseringen.

## JSON och spårbarhet

`target.json` och `manifest.json` har samma `printSettings`: paketnamn, fullständig utmatningsmapp, indatafilens sökväg, DPI, sidbredd och längd i mm, marginal, kontrastmarkörer, randomiseringsinställningar, 16-bitarsformat och avsaknad av inbäddad ICC-profil. Källans namn, hash och nätinformation ligger kvar i `targetInfo`.

`manifest.json` innehåller dessutom faktiskt renderat sidmått (avrundat nedåt till hela pixlar), fullständiga genereringsalternativ och filernas kontrollsummor. `layout.json` anger patcharnas identiteter, RGB-värden, sidor och positioner. `target.ti2` matchar utskriften för senare mätning. Sidfoten visar den slutliga TIFF-sökvägen.

## Avbryt, spara och sidantal

**Cancel** stänger fönstret utan att spara. Under beräkning eller rendering begär knappen avbrott vid nästa säkra kontrollpunkt; ett pågående externt Argyll-anrop måste först återvända. Tillfälliga utskriftsfiler städas bort och inget nytt paket publiceras vid avbrott. **Stop generation** i nätfönstret avbryter däremot endast förtätningen och låter fönstret vara kvar.

Efter lyckad sparning stängs genereringsfönstret automatiskt. Ett separat resultatfönster visar **Saved TIFF16 target — N pages**, PNG av sida 1 samt paketets sökväg. Vid sparfel ligger genereringsfönstret kvar. Sidantalet sparas också i paketets JSON (`manifest.pageCount` och `printSettings.pageCount`), och för nätgenererade mål i designens `print.pageCount`. TIFF-sidfotens märkning `1 (N)` behålls.

## Sidantal före sparning och RGB-talens skala

Klicka **Calculate / preview** efter filval och sidinställningar. **Pages: N** och PNG av sida 1 visas direkt i TIFF16-fönstret, innan något slutligt paket sparas. Beräkningen använder samma renderare, DPI och layout som exporten; den är inte en grov uppskattning. Tillfälliga filer tas bort efter beräkningen. Sidfotens tillfälliga sökväg ersätts med slutlig sökväg vid sparning. Ändrade inställningar rensar det gamla sidantalet och förhandsvisningen; klicka på nytt för en aktuell beräkning.

**RGB: automatic** avser talområdet i indatafilen. För kända format bestämmer importören det automatiskt: TI1/TI2 använder normalt 0–100 och de stödda PXF/TXF-varianterna 0–255. För generella format som kräver en explicit skala, välj filens dokumenterade talområde: 0–1, 0–100 eller 0–255. Detta är varken en färgprofil, färgrymd eller inställning av TIFF-bitdjupet. Utdata är alltid RGB med 16 bitar per kanal.

## Fönsterfokus och sidbläddring

TIFF16-dialogen använder `WindowStyle="alwaysontop"` och `focus` för att ligga framför MATLAB. `modal` räcker inte, eftersom det inte blockerar MATLABs huvudfönster. Under filval används tillfälligt normalt fönsterläge och toppläget återställs när filväljaren stängs. Efter **Calculate / preview** kan alla sidor granskas med **◀ Previous** och **Next ▶** under bilden. **Page X of N** visar aktuell sida. Pilarna stängs av vid första respektive sista sidan, och när inställningarna ändras. De små PNG-bilderna behålls i minnet så att tillfälliga renderingsfiler fortfarande kan tas bort.

Resultatfönstret efter sparning har samma sidbläddring och öppnas också framför MATLAB. Sidordningen följer sidnumren, även för mål med tio eller fler sidor.

Fönsterbeteendet följer [MathWorks dokumentation för uifigure](https://www.mathworks.com/help/matlab/ref/uifigure.html).

## Separat steg efter nätgenereringen

Mesh-fönstret sparar enbart TI1 och design-JSON med `saveRGBDefinition`. Öppna TI1 här när en utskrift ska skapas. Behåll JSON bredvid TI1 för hashverifierad nätinformation. **Randomize positions** och dess seed ligger nu här tillsammans med sidmått och DPI. Både förhandsvisning och sparning använder samma val. En ny utskriftsmapp skapas; den sparade nätdefinitionen ändras inte.
