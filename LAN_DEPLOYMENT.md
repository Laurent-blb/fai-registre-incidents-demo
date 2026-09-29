# Déployer FAI Registre sur le LAN

## 1. Limite de la version statique actuelle

L’interface actuelle est un frontend statique. Elle peut être protégée par Nginx, mais elle ne fournit pas encore une authentification applicative avec comptes individuels, sessions serveur, rôles ou base centrale. Les modifications de la démo sont stockées dans le navigateur de chaque poste (`localStorage`).

Pour une vraie exploitation multi-techniciens, l’authentification et les rôles doivent être contrôlés côté serveur, jamais uniquement dans JavaScript.

## 2. Déploiement immédiat et protégé par mot de passe

Sur un serveur Ubuntu du LAN :

```bash
sudo apt update
sudo apt install -y nginx apache2-utils unzip
sudo mkdir -p /var/www/fai-registre
sudo cp -r interface/* /var/www/fai-registre/
sudo chown -R www-data:www-data /var/www/fai-registre
```

Créer un compte HTTP par technicien :

```bash
sudo htpasswd -c /etc/nginx/.htpasswd tech-1
sudo htpasswd /etc/nginx/.htpasswd tech-2
sudo htpasswd /etc/nginx/.htpasswd superviseur-1
```

Le premier appel utilise `-c`; ne pas le réutiliser, sinon le fichier est recréé.

Créer `/etc/nginx/sites-available/fai-registre` :

```nginx
server {
    listen 8080;
    listen [::]:8080;
    server_name _;

    root /var/www/fai-registre;
    index index.html;

    auth_basic "FAI Registre - Acces techniciens";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|json|png|svg|webmanifest)$ {
        add_header Cache-Control "no-cache";
        try_files $uri =404;
    }
}
```

Activer et tester :

```bash
sudo ln -s /etc/nginx/sites-available/fai-registre /etc/nginx/sites-enabled/fai-registre
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp
hostname -I
```

Les techniciens ouvrent ensuite : `http://IP_DU_SERVEUR:8080`.

Cette protection est adaptée à une démonstration ou à un premier test LAN. Elle ne donne pas encore de droits différents selon le rôle.

## 3. Gestion correcte des rôles

Pour un usage de production, ajouter un backend Flask/FastAPI et une base SQLite ou PostgreSQL. Le backend doit :

1. stocker les utilisateurs avec un mot de passe haché (`argon2id` ou `bcrypt`) ;
2. créer une session serveur avec cookie `HttpOnly`, `Secure` si HTTPS et `SameSite=Lax` ;
3. vérifier le rôle sur chaque endpoint ;
4. journaliser l’utilisateur, l’action, l’incident et l’heure ;
5. centraliser les incidents dans une base, au lieu de `localStorage`.

Rôles recommandés :

| Rôle | Consultation | Création | Modification | Clôture | Gestion utilisateurs | Export / rapports |
|---|---:|---:|---:|---:|---:|---:|
| Administrateur | Oui | Oui | Oui | Oui | Oui | Oui |
| Superviseur | Oui | Oui | Oui | Oui | Non | Oui |
| Technicien | Oui | Oui | Ses tickets / tickets assignés | Non ou avec validation | Non | Oui, périmètre autorisé |
| Lecture seule | Oui | Non | Non | Non | Non | Oui |

La règle de contrôle doit être appliquée dans l’API, par exemple : `require_role('superviseur', 'admin')` pour clôturer un incident. Masquer un bouton dans le frontend ne constitue pas une sécurité.

## 4. Architecture recommandée

```text
Postes techniciens
        |
        | HTTP LAN ou HTTPS interne
        v
Nginx : TLS, limitation réseau, reverse proxy
        |
        v
API Flask/FastAPI : sessions, rôles, validation métier
        |
        v
SQLite (petite équipe) ou PostgreSQL (équipe importante)
```

Pour une équipe réduite, SQLite peut convenir sur un serveur unique. Utiliser PostgreSQL si plusieurs écritures simultanées, historique important ou haute disponibilité sont nécessaires.

## 5. Sécurisation minimale

- donner au serveur une adresse IP fixe ou une réservation DHCP ;
- limiter le port au VLAN ou sous-réseau des techniciens ;
- ne pas exposer le port à Internet ;
- utiliser un VPN pour les techniciens hors site ;
- sauvegarder la base et les exports quotidiennement ;
- activer HTTPS interne dès que les identifiants ne sont plus uniquement de test ;
- prévoir une procédure de désactivation immédiate d’un compte ;
- ne jamais mettre de mots de passe dans le dépôt GitHub ou dans le frontend.

## 6. Rapports PDF et analytique

Le bouton `Rapport PDF` de l’interface génère une vue imprimable des incidents filtrés. Dans la boîte d’impression du navigateur, choisir **Enregistrer au format PDF**. Le rapport contient le logo AllSolutions, les KPI et le détail des incidents visibles selon les filtres courants.

Le dashboard analytique affiche les ouvertures des sept derniers jours, les catégories dominantes et le respect SLA par priorité.
