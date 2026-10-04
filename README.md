# FAI Registre Incidents

Registre d’incidents FAI avec tableau de bord, export CSV/PDF et stockage partagé Supabase.

## Fonctionnement

- **Authentification obligatoire** : les incidents et indicateurs ne sont visibles qu’après connexion.
- **Inscription contrôlée** : les nouveaux utilisateurs sont invités par l’administrateur depuis Supabase.
- **Rôles protégés** : les utilisateurs gèrent leurs propres tickets ; les administrateurs gèrent tous les tickets.
- **Stockage partagé** : les incidents sont enregistrés dans PostgreSQL via Supabase, et non plus uniquement dans le navigateur.
- **Mode de secours** : les données synthétiques restent visibles si la base n’est pas encore initialisée ou temporairement indisponible.

## Initialisation Supabase

1. Ouvrir le projet Supabase.
2. Aller dans **SQL Editor**.
3. Copier le contenu de [`supabase/schema.sql`](./supabase/schema.sql).
4. Exécuter le script. Cette version remplace les anciennes politiques de lecture publique.
5. Dans **Authentication → Providers → Email**, activer Email si nécessaire.
6. Dans **Authentication → URL Configuration**, ajouter :
   - `https://laurent-blb.github.io`
   - `https://laurent-blb.github.io/fai-registre-incidents-demo`

Pour inviter un utilisateur, utiliser **Authentication → Users → Invite user**. L’application ne propose plus d’inscription libre. Définir aussi l’URL du site sur `https://laurent-blb.github.io/fai-registre-incidents-demo/` afin que les confirmations email ne renvoient pas vers `localhost:3000`.

Le formulaire exige également le nom, le téléphone et l’email de la personne qui déclare l’incident. Réexécuter `supabase/schema.sql` après mise à jour pour ajouter les colonnes correspondantes.

Le rapport PDF contient désormais les KPI, des graphiques par statut, par priorité et par catégorie, puis le tableau détaillé des incidents et des informations du déclarant.

Les administrateurs disposent également d’une route `#sessions` pour consulter l’historique des ouvertures et fermetures de session. Réexécuter `supabase/schema.sql` pour créer `session_events` et ses politiques RLS.

Cette vue propose aussi un filtre par utilisateur et une période **Du / Au**. Pour tester, connectez-vous avec un utilisateur, déconnectez-vous, reconnectez-vous comme admin, puis ouvrez **Historique des sessions**. La requête SQL `select * from public.session_events order by occurred_at desc;` permet de vérifier directement les événements enregistrés.

Le Dashboard admin ajoute un graphique des connexions réussies par jour sur 14 jours et une alerte en cas d’ouvertures multiples pour le même compte en 15 minutes. Les échecs répétés sont signalés localement après trois tentatives ; une surveillance globale des échecs nécessite un Auth Hook ou une Edge Function Supabase.

## Architecture multi-vues

L’application utilise maintenant une coque persistante avec sidebar et barre d’en-tête. La zone centrale monte une seule vue à la fois avec les routes hash suivantes :

- `#dashboard` : [`src/views/dashboard.js`](./src/views/dashboard.js) ;
- `#incidents` : [`src/views/incidents.js`](./src/views/incidents.js) ;
- `#quality` : [`src/views/quality.js`](./src/views/quality.js).

Le routeur est géré dans `src/main.js`. Cliquer sur la sidebar remplace le contenu de `#pageContent` au lieu de faire défiler une longue page. Cette approche conserve l’URL, fonctionne sur GitHub Pages et permet d’ajouter d’autres vues indépendantes sans modifier la coque principale.

La clé `Publishable` est utilisée côté navigateur. Elle ne doit pas être confondue avec une clé `secret` ou `service_role`.

La procédure détaillée pour nommer un administrateur et personnaliser les champs se trouve dans [`CUSTOMIZATION.md`](./CUSTOMIZATION.md).

## Développement local

Le projet est une application statique sans étape de compilation. Il peut être servi avec n’importe quel serveur HTTP statique, par exemple :

```bash
python3 -m http.server 8000
```

Puis ouvrir `http://localhost:8000`.
