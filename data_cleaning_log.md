# Data Cleaning & Decision Log

**Project:** BrightCart Marketplace (Olist public dataset)
**Tools:** SQLite (DB Browser for SQLite), Power BI Desktop
**Principle:** Raw CSVs in `data/raw/` were never edited. All cleaning happens in SQL views, so every step is reproducible by re-running `02_analysis.sql`.

---

## 1. Data load

| Item | Detail |
|---|---|
| Source | Olist Brazilian E-Commerce Public Dataset (Kaggle), 9 CSV files |
| Import settings | Column names in first line, comma separator, double-quote character, UTF-8 |
| Verification | Row counts compared to expected; `SELECT * ... LIMIT` spot checks; date columns confirmed as text in `YYYY-MM-DD HH:MM:SS` format (works with SQLite date functions) |
| Orders loaded | 99,441 |

## 2. Issues found and decisions made

| # | Issue | Evidence | Decision | Why |
|---|---|---|---|---|
| 1 | **Two customer IDs.** `customer_id` is generated per order; `customer_unique_id` identifies the person | 99,441 distinct `customer_id` vs. 96,096 distinct `customer_unique_id` | Use `customer_unique_id` for every customer metric | Counting by `customer_id` would make nearly every customer look like a one-time buyer |
| 2 | **Missing delivery dates** | 2,965 orders have a NULL delivery date (true NULLs, 0 empty strings) | Treat as expected for undelivered orders; exclude from delivery metrics | See status breakdown below |
| 3 | **Orders marked "delivered" with no delivery date** | 8 orders | Excluded from the analysis base | Delivery time and late status can't be calculated; 8 of 96,478 is immaterial. Possible cause: a logging or tracking error (hypothesis, not confirmed) |
| 4 | **Which orders count as a real purchase?** | Status includes canceled, unavailable, shipped, etc. | **Real purchase = `order_status = 'delivered'` with a delivery date** | Canceled and unavailable orders are not completed sales. Strict rule chosen for consistency |
| 5 | **Orders with several items** | One row per item in `order_items` | Pre-aggregate revenue to one row per order (`v_order_revenue`) before joining | Prevents double counting and inflated order counts |
| 6 | **Orders with several reviews** | Some orders have more than one review row | Average the review score per order (`v_order_reviews`) | Keeps one row per order |
| 7 | **Delivered orders with no review** | 646 (about 0.7% of delivered orders) | Kept in revenue and delivery metrics; excluded from review-score metrics automatically | Absence of a review is not a score of zero |
| 8 | **Products with no category** | 610 products | Labeled `Unknown` via `COALESCE` after a LEFT JOIN to the translation table | Keeps their revenue in totals instead of silently dropping it |
| 9 | **Portuguese category names** | `product_category_name` | Joined `product_category_name_translation` for English names | Readability for business audience |
| 10 | **Sparse 2016 data** | 3 months with data, 267 delivered orders | Analysis window starts **Jan 2017** | Too thin for trend or growth comparisons |
| 11 | **Orders after Aug 2018** | 20 orders in Sep and Oct 2018: 19 canceled, 1 shipped, 0 delivered | Analysis window ends **Aug 2018** | No delivered-order data after August |
| 12 | **Geolocation table has many duplicate rows per zip prefix** | About 1M rows | Not used | State comes directly from the customers table, so joining would only multiply rows |
| 13 | **Currency and revenue definition** | Data is in Brazilian reais (BRL) | **Revenue = SUM(price)**; freight excluded and tracked separately | Freight is a pass-through cost, not product revenue |

### Status breakdown of the 2,965 orders with no delivery date

| Status | Orders |
|---|---|
| shipped | 1,107 |
| canceled | 619 |
| unavailable | 609 |
| invoiced | 314 |
| processing | 301 |
| delivered (no date) | 8 |
| created | 5 |
| approved | 2 |
| **Total** | **2,965** |

### Sensitivity check: does the "real purchase" definition change the repeat rate?

| Definition | Customers | Repeat customers | Repeat rate |
|---|---|---|---|
| All orders | 96,096 | 2,997 | 3.12% |
| Delivered only (used) | 93,358 | 2,801 | 3.00% |

Conclusion: the headline (roughly 3% of customers repeat) holds under both definitions.

## 3. Metric definitions used

| Metric | Definition |
|---|---|
| Late delivery | Delivered after `order_estimated_delivery_date` |
| Late Delivery Rate | Late delivered orders ÷ delivered orders |
| Repeat Purchase Rate | Unique customers with 2+ delivered orders ÷ unique customers |
| New Customers | Unique customers whose first delivered order falls in the month |
| Avg Order Value | Total revenue ÷ delivered orders |
| Growth | % change in revenue, Jan to Aug 2017 vs. Jan to Aug 2018 (same months, so the partial-year 2018 data is not penalized) |
| Small-state filter | States with fewer than 500 customers (or 1,000 orders in the focus query) are hidden from rate rankings because percentages are unstable on small counts |

## 4. Power BI preparation

- Exported two SQL views (`v_orders_fact`, `v_items_category`) as CSVs to `data/processed/`.
- Set data types in Power Query (dates, decimals, whole numbers) and filtered `purchase_date` to on or after 2017-01-01.
- Result in Power BI: 96,203 orders and R$13.18M revenue (the 267 orders from 2016 are excluded, which explains the small difference from the 96,470 / R$13.22M in SQL).
- Added a `Calendar` table (Jan 2017 to Aug 2018), marked as the date table.
- Relationships: `Calendar` → `orders_fact` (one-to-many); `orders_fact` → `items_category` (one-to-many).
- Fixed a bug where category revenue summed to R$15.97M instead of R$13.18M: it had been created as a calculated column, and was rebuilt as a measure.
- Validated dashboard cards against SQL results (orders, revenue, late rate, repeat rate all matched).

## 5. Known limitations

- No cost or profit data exists, so "performance" is measured with revenue, delivery, reviews, and retention, not margin.
- About two years of data, so the repeat rate is likely a floor (late-arriving customers had less time to return).
- Findings show association, not causation.
- Per-state repeat rates for smaller states rest on small counts.
