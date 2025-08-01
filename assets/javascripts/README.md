# Organização dos arquivos JS do plugin Foton Cash Flow

- `cash_flow_main.js`: JS principal para filtros e interações gerais (sem dependência de Bootstrap).
- `cash_flow_dashboard.js`: JS exclusivo para gráficos (Chart.js).
- Os arquivos `cash_flow.js` e `cash_flow_filters.js` são legados e podem ser removidos.

**Recomendação:**
Mantenha apenas `cash_flow_main.js` e `cash_flow_dashboard.js` para garantir organização e fácil manutenção.
