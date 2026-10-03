# InkProf: modell, invers och mätstrategi

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Tekniskt diskussionsunderlag • 25 september 2026 • Version 1.0

**Förslag:** beskriv den samlade utskriftskedjan med en uppmätt RGB-framåtmodell. Beräkna inversen lokalt med en approximerad Jacobian, dämpning och bra startvärden. Anpassa mätningen efter observerade fel och användarens prioriteringar.

Dokumentet sammanfattar diskussionen om Canon PRO-2600 och InkProf. Det beskriver en föreslagen metod, inte en implementerad eller experimentellt verifierad lösning. Prestanda, patchantal och tidsvinster återstår att mäta.

### 1. Vad vi faktiskt kan styra

> RGB → drivrutinens bläckseparation och rastrering → papper → uppmätt spektrum

Vi kan ange RGB och mäta utskriftens reflektans. Vi antar inte tillgång till enskilda bläckkanaler. Modellen gäller därför en bestämd kombination av skrivare, papper, mediatyp, kvalitetsläge och övriga utskriftsinställningar. Targetflödet måste bevara de avsedda enhetsvärdena utan en oavsiktlig extra profilomvandling.

### 2. Yule-Nielsen/Neugebauer: relevant, men inte förstaval

$$
\rho(\lambda)=\left[\sum_i a_i\,\rho_i(\lambda)^{1/n}\right]^n
$$

ρᵢ är spektra för papper och bläckövertryck, aᵢ deras yttäckningsandelar och n en anpassningsparameter. Utökade modeller har demonstrerats för bläckstråleutskrifter, bland annat med bläckspridning. Modellen är alltså inte principiellt olämplig för denna tryckteknik. [1]

Svårigheten här är den dolda bläckseparationen. Vi kan inte utan vidare framställa alla enskilda primärer eller veta deras täckning. Parametrar kan anpassas numeriskt, men flera olika parameteruppsättningar kan förklara liknande mätningar. God anpassning innebär inte identifierad bläckfysik.

Det finns också RGB-baserade, Yule-Nielsen-inspirerade modeller som inkluderar drivrutinens beteende. [2] De bör kunna prövas senare som jämförelse. För InkProf föreslås först en empirisk RGB-modell som inte kräver antaganden om Canons interna separation.

## En lokal modell från RGB till färg

### 3. Framåtmodellen

$$
\mathbf u=(r,g,b),\quad 0\le r,g,b\le1,\qquad \rho(\lambda)=F_\lambda(\mathbf u)
$$

Träningsdata består av de RGB-värden som skickas till skrivaren och uppmätta spektra från motsvarande patchar. En spektral modell kan omräknas till XYZ och Lab för specificerad belysning och observatör. Fluorescerande papper kräver särskild försiktighet: en vanlig reflektansmätning beskriver inte all belysningsberoende fluorescens.

### Taylorapproximation och polynomregression

$$
F_\lambda(\mathbf u_0+\Delta\mathbf u)\approx F_\lambda(\mathbf u_0)+J_\lambda\Delta\mathbf u+\frac12\Delta\mathbf u^{\mathsf T}H_\lambda\Delta\mathbf u
$$

Taylorutvecklingen beskriver funktionen lokalt genom lutning och krökning. Praktiskt kan dessa uppskattas från en anpassad lokal polynommodell, i stället för genom differenser mellan enstaka brusiga mätningar.

$$
\hat\rho(\lambda)=\beta_0+\beta_1r+\beta_2g+\beta_3b+\beta_4r^2+\beta_5g^2+\beta_6b^2+\beta_7rg+\beta_8rb+\beta_9gb
$$

Ett andragradspolynom har tio koefficienter per våglängd. Tio mätningar är inte ett rekommenderat target: stabil anpassning och oberoende validering kräver fler och välplacerade patchar. Koefficienterna kan skattas med viktad, regulariserad minsta kvadrat. För en fast polynombas är denna skattning linjär i koefficienterna; den kräver inte i sig en icke-linjär inverslösare.

Lokala modeller begränsar risken för svängningar och stora fel som ett enda globalt höggradspolynom kan ge. Lokal viktad polynomregression för RGB till reflektans har stöd i tidigare forskning. [3]

### Arbetsantagandet: lokalt jämnt beteende

