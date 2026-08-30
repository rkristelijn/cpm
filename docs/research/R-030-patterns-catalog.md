# R-030: Design Patterns Catalogus (Tussenresultaat)

**Date:** 2026-08-30
**Status:** Tussenresultaat (Fase 1/5)

## Samenvatting

**137 patterns** gecatalogiseerd in **15 categorieën**.

Dit document dient als tussenresultaat voor patroondetectie in cpm's rule engine. Elke pattern is voorzien van een korte beschrijving en het kernprobleem dat het oplost, zodat vervolgfases (detectieregels, scoring, aanbevelingen) hierop kunnen voortbouwen.

---

## Catalogus

### 1. GoF Creational (5 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 1 | **Singleton** | Garandeert dat een klasse precies één instantie heeft en biedt een globaal toegangspunt. | Ongecontroleerd aanmaken van meerdere instanties van een gedeelde resource (config, logger, connection pool). |
| 2 | **Factory Method** | Definieert een interface voor het aanmaken van objecten, maar laat subklassen beslissen welke klasse wordt geïnstantieerd. | Directe koppeling tussen aanroepcode en concrete klassen bij object-creatie. |
| 3 | **Abstract Factory** | Biedt een interface voor het aanmaken van families van gerelateerde objecten zonder concrete klassen te specificeren. | Inconsistente objectfamilies wanneer productvarianten (bijv. UI-thema's, OS-specifiek) door elkaar worden aangemaakt. |
| 4 | **Builder** | Scheidt de constructie van een complex object van zijn representatie, zodat hetzelfde bouwproces verschillende representaties kan opleveren. | Telescoping constructors en onleesbare object-initialisatie bij objecten met veel optionele parameters. |
| 5 | **Prototype** | Maakt nieuwe objecten door bestaande instanties te klonen in plaats van ze from scratch te construeren. | Hoge kosten of complexiteit bij het opnieuw opbouwen van objecten die beter gekopieerd kunnen worden. |

### 2. GoF Structural (7 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 6 | **Adapter** | Converteert de interface van een klasse naar een andere interface die clients verwachten. | Incompatibele interfaces tussen bestaande klassen die moeten samenwerken. |
| 7 | **Bridge** | Ontkoppelt een abstractie van zijn implementatie zodat beide onafhankelijk kunnen variëren. | Exponentiële groei van subklassen wanneer abstractie en implementatie in één hiërarchie zitten. |
| 8 | **Composite** | Componeert objecten in boomstructuren om deel-geheel hiërarchieën te representeren, zodat individuele objecten en composities uniform behandeld worden. | Verschil in behandeling tussen enkelvoudige objecten en groepen van objecten. |
| 9 | **Decorator** | Voegt dynamisch verantwoordelijkheden toe aan een object, als flexibel alternatief voor subklassen. | Rigide klassenhiërarchieën wanneer functionaliteit combinatorisch moet worden uitgebreid. |
| 10 | **Facade** | Biedt een vereenvoudigde interface voor een complex subsysteem. | Hoge complexiteit en sterke koppeling wanneer clients direct met meerdere subsysteemklassen communiceren. |
| 11 | **Flyweight** | Deelt fijnkorrelige objecten efficiënt door intrinsieke staat te delen tussen vele instanties. | Excessief geheugengebruik door grote aantallen vergelijkbare objecten. |
| 12 | **Proxy** | Plaatst een surrogaat of plaatsvervanger voor een ander object om toegang te controleren. | Behoefte aan toegangscontrole, lazy loading, caching of logging zonder het oorspronkelijke object te wijzigen. |

### 3. GoF Behavioral (11 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 13 | **Chain of Responsibility** | Geeft een verzoek door langs een keten van handlers totdat er één het afhandelt. | Harde koppeling tussen verzender en ontvanger van een verzoek, en inflexibele routering van requests. |
| 14 | **Command** | Encapsuleert een verzoek als een object, waardoor parametrisering, queueing en undo mogelijk wordt. | Directe koppeling tussen de aanvrager van een operatie en de uitvoerder ervan; geen undo/redo-mogelijkheid. |
| 15 | **Iterator** | Biedt een manier om sequentieel door elementen van een aggregaat te lopen zonder de interne structuur bloot te leggen. | Blootstelling van interne datastructuur bij het doorlopen van collecties. |
| 16 | **Mediator** | Definieert een object dat de communicatie tussen een groep objecten coördineert, waardoor directe onderlinge koppelingen worden vermeden. | Spaghetti-communicatie tussen veel objecten die allemaal naar elkaar verwijzen. |
| 17 | **Memento** | Vangt de interne toestand van een object op en slaat die extern op, zodat het object later naar die toestand kan worden hersteld. | Onvermogen om objecttoestand te herstellen (undo) zonder encapsulatie te breken. |
| 18 | **Observer** | Definieert een één-op-veel afhankelijkheid zodat wanneer één object verandert, alle afhankelijken automatisch genotificeerd worden. | Polling of harde koppeling wanneer meerdere objecten moeten reageren op toestandsveranderingen. |
| 19 | **State** | Laat een object zijn gedrag wijzigen wanneer zijn interne toestand verandert, alsof het van klasse wisselt. | Complexe conditionals (if/switch) die gedrag bepalen op basis van toestand, verspreid door de code. |
| 20 | **Strategy** | Definieert een familie van algoritmen, encapsuleert elk algoritme en maakt ze uitwisselbaar. | Hardcoded algoritmen die niet vervangbaar zijn zonder de context-klasse te wijzigen. |
| 21 | **Template Method** | Definieert het skelet van een algoritme in een basisklasse en laat subklassen specifieke stappen invullen. | Codeduplicatie wanneer meerdere algoritmen dezelfde structuur maar verschillende details delen. |
| 22 | **Visitor** | Scheidt een algoritme van de objectstructuur waarop het werkt, zodat nieuwe operaties kunnen worden toegevoegd zonder de klassen te wijzigen. | Noodzaak om nieuwe operaties toe te voegen aan een stabiele klassenhiërarchie zonder die klassen aan te passen. |
| 23 | **Interpreter** | Definieert een grammatica voor een taal en een interpreter die zinnen in die taal evalueert. | Herhaaldelijk parsen en uitvoeren van uitdrukkingen in een domeinspecifieke taal. |

### 4. SOLID Principles (5 patterns/practices)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 24 | **Single Responsibility Principle (SRP)** | Een klasse heeft precies één reden om te veranderen — één verantwoordelijkheid. | God-classes die meerdere concerns mengen en bij elke wijziging risico op onbedoelde neveneffecten geven. |
| 25 | **Open/Closed Principle (OCP)** | Software-entiteiten zijn open voor uitbreiding maar gesloten voor wijziging. | Bestaande, geteste code breken bij het toevoegen van nieuwe functionaliteit. |
| 26 | **Liskov Substitution Principle (LSP)** | Subtypes moeten substitueerbaar zijn voor hun basistypes zonder het programma te breken. | Overerving die contracten schendt en onverwacht gedrag veroorzaakt bij polymorf gebruik. |
| 27 | **Interface Segregation Principle (ISP)** | Clients mogen niet gedwongen worden te afhangen van interfaces die ze niet gebruiken. | Opgeblazen interfaces die implementors dwingen tot lege of unsupported methoden. |
| 28 | **Dependency Inversion Principle (DIP)** | High-level modules hangen af van abstracties, niet van low-level modules; abstracties hangen niet af van details. | Directe afhankelijkheden van concrete implementaties die wijziging, testen en hergebruik bemoeilijken. |

### 5. Enterprise / Integration Patterns (17 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 29 | **Repository** | Abstraheert de dataopslaglaag achter een collectie-achtige interface voor domeinobjecten. | Verstrengeling van domeinlogica met database-queries en persistentietechnologie. |
| 30 | **Unit of Work** | Houdt bij welke objecten tijdens een business-transactie zijn gewijzigd en coördineert het schrijven van wijzigingen als één atomaire operatie. | Inconsistente persistentie wanneer meerdere objectwijzigingen niet atomair worden opgeslagen. |
| 31 | **CQRS (Command Query Responsibility Segregation)** | Scheidt het lees-model van het schrijf-model in aparte paden met elk hun eigen optimalisatie. | Conflicterende eisen tussen lees- en schrijfoperaties die niet met één model efficiënt op te lossen zijn. |
| 32 | **Event Sourcing** | Slaat toestandsveranderingen op als een append-only reeks van events in plaats van de huidige toestand te overschrijven. | Verlies van historie en audittrail bij traditionele CRUD-opslag; onvermogen om toestand te reconstrueren. |
| 33 | **Saga** | Coördineert een reeks lokale transacties over meerdere services met compensatie-acties bij falen. | Gedistribueerde transacties die niet met een traditionele 2PC kunnen worden afgehandeld in microservices. |
| 34 | **Circuit Breaker** | Voorkomt herhaalde aanroepen naar een falende service door tijdelijk verzoeken te blokkeren na een drempelwaarde aan fouten. | Cascade-failures wanneer een falende downstream-service herhaaldelijk wordt aangeroepen. |
| 35 | **Retry** | Herhaalt een gefaalde operatie automatisch met een configureerbare strategie (exponential backoff, jitter). | Tijdelijke (transient) fouten bij netwerk- of serviceaanroepen die bij een volgende poging slagen. |
| 36 | **Bulkhead** | Isoleert componenten in compartimenten zodat een falen in één compartiment niet het hele systeem meesleept. | Resource-uitputting in één component die het hele systeem onbeschikbaar maakt. |
| 37 | **Service Locator** | Biedt een centraal register waar services hun implementatie op runtime opvragen. | Directe afhankelijkheden van concrete services zonder centraal punt van configuratie. |
| 38 | **Gateway** | Biedt een enkel toegangspunt dat verzoeken naar achterliggende services routeert en cross-cutting concerns afhandelt. | Clients die rechtstreeks meerdere services moeten kennen en aanroepen. |
| 39 | **Message Broker** | Ontkoppelt producenten en consumenten van berichten via een tussenliggende broker die routering en buffering verzorgt. | Directe point-to-point communicatie die schaalbaarheid en ontkoppeling belemmert. |
| 40 | **Publish-Subscribe** | Laat producenten events publiceren naar een topic waarop meerdere consumenten onafhankelijk geabonneerd zijn. | Harde koppeling tussen event-producent en -consumenten; onvermogen om dynamisch consumers toe te voegen. |
| 41 | **Outbox** | Schrijft domein-events naar een outbox-tabel in dezelfde databasetransactie als de domeinwijziging, en publiceert ze daarna asynchroon. | Inconsistentie tussen databasetoestand en gepubliceerde events (dual-write probleem). |
| 42 | **Dead Letter Queue** | Vangt berichten op die niet succesvol verwerkt kunnen worden, zodat ze later onderzocht en opnieuw geprobeerd kunnen worden. | Onverwerkte berichten die verloren gaan of oneindige retries veroorzaken. |
| 43 | **Strangler Fig** | Vervangt geleidelijk delen van een legacy-systeem door nieuwe implementaties, waarbij het oude systeem stap voor stap wordt afgebouwd. | Big-bang migraties die te riskant zijn; behoefte aan incrementele modernisering. |
| 44 | **Transactional Outbox** | Variant van Outbox specifiek gericht op het garanderen van exactly-once event delivery via change data capture (CDC). | Verlies of duplicatie van events bij publicatie buiten de databasetransactie. |
| 45 | **Idempotent Receiver** | Zorgt dat een consumer hetzelfde bericht meerdere keren kan ontvangen zonder ongewenste neveneffecten. | Duplicate message delivery in gedistribueerde systemen die tot dubbele verwerking leidt. |

### 6. Concurrency Patterns (12 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 46 | **Active Object** | Ontkoppelt methode-aanroep van methode-uitvoering door elke aanroep in een eigen thread/queue uit te voeren. | Directe multithreaded toegang tot objecten die complexe synchronisatie vereist. |
| 47 | **Monitor** | Encapsuleert mutual exclusion en condition variables in een object zodat slechts één thread tegelijk toegang heeft. | Race conditions bij gedeelde mutable state zonder gestructureerde synchronisatie. |
| 48 | **Producer-Consumer** | Ontkoppelt producenten die data genereren van consumenten die data verwerken via een gedeelde buffer. | Snelheidsverschil tussen producenten en consumenten dat tot blokkering of dataverlies leidt. |
| 49 | **Thread Pool** | Hergebruikt een vast aantal threads om taken uit te voeren, in plaats van per taak een nieuwe thread te starten. | Overhead van thread-creatie en -destructie bij veel korte taken; resource-uitputting. |
| 50 | **Future / Promise** | Representeert een resultaat dat nog niet beschikbaar is, zodat asynchrone operaties composeerbaar worden. | Callback-hel en ongestructureerde asynchrone code die moeilijk te volgen en combineren is. |
| 51 | **Actor Model** | Encapsuleert toestand en gedrag in actors die uitsluitend via asynchrone berichten communiceren, zonder gedeelde state. | Complexiteit van lock-gebaseerde synchronisatie; deadlocks en race conditions. |
| 52 | **Read-Write Lock** | Staat meerdere gelijktijdige lezers toe maar slechts één exclusieve schrijver. | Onnodige blokkering van lezers wanneer er geen schrijfoperatie plaatsvindt. |
| 53 | **Semaphore** | Beperkt het aantal threads dat gelijktijdig toegang heeft tot een gedeelde resource via een teller. | Ongecontroleerde gelijktijdige toegang die resource-uitputting of corruptie veroorzaakt. |
| 54 | **Barrier** | Synchroniseert meerdere threads op een punt zodat ze allemaal wachten totdat iedereen dat punt heeft bereikt. | Coördinatie van parallelle taken die allemaal een fase moeten voltooien voordat de volgende fase begint. |
| 55 | **Fork-Join** | Splitst een taak recursief in subtaken (fork), voert ze parallel uit en combineert de resultaten (join). | Inefficiënt sequentieel verwerken van taken die zich lenen voor parallelle verdeel-en-heers. |
| 56 | **Scheduler** | Beheert de volgorde en timing waarin taken worden uitgevoerd op basis van prioriteit, deadline of beschikbare resources. | Ad-hoc taakuitvoering zonder controle over prioritering en resource-allocatie. |
| 57 | **Double-Checked Locking** | Reduceert de overhead van synchronisatie bij lazy initialization door de lock alleen te nemen wanneer nodig. | Onnodige lock-contention bij elke toegang tot een lazy-geïnitialiseerd veld. |

### 7. Functional Patterns (12 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 58 | **Monad** | Wikkelt een waarde in een context (bijv. Maybe, IO) en biedt chaining via bind/flatMap met contextpropagatie. | Ongestructureerde neveneffecten en foutafhandeling die composability van functies belemmeren. |
| 59 | **Functor** | Een type dat map ondersteunt: past een functie toe op de ingepakte waarde zonder de context te verlaten. | Onvermogen om functies toe te passen op waarden die in een container zitten (Optional, List, etc.). |
| 60 | **Applicative** | Breidt Functor uit door functies die zelf in een context zitten toe te passen op waarden in een context. | Onvermogen om meerdere onafhankelijke effectvolle waarden te combineren. |
| 61 | **Lens** | Biedt composable getters en setters voor geneste immutable datastructuren. | Verbositeit en foutgevoeligheid bij het updaten van diep geneste velden in immutable data. |
| 62 | **Pipe / Compose** | Combineert meerdere functies tot een nieuwe functie door de output van de ene als input van de volgende te gebruiken. | Diepe nesting van functieaanroepen die moeilijk leesbaar en onderhoudbaar is. |
| 63 | **Currying** | Transformeert een functie met meerdere argumenten naar een reeks functies die elk één argument nemen. | Inflexibiliteit bij gedeeltelijke toepassing van functies; herhaalde argumenten. |
| 64 | **Memoization** | Cacht het resultaat van dure pure functies zodat herhaalde aanroepen met dezelfde argumenten direct het gecachte resultaat teruggeven. | Herhaalde berekening van dezelfde dure operatie met identieke inputs. |
| 65 | **Either / Result** | Representeert een waarde die ofwel een succes (Right/Ok) ofwel een fout (Left/Err) is, als alternatief voor exceptions. | Ongecontroleerde exceptions die de flow van foutafhandeling ondoorzichtig maken. |
| 66 | **Option / Maybe** | Representeert een waarde die wel of niet aanwezig is, als veilig alternatief voor null. | NullPointerException en ongedefinieerd gedrag door ontbrekende waarden. |
| 67 | **Algebraic Data Types (ADT)** | Modelleren data als sommen (OR) en producten (AND) van types, waardoor exhaustive pattern matching mogelijk wordt. | Onvolledige of incorrecte representatie van domeinvarianten met primitieve types of klassenhiërarchieën. |
| 68 | **Church Encoding** | Representeert data als functies in plaats van datastructuren, zodat operaties op data puur functioneel zijn. | Afhankelijkheid van concrete datastructuren voor eenvoudige bewerkingen. |
| 69 | **Free Monad** | Scheidt de beschrijving van een programma (als datastructuur) van de interpretatie ervan. | Verstrengeling van business-logica met IO en neveneffecten; moeilijk testbaar. |

### 8. Architecture Patterns (13 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 70 | **MVC (Model-View-Controller)** | Scheidt een applicatie in Model (data/logica), View (presentatie) en Controller (input-afhandeling). | Vermenging van UI, business-logica en data-toegang in monolithische componenten. |
| 71 | **MVP (Model-View-Presenter)** | Variant van MVC waarbij de Presenter alle logica bevat en de View passief is (geen directe model-kennis). | Moeilijk testbare UI-logica in MVC doordat de View te veel verantwoordelijkheid heeft. |
| 72 | **MVVM (Model-View-ViewModel)** | De ViewModel exposeert observeerbare data en commands; de View bindt declaratief aan het ViewModel. | Boilerplate code voor synchronisatie tussen UI-state en domein-state. |
| 73 | **Clean Architecture** | Organiseert code in concentrische ringen waarbij afhankelijkheden alleen naar binnen wijzen (entities → use cases → adapters → frameworks). | Framework-lock-in en onvermogen om business-logica te testen zonder infrastructuur. |
| 74 | **Hexagonal / Ports & Adapters** | Plaatst de domeinlogica centraal met ports (interfaces) en adapters (implementaties) voor alle externe interactie. | Directe afhankelijkheid van externe systemen (DB, API, UI) die de kern onvervangbaar maakt. |
| 75 | **Onion Architecture** | Variant van Hexagonal met expliciete lagen (Domain Model → Domain Services → Application Services → Infrastructure). | Infrastructuur-afhankelijkheden die de domeinlaag binnendringen. |
| 76 | **Layered Architecture** | Organiseert code in horizontale lagen (Presentation → Business → Data) met strikt top-down afhankelijkheden. | Ongestructureerde code waar alle lagen door elkaar heen verwijzen. |
| 77 | **Microkernel / Plugin** | Een minimale kern biedt basisinfrastructuur; functionaliteit wordt uitgebreid via dynamisch geladen plugins. | Monolithische systemen die niet uitbreidbaar zijn zonder de kern te wijzigen. |
| 78 | **Event-Driven Architecture** | Componenten communiceren via events (produceren, routeren, consumeren) in plaats van directe aanroepen. | Sterk gekoppelde synchrone communicatie die schaalbaarheid en responsiviteit beperkt. |
| 79 | **Space-Based Architecture** | Verdeelt verwerking en data over meerdere processing units met in-memory data grids voor lineaire schaalbaarheid. | Database-bottleneck bij hoge concurrency die verticale schaling onmogelijk maakt. |
| 80 | **Serverless** | Draait code als kortstondige functies die on-demand worden uitgevoerd en automatisch schalen, zonder serverbeheer. | Operationele overhead van serverbeheer en provisionering voor variabele workloads. |
| 81 | **Service Mesh** | Plaatst een infrastructuurlaag (sidecar proxies) tussen services voor observability, security en traffic management. | Cross-cutting concerns (mTLS, retries, tracing) die in elke service apart geïmplementeerd moeten worden. |
| 82 | **Modular Monolith** | Organiseert een monoliet in strikt gescheiden modules met expliciete interfaces, als tussenstap naar microservices. | Ongestructureerde monoliet waar alle code door elkaar heen grijpt; te vroege microservices-migratie. |

### 9. State Management Patterns (7 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 83 | **Flux** | Unidirectionele dataflow: Actions → Dispatcher → Stores → Views, waardoor state-mutaties voorspelbaar worden. | Onvoorspelbare state-updates door bidirectionele data-binding in complexe UI's. |
| 84 | **Redux** | Enkele immutable state-tree met pure reducer-functies die de volgende state berekenen op basis van de huidige state en een action. | Verspreidde mutable state die moeilijk te debuggen, reproduceren en testen is. |
| 85 | **State Machine** | Modelleert een systeem als een eindige verzameling toestanden met expliciete transities tussen toestanden op basis van events. | Impliciete toestandslogica verspreid over booleans en conditionals die tot ongeldige toestanden leiden. |
| 86 | **Finite Automaton** | Formele variant van een state machine (DFA/NFA) gebruikt voor parsing, validatie en patroonherkenning. | Ad-hoc parsing of validatie zonder formele garanties over correctheid en volledigheid. |
| 87 | **Store Pattern** | Centraliseert applicatie-state in een reactieve store die componenten observeren en waarop ze acties dispatchen. | Versnipperde state over componenten die moeilijk te synchroniseren en delen is. |
| 88 | **Event Store** | Persisteert alle toestandsveranderingen als geordende events in een append-only log, zodat huidige state uit events reconstrueerbaar is. | Verlies van toestandshistorie en onvermogen tot tijdreizen door destructieve updates. |
| 89 | **Snapshot** | Slaat periodiek de volledige staat op zodat event replay niet vanaf het begin hoeft, maar vanaf het laatste snapshot. | Lange replay-tijden bij event sourcing wanneer de event-reeks te lang wordt. |

### 10. Data Patterns (10 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 90 | **Active Record** | Een domeinobject bevat zowel data als persistentielogica (save, find, delete). | Behoefte aan eenvoudige CRUD-operaties zonder aparte data-access laag. |
| 91 | **Data Mapper** | Een aparte mapper-laag vertaalt tussen domeinobjecten en database-records, zodat beide onafhankelijk zijn. | Koppeling tussen domeinmodel en databaseschema die onafhankelijke evolutie verhindert. |
| 92 | **Table Data Gateway** | Eén klasse per database-tabel die alle SQL voor die tabel encapsuleert en recordsets teruggeeft. | SQL verspreid door de applicatiecode; gebrek aan centralisatie per tabel. |
| 93 | **Row Data Gateway** | Eén object per rij in de database dat de data van die rij bevat plus methoden om te lezen/schrijven. | Directe row-level database-toegang vermengd met domeinlogica. |
| 94 | **Identity Map** | Houdt een in-memory map bij van al geladen objecten zodat elk database-record maximaal één keer als object bestaat. | Dubbele objectinstanties voor hetzelfde record die tot inconsistentie en onnodige queries leiden. |
| 95 | **Lazy Load** | Stelt het laden van gerelateerde data uit tot het moment dat het daadwerkelijk nodig is. | Onnodige data laden (N+1 in bulk) wanneer slechts een deel van de relaties wordt gebruikt. |
| 96 | **Eager Load** | Laadt gerelateerde data in dezelfde query als de hoofdentiteit om latere round-trips te voorkomen. | N+1 query-probleem waarbij elke rij een extra query triggert voor relaties. |
| 97 | **DTO (Data Transfer Object)** | Een plat object zonder logica dat data transporteert tussen lagen of services. | Over-exposure van domeinmodel naar externe consumers; onnodige koppeling aan interne structuur. |
| 98 | **Value Object** | Een onveranderlijk object zonder identiteit dat alleen gedefinieerd wordt door zijn attributen. | Primitieve obsessie (string, int) voor domeinconcepten die validatie en semantiek missen. |
| 99 | **Specification** | Encapsuleert een business-rule als een composable boolean-expressie die op domeinobjecten kan worden toegepast. | Herhaalde, verspreide querycriteria en filterlogica die moeilijk herbruikbaar en testbaar is. |

### 11. UI / Frontend Patterns (9 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 100 | **Container / Presentational** | Scheidt componenten in containers (data/logica) en presentational (puur UI, ontvangen data via props). | Vermenging van datafetching en rendering in één component die herbruikbaarheid vermindert. |
| 101 | **Compound Component** | Een groep componenten die impliciet state delen en samenwerken als één semantische eenheid (bijv. Tabs + Tab + TabPanel). | Rigide API's voor samengestelde UI-elementen die geen flexibele compositie toelaten. |
| 102 | **Render Props** | Een component ontvangt een functie als prop die de rendering controleert, waardoor renderlogica deelbaar wordt. | Code-duplicatie van gedeeld gedrag tussen componenten die niet via overerving opgelost kan worden. |
| 103 | **Higher-Order Component (HOC)** | Een functie die een component ontvangt en een verrijkt component teruggeeft met extra functionaliteit. | Cross-cutting concerns (auth, logging, theming) die in elke component apart geïmplementeerd moeten worden. |
| 104 | **Hooks Pattern** | Encapsuleert herbruikbare state-logica in functies (custom hooks) die in elk functioneel component gebruikt kunnen worden. | Complexe state-logica die niet deelbaar is tussen componenten zonder class-gebaseerde patronen. |
| 105 | **Atomic Design** | Organiseert UI-componenten in vijf niveaus: Atoms → Molecules → Organisms → Templates → Pages. | Inconsistente UI door gebrek aan een gestructureerde componenthiërarchie en design-systeem. |
| 106 | **Micro-Frontend** | Splitst een frontend-applicatie in onafhankelijk deploybare mini-applicaties die samen één UI vormen. | Monolithische frontends die teamautonomie en onafhankelijke releases belemmeren. |
| 107 | **Island Architecture** | Combineert server-rendered statische HTML met selectieve client-side hydration voor interactieve "eilanden". | Onnodige JavaScript-payload voor pagina's die grotendeels statisch zijn. |
| 108 | **Slot Pattern** | Biedt benoemde plekken (slots) in een component waar de consumer eigen content kan injecteren. | Inflexibele componenten die niet toestaan dat de consumer bepaalde delen van de UI aanpast. |

### 12. API / Communication Patterns (8 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 109 | **REST (Representational State Transfer)** | Resource-georiënteerde API met HTTP-verbs (GET, POST, PUT, DELETE) en stateless communicatie. | Gebrek aan een uniforme, voorspelbare interface voor CRUD-operaties over HTTP. |
| 110 | **GraphQL** | Een querytaal waarmee clients precies specificeren welke data ze nodig hebben in één request. | Over-fetching en under-fetching van data bij vaste REST-endpoints. |
| 111 | **RPC (Remote Procedure Call)** | Roept een procedure aan op een remote server alsof het een lokale functieaanroep is (gRPC, JSON-RPC). | Complexiteit van netwerkcommunicatie die ontwikkelaars dwingt tot handmatige request/response-afhandeling. |
| 112 | **BFF (Backend for Frontend)** | Een dedicated backend-laag per frontend-type (web, mobile, IoT) die data aggregeert en transformeert. | Generieke API's die niet passen bij de specifieke behoeften van verschillende frontend-types. |
| 113 | **API Gateway** | Eén centraal toegangspunt dat verzoeken routeert, aggregeert en cross-cutting concerns (auth, rate limiting) afhandelt. | Clients die meerdere microservice-endpoints direct moeten aanspreken. |
| 114 | **Anti-Corruption Layer** | Vertaalt en isoleert communicatie met een extern of legacy-systeem zodat het eigen domeinmodel zuiver blijft. | Lekkende abstracties van externe systemen die het eigen domeinmodel vervuilen. |
| 115 | **API Versioning** | Beheert meerdere versies van een API (URL, header, content negotiation) zodat bestaande clients niet breken. | Breaking changes in API's die alle consumers tegelijk dwingen tot aanpassing. |
| 116 | **HATEOAS** | API-responses bevatten hyperlinks naar gerelateerde acties en resources, zodat de client de API dynamisch kan navigeren. | Hardcoded URL's in clients die breken bij API-wijzigingen; gebrek aan discoverability. |

### 13. Testing Patterns (8 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 117 | **Arrange-Act-Assert (AAA)** | Structureert een test in drie fasen: setup, uitvoering en verificatie van het resultaat. | Ongestructureerde, moeilijk leesbare tests zonder duidelijke scheiding van stappen. |
| 118 | **Given-When-Then** | BDD-variant van AAA: gegeven een begintoestand, wanneer een actie plaatsvindt, dan is het verwachte resultaat. | Gebrek aan een gedeelde taal tussen business en developers voor het beschrijven van testscenario's. |
| 119 | **Mock Object** | Vervangt een echte afhankelijkheid door een nep-object met geprogrammeerd gedrag en verwachtingen. | Afhankelijkheid van externe systemen (DB, API) die tests traag, fragiel en niet-deterministisch maakt. |
| 120 | **Test Double** | Overkoepelende term voor alle testvervangers: dummy, stub, spy, mock, fake. | Behoefte aan verschillende niveaus van testvervanging afhankelijk van wat er geverifieerd moet worden. |
| 121 | **Fixture** | Een vaste, bekende dataset of objectconfiguratie die als startpunt voor tests dient. | Herhaalde, foutgevoelige testdata-setup die tests fragiel en moeilijk onderhoudbaar maakt. |
| 122 | **Page Object** | Encapsuleert de structuur en interactie van een webpagina in een klasse zodat E2E-tests leesbaar en onderhoudbaar blijven. | Fragiele E2E-tests die breken bij UI-wijzigingen door directe selector-referenties in testcode. |
| 123 | **Object Mother** | Een factory die vooraf geconfigureerde testobjecten levert voor veelgebruikte scenario's. | Herhaalde, verspreidde testdata-constructie die tot inconsistente en moeilijk onderhoudbare tests leidt. |
| 124 | **Builder (Test)** | Variant van het Builder-pattern specifiek voor het stapsgewijs opbouwen van complexe testobjecten met defaults. | Verbositeit bij het opzetten van testdata met veel optionele velden. |

### 14. Security Patterns (6 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 125 | **Null Object** | Biedt een object met neutraal gedrag (no-op) als alternatief voor null-checks. | NullPointerExceptions en defensieve null-checks verspreid door de codebase. |
| 126 | **Guard Clause** | Controleert precondities aan het begin van een methode en keert vroeg terug bij ongeldige input. | Diepe nesting van if-statements die de happy path onleesbaar maakt. |
| 127 | **Sanitization Pipeline** | Verwerkt input door een keten van sanitizers (trim, escape, validate) voordat het de domeinlogica bereikt. | Injection-aanvallen (XSS, SQL injection) door ongesanitiseerde user input. |
| 128 | **Input Validation Gateway** | Valideert alle inkomende data op één centraal punt voordat het de applicatie binnenkomt. | Verspreide, inconsistente validatielogica die security-gaten achterlaat. |
| 129 | **Secure Token** | Gebruikt cryptografisch ondertekende tokens (JWT, CSRF-tokens) voor authenticatie en autorisatie. | Session-hijacking en CSRF-aanvallen door gebrek aan verifieerbare, stateless credentials. |
| 130 | **Capability-Based Security** | Kent specifieke, minimale rechten (capabilities) toe aan code of gebruikers in plaats van brede rollen. | Over-geprivilegieerde toegang door grove role-based access control. |

### 15. Meta / Cross-Cutting Patterns (7 patterns)

| # | Pattern | Beschrijving | Kernprobleem |
|---|---------|-------------|---------------|
| 131 | **Dependency Injection (DI)** | Externe injectie van afhankelijkheden via constructor, setter of interface in plaats van interne creatie. | Harde koppeling aan concrete implementaties die testbaarheid en flexibiliteit belemmert. |
| 132 | **Inversion of Control (IoC)** | Het framework roept jouw code aan in plaats van andersom; de controleflow wordt omgedraaid. | Applicatiecode die verantwoordelijk is voor lifecycle-management en coördinatie die beter door een framework gedaan kan worden. |
| 133 | **Plugin** | Breidt een systeem uit door dynamisch geladen modules die een gedefinieerde interface implementeren. | Gesloten systemen die niet uitbreidbaar zijn zonder broncode te wijzigen. |
| 134 | **Module** | Organiseert code in zelfstandige eenheden met een expliciet publiek API en verborgen interne implementatie. | Namespace-conflicten, ongecontroleerde afhankelijkheden en gebrek aan encapsulatie op bestandsniveau. |
| 135 | **Interceptor** | Vangt methode-aanroepen of requests af en voert cross-cutting logica uit (logging, auth, caching) zonder de oorspronkelijke code te wijzigen. | Cross-cutting concerns die elke methode/handler vervuilen met herhaalde boilerplate. |
| 136 | **Middleware** | Verwerkt requests/responses in een chain van handlers waarbij elke handler kan transformeren, afwijzen of doorgeven. | Verstrengeling van request-verwerking (auth, logging, parsing) met business-logica in route-handlers. |
| 137 | **Decorator (Framework-level)** | Annoteert klassen of methoden met metadata (@decorator) die het framework gebruikt voor configuratie, routing, validatie, etc. | Expliciete configuratiecode die gescheiden leeft van de code die het configureert. |

---

## Overzicht per categorie

| # | Categorie | Aantal |
|---|-----------|--------|
| 1 | GoF Creational | 5 |
| 2 | GoF Structural | 7 |
| 3 | GoF Behavioral | 11 |
| 4 | SOLID Principles | 5 |
| 5 | Enterprise / Integration | 17 |
| 6 | Concurrency | 12 |
| 7 | Functional | 12 |
| 8 | Architecture | 13 |
| 9 | State Management | 7 |
| 10 | Data | 10 |
| 11 | UI / Frontend | 9 |
| 12 | API / Communication | 8 |
| 13 | Testing | 8 |
| 14 | Security | 6 |
| 15 | Meta / Cross-Cutting | 7 |
| | **Totaal** | **137** |

---

## Vervolgstappen (Fase 2-5)

1. **Fase 2 — Detectieregels**: Per pattern de code-signalen (imports, structuren, naming conventions) definiëren die op aanwezigheid of afwezigheid wijzen.
2. **Fase 3 — Rule-engine integratie**: Vertaling naar `.rule`-bestanden compatibel met cpm's pattern/absence/presence engines.
3. **Fase 4 — Scoring**: Gewicht per pattern toekennen aan de maturity-score op basis van impact en context.
4. **Fase 5 — Aanbevelingen**: Per ontbrekend pattern een actionable fix-beschrijving genereren.

---

## Bronnen

- Gamma, E. et al. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software* (GoF).
- Fowler, M. (2002). *Patterns of Enterprise Application Architecture* (PoEAA).
- Hohpe, G. & Woolf, B. (2003). *Enterprise Integration Patterns*.
- Vernon, V. (2013). *Implementing Domain-Driven Design*.
- Richards, M. (2015). *Software Architecture Patterns* (O'Reilly).
- Nygard, M. (2007). *Release It!* — stability patterns.
- Martin, R.C. (2017). *Clean Architecture*.
