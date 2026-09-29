# FAI Registre Incidents — Version de démonstration synthétique

Cette version conserve la structure du registre original, mais toutes les données sont fictives : clients, codes, sites, équipements, adresses IP, incidents et commentaires.

## Contenu

- `registre_fai_demo_synthetique.xlsx` : classeur complet avec registre, tableau de bord, listes, paramètres SLA et guide de démarrage.
- `dist/` : interface web statique utilisable hors ligne ou sur un LAN.
- `audit_registre_fai.md` : rapport d’audit de la structure et des règles du registre.

## Utilisation LAN

```bash
cd dist
python3 -m http.server 8080 --bind 0.0.0.0
```

Puis ouvrir `http://ADRESSE_IP_DU_SERVEUR:8080` depuis un poste du réseau.

> Cette démonstration stocke les modifications dans le navigateur (`localStorage`). Elle ne constitue pas encore une base partagée entre techniciens.