En bra skrivare bör ge jämna färgövergångar vid små RGB-förändringar. Detta motiverar lokal jämnhet som arbetsantagande på relevant mät- och korrigeringsskala. Det är inte ett bevis för kontinuerliga derivator på varje digital nivå. Bläckväxlingar kan ändra lutningen utan synliga färgsprång.

**Första implementation:** börja med lokal linjär approximation. Inför kvadratiska termer där kontrollmätningarna visar att krökningen är betydelsefull. En exakt Hessian är inget startkrav.

## En hanterbar och stabil invers

### 4. Från önskad färg till RGB

$$
\min_{\mathbf u\in[0,1]^3}\frac12\left\|F(\mathbf u)-\mathbf y_{\mathrm{mål}}\right\|^2
$$

F kan här avse XYZ, Lab eller ett viktat spektrum. Valet bestämmer felmåttets betydelse. Vanligt kvadratiskt Lab-avstånd är inte samma sak som ΔE00. Ett godtyckligt målspektrum behöver inte vara reproducerbart med skrivarens tre RGB-styrvärden.

Startvärdet hämtas från närliggande patchar eller en preliminär inverterad tabell. Med ett bra startvärde kan en lokal korrigering räcka. Det är en arbetshypotes att verifiera, inte en generell garanti.

$$
\begin{aligned}\mathbf e&=F(\mathbf u)-\mathbf y_{\mathrm{mål}}\\(J^{\mathsf T}J+\mu I)\Delta\mathbf u&=-J^{\mathsf T}\mathbf e\end{aligned}
$$

Detta visar ett dämpat Gauss-Newton-steg. Stor μ begränsar korrigeringen. Dämpningen minskas när steget ger den förbättring som modellen förutsäger. En trust-region-metod begränsar på liknande sätt området där den lokala modellen används. [4] RGB-gränser ska hanteras i lösningen, inte bara genom okontrollerad klippning efteråt.

### Approximerad Jacobian och successiva delmål

En approximerad Jacobian kan behållas så länge den ger tillräckligt bra korrigeringar. Den beräknas från modellen; nya utskrifter behövs inte vid varje numeriskt steg. Vid svårigheter kan målet flyttas successivt från en känd, reproducerad färg:

$$
\mathbf y(t)=(1-t)F(\mathbf u_0)+t\mathbf y_{\mathrm{mål}},\qquad 0\le t\le1
$$

Föregående lösning blir startpunkt för nästa delmål. Mindre steg används vid svårigheter. En sådan väg kan dock passera områden som skrivaren inte kan återge, även om ändpunkterna är åtkomliga; metoden garanterar därför inte konvergens.

### Vad närhet till lösningen inte löser

Liten residual gör ofta Gauss-Newton-approximationen av målfunktionens Hessian bättre. Men närhet innebär inte automatiskt låg känslighet för mät- eller modellfel. Nära ett plant eller mättat område kan olika RGB-värden ge nästan samma färg: den lokala inversen blir då dåligt bestämd.

Dämpning, RGB-gränser och kontinuitet mellan närliggande lösningar ger ett praktiskt val bland flera likvärdiga svar. Målet är en användbar invers, inte nödvändigtvis en unik matematisk invers. Iterationerna görs när profilen byggs; resultatet lagras därefter som en interpolerad ICC-tabell.

## Profilens prioriteringar och glesa områden

### 5. Definiera vad en bra profil betyder

$$
E(\theta)=\sum_i w_i\,\Delta E_{00,i}(\theta)^2+\lambda S(\theta)
$$

θ betecknar här den valda inversens eller profilens parametrar. Vikterna wᵢ anger prioriteringar och S straffar oönskad ojämnhet. Hög vikt för gråskalan kan förbättra den på bekostnad av andra färger. Redovisa därför fel separat för olika färgområden, inte bara ett viktat medelvärde.

Gråskalans krav bör delas i neutralitet, ljushet och ett jämnt, monotont tonförlopp. Referensvitpunkten måste anges. Ett absolut kvalitetskrav kan uttryckas som en tolerans i stället för en hög vikt, om skrivaren kan uppfylla toleransen.

**Skilj beskrivning från prioritering:** framåtmodellen ska återge mätningarna trovärdigt. Användarens preferenser styr främst invers, gamutmappning och fördelning av extra mätningar. Samma framåtmodell kan då ge flera profilalternativ.

### 6. Förtäta där information saknas

