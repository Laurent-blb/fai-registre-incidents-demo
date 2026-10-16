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

## Administration, sécurité et audit

La migration complémentaire [`supabase/next-migration.sql`](./supabase/next-migration.sql) ajoute :

- les emails et statuts `active` / `suspended` aux profils ;
- la page admin `#users` pour modifier les rôles et statuts ;
- `security_events` pour les échecs d’authentification centralisés ;
- `incident_audit` et un trigger SQL qui conserve chaque création, modification et suppression ;
- la timeline visible dans chaque fiche incident.

Exécutez cette migration dans **Supabase → SQL Editor** après `schema.sql`. La fonction [`supabase/functions/auth-audit/index.ts`](./supabase/functions/auth-audit/index.ts) est l’endpoint serveur prévu pour recevoir les événements Auth. Déployez-la avec la Supabase CLI, définissez `AUTH_AUDIT_SECRET` et reliez-la à votre mécanisme de journaux/Auth Hook. Le secret ne doit jamais être placé dans le JavaScript du navigateur.

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

## Qualité, pièces jointes et alertes opérationnelles

La migration [`supabase/quality-dashboard-migration.sql`](./supabase/quality-dashboard-migration.sql) ajoute :

- `incident_attachments` et le bucket privé `incident-attachments` ;
- des politiques Storage réservant la lecture aux utilisateurs authentifiés ;
- `security_alerts` avec niveaux `information`, `attention` et `critical` ;
- les alertes automatiques pour incidents critiques non affectés et dépassements SLA ;
- région, première prise en charge et compteur de réouvertures sur les incidents.

Le Dashboard propose des filtres globaux par période, site/région, responsable, catégorie et client. Les KPI, graphiques et indicateurs de prise en charge/résolution sont recalculés selon ces filtres. Le bouton d’export des graphiques ouvre l’impression navigateur, ce qui permet une exportation PDF ou image via le dialogue d’impression.

Les rapports périodiques par email nécessitent une Edge Function planifiée et un fournisseur SMTP/email. La base est prête pour ces alertes, mais aucun email ne sera envoyé tant qu’un fournisseur et des destinataires n’auront pas été configurés.

## Premier administrateur et mot de passe

La migration `supabase/next-migration.sql` contient la fonction sécurisée `public.promote_user_to_admin(email)`. Elle ne crée pas directement un mot de passe dans SQL : les mots de passe ne doivent jamais être stockés en clair dans une migration.

Procédure :

1. Créer le compte dans **Supabase → Authentication → Users** avec l’email réel et un mot de passe temporaire.
2. Exécuter dans le SQL Editor :

```sql
select public.promote_user_to_admin('admin@votre-domaine.com');
```

3. Se connecter dans l’application.
4. Utiliser le bouton **Mot de passe** dans la barre supérieure.
5. Saisir l’ancien mot de passe, le nouveau et sa confirmation.

Le nouveau mot de passe doit contenir au moins 8 caractères. La modification utilise `supabase.auth.updateUser` après vérification de l’ancien mot de passe ; aucun mot de passe n’est enregistré dans `profiles` ou dans l’application.

## Diagnostic des vues administrateur

Les vues **Historique des sessions** et **Utilisateurs** disposent maintenant d’un délai maximal de 10 secondes. En cas de table absente, de politique RLS incorrecte ou de problème réseau, elles affichent l’erreur Supabase au lieu de rester bloquées sur « Chargement… ».

## Sessions persistantes et inactivité

La session Supabase est maintenant explicitement persistante dans `localStorage` et ses jetons sont renouvelés automatiquement. Une actualisation de la page ne doit donc plus demander une nouvelle connexion, tant que le stockage du navigateur n’est pas effacé et que la session n’a pas expiré côté Supabase.

Pour limiter les sessions oubliées, l’application déconnecte automatiquement l’utilisateur après **5 minutes sans activité**. Les clics, frappes clavier, mouvements de souris, défilements et interactions tactiles réinitialisent ce délai. Un avertissement est affiché 30 secondes avant la déconnexion.


## Correctif suppression admin

Si Supabase affiche une erreur `incident_audit_incident_id_fkey` ou `public.incident_attachments` introuvable, exécutez `supabase/incident-delete-fix.sql` dans le SQL Editor Supabase. Cette migration crée les pièces jointes, corrige l’audit des suppressions et active la fonction sécurisée `delete_incident_admin`.


## Colonnes avancées des incidents

Si Supabase affiche une colonne `reopened_count` absente du schema cache, exécutez `supabase/incident-columns-fix.sql` puis rechargez le schéma avec `notify pgrst, 'reload schema'`. La v2026.10.16.4 réessaie aussi l’enregistrement sans les colonnes avancées pour rester compatible temporairement.
