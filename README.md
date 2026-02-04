# Stage de recherches au LIST3N (UTT) en 2025
Les travaux menés ont porté sur l'étude du problème du TCVRP-softTW.
### Présentation du problème
Soit une entreprise qui livre quotidiennement des clients plus ou moins fidèles au moyen
d’une flotte homogène de véhicules de capacité adaptée et suffisante. Afin d’améliorer la qualité
du service proposé pour un horizon de temps de plusieurs jours, elle s’engage à servir un
maximum de clients à l’intérieur d’une fenêtre de temps les jours où ils demandent à être livré.
Pour ce faire, l’entreprise attribue, à chaque client, une fenêtre de temps dans la journée, sur
la base d’un historique des livraisons précédentes. Plus un client est fidèle, plus il doit être
prioritaire et plus sa fenêtre de temps doit être restreinte.

Si la livraison a lieu en dehors des fenêtres de temps, l’entreprise verse un dédommagement
financier qui est plus important pour les clients les plus fidèles. Dans le cas de cetaines sociétés
de sevice, seule la livraison en retard engendre des pénaliés et la livraison en avance entraîne
simplement des temps d’attente pour les conducteurs mais nous supposons ici que le retard et
l’avance sont pénalisées. Outre la garantie sur les délais de livraison, l’entreprise doit considérer
les coûts générés par l’usage des véhicules et les coûts occasionnés par la location de véhicules
externes supplémentaires durant les périodes de forte demande. Afin de tenir compte de la
charge de travail des conducteurs, une limite sur la durée des tournées est mise en place.  

Dans la situation décrite, le TCVRP-softTW permet à la fois de déterminer la position des
fenêtres de temps fixée pour tout l’horizon de temps et de planifier la tournée quotidienne de
chaque véhicule depuis le dépôt tout en limitant les coûts. La planification des tournées revient
à fixer quel véhicule livre quel client et à quelle heure à partir d’un calendrier de demande de
livraison qui couvre l’horizon de temps.

<!-- Une modélisation mathématique du TCVRP-softTW est présentée dans le fichier model.pdf et est implémentée dans la fonction tcvrp (fichier milp.jl).-->
### Approche de résolution
L’approche de résolution choisie s’appuie sur l’optimisation bi-niveaux. Celle-ci regroupe les problèmes mettant en jeu deux acteurs,
le leader et le suiveur, dont les décisions sont liées mais prises dans un ordre spécifique. Dans un second temps, le suiveur réagit en
privilégiant ses propres intérêts. Une fois cette réponse connue, le leader peut alors évaluer la
pertinence de sa stratégie initiale.

Dans le cas du TCVRP-softTW, le problème suiveur (TWPFP) permet
de connaître la position des fenêtres de temps des clients sur l’ensemble des jours considérés
tandis que le problème leader (VRP-softTW) vise à déterminer les tournées de véhicules
pour chaque jour en s’appyant sur la position préalablement calculée des fenêtres de temps.
La résolution du TWPFP nécessite d’avoir des tournées déjà connues, ce qui correspond à
l’historique des livraisons passées. Pour construire cet historique, des VRP sans contraintes de
fenêtres de temps sont résolus à partir d’un calendrier des demandes de livraison. A l’image des
TCVRP-softTW, le nombre de VRP à résoudre est égal au nombre de jours dans ce calendrier.
##### Résolution des VRP
Un algorithme glouton permet de résoudre les VRP dans la fonction greedy0 (fichier greedy.jl).
##### Résolution du TWPFP
Le TWPFP est un problème linéaire. Il est résolu dans la fonction twpfp (fichier milp.jl) via le solveur Gurobi directement exécuté à partir du modèle de ce problème.
##### Résolution des VRP-sofTW
Les VRP-softTW sont résolus grâce à un algorithme glouton. Au préalable, un algorithme de clustering hiérarchique agglomératif peut être lancé
afin de garantir une certaine homogénéité dans la répartition des clients sur les tournées. Les clients sont regroupés selon la distance euclidienne d’une part et la différence des centres des
fenêtres de temps pondérée par la fidélité des clients concernés d’autre part. Les fonctions mises en oeuvre sont les suivantes :
<ul>
    <li> greedy2 (fichier greedy.jl) pour glouton seul</li>
  <li> clusterClients2 (fichier structures.jl) + greedy3 (fichier greedy.jl) pour glouton avec clustering </li>
