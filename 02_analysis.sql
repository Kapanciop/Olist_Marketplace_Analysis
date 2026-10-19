-- =====================================================================
-- BrightCart Marketplace (Olist data) - SQL Analysis Script
-- Database: SQLite (olist.db)
-- Business rules (see data_cleaning_log.md):
--   * "Real purchase" = order_status = 'delivered' with a delivery date
--   * Revenue = SUM(price) from order items (freight excluded)
--   * Customer = customer_unique_id (NOT customer_id)
--   * Late = delivered after estimated delivery date
-- HOW TO RUN: run STEP 0 once, then run each query by itself
-- (highlight it and press Ctrl+Shift+Enter in DB Browser) and
-- copy the result grid into your notes.
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 0: Reusable views (run all of these once)
-- ---------------------------------------------------------------------

DROP VIEW IF EXISTS v_delivered_orders;
CREATE VIEW v_delivered_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp       AS purchase_ts,
    o.order_delivered_customer_date  AS delivered_ts,
    o.order_estimated_delivery_date  AS estimated_ts,
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
         THEN 1 ELSE 0 END           AS is_late,
    julianday(o.order_delivered_customer_date)
      - julianday(o.order_purchase_timestamp) AS delivery_days
FROM olist_orders_dataset AS o
INNER JOIN olist_customers_dataset AS c
        ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

-- One row per order (prevents double counting when an order has several items)
DROP VIEW IF EXISTS v_order_revenue;
CREATE VIEW v_order_revenue AS
SELECT
    order_id,
    SUM(price)         AS revenue,
    SUM(freight_value) AS freight,
    COUNT(*)           AS items
FROM olist_order_items_dataset
GROUP BY order_id;

-- One row per order (some orders have more than one review)
DROP VIEW IF EXISTS v_order_reviews;
CREATE VIEW v_order_reviews AS
SELECT order_id, AVG(review_score) AS review_score
FROM olist_order_reviews_dataset
GROUP BY order_id;


-- ---------------------------------------------------------------------
-- Q0: Data quality checks (feed these into your cleaning log)
-- ---------------------------------------------------------------------

-- Date range of the data (confirms the growth window)
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM olist_orders_dataset;

-- Delivered orders with no delivery date (expected: 8)
SELECT COUNT(*) AS delivered_without_date
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Delivered orders with no items (revenue would be missing)
SELECT COUNT(*) AS delivered_orders_without_items
FROM v_delivered_orders AS d
LEFT JOIN v_order_revenue AS r ON r.order_id = d.order_id
WHERE r.order_id IS NULL;

-- Products with no category
SELECT COUNT(*) AS products_without_category
FROM olist_products_dataset
WHERE product_category_name IS NULL OR product_category_name = '';


-- ---------------------------------------------------------------------
-- Q1: Executive KPIs (delivered orders only)
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                   AS orders,
    COUNT(DISTINCT d.customer_unique_id)       AS unique_customers,
    ROUND(SUM(r.revenue), 2)                   AS total_revenue,
    ROUND(SUM(r.revenue) / COUNT(*), 2)        AS avg_order_value,
    ROUND(AVG(d.delivery_days), 1)             AS avg_delivery_days,
    ROUND(100.0 * AVG(d.is_late), 2)           AS late_delivery_rate_pct,
    ROUND(AVG(v.review_score), 2)              AS avg_review_score
FROM v_delivered_orders AS d
INNER JOIN v_order_revenue AS r ON r.order_id = d.order_id
LEFT JOIN  v_order_reviews AS v ON v.order_id = d.order_id;


-- ---------------------------------------------------------------------
-- Q2: Monthly revenue with month-over-month change (window function)
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT
        strftime('%Y-%m', d.purchase_ts) AS month,
        COUNT(*)                         AS orders,
        ROUND(SUM(r.revenue), 2)         AS revenue
    FROM v_delivered_orders AS d
    INNER JOIN v_order_revenue AS r ON r.order_id = d.order_id
    GROUP BY strftime('%Y-%m', d.purchase_ts)
)
SELECT
    month,
    orders,
    revenue,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1) AS mom_change_pct
FROM monthly
ORDER BY month;


-- ---------------------------------------------------------------------
-- Q3: Top 15 product categories by revenue (with share of total)
-- ---------------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english,
             p.product_category_name, 'Unknown')       AS category,
    COUNT(DISTINCT i.order_id)                         AS orders,
    ROUND(SUM(i.price), 2)                             AS revenue,
    ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 1) AS pct_of_revenue
FROM olist_order_items_dataset AS i
INNER JOIN v_delivered_orders AS d ON d.order_id = i.order_id
LEFT JOIN olist_products_dataset AS p ON p.product_id = i.product_id
LEFT JOIN product_category_name_translation AS t
       ON t.product_category_name = p.product_category_name
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown')
ORDER BY revenue DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- Q4: Revenue by state (volume, value, share)
-- ---------------------------------------------------------------------
SELECT
    d.customer_state                                   AS state,
    COUNT(*)                                           AS orders,
    ROUND(SUM(r.revenue), 2)                           AS revenue,
    ROUND(SUM(r.revenue) / COUNT(*), 2)                AS avg_order_value,
    ROUND(100.0 * SUM(r.revenue) / SUM(SUM(r.revenue)) OVER (), 1) AS pct_of_revenue
