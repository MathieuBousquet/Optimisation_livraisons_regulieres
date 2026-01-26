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
  <li> clusterClients2 (fichier structures.jl) + greedy2 (fichier greedy.jl) pour glouton avec clustering </li>
  <li> greedy3 (fichier greedy.jl) pour glouton seul</li>
</ul>