</ul>

### Expérimentations

Pour les expérimentations, la période considérée s'étend sur un mois (30 jours).
##### Génération d'instances

Placé dans la fonction generateOwnInst (fichier fonctions.jl), l'algorithme de génération d'instances se compose de trois étapes : attribution à cHaque client d'une classe et d'un nombre de demandes de livraison, affectation de chaque demande de livraison des clients sur un jour du mois puis procédure de réparation. L'attribution des classes de fidlité et du nombre de demandes de livraison s'effectue selon une loi uniforme tandis que l'affectation des clients sur les jours dépend d'une sorte de roulette biaisée ppar le nombre de demandes de livraisons de chaque client. Le nombre clients à livrer par jour est déterminé par une loi normale dont l'espérance évolue afin que le nombre de clients à livrer chaque jour reste homogène. La procédure de réparation permet de remédier au fait que certaines demandes de livraison peuvent ne pas avoir été prise en compte. Le nombre de demandes mensuelles de chaque client est alors diminué. Les clients peuvent même être changés de classe de fidélité si nécessaire. La limite de l'algorthme proposé est que, si aucune des demandes de livraison d'un client n'a été affceté à un jour,  changer ce client de classe n'est pas possible.
##### Visualisation des résultats

La fonction visualizeResults2 (fichier fonctions.jl) permet de produire, pour chaque jour du mois, un fichier texte et un fichier image. Dans le fichier texte, sont détaillées les tournées avec heure de départ, heure d'arrivée, heure de passage chez chaque client et coûts. Le fichier image contient 3 graphiques. Le premier donne un aperçu géographique des tournées. Le second permet d'appréhender les heures de passage par rapport aux fenêtres de temps des clients. Le troisième offre un moyen d'évaluer les pénalités de retard ou d'avance par client.
<!--
##### Tests pour les VRP-softTW

Les expérimentations rélisées en combinant clustering et algorithme glouton aboutissent à de bons résultats en termes de temps de calcul, en supposant que l'objectif souhaité est d'une seconde pour résoudre un VRP-softTW (soit 30 secondes pour tout le mois). Le tableau suivant rend compte de ces tests. Les temps y sont donnés arrondis à la seconde et égals à la moyenne de 10 exécutions successives.
<table>
    <tr><td><table><tr><th>Méthode &rarr;</th></tr><tr><th>Type d'instance &darr;</th></tr></table></td><td>glouton</td><td>clustering + glouton</td></tr>
    <tr><td>&asymp; 20 clients/jour</td><td> 5</td><td> 1 </td></tr>
    <tr><td>&asymp; 40 clients/jour </td><td> 24 </td><td>2</td></tr>
    <tr><td>&asymp; 60 clients/jour</td><td>56</td><td> 3</td></tr>
    <tr><td>&asymp; 80 clients/jour</td><td> 128</td><td> 6</td></tr>
</table>

Toutefois, avec la méthode de clustering, de nombreuses tournées sont créées, chacune ne servant que peu de clients. De ce fait, le coût total est plus élevé.

### Perspectives

L'étude offre une première appproche pour résoudre le TCVRP-softTW. A court terme, il faut avancer dans les recherches afin de disposer de résultats sur l'ensemble des étapes de l'approche. A plus long terme, il est envisagé de lancer plusieurs résolutions du TWPFP et des VRP-softTW en utilisant des méthodes d'apprentissage. 

Par ailleurs, des pistes d'exploration consisteraient à considérer une flotte interne ou des temps de service dans les travaux, ce qui permettrait d'être plus en adéquation avec la réalité des entreprises.
--!>
