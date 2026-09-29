# Audit du registre d’incidents — version de démonstration synthétique

## Périmètre

Cette version conserve la structure fonctionnelle du registre FAI AllSolutions, mais toutes les valeurs sont fictives : clients, codes, sites, équipements, IP privées de démonstration, incidents et commentaires.

## Contenu généré

- 30 incidents synthétiques cohérents et reproductibles.
- 200 lignes disponibles dans la feuille `Registre_Incidents`.
- Tableau de bord avec KPI, répartitions par statut et priorité.
- Guide de démarrage, listes de validation et paramètres SLA.
- Interface web avec recherche, filtres, tri, ajout/édition, contrôles de cohérence et export CSV.

## Règles conservées

- SLA : Critique 4 h, Haute 8 h, Moyenne 24 h, Basse 72 h.
- Échéance calculée à partir de la date, de l’heure d’ouverture et du SLA.
- Durée calculée sur le timestamp complet.
- Validations Excel pour source, catégorie, priorité, responsable, statut et escalade.
- Mise en évidence des dépassements SLA et des priorités critiques.

## Garantie d’anonymisation

Les identifiants utilisent le préfixe `Inc-Demo`, les codes utilisent `DEMO-`, les clients portent le nom `Client Démo ...`, et les adresses IP utilisent le bloc privé de démonstration `10.99.0.0/16`.

> Ce paquet ne doit pas être utilisé comme registre de production. Il sert à tester l’interface, former les techniciens et valider le futur déploiement LAN.
