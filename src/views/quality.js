export const qualityView = () => `
  <section class="page-section view-page" aria-labelledby="quality-title">
    <div class="section-heading"><div><p class="eyebrow">CONTRÔLE</p><h2 id="quality-title">Qualité des données</h2><p class="muted">Les alertes sont calculées à partir des règles métier du registre.</p></div></div>
    <div id="qualityCards" class="quality-grid"></div>
  </section>`;

export const qualityMeta = { title: 'Qualité des données', description: 'Contrôlez la cohérence, les SLA et les escalades.' };
