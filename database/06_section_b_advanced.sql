-- FILE: database/06_section_b_advanced.sql
-- Section B: advanced questions (Q16 - Q27)

USE netflix_churn;
SET @as_of    = (SELECT as_of_date        FROM ref_dates);   -- 2026-06-30
SET @last_pay = (SELECT last_payment_date FROM ref_dates);   -- 2026-05-31

-- ---------------------------------------------------------------------------
-- VIEW: minutes watched per customer per month.
-- A month with no viewing shows 0 instead of having no row. Without these zero rows
-- LAG() would compare a month with a month from long ago.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_month_watch AS
WITH months AS (
    SELECT DISTINCT DATE_FORMAT(viewing_date, '%Y-%m-01') AS viewing_month
    FROM viewing_activity
),
viewers AS (
    SELECT DISTINCT customer_id FROM viewing_activity
),
monthly AS (
    SELECT customer_id,
           DATE_FORMAT(viewing_date, '%Y-%m-01') AS viewing_month,
           SUM(watch_duration_minutes)           AS watch_minutes,
           COUNT(*)                              AS sessions
    FROM viewing_activity
    GROUP BY customer_id, viewing_month
)
SELECT v.customer_id,
       m.viewing_month,
       COALESCE(mo.watch_minutes, 0) AS watch_minutes,
       COALESCE(mo.sessions, 0)      AS sessions
FROM viewers v
CROSS JOIN months m
LEFT JOIN monthly mo ON mo.customer_id = v.customer_id AND mo.viewing_month = m.viewing_month;

-- check: 7,980 customers x 12 months = 95,760 rows
SELECT COUNT(*) AS rows_in_view, MIN(viewing_month) AS first_month, MAX(viewing_month) AS last_month
FROM v_customer_month_watch;


-- ---------------------------------------------------------------------------
-- Q16. Rank plans by total revenue = monthly_price x number of ACTIVE subscriptions
-- ---------------------------------------------------------------------------
SELECT RANK() OVER (ORDER BY SUM(s.monthly_price) DESC) AS revenue_rank,
       p.plan_name,
       COUNT(*)                     AS active_subscriptions,
       ROUND(SUM(s.monthly_price), 2) AS monthly_recurring_revenue
FROM subscriptions s
JOIN subscription_plans p ON p.plan_id = s.plan_id
WHERE s.subscription_status = 'Active'
GROUP BY p.plan_id, p.plan_name
ORDER BY revenue_rank;


-- ---------------------------------------------------------------------------
-- Q17. Each customer's MOST RECENT support ticket (ROW_NUMBER = 1)
--      Tickets with an unknown date (NULL) sort last, so a dated ticket always wins.
-- ---------------------------------------------------------------------------
WITH ranked_tickets AS (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id
                              ORDER BY ticket_date DESC, ticket_id DESC) AS recency_rank
    FROM support_tickets t
)
SELECT customer_id, ticket_id, ticket_date, issue_category, issue_subcategory,
       priority, ticket_status, customer_satisfaction_score
FROM ranked_tickets
WHERE recency_rank = 1
ORDER BY customer_id;


