# Authentification et rôles — FAI Registre

## 1. Point essentiel sur la version actuelle

La version actuelle du registre est une interface statique. Elle ne doit pas gérer les mots de passe ou les rôles dans `localStorage` ou dans le JavaScript du navigateur : un utilisateur pourrait modifier le code et contourner toute règle affichée dans l’interface.

Nginx Basic Auth peut protéger l’accès au site, mais il ne sait pas appliquer proprement les droits Admin/Technicien dans l’application. Pour des rôles réels, il faut un backend qui vérifie les permissions sur chaque requête.

## 2. Modèle de droits recommandé

| Action | Admin | Technicien |
|---|---:|---:|
| Se connecter | Oui | Oui |
| Voir le dashboard | Oui | Oui |
| Voir les incidents | Tous | Tous ou incidents autorisés par périmètre |
| Créer un incident | Oui | Oui |
| Modifier un incident | Oui | Oui, si assigné ou autorisé |
| Changer le responsable | Oui | Non, ou demande d’escalade |
| Changer la priorité | Oui | Oui, avec journalisation |
| Clôturer un incident | Oui | Non, validation Admin/Superviseur recommandée |
| Générer un rapport PDF | Oui | Oui, périmètre autorisé |
| Exporter toutes les données | Oui | Non ou export limité |
| Créer / désactiver des comptes | Oui | Non |
| Modifier les rôles | Oui | Non |
| Consulter l’audit | Oui | Non |

Le contrôle doit exister côté API. Le frontend peut masquer un bouton, mais cette mesure est uniquement ergonomique.

## 3. Architecture locale

```text
Navigateur technicien
        |
        | HTTPS interne recommandé
        v
Nginx : certificat, réseau LAN, reverse proxy
        |
        v
Backend Flask/FastAPI : login, sessions, rôles, règles métier
        |
        v
SQLite ou PostgreSQL : utilisateurs, incidents, audit
```

Pour une petite équipe sur une seule machine, Flask + SQLite est un démarrage simple. Pour plusieurs écritures simultanées ou une équipe importante, PostgreSQL est préférable.

## 4. Tables minimales

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'technicien')),
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  last_login_at TEXT
);

CREATE TABLE incidents (
  id TEXT PRIMARY KEY,
  client TEXT NOT NULL,
  date_ouverture TEXT NOT NULL,
  priorite TEXT NOT NULL,
  statut TEXT NOT NULL,
  responsable_user_id INTEGER,
  payload_json TEXT NOT NULL,
  created_by INTEGER NOT NULL,
  updated_by INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (responsable_user_id) REFERENCES users(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  FOREIGN KEY (updated_by) REFERENCES users(id)
);

CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  incident_id TEXT,
  details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

Ne jamais stocker un mot de passe en clair. Seul `password_hash` doit être conservé.

## 5. Hachage des mots de passe

Utiliser Argon2id ou bcrypt. Exemple Python avec Werkzeug :

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install flask flask-login flask-sqlalchemy argon2-cffi
```

```python
from argon2 import PasswordHasher

ph = PasswordHasher()
password_hash = ph.hash(mot_de_passe)

# À la connexion
ph.verify(user.password_hash, mot_de_passe_saisi)
```

L’application doit imposer un mot de passe long, empêcher les comptes désactivés de se connecter et journaliser les échecs répétés.

## 6. Session de connexion

Après authentification réussie, créer une session serveur. Le cookie doit avoir les propriétés suivantes :

```text
HttpOnly = true
SameSite = Lax
Secure = true lorsque HTTPS est activé
Durée limitée, par exemple 8 heures
```

Ne pas mettre le rôle ou l’identité uniquement dans un objet JavaScript local. Le serveur doit relire la session à chaque requête protégée.

Exemple de logique :

```python
from functools import wraps
from flask import abort, session

def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if not session.get('user_id'):
            abort(401)
        return view(*args, **kwargs)
    return wrapped

def roles_required(*allowed_roles):
    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            if not session.get('user_id'):
                abort(401)
            if session.get('role') not in allowed_roles:
                abort(403)
            return view(*args, **kwargs)
        return wrapped
    return decorator
```

Exemples d’utilisation :

```python
@app.get('/api/incidents')
@login_required
def list_incidents():
    ...

@app.post('/api/incidents')
@roles_required('admin', 'technicien')
def create_incident():
    ...

@app.post('/api/incidents/<incident_id>/close')
@roles_required('admin')
def close_incident(incident_id):
    ...

@app.post('/api/users')
@roles_required('admin')
def create_user():
    ...
```

## 7. Flux de création des utilisateurs

1. L’Admin se connecte.
2. Il ouvre **Administration > Utilisateurs**.
3. Il crée un nom d’utilisateur unique.
4. Il choisit `Technicien` ou `Admin`.
5. Le backend génère le hash du mot de passe.
6. Le compte est créé actif ou désactivé.
7. L’action est inscrite dans `audit_log`.
8. En cas de départ d’un technicien, l’Admin désactive le compte plutôt que de le supprimer.

Pour une première installation, créer le premier Admin par une commande locale de bootstrap qui ne peut être exécutée qu’une fois :

```bash
python manage.py create-admin
```

Cette commande doit demander le mot de passe interactif et ne doit jamais recevoir le mot de passe dans l’historique shell.

## 8. Règles métier Technicien

Un Technicien peut créer un ticket et modifier les informations opérationnelles autorisées. Pour éviter les modifications non contrôlées, le backend peut limiter :

- la modification aux tickets qui lui sont assignés ;
- la clôture à l’Admin ;
- l’augmentation de priorité à une demande d’escalade ;
- l’export au périmètre de son équipe ;
- les champs sensibles comme responsable, SLA ou historique.

Chaque modification doit enregistrer l’ancienne et la nouvelle valeur dans l’audit.

## 9. Protection Nginx

Nginx ne remplace pas le backend, mais il protège le réseau et relaie l’application :

```nginx
server {
    listen 443 ssl;
    server_name registre.lan;

    ssl_certificate     /etc/ssl/local/registre.crt;
    ssl_certificate_key /etc/ssl/local/registre.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Le port 8000 du backend doit écouter uniquement sur `127.0.0.1`. Seul Nginx doit être accessible depuis le LAN.

Pare-feu exemple :

```bash
sudo ufw default deny incoming
sudo ufw allow from 192.168.1.0/24 to any port 443 proto tcp
sudo ufw enable
```

Adapter le sous-réseau à votre LAN réel.

## 10. Ce qui est possible immédiatement

Pour un test sans backend, utiliser Nginx Basic Auth avec un compte par technicien. Cela protège l’accès mais tous les utilisateurs ont les mêmes droits fonctionnels dans l’application.

Pour passer en production, la prochaine étape consiste à remplacer le chargement `src/data.json` et `localStorage` par des appels `/api/...`, puis à ajouter les écrans de connexion, d’administration des utilisateurs et d’audit.

## 11. Historique des sessions Supabase

Le registre ajoute une table `public.session_events`. Après exécution de `supabase/schema.sql`, une ouverture ou une fermeture de session est enregistrée avec l’utilisateur, la date, le navigateur et la plateforme.

La vue **Historique des sessions** est uniquement affichée aux profils dont `profiles.role = 'admin'`. La politique RLS autorise uniquement un administrateur à lire tous les événements ; un utilisateur connecté ne peut insérer qu’un événement associé à son propre identifiant.

Cette piste est un journal applicatif côté client. Pour une preuve d’audit réglementaire forte, il faut compléter ce mécanisme par les journaux Auth Supabase ou un service backend/Edge Function qui enregistre les événements côté serveur.
