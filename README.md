# FAI Registre Incidents

Registre d’incidents FAI avec tableau de bord, export CSV/PDF et stockage partagé Supabase.

## Fonctionnement

- **Authentification obligatoire** : les incidents et indicateurs ne sont visibles qu’après connexion.
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

La clé `Publishable` est utilisée côté navigateur. Elle ne doit pas être confondue avec une clé `secret` ou `service_role`.

La procédure détaillée pour nommer un administrateur et personnaliser les champs se trouve dans [`CUSTOMIZATION.md`](./CUSTOMIZATION.md).

## Développement local

Le projet est une application statique sans étape de compilation. Il peut être servi avec n’importe quel serveur HTTP statique, par exemple :

```bash
python3 -m http.server 8000
```

Puis ouvrir `http://localhost:8000`.