-- ---------------------------------------------------------------------------
-- Q18. 3-month moving average of new registrations
--      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW = this month and the two before it.
--      The first two months only have 1 and 2 months of history, so read them with care.
-- ---------------------------------------------------------------------------
WITH monthly_signups AS (
    SELECT DATE_FORMAT(registration_date, '%Y-%m') AS signup_month,
           COUNT(*)                                AS new_customers
    FROM customers
    GROUP BY signup_month
)
SELECT signup_month,
       new_customers,
       ROUND(AVG(new_customers) OVER (ORDER BY signup_month
                                      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS moving_avg_3m
FROM monthly_signups
ORDER BY signup_month;


-- ---------------------------------------------------------------------------
-- Q19. Month-over-month decline flag with LAG()
--      Customers who watched LESS in the latest month than in the month before.
-- ---------------------------------------------------------------------------
WITH with_previous AS (
    SELECT customer_id, viewing_month, watch_minutes,
           LAG(watch_minutes, 1) OVER (PARTITION BY customer_id ORDER BY viewing_month) AS prev_month_minutes
    FROM v_customer_month_watch
)
SELECT customer_id,
       prev_month_minutes,
       watch_minutes                       AS latest_month_minutes,
       watch_minutes - prev_month_minutes  AS change_minutes
FROM with_previous
WHERE viewing_month = (SELECT MAX(viewing_month) FROM v_customer_month_watch)
  AND watch_minutes < prev_month_minutes
ORDER BY change_minutes
LIMIT 200;


-- ---------------------------------------------------------------------------
-- Q20. Cohort retention: for customers grouped by registration month, what % are still
--      active 1, 3 and 6 months later?
--      A customer is "active at month k" if they had not churned by registration + k months.
--      A cohort is only measured at k if that date is not after the as-of date.
--      NOTE: churn dates only exist from 2025-10 on, so older cohorts look close to 100%.
--      That is a property of this dataset, not an error in the query.
-- ---------------------------------------------------------------------------
WITH customer_checks AS (
    SELECT c.customer_id,
           DATE_FORMAT(c.registration_date, '%Y-%m') AS cohort_month,
           cl.churned,
           cl.churn_date,
           DATE_ADD(c.registration_date, INTERVAL 1 MONTH) AS date_m1,
           DATE_ADD(c.registration_date, INTERVAL 3 MONTH) AS date_m3,
           DATE_ADD(c.registration_date, INTERVAL 6 MONTH) AS date_m6
    FROM customers c
    JOIN churn_labels cl ON cl.customer_id = c.customer_id
)
SELECT cohort_month,
       COUNT(*) AS cohort_size,
       ROUND(100 * AVG(CASE WHEN date_m1 <= @as_of THEN (churn_date IS NULL OR churn_date > date_m1) END), 1) AS retained_1m_pct,
       ROUND(100 * AVG(CASE WHEN date_m3 <= @as_of THEN (churn_date IS NULL OR churn_date > date_m3) END), 1) AS retained_3m_pct,
       ROUND(100 * AVG(CASE WHEN date_m6 <= @as_of THEN (churn_date IS NULL OR churn_date > date_m6) END), 1) AS retained_6m_pct,
       ROUND(100 * AVG(1 - churned), 1) AS still_active_today_pct
FROM customer_checks
GROUP BY cohort_month
ORDER BY cohort_month;
-- >>> EXPORT this result: data/sql_exports/q20_cohort_retention.csv


-- ---------------------------------------------------------------------------
-- Q21. DENSE_RANK countries by churn rate, keep the top 5
-- ---------------------------------------------------------------------------
WITH country_churn AS (
    SELECT country,
           COUNT(*)                     AS customers,
           SUM(churned)                 AS churned_customers,
           ROUND(100 * AVG(churned), 2) AS churn_rate_pct
    FROM v_customer_current
    GROUP BY country
),
ranked AS (
    SELECT *, DENSE_RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rank
    FROM country_churn
)
SELECT churn_rank, country, customers, churned_customers, churn_rate_pct
FROM ranked
WHERE churn_rank <= 5
ORDER BY churn_rank, country;
-- >>> EXPORT this result: data/sql_exports/q21_top5_churn_countries.csv


-- ---------------------------------------------------------------------------
-- Q22. Running total of payments per customer (successful payments only)
--      Only the first 100 rows are shown; remove the LIMIT to see all of them.
-- ---------------------------------------------------------------------------
SELECT customer_id,
       payment_date,
       amount,
       SUM(amount) OVER (PARTITION BY customer_id
                         ORDER BY payment_date, payment_id) AS running_total
FROM payments
WHERE payment_status = 'Success'
ORDER BY customer_id, payment_date, payment_id
LIMIT 100;


-- ---------------------------------------------------------------------------
-- Q23. Watch time fell three months in a row (month N < month N-1 < month N-2), latest month = N
-- ---------------------------------------------------------------------------
WITH lagged AS (
    SELECT customer_id, viewing_month, watch_minutes,
           LAG(watch_minutes, 1) OVER (PARTITION BY customer_id ORDER BY viewing_month) AS minutes_1_month_ago,
           LAG(watch_minutes, 2) OVER (PARTITION BY customer_id ORDER BY viewing_month) AS minutes_2_months_ago
    FROM v_customer_month_watch
)
SELECT customer_id,
       minutes_2_months_ago,
       minutes_1_month_ago,
       watch_minutes AS latest_month_minutes
FROM lagged
WHERE viewing_month = (SELECT MAX(viewing_month) FROM v_customer_month_watch)
  AND watch_minutes < minutes_1_month_ago
  AND minutes_1_month_ago < minutes_2_months_ago
ORDER BY minutes_2_months_ago - watch_minutes DESC;


-- ---------------------------------------------------------------------------
-- Q24. Monthly churn rate for the last 12 months (churn is only recorded from 2025-10, so Jul-Sep 2025 show 0)
--      = customers who churned in month X / customers active at the START of month X
-- ---------------------------------------------------------------------------
WITH months AS (
    SELECT DISTINCT DATE_FORMAT(viewing_date, '%Y-%m-01') AS month_start
    FROM viewing_activity                      -- the 12 months of data we have
),
customer_state AS (
    SELECT c.customer_id, c.registration_date, cl.churn_date
    FROM customers c
    JOIN churn_labels cl ON cl.customer_id = c.customer_id
)
SELECT DATE_FORMAT(m.month_start, '%Y-%m') AS month,
       SUM(cs.registration_date < m.month_start
           AND (cs.churn_date IS NULL OR cs.churn_date >= m.month_start))        AS active_at_start,
       SUM(cs.churn_date >= m.month_start
           AND cs.churn_date <  DATE_ADD(m.month_start, INTERVAL 1 MONTH))      AS churned_in_month,
       ROUND(100 * SUM(cs.churn_date >= m.month_start
                       AND cs.churn_date < DATE_ADD(m.month_start, INTERVAL 1 MONTH))
                 / SUM(cs.registration_date < m.month_start
                       AND (cs.churn_date IS NULL OR cs.churn_date >= m.month_start)), 2) AS monthly_churn_rate_pct
FROM months m
CROSS JOIN customer_state cs
GROUP BY m.month_start
ORDER BY m.month_start;


-- ---------------------------------------------------------------------------
-- Q25. Retention by acquisition channel: % of each channel's customers still active today
-- ---------------------------------------------------------------------------
SELECT acquisition_channel,
       COUNT(*)                          AS customers,
       SUM(1 - churned)                  AS still_active,
       ROUND(100 * AVG(1 - churned), 2)  AS retention_rate_pct
FROM v_customer_current
GROUP BY acquisition_channel
ORDER BY retention_rate_pct DESC;


-- ---------------------------------------------------------------------------
-- Q26. Lifetime spend per customer (CTE) and spend quartiles with NTILE(4)
--      Data note: payments hold at most 15 monthly payments per customer, so spend is capped by that.
--      Ordered from highest to lowest spend, so quartile 1 = the top 25% of spenders.
-- ---------------------------------------------------------------------------
WITH lifetime_spend AS (
    SELECT customer_id, ROUND(SUM(amount), 2) AS total_spend
    FROM payments
    WHERE payment_status = 'Success'
    GROUP BY customer_id
),
quartiles AS (
    SELECT customer_id, total_spend,
           NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
    FROM lifetime_spend
)
SELECT spend_quartile,
       COUNT(*)                    AS customers,
       ROUND(MIN(total_spend), 2)  AS min_spend,
       ROUND(AVG(total_spend), 2)  AS avg_spend,
       ROUND(MAX(total_spend), 2)  AS max_spend
FROM quartiles
GROUP BY spend_quartile
ORDER BY spend_quartile;


-- ---------------------------------------------------------------------------
-- Q27. Top 3 issue subcategories by ticket volume, per country
-- ---------------------------------------------------------------------------
WITH ticket_counts AS (
    SELECT c.country, t.issue_subcategory, COUNT(*) AS tickets
    FROM support_tickets t
    JOIN customers c ON c.customer_id = t.customer_id
    GROUP BY c.country, t.issue_subcategory
),
ranked AS (
    SELECT country, issue_subcategory, tickets,
           ROW_NUMBER() OVER (PARTITION BY country
                              ORDER BY tickets DESC, issue_subcategory) AS rank_in_country
    FROM ticket_counts
)
SELECT country, rank_in_country, issue_subcategory, tickets
FROM ranked
WHERE rank_in_country <= 3
ORDER BY country, rank_in_country;