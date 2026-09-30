# Configuration des rôles et personnalisation

## Accès

Le registre exige désormais une session Supabase avant d’afficher les incidents. La table `incidents` n’autorise que les utilisateurs authentifiés.

L’inscription libre est désactivée dans l’interface : seuls les comptes invités par l’administrateur doivent être utilisés.

### Inviter un utilisateur

Depuis Supabase : **Authentication → Users → Invite user**, saisir l’adresse email puis envoyer l’invitation. L’utilisateur ouvre le lien reçu, définit son mot de passe si nécessaire, puis revient sur le registre pour se connecter.

Dans **Authentication → Providers → Email**, désactiver **Allow new users to sign up** si l’option est disponible. Ne pas désactiver la confirmation email si vous voulez continuer à vérifier les adresses.

Dans **Authentication → URL Configuration**, définir :

```text
Site URL: https://laurent-blb.github.io/fai-registre-incidents-demo/
Redirect URL: https://laurent-blb.github.io/fai-registre-incidents-demo/
```

Cela évite les redirections vers `http://localhost:3000`. Si un email n’arrive pas, vérifier d’abord que l’adresse n’existe pas déjà, le dossier spam, puis **Authentication → Logs → Auth logs** et les limites d’envoi de l’offre Supabase.

## Rôles

La migration [`supabase/schema.sql`](./supabase/schema.sql) crée :

- `profiles.role = 'user'` par défaut ;
- `profiles.role = 'admin'` pour les administrateurs ;
- une fonction sécurisée `public.is_admin()` ;
- des politiques RLS : un utilisateur peut modifier ses propres tickets, un administrateur peut modifier tous les tickets et supprimer un ticket.

### Créer le premier administrateur

1. Créer un compte depuis l’écran de connexion du registre.
2. Dans Supabase, ouvrir **SQL Editor**.
3. Exécuter, en remplaçant l’adresse :

```sql
update public.profiles
set role = 'admin'
where id = (
  select id from auth.users
  where email = 'votre-email@example.com'
);
```

4. Se déconnecter puis se reconnecter pour afficher le rôle `Admin`.

Ne jamais attribuer le rôle admin depuis le navigateur. Le rôle doit être modifié par un administrateur du projet Supabase ou par une fonction backend protégée.

## Personnaliser les champs du formulaire

Les champs visibles sont définis dans [`index.html`](./index.html), dans le bloc `#incidentForm`.

Exemples :

- ajouter un champ texte :

```html
<label>Numéro de contrat<input id="fContrat" /></label>
```

- ajouter une liste :

```html
<label>Canal<select id="fCanal"><option>Agence</option><option>Téléphone</option></select></label>
```

Pour qu’un champ soit réellement enregistré, il faut aussi :

1. ajouter une colonne dans `supabase/schema.sql` ;
2. ajouter le champ dans `openDrawer()` ;
3. ajouter le champ dans l’objet `r` de `saveForm()` ;
4. ajouter le mapping dans `recordToDb()` et `dbToRecord()` ;
5. ajouter éventuellement la colonne à l’export CSV et au rapport PDF.

## Personnaliser le design

Les styles sont centralisés dans [`src/styles.css`](./src/styles.css).

Variables principales :

```css
:root {
  --ink: #102433;
  --cyan: #13b8c8;
  --coral: #d85b5b;
  --bg: #f3f8f9;
}
```

Pour changer rapidement la charte, modifier ces variables. Pour changer la largeur du formulaire, ajuster `.drawer`. Pour modifier l’écran de connexion, ajuster `.auth-gate` et `.auth-gate-card`.

## Ajouter un champ métier aux filtres et indicateurs

Les listes de valeurs sont en haut de `src/main.js` : `statuses`, `priorities`, `sources`, `categories`, `owners` et `escalations`. Les indicateurs sont calculés dans `metrics()` et les graphiques dans `renderAnalytics()`.
