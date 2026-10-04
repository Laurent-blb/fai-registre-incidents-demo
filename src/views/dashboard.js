export const dashboardView = () => `
  <section class="page-section view-page" aria-labelledby="dashboard-title">
    <div class="section-heading"><div><p class="eyebrow">SITUATION</p><h2 id="dashboard-title">Lecture opérationnelle</h2></div><span id="updatedAt" class="muted"></span></div>
    <div id="kpis" class="kpi-grid"></div>
    <div id="qualityBanner"></div>
    <div class="analytics-grid">
      <article class="panel chart-panel"><div class="panel-head"><div><h3>Répartition par statut</h3><p class="muted">État courant des incidents</p></div><span class="panel-mark cyan">●</span></div><div id="statusChart" class="bars"></div></article>
      <article class="panel chart-panel"><div class="panel-head"><div><h3>Priorités SLA</h3><p class="muted">Niveau d’urgence des tickets</p></div><span class="panel-mark coral">!</span></div><div id="priorityChart" class="bars"></div></article>
      <article class="panel attention-panel"><div class="panel-head"><div><h3>À surveiller</h3><p class="muted">Les actions qui méritent votre attention</p></div></div><div id="attentionList" class="attention-list"></div></article>
    </div>
    <div class="section-heading view-subheading"><div><p class="eyebrow">ANALYTIQUE</p><h2>Analyse opérationnelle</h2><p class="muted">Tendances, catégories dominantes et respect SLA par priorité.</p></div></div>
    <div class="analytics-deep-grid"><article class="panel chart-panel"><div class="panel-head"><div><h3>Tendance des ouvertures</h3><p class="muted">7 derniers jours de la base</p></div></div><div id="trendChart" class="bars"></div></article><article class="panel chart-panel"><div class="panel-head"><div><h3>Catégories dominantes</h3><p class="muted">Top catégories d’incident</p></div></div><div id="categoryChart" class="bars"></div></article><article class="panel chart-panel"><div class="panel-head"><div><h3>SLA par priorité</h3><p class="muted">Respecté vs hors SLA</p></div></div><div id="slaPriorityChart" class="bars"></div></article></div>
  </section>`;

export const dashboardMeta = { title: 'Vue d’ensemble', description: 'Pilotez les plaintes, les escalades et les engagements SLA.' };
