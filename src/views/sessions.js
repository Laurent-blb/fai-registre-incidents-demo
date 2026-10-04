export const sessionsView = () => `
  <section class="page-section view-page" aria-labelledby="sessions-title">
    <div class="section-heading"><div><p class="eyebrow">SÉCURITÉ</p><h2 id="sessions-title">Historique des sessions</h2><p class="muted">Consultez les ouvertures de session enregistrées pour tous les utilisateurs.</p></div></div>
    <div class="panel table-panel"><div class="table-scroll"><table><thead><tr><th>Date et heure</th><th>Utilisateur</th><th>Événement</th><th>Navigateur</th><th>Appareil</th></tr></thead><tbody id="sessionRows"><tr><td colspan="5" class="muted">Chargement de l’historique…</td></tr></tbody></table></div></div>
  </section>`;

export const sessionsMeta = { title: 'Historique des sessions', description: 'Surveillez les ouvertures et fermetures de session des utilisateurs.' };