En stor gradient betyder att små RGB-steg ger stora färgskillnader. Den kan kräva tätare provtagning för önskad perceptuell upplösning. Men en brant, linjär funktion kan interpoleras exakt. Interpolationsfelet beror särskilt på krökning och avstånd mellan punkterna:

$$
\text{Lokalt försummat bidrag}\approx\frac12\Delta\mathbf u^{\mathsf T}H\Delta\mathbf u
$$

Kompletterande patchar bör placeras där det finns stora luckor, snabbt ändrad Jacobian eller stora oberoende kontrollfel. För gråskalor behövs punkter både längs neutralaxeln och omkring den. Högre vikt kan inte ersätta saknade data.

En gles modell kan själv missa ett problem. Därför behövs också kontrollpunkter som inte enbart valts utifrån modellens egen uppskattning. När fel upptäcks läggs nya träningspatchar till, medan en separat slutlig kontrollmängd behålls.

ArgyllCMS targen kan använda en preliminär ICC- eller MPP-profil för uppskattning av perceptuella avstånd och krökning vid targetgenerering. Verktyget erbjuder även koncentration kring neutralaxeln och mörka områden. [5] Detta är en användbar grund, men inte samma sak som en färdig felstyrd återkopplingsloop för InkProf.

## Verifiering, kostnad och nästa steg

### 7. Två upplösningar och två återkopplingar

**Mätunderlag:** fler relevanta mätningar förbättrar kunskapen om skrivaren. **ICC-tabell:** fler tabellpunkter kan minska interpolationsförlusten när en redan känd modell lagras. En tät tabell kan inte skapa saknad mätinformation. ArgyllCMS colprof har val för tabellupplösning, även för inversen. [6]

Snabba numeriska iterationer sker inom modellen. Verklig återkoppling kräver utskrift, stabilisering och mätning. Den senare är normalt den tidskrävande delen. En möjlig besparing kommer därför från bra startvärden och riktade kompletteringar, men måste jämföras experimentellt med ett vanligt targetflöde.

### Föreslagen ordning i InkProf

1. Lås utskrifts- och mätförhållanden. Mät ett bas-target med upprepade patchar.
2. Bygg och validera en enkel framåtmodell. Behåll en Argyll-profil som referens.
3. Beräkna en dämpad lokal invers med valbara prioriteringar.
4. Mät kontrollpatchar och komplettera target där felen motiverar det.
5. Bygg ICC-tabellen och kontrollera även färger mellan dess noder.
6. Jämför färgfel, spektralfel, tonförlopp, patchantal och total arbetstid.

Använd upprepade patchar för att uppskatta brus och variation, och gärna en separat utskriftsomgång för slutkontroll. Stoppa förtätningen när den önskade toleransen nås eller när förbättringen inte längre kan skiljas från variationen. Yule-Nielsen-inspirerade modeller tas in först när de kan prövas mot samma kontrollunderlag.

### Källor

[1] Rossier, Bugnon & Hersch (2010). Introducing Ink Spreading Within the Cellular Yule-Nielsen Modified Neugebauer Model. [Öppna källa](https://lspwww.epfl.ch/publications/colour/iiswtcynmnm_10.pdf).

[2] Zuffi, Schettini & Mauri (2005). Spectral-Based Printer Modeling and Characterization. Journal of Electronic Imaging 14(2). [Öppna källa](https://boa.unimib.it/handle/10281/2557).

[3] Shen m.fl. (2013). Adaptive Characterization Method for Desktop Color Printers. Journal of Electronic Imaging 22(2), 023012. [Öppna källa](https://doi.org/10.1117/1.JEI.22.2.023012).

[4] MathWorks. Least-Squares (Model Fitting) Algorithms. Metoderna beskrivs här; färdiga lösare hör till Optimization Toolbox. En egen liten lösare kan byggas med MATLAB Base. [Öppna källa](https://www.mathworks.com/help/optim/ug/least-squares-model-fitting-algorithms.html).

[5] ArgyllCMS. targen: adaptiv targetgenerering och förkonditionering. [Öppna källa](https://www.argyllcms.com/doc/targen.html).

[6] ArgyllCMS. colprof: ICC-profiler och tabellupplösning. [Öppna källa](https://www.argyllcms.com/doc/colprof.html).

Källorna stödjer metodprinciperna. Den föreslagna kombinationen och dess lämplighet för Canon PRO-2600 är InkProf-arbetets hypoteser, inte resultat från dessa publikationer.