FROM v_delivered_orders AS d
INNER JOIN v_order_revenue AS r ON r.order_id = d.order_id
GROUP BY d.customer_state
ORDER BY revenue DESC;


-- ---------------------------------------------------------------------
-- Q5: Repeat purchase rate by state
-- (a person is assigned one state via MIN() in case they moved)
-- ---------------------------------------------------------------------
WITH per_person AS (
    SELECT
        customer_unique_id,
        MIN(customer_state) AS state,
        COUNT(*)            AS order_count
    FROM v_delivered_orders
    GROUP BY customer_unique_id
)
SELECT
    state,
    COUNT(*)                                              AS customers,
    SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)     AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                  AS repeat_rate_pct
FROM per_person
GROUP BY state
HAVING COUNT(*) >= 500          -- avoids noisy tiny states
ORDER BY repeat_rate_pct DESC;


-- ---------------------------------------------------------------------
-- Q6: Delivery performance and satisfaction by state
-- ---------------------------------------------------------------------
SELECT
    d.customer_state                         AS state,
    COUNT(*)                                 AS orders,
    ROUND(AVG(d.delivery_days), 1)           AS avg_delivery_days,
    ROUND(100.0 * AVG(d.is_late), 2)         AS late_rate_pct,
    ROUND(AVG(v.review_score), 2)            AS avg_review_score
FROM v_delivered_orders AS d
LEFT JOIN v_order_reviews AS v ON v.order_id = d.order_id
GROUP BY d.customer_state
HAVING COUNT(*) >= 500
ORDER BY late_rate_pct DESC;


-- ---------------------------------------------------------------------
-- Q7: Do late deliveries go with lower review scores?
-- ---------------------------------------------------------------------
SELECT
    CASE WHEN d.is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery_status,
    COUNT(*)                                               AS orders,
    ROUND(AVG(v.review_score), 2)                          AS avg_review_score,
    ROUND(100.0 * AVG(CASE WHEN v.review_score <= 2 THEN 1.0 ELSE 0 END), 1)
                                                           AS pct_low_reviews
FROM v_delivered_orders AS d
INNER JOIN v_order_reviews AS v ON v.order_id = d.order_id
GROUP BY d.is_late;


-- ---------------------------------------------------------------------
-- Q8: Is a late FIRST delivery associated with fewer repeat customers?
-- (association only, not proof of cause)
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT
        customer_unique_id,
        is_late,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY purchase_ts) AS rn,
        COUNT(*)     OVER (PARTITION BY customer_unique_id)                      AS total_orders
    FROM v_delivered_orders
)
SELECT
    CASE WHEN is_late = 1 THEN 'First order late' ELSE 'First order on time' END AS first_delivery,
    COUNT(*)                                             AS customers,
    SUM(CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END)   AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                 AS repeat_rate_pct
FROM ranked
WHERE rn = 1
GROUP BY is_late;


-- ---------------------------------------------------------------------
-- Q9: State revenue growth, Jan-Aug 2017 vs Jan-Aug 2018
-- (CHECK Q0 first: confirm 2018 data really runs through August)
-- ---------------------------------------------------------------------
WITH state_rev AS (
    SELECT
        d.customer_state AS state,
        SUM(CASE WHEN strftime('%Y', d.purchase_ts) = '2017' THEN r.revenue ELSE 0 END) AS rev_2017,
        SUM(CASE WHEN strftime('%Y', d.purchase_ts) = '2018' THEN r.revenue ELSE 0 END) AS rev_2018
    FROM v_delivered_orders AS d
    INNER JOIN v_order_revenue AS r ON r.order_id = d.order_id
    WHERE strftime('%m', d.purchase_ts) BETWEEN '01' AND '08'
    GROUP BY d.customer_state
)
SELECT
    state,
    ROUND(rev_2017, 2) AS rev_jan_aug_2017,
    ROUND(rev_2018, 2) AS rev_jan_aug_2018,
    ROUND(100.0 * (rev_2018 - rev_2017) / rev_2017, 1) AS growth_pct
FROM state_rev
WHERE rev_2017 > 10000          -- ignore tiny states where % swings are noise
ORDER BY growth_pct DESC;


-- ---------------------------------------------------------------------
-- Q10: Where to focus? Big states with weak delivery or satisfaction
-- ---------------------------------------------------------------------
SELECT
    d.customer_state                         AS state,
    COUNT(*)                                 AS orders,
    ROUND(SUM(r.revenue), 2)                 AS revenue,
    ROUND(100.0 * AVG(d.is_late), 2)         AS late_rate_pct,
    ROUND(AVG(v.review_score), 2)            AS avg_review_score
FROM v_delivered_orders AS d
INNER JOIN v_order_revenue AS r ON r.order_id = d.order_id
LEFT JOIN  v_order_reviews AS v ON v.order_id = d.order_id
GROUP BY d.customer_state
HAVING COUNT(*) >= 1000
ORDER BY late_rate_pct DESC;
