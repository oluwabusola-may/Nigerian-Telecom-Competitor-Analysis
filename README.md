[README (9).md](https://github.com/user-attachments/files/32795068/README.9.md)
# Nigerian Telecom Competitor Analysis

**Which operators are winning or losing market share, where, and what subscriber switching behavior reveals about why.**

An end-to-end analysis of real NCC (Nigerian Communications Commission) data, Q2 2024 – Q4 2025: data cleaning in Power Query, 14 business questions answered in MySQL, and a single-page Power BI dashboard.

![Dashboard](images/dashboard.png)
<img width="847" height="484" alt="Dashboard" src="https://github.com/user-attachments/assets/71161501-f089-4db0-b8ca-ea366060ce62" />

<!-- Add a screenshot of the finished dashboard at images/dashboard.png -->

---

## Business problem

A telecom strategy team needs to know where competitive pressure is building, and which operators and regions deserve a closer look. This project builds a competitive-monitoring view from public regulator data: market share by operator, subscriber switching (number porting) as a signal of customer defection, and state-level battlegrounds.

## Key findings

| # | Finding | Evidence |
|---|---|---|
| 1 | **MTN is the biggest and the biggest gainer.** | Voice share 49.01% → 52.08% (+3.07 pp) between Q2 2024 and Q4 2025. |
| 2 | **EMTS lost the most ground.** | Voice share 3.41% → 1.27% (-2.14 pp). AIRTEL slipped 1.01 pp; GLO was roughly flat (+0.15 pp). |
| 3 | **MTN wins most switchers.** | 59–71% of all port-ins each quarter went to MTN. |
| 4 | **EMTS has the worst cumulative porting outflow.** | Net porting of -17,611 across all quarters, against +12,802 (MTN), +4,219 (AIRTEL), +590 (GLO). |
| 5 | **EMTS's porting losses were followed by share declines in most quarters.** | Observed in 7 quarters of data; treat as an early-warning pattern, not proof of cause. |
| 6 | **Regional picture differs from the national one.** | Lagos is contested (MTN 45.99%); Borno is the one state AIRTEL leads (56.88%). GLO's national share is flat, yet it shows the largest YoY subscriber gains in Edo, Delta and FCT. |
| 7 | **Internet lags voice everywhere, and more so in some states.** | Internet subscriptions are 75–87% of voice subscriptions by state. Lowest: Benue (75.3%), Sokoto (75.3%), Niger (77.1%), Kogi (77.4%). |
| 8 | **South West is the most contested zone; North East the most concentrated.** | Herfindahl index 0.376 vs 0.459 (lower = more competitive). |

## Data

- **Source:** NCC quarterly telecom subscription and porting reports (`Telecoms_Q4_2025.xlsx`, 21 sheets across 7 quarters).
- **Coverage:** Q2 2024 – Q4 2025; MTN, AIRTEL, GLO, EMTS (9mobile) plus smaller operators; 36 states + FCT across 6 geopolitical zones.
- **Tables (MySQL):**

| Table | Grain | Key columns |
|---|---|---|
| `voice` | State × Operator × Quarter | `Year`, `Quarter`, `State`, `Zone`, `Operator`, `Service_type`, `Subscriptions` |
| `internet` | State × Operator × Quarter | same as `voice` |
| `porting` | Operator × Quarter (national only) | `Year`, `Quarter`, `Operator`, `Port_Type` (`PORT IN` / `PORT OUT`), `Count` |

## Process

1. **Cleaning (Power Query).** Work was split by table type across a team of four using a shared cleaning spec. Removed TOTAL and OTHERS rows (TOTAL values preserved separately for validation), standardized headers, and mapped all states and FCT to their six geopolitical zones.
2. **SQL analysis (MySQL).** 14 questions across four themes: competitive positioning, competitive pressure (porting), regional battlegrounds, and validation. Uses CTEs and window functions (`LAG`, `LEAD`, `SUM() OVER`). Full queries in [`/sql`](sql/).
3. **Dashboard (Power BI).** Single-page dashboard. Because the tables share a composite key (Operator + Year + Quarter), a concatenated `Key` column was added to each table and many-to-many relationships built in Model view.

## SQL business questions

**Validation** — 1. Do state-level sums reconcile with the published TOTAL rows?

**Competitive positioning** — 2. Market share by operator by quarter. 3. Biggest share gain, Q2 2024 → Q4 2025. 4. States where MTN dominates (>50%) vs contested (no operator >35%). 5. Operators stronger in internet than voice. 6. Most volatile quarter-over-quarter growth.

**Competitive pressure (porting)** — 7. Net porting flow per operator per quarter. 8. Worst cumulative net porting loss. 9. Do porting losses precede next-quarter share declines? 10. Share of all port-ins won by each operator.

**Competitive battlegrounds** — 11. Do national porting and share trends move together? 12. Fastest-gaining challenger states, YoY. 13. Most contested vs most concentrated zone (Herfindahl index). 14. Voice vs internet gap by state.

## Dashboard contents

- KPI cards: current voice market share by operator, and MTN's share of all port-ins
- Line chart: market share trend, Q2 2024 – Q4 2025
- Bar chart: share change by operator, Q2 2024 → Q4 2025
- Bar chart: cumulative net porting by operator
- Scatter: quarterly net porting flow vs next-quarter share change
- Matrix: operator share by state, heat-mapped

## Limitations

- **Porting data is national only.** There is no state or zone breakdown, so porting cannot be tied to regional share shifts. Question 11 is therefore a national comparison.
- **Correlation, not causation.** Porting losses preceding share declines is a useful early-warning signal, but this data cannot show why subscribers switch (pricing, network quality, promotions).
- **Short time series.** Seven quarters is enough to see direction, not to establish a stable pattern.
- **Small-base distortion.** Operators with tiny subscriber bases (NTEL, SMILE, BIG PICTURE) show extreme quarter-over-quarter volatility as a mathematical artifact. Volatility rankings should be read for the major operators only.
- **Internet gap is an observation.** Lower internet-to-voice ratios in Benue, Sokoto, Niger and Kogi may reflect infrastructure or affordability, but this data does not test that; treat it as a hypothesis to investigate.
- **Subscriptions are not unique users.** Multi-SIM ownership can inflate counts, and no population data was used, so "penetration" here means internet as a share of voice, not share of population.
- **No revenue data.** Findings identify where competitive pressure is; sizing it in naira would require ARPU or revenue inputs that NCC does not publish.

## Data notes

- `Port_Type` values are stored as `PORT IN` / `PORT OUT`; queries filtering on `Port-In` return zero.
- `CHANGE` is a reserved word in MySQL and cannot be used as a CTE name.

## Tools

MySQL Workbench · Power Query (M) · Power BI (DAX) · Excel

## Author

**Oluwabusola Oyenuga** — [GitHub](https://github.com/oluwabusola-may)

<!-- Add teammates' names/links here if crediting the team -->
