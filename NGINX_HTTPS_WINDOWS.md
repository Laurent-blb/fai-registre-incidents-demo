# Nginx + HTTPS sur Windows 11 — FAI Registre LAN

## 1. Architecture cible

```text
Postes techniciens
        |
        | https://registre.lan
        v
Serveur Windows 11
  Nginx :443
        |
        v
C:\fai-registre\dist\
```

Cette procédure protège l’accès au registre sur le réseau interne. Elle ne rend pas encore l’application multi-utilisateur : la version statique utilise toujours `localStorage`. Pour des rôles Admin/Technicien réels, il faudra ensuite ajouter un backend.

## 2. Choisir un nom réseau

Utiliser un nom interne stable, par exemple :

```text
registre.lan
```

Si votre réseau possède un DNS interne, créer une entrée A :

```text
registre.lan  ->  192.168.1.25
```

Sinon, ajouter la ligne suivante dans le fichier `C:\Windows\System32\drivers\etc\hosts` de chaque poste technicien, avec le Bloc-notes lancé en administrateur :

```text
192.168.1.25    registre.lan
```

Remplacer `192.168.1.25` par l’adresse IP fixe du serveur Windows.

Il est préférable de créer une réservation DHCP pour que l’adresse IP du serveur ne change pas.

## 3. Installer Nginx pour Windows

1. Télécharger l’archive officielle depuis [nginx.org/en/download.html](https://nginx.org/en/download.html).
2. Choisir la version Windows stable.
3. Décompresser dans :

```text
C:\nginx
```

Vérifier que le fichier existe :

```text
C:\nginx\nginx.exe
```

Copier l’interface dans :

```text
C:\fai-registre\dist
```

Le dossier doit contenir au minimum :

```text
index.html
allsolutions-logo.png
src\main.js
src\styles.css
src\data.json
```

## 4. Créer un certificat HTTPS interne avec mkcert

Pour un LAN, `mkcert` est pratique car il crée une autorité de certification locale et un certificat avec les bons noms DNS.

Dans PowerShell administrateur :

```powershell
winget install FiloSottile.mkcert
```

Créer le dossier des certificats :

```powershell
New-Item -ItemType Directory -Force C:\nginx\certs
```

Installer l’autorité locale sur le serveur :

```powershell
mkcert -install
```

Créer le certificat pour le nom DNS et l’adresse IP du serveur :

```powershell
mkcert `
  -cert-file C:\nginx\certs\registre.lan.pem `
  -key-file C:\nginx\certs\registre.lan-key.pem `
  registre.lan 192.168.1.25 localhost 127.0.0.1
```

Ne jamais communiquer le fichier suivant aux techniciens :

```text
C:\nginx\certs\registre.lan-key.pem
```

## 5. Faire reconnaître le certificat par les postes techniciens

Sur le serveur, afficher le chemin de l’autorité mkcert :

```powershell
mkcert -CAROOT
```

Le fichier à distribuer est généralement :

```text
rootCA.pem
```

### Réseau avec Active Directory

Distribuer le certificat racine par GPO dans :

```text
Computer Configuration
  > Policies
  > Windows Settings
  > Security Settings
  > Public Key Policies
  > Trusted Root Certification Authorities
```

### Petit réseau sans Active Directory

Sur chaque poste technicien :

1. Copier `rootCA.pem` sur le poste.
2. Renommer éventuellement le fichier en `FAI-LAN-RootCA.cer`.
3. Double-cliquer dessus.
4. Choisir **Installer le certificat**.
5. Sélectionner **Ordinateur local**.
6. Choisir **Placer tous les certificats dans le magasin suivant**.
7. Sélectionner **Autorités de certification racines de confiance**.
8. Valider l’installation.

Ne pas installer le certificat privé `registre.lan-key.pem` sur les postes.

## 6. Configurer Nginx

Créer ou remplacer :

```text
C:\nginx\conf\nginx.conf
```

Configuration pour servir l’interface statique :

```nginx
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name registre.lan 192.168.1.25;
        return 301 https://registre.lan$request_uri;
    }

    server {
        listen 443 ssl;
        server_name registre.lan;

        root C:/fai-registre/dist;
        index index.html;

        ssl_certificate     C:/nginx/certs/registre.lan.pem;
        ssl_certificate_key C:/nginx/certs/registre.lan-key.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_session_timeout 10m;
        ssl_session_cache shared:SSL:10m;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location ~* \.(js|css|json|png|svg|webmanifest)$ {
            add_header Cache-Control "no-cache";
            try_files $uri =404;
        }
    }
}
```

Tester la configuration depuis PowerShell :

```powershell
cd C:\nginx
.\nginx.exe -t
```

Démarrer Nginx :

```powershell
Start-Process .\nginx.exe
```

Recharger après une modification :

```powershell
.\nginx.exe -s reload
```

Arrêter Nginx :

```powershell
.\nginx.exe -s quit
```

Ouvrir dans le navigateur du serveur :

```text
https://registre.lan
```

## 7. Autoriser uniquement le LAN dans le pare-feu Windows

PowerShell administrateur :

```powershell
New-NetFirewallRule `
  -DisplayName "FAI Registre HTTPS LAN" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 443 `
  -Action Allow `
  -Profile Domain,Private `
  -RemoteAddress 192.168.1.0/24
```

Rediriger éventuellement HTTP uniquement pour le LAN :

```powershell
New-NetFirewallRule `
  -DisplayName "FAI Registre HTTP LAN" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 80 `
  -Action Allow `
  -Profile Domain,Private `
  -RemoteAddress 192.168.1.0/24
```

Adapter `192.168.1.0/24` à votre sous-réseau réel. Ne pas créer de règle autorisant Internet et ne pas effectuer de redirection de ports sur le routeur.

## 8. Ajouter une protection par mot de passe temporaire

HTTPS chiffre les échanges, mais ne vérifie pas l’identité. Pour une protection provisoire, Nginx peut utiliser `auth_basic`.

Il faut générer un fichier compatible htpasswd. Deux possibilités :

- installer Apache httpd uniquement pour récupérer `htpasswd.exe` ;
- utiliser un backend applicatif, solution préférable pour gérer les rôles.

Une fois `htpasswd.exe` disponible :

```powershell
New-Item -ItemType Directory -Force C:\nginx\auth
C:\Apache24\bin\htpasswd.exe -c C:\nginx\auth\.htpasswd admin
C:\Apache24\bin\htpasswd.exe C:\nginx\auth\.htpasswd technicien1
```

Ajouter dans le bloc `server` HTTPS :

```nginx
auth_basic "FAI Registre";
auth_basic_user_file C:/nginx/auth/.htpasswd;
```

Puis :

```powershell
cd C:\nginx
.\nginx.exe -t
.\nginx.exe -s reload
```

Cette méthode protège le site, mais elle ne fournit pas de vrais rôles applicatifs. `admin` et `technicien1` auront encore les mêmes droits dans l’interface statique.

## 9. Démarrage automatique de Nginx

Nginx Windows ne devient pas automatiquement un service Windows. Pour un premier déploiement, utiliser le Planificateur de tâches :

1. Ouvrir **Planificateur de tâches**.
2. Choisir **Créer une tâche**.
3. Nom : `FAI Registre Nginx`.
4. Cocher **Exécuter même si l’utilisateur n’est pas connecté**.
5. Cocher **Exécuter avec les autorisations maximales**.
6. Déclencheur : **Au démarrage**.
7. Action : démarrer un programme.
8. Programme : `C:\nginx\nginx.exe`.
9. Répertoire de démarrage : `C:\nginx`.

Tester après redémarrage :

```powershell
Get-Process nginx
Test-NetConnection registre.lan -Port 443
```

## 10. Vérification depuis un poste technicien

Depuis chaque poste :

```powershell
Resolve-DnsName registre.lan
Test-NetConnection registre.lan -Port 443
```

Puis ouvrir :

```text
https://registre.lan
```

Vérifier :

- absence d’alerte certificat ;
- redirection HTTP vers HTTPS ;
- affichage du logo AllSolutions ;
- chargement du dashboard ;
- chargement des données synthétiques ;
- fonctionnement du rapport PDF.

## 11. Passage ultérieur à l’authentification Admin/Technicien

Lorsque le backend sera ajouté, conserver Nginx pour HTTPS et remplacer `auth_basic` par un reverse proxy vers Flask/FastAPI :

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
}
```

Le backend gérera alors les comptes, sessions, rôles, incidents centralisés et journal d’audit. Nginx restera responsable du certificat HTTPS, du filtrage réseau et de la terminaison TLS.
