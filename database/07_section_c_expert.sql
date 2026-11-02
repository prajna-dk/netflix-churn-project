-- FILE: database/07_section_c_expert.sql
-- Section C: expert questions (Q28 - Q37)

USE netflix_churn;
SET @as_of    = (SELECT as_of_date        FROM ref_dates);   -- 2026-06-30
SET @last_pay = (SELECT last_payment_date FROM ref_dates);   -- 2026-05-31

-- ---------------------------------------------------------------------------
-- VIEW 1: risk signals, one row per customer.
-- Each signal is built in its own CTE first, so the joins never multiply rows.
-- (A view cannot use @variables, so it reads the dates from ref_dates itself.)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_risk_signals AS
WITH ref AS (
    SELECT as_of_date AS as_of, last_payment_date AS last_pay FROM ref_dates
),
last_view AS (
    SELECT customer_id, MAX(viewing_date) AS last_view_date
    FROM viewing_activity
    GROUP BY customer_id
),
pay AS (
    SELECT p.customer_id,
           SUM(p.payment_date > DATE_SUB(r.last_pay, INTERVAL 12 MONTH))                              AS payments_12m,
           SUM(p.payment_status = 'Failed' AND p.payment_date > DATE_SUB(r.last_pay, INTERVAL 12 MONTH)) AS failed_12m,
           SUM(p.payment_status = 'Failed' AND p.payment_date > DATE_SUB(r.last_pay, INTERVAL 90 DAY))   AS failed_90d
    FROM payments p CROSS JOIN ref r
    GROUP BY p.customer_id
),
tk AS (
    SELECT customer_id, COUNT(*) AS ticket_count, AVG(customer_satisfaction_score) AS avg_csat
    FROM support_tickets
    GROUP BY customer_id
)
SELECT cur.customer_id,
       cur.country,
       cur.plan_name,
       cur.monthly_price,
       cur.subscription_status,
       cur.churned,
       cur.registration_date,
       DATEDIFF(r.as_of, cur.registration_date)                         AS tenure_days,
       COALESCE(DATEDIFF(r.as_of, lv.last_view_date), 365)              AS days_since_last_activity,
       COALESCE(pay.payments_12m, 0)                                    AS payments_12m,
       COALESCE(pay.failed_12m, 0)                                      AS failed_payments_12m,
       ROUND(COALESCE(pay.failed_12m / NULLIF(pay.payments_12m, 0), 0), 4) AS failed_payment_rate,
       COALESCE(pay.failed_90d, 0)                                      AS failed_payments_90d,
       COALESCE(tk.ticket_count, 0)                                     AS support_ticket_count,
       ROUND(tk.avg_csat, 2)                                            AS avg_csat
FROM v_customer_current cur
CROSS JOIN ref r
LEFT JOIN last_view lv ON lv.customer_id = cur.customer_id
LEFT JOIN pay          ON pay.customer_id = cur.customer_id
LEFT JOIN tk           ON tk.customer_id  = cur.customer_id;

-- ---------------------------------------------------------------------------
-- VIEW 2: composite risk score (0 to 1) and risk tier
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_risk_score AS
WITH scaled AS (
    SELECT s.*,
           (days_since_last_activity - MIN(days_since_last_activity) OVER ())
             / NULLIF(MAX(days_since_last_activity) OVER () - MIN(days_since_last_activity) OVER (), 0) AS recency_scaled,
           (failed_payment_rate - MIN(failed_payment_rate) OVER ())
             / NULLIF(MAX(failed_payment_rate) OVER () - MIN(failed_payment_rate) OVER (), 0)           AS payment_scaled,
           (support_ticket_count - MIN(support_ticket_count) OVER ())
             / NULLIF(MAX(support_ticket_count) OVER () - MIN(support_ticket_count) OVER (), 0)         AS ticket_scaled
    FROM v_customer_risk_signals s
),
scored AS (
    SELECT scaled.*,
           ROUND(0.5 * recency_scaled + 0.3 * payment_scaled + 0.2 * ticket_scaled, 4) AS risk_score
    FROM scaled
)
SELECT scored.*,
       PERCENT_RANK() OVER (PARTITION BY subscription_status ORDER BY risk_score) AS risk_pct_rank_in_status,
       CASE WHEN subscription_status = 'Active'
             AND PERCENT_RANK() OVER (PARTITION BY subscription_status ORDER BY risk_score) >= 0.80
            THEN 'High' ELSE 'Normal' END AS risk_tier
FROM scored;

-- check: 8000 rows, and how many active customers are 'High'
SELECT COUNT(*) AS customers, SUM(risk_tier = 'High') AS high_risk_active FROM v_customer_risk_score;


-- ---------------------------------------------------------------------------
-- Q28. Active customers with 2+ failed payments in the last 90 days AND a high churn risk tier
-- ---------------------------------------------------------------------------
SELECT customer_id,
       failed_payments_90d AS failed_payment_count,
       plan_name           AS current_plan,
       risk_score
FROM v_customer_risk_score
WHERE subscription_status = 'Active'
  AND failed_payments_90d >= 2
  AND risk_tier = 'High'
ORDER BY failed_payments_90d DESC, risk_score DESC;


-- ---------------------------------------------------------------------------
-- Q29. Engagement 30 days before vs 30 days after each customer's MOST RECENT price change.
--      A price change = the customer moved to a plan with a different monthly price.
--      Engagement = average watch minutes per session. Only customers with sessions in BOTH windows count.
-- ---------------------------------------------------------------------------
WITH segments AS (
    SELECT s.customer_id, s.subscription_start_date, s.plan_id, pl.monthly_price,
           LAG(s.plan_id)       OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS prev_plan,
           LAG(pl.monthly_price) OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS prev_price,
           ROW_NUMBER()         OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date DESC) AS newest_first
    FROM subscriptions s
    JOIN subscription_plans pl ON pl.plan_id = s.plan_id
),
price_changes AS (
    SELECT customer_id, subscription_start_date AS change_date, prev_plan, plan_id AS new_plan,
           prev_price, monthly_price AS new_price
    FROM segments
    WHERE newest_first = 1 AND prev_plan IS NOT NULL AND prev_price <> monthly_price
),
windows AS (
    SELECT pc.customer_id, pc.change_date, pc.prev_plan, pc.new_plan,
           AVG(CASE WHEN v.viewing_date >= DATE_SUB(pc.change_date, INTERVAL 30 DAY)
                     AND v.viewing_date <  pc.change_date
                    THEN v.watch_duration_minutes END) AS avg_minutes_before,
           AVG(CASE WHEN v.viewing_date >= pc.change_date
                     AND v.viewing_date <  DATE_ADD(pc.change_date, INTERVAL 30 DAY)
                    THEN v.watch_duration_minutes END) AS avg_minutes_after
    FROM price_changes pc
    JOIN viewing_activity v ON v.customer_id = pc.customer_id
    GROUP BY pc.customer_id, pc.change_date, pc.prev_plan, pc.new_plan
)
SELECT customer_id, change_date, prev_plan, new_plan,
       ROUND(avg_minutes_before, 1) AS avg_minutes_before,
       ROUND(avg_minutes_after, 1)  AS avg_minutes_after,
       ROUND(100 * (avg_minutes_after - avg_minutes_before) / avg_minutes_before, 1) AS pct_change
FROM windows
WHERE avg_minutes_before IS NOT NULL AND avg_minutes_after IS NOT NULL
ORDER BY pct_change;

-- Q29 summary: the average effect (how many customers qualified, and the overall % change)
WITH segments AS (
    SELECT s.customer_id, s.subscription_start_date, s.plan_id, pl.monthly_price,
           LAG(s.plan_id)       OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS prev_plan,
           LAG(pl.monthly_price) OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS prev_price,
           ROW_NUMBER()         OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date DESC) AS newest_first
    FROM subscriptions s
    JOIN subscription_plans pl ON pl.plan_id = s.plan_id
),
price_changes AS (
    SELECT customer_id, subscription_start_date AS change_date
    FROM segments
    WHERE newest_first = 1 AND prev_plan IS NOT NULL AND prev_price <> monthly_price
),
windows AS (
    SELECT pc.customer_id,
           AVG(CASE WHEN v.viewing_date >= DATE_SUB(pc.change_date, INTERVAL 30 DAY) AND v.viewing_date < pc.change_date
                    THEN v.watch_duration_minutes END) AS avg_before,
           AVG(CASE WHEN v.viewing_date >= pc.change_date AND v.viewing_date < DATE_ADD(pc.change_date, INTERVAL 30 DAY)
                    THEN v.watch_duration_minutes END) AS avg_after
    FROM price_changes pc
    JOIN viewing_activity v ON v.customer_id = pc.customer_id
    GROUP BY pc.customer_id, pc.change_date
)
SELECT (SELECT COUNT(*) FROM price_changes)                         AS customers_with_price_change,
       COUNT(*)                                                     AS customers_with_data_in_both_windows,
       ROUND(AVG(avg_before), 1)                                    AS avg_minutes_before,
       ROUND(AVG(avg_after), 1)                                     AS avg_minutes_after,
       ROUND(100 * (AVG(avg_after) - AVG(avg_before)) / AVG(avg_before), 1) AS overall_pct_change
FROM windows
WHERE avg_before IS NOT NULL AND avg_after IS NOT NULL;


-- ---------------------------------------------------------------------------
-- Q30. Country scorecard: customers, churned, churn rate, average lifetime value of churned
--      customers, and the single most common churn reason. Three CTEs, one result.
-- ---------------------------------------------------------------------------
WITH country_totals AS (
    SELECT country,
           COUNT(*)                     AS total_customers,
           SUM(churned)                 AS churned_customers,
           ROUND(100 * AVG(churned), 2) AS churn_rate_pct
    FROM v_customer_current
    GROUP BY country
),
churned_value AS (
    SELECT v.country,
           ROUND(AVG(sp.total_spend), 2) AS avg_lifetime_value_churned
    FROM v_customer_current v
    JOIN (SELECT customer_id, SUM(amount) AS total_spend
          FROM payments WHERE payment_status = 'Success' GROUP BY customer_id) sp
      ON sp.customer_id = v.customer_id
    WHERE v.churned = 1
    GROUP BY v.country
),
reason_counts AS (
    SELECT country, churn_reason, COUNT(*) AS customers
    FROM v_customer_current
    WHERE churned = 1
    GROUP BY country, churn_reason
),
top_reason AS (
    SELECT country, churn_reason, customers,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY customers DESC, churn_reason) AS reason_rank
    FROM reason_counts
)
SELECT t.country,
       t.total_customers,
       t.churned_customers,
       t.churn_rate_pct,
       cv.avg_lifetime_value_churned,
       tr.churn_reason AS top_churn_reason,
       tr.customers    AS customers_with_top_reason
FROM country_totals t
LEFT JOIN churned_value cv ON cv.country = t.country
LEFT JOIN top_reason    tr ON tr.country = t.country AND tr.reason_rank = 1
ORDER BY t.churn_rate_pct DESC;
-- >>> EXPORT: data/sql_exports/q30_country_churn_summary.csv


-- ---------------------------------------------------------------------------
-- Q31. At-risk revenue: for ACTIVE customers, risk_score x monthly_price. Top 50.
-- ---------------------------------------------------------------------------
SELECT RANK() OVER (ORDER BY risk_score * monthly_price DESC) AS at_risk_rank,
       customer_id,
       country,
       plan_name,
       monthly_price,
       days_since_last_activity,
       failed_payment_rate,
       support_ticket_count,
       risk_score,
       ROUND(risk_score * monthly_price, 2) AS at_risk_revenue
FROM v_customer_risk_score
WHERE subscription_status = 'Active'
ORDER BY at_risk_revenue DESC
LIMIT 50;
-- >>> EXPORT: data/sql_exports/q31_at_risk_revenue_top50.csv


-- ---------------------------------------------------------------------------
-- Q32. Top 5 complaints (issue_subcategory) per country in the most recent COMPLETED quarter,
--      with average resolution time and average satisfaction for that subcategory.
-- ---------------------------------------------------------------------------
WITH quarter_start_today AS (
    -- first day of the quarter that contains the as-of date
    SELECT as_of_date,
           DATE_ADD(MAKEDATE(YEAR(as_of_date), 1), INTERVAL (QUARTER(as_of_date) - 1) QUARTER) AS this_q_start
    FROM ref_dates
),
last_complete_quarter AS (
    -- if the current quarter has already ended on the as-of date, use it; otherwise use the one before
    SELECT CASE WHEN LAST_DAY(DATE_ADD(this_q_start, INTERVAL 2 MONTH)) <= as_of_date
                THEN this_q_start
                ELSE DATE_SUB(this_q_start, INTERVAL 1 QUARTER) END                   AS q_start,
           LAST_DAY(DATE_ADD(CASE WHEN LAST_DAY(DATE_ADD(this_q_start, INTERVAL 2 MONTH)) <= as_of_date
                                  THEN this_q_start
                                  ELSE DATE_SUB(this_q_start, INTERVAL 1 QUARTER) END, INTERVAL 2 MONTH)) AS q_end
    FROM quarter_start_today
),
complaints AS (
    SELECT c.country, t.issue_subcategory,
           COUNT(*)                                     AS tickets,
           ROUND(AVG(t.resolution_time_hours), 1)       AS avg_resolution_hours,
           ROUND(AVG(t.customer_satisfaction_score), 2) AS avg_csat
    FROM support_tickets t
    JOIN customers c ON c.customer_id = t.customer_id
    JOIN last_complete_quarter q ON t.ticket_date BETWEEN q.q_start AND q.q_end
    GROUP BY c.country, t.issue_subcategory
),
ranked AS (
    SELECT complaints.*,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY tickets DESC, issue_subcategory) AS complaint_rank
    FROM complaints
)
SELECT q.q_start AS quarter_start, q.q_end AS quarter_end,
       r.country, r.complaint_rank, r.issue_subcategory, r.tickets, r.avg_resolution_hours, r.avg_csat
FROM ranked r
CROSS JOIN last_complete_quarter q
WHERE r.complaint_rank <= 5
ORDER BY r.country, r.complaint_rank;


-- ---------------------------------------------------------------------------
-- Q33. Win-back candidates: CHURNED customers whose lifetime value BEFORE churning is in the
--      top quartile of churned customers. Show the churn reason and their last known engagement.
--      Engagement = minutes watched in the 90 days before the churn date:
--      0 = None, under 100 = Low, 100-299 = Medium, 300+ = High.
-- ---------------------------------------------------------------------------
WITH churned AS (
    SELECT customer_id, churn_date, churn_reason
    FROM churn_labels
    WHERE churned = 1
),
value_before_churn AS (
    SELECT ch.customer_id, ch.churn_date, ch.churn_reason,
           ROUND(COALESCE(SUM(p.amount), 0), 2) AS lifetime_value
    FROM churned ch
    LEFT JOIN payments p ON p.customer_id = ch.customer_id
                        AND p.payment_status = 'Success'
                        AND p.payment_date <= ch.churn_date
    GROUP BY ch.customer_id, ch.churn_date, ch.churn_reason
),
quartiled AS (
    SELECT value_before_churn.*,
           NTILE(4) OVER (ORDER BY lifetime_value DESC) AS value_quartile
    FROM value_before_churn
),
engagement AS (
    SELECT q.customer_id,
           COALESCE(SUM(v.watch_duration_minutes), 0) AS minutes_last_90d,
           MAX(v.viewing_date)                        AS last_view_date
    FROM quartiled q
    LEFT JOIN viewing_activity v ON v.customer_id = q.customer_id
                                AND v.viewing_date >  DATE_SUB(q.churn_date, INTERVAL 90 DAY)
                                AND v.viewing_date <= q.churn_date
    GROUP BY q.customer_id
)
SELECT q.customer_id, q.churn_date, q.churn_reason, q.lifetime_value,
       e.minutes_last_90d, e.last_view_date,
       CASE WHEN e.minutes_last_90d = 0   THEN 'None'
            WHEN e.minutes_last_90d < 100 THEN 'Low'
            WHEN e.minutes_last_90d < 300 THEN 'Medium'
            ELSE 'High' END AS last_engagement_level
FROM quartiled q
JOIN engagement e ON e.customer_id = q.customer_id
WHERE q.value_quartile = 1
ORDER BY q.lifetime_value DESC, q.customer_id;
-- >>> EXPORT: data/sql_exports/q33_winback_candidates.csv


-- ---------------------------------------------------------------------------
-- Q34. Plan migration: most common path (e.g. Basic -> Standard) and churn of upgraders vs downgraders.
--      Upgrade = the new plan costs more. LAG() gives the plan the customer had before.
-- ---------------------------------------------------------------------------
WITH moves AS (
    SELECT s.customer_id,
           LAG(s.plan_id)       OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS from_plan_id,
           LAG(pl.monthly_price) OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS from_price,
           s.plan_id AS to_plan_id,
           pl.monthly_price AS to_price
    FROM subscriptions s
    JOIN subscription_plans pl ON pl.plan_id = s.plan_id
),
paths AS (
    SELECT m.customer_id,
           pf.plan_name AS from_plan,
           pt.plan_name AS to_plan,
           CASE WHEN m.to_price > m.from_price THEN 'Upgrade'
                WHEN m.to_price < m.from_price THEN 'Downgrade'
                ELSE 'Same price' END AS direction,
           cl.churned
    FROM moves m
    JOIN subscription_plans pf ON pf.plan_id = m.from_plan_id
    JOIN subscription_plans pt ON pt.plan_id = m.to_plan_id
    JOIN churn_labels cl       ON cl.customer_id = m.customer_id
    WHERE m.from_plan_id IS NOT NULL
)
SELECT CONCAT(from_plan, ' -> ', to_plan) AS migration_path,
       direction,
       COUNT(*)                     AS customers,
       SUM(churned)                 AS churned_customers,
       ROUND(100 * AVG(churned), 1) AS churn_rate_pct
FROM paths
GROUP BY from_plan, to_plan, direction
ORDER BY customers DESC;
-- >>> EXPORT: data/sql_exports/q34_plan_migration.csv

-- Q34 summary: upgraders vs downgraders, and compared with customers who never changed plan
WITH counts AS (
    SELECT customer_id, COUNT(*) AS n FROM subscriptions GROUP BY customer_id
),
moves AS (
    SELECT s.customer_id,
           LAG(pl.monthly_price) OVER (PARTITION BY s.customer_id ORDER BY s.subscription_start_date) AS from_price,
           pl.monthly_price AS to_price
    FROM subscriptions s
    JOIN subscription_plans pl ON pl.plan_id = s.plan_id
),
direction AS (
    SELECT c.customer_id,
           CASE WHEN c.n = 1 THEN 'No plan change'
                WHEN m.to_price > m.from_price THEN 'Upgraded'
                WHEN m.to_price < m.from_price THEN 'Downgraded'
                ELSE 'Changed (same price)' END AS group_name
    FROM counts c
    JOIN moves m ON m.customer_id = c.customer_id AND (c.n = 1 OR m.from_price IS NOT NULL)
)
SELECT d.group_name,
       COUNT(*)                      AS customers,
       ROUND(100 * AVG(cl.churned), 1) AS churn_rate_pct
FROM direction d
JOIN churn_labels cl ON cl.customer_id = d.customer_id
GROUP BY d.group_name
ORDER BY churn_rate_pct DESC;


-- ---------------------------------------------------------------------------
-- Q35. WAU, MAU and stickiness (WAU / MAU) for the last 6 months.
--      MAU = distinct customers with a session in the month.
--      WAU = average number of distinct customers per week, using weeks (Mon-Sun) that START in
--      that month and are complete (the last partial week of the data is dropped).
-- ---------------------------------------------------------------------------
WITH weekly AS (
    SELECT DATE_SUB(viewing_date, INTERVAL WEEKDAY(viewing_date) DAY) AS week_start,
           COUNT(DISTINCT customer_id)                                AS active_users
    FROM viewing_activity
    GROUP BY week_start
),
monthly_wau AS (
    SELECT DATE_FORMAT(week_start, '%Y-%m') AS month,
           ROUND(AVG(active_users), 1)       AS avg_wau,
           COUNT(*)                          AS weeks_counted
    FROM weekly
    WHERE DATE_ADD(week_start, INTERVAL 6 DAY) <= @as_of
    GROUP BY month
),
monthly_mau AS (
    SELECT DATE_FORMAT(viewing_date, '%Y-%m') AS month,
           COUNT(DISTINCT customer_id)         AS mau
    FROM viewing_activity
    GROUP BY month
)
SELECT mm.month,
       mm.mau,
       mw.avg_wau,
       mw.weeks_counted,
       ROUND(mw.avg_wau / mm.mau, 3) AS stickiness_wau_over_mau
FROM monthly_mau mm
JOIN monthly_wau mw ON mw.month = mm.month
WHERE mm.month >= DATE_FORMAT(DATE_SUB(@as_of, INTERVAL 5 MONTH), '%Y-%m')
ORDER BY mm.month;
-- >>> EXPORT: data/sql_exports/q35_wau_mau.csv


-- ---------------------------------------------------------------------------
-- Q36. Proactive outreach list: ACTIVE customers with NEGATIVE feedback within 14 days (before or after)
--      of a failed payment or of a support ticket with satisfaction <= 2.
-- ---------------------------------------------------------------------------
WITH negative_feedback AS (
    SELECT customer_id, feedback_id, feedback_date, rating
    FROM customer_feedback
    WHERE sentiment_from_rating = 'Negative'
),
triggers AS (
    SELECT customer_id, payment_date AS trigger_date, 'Failed payment' AS trigger_type
    FROM payments
    WHERE payment_status = 'Failed'
    UNION ALL
    SELECT customer_id, ticket_date, 'Low-CSAT ticket'
    FROM support_tickets
    WHERE customer_satisfaction_score <= 2 AND ticket_date IS NOT NULL
),
matches AS (
    SELECT f.customer_id, f.feedback_id, f.feedback_date, f.rating, t.trigger_type, t.trigger_date
    FROM negative_feedback f
    JOIN triggers t ON t.customer_id = f.customer_id
                   AND ABS(DATEDIFF(f.feedback_date, t.trigger_date)) <= 14
)
SELECT cur.customer_id,
       cur.country,
       cur.plan_name,
       COUNT(DISTINCT m.feedback_id)                     AS negative_feedbacks_matched,
       GROUP_CONCAT(DISTINCT m.trigger_type ORDER BY m.trigger_type SEPARATOR ' + ') AS trigger_types,
       MAX(m.feedback_date)                              AS latest_negative_feedback
FROM matches m
JOIN v_customer_current cur ON cur.customer_id = m.customer_id
WHERE cur.subscription_status = 'Active'
GROUP BY cur.customer_id, cur.country, cur.plan_name
ORDER BY negative_feedbacks_matched DESC, latest_negative_feedback DESC;
-- >>> EXPORT: data/sql_exports/q36_outreach_list.csv


-- ---------------------------------------------------------------------------
-- Q37. Customer health score for ALL customers: 0 (healthy) to 100 (healthiest) and a risk score.
--      Five parts, each turned into a 0-1 RISK first (1 = worst), then weighted:
--        last viewing recency 30 | payment failure rate 25 | support satisfaction 20 | tenure 15 | plan 10
--      Customers with no tickets get the average satisfaction of everyone (no complaints, no penalty).
-- ---------------------------------------------------------------------------
WITH parts AS (
    SELECT s.customer_id, s.country, s.plan_name, s.subscription_status, s.churned,
           s.days_since_last_activity, s.failed_payment_rate, s.avg_csat, s.tenure_days,
           (s.days_since_last_activity - MIN(s.days_since_last_activity) OVER ())
             / NULLIF(MAX(s.days_since_last_activity) OVER () - MIN(s.days_since_last_activity) OVER (), 0) AS recency_risk,
           (s.failed_payment_rate - MIN(s.failed_payment_rate) OVER ())
             / NULLIF(MAX(s.failed_payment_rate) OVER () - MIN(s.failed_payment_rate) OVER (), 0)           AS payment_risk,
           (5 - COALESCE(s.avg_csat, AVG(s.avg_csat) OVER ())) / 4                                          AS csat_risk,
           1 - (s.tenure_days - MIN(s.tenure_days) OVER ())
                 / NULLIF(MAX(s.tenure_days) OVER () - MIN(s.tenure_days) OVER (), 0)                       AS tenure_risk,
           CASE s.plan_name WHEN 'Basic' THEN 1.0 WHEN 'Standard' THEN 0.5 ELSE 0.0 END                     AS plan_risk
    FROM v_customer_risk_signals s
),
scored AS (
    SELECT parts.*,
           ROUND(100 * (0.30 * recency_risk + 0.25 * payment_risk + 0.20 * csat_risk
                      + 0.15 * tenure_risk  + 0.10 * plan_risk), 1) AS risk_score_0_100
    FROM parts
)
SELECT RANK() OVER (ORDER BY risk_score_0_100 DESC) AS risk_rank,
       customer_id, country, plan_name, subscription_status, churned,
       days_since_last_activity, failed_payment_rate, avg_csat, tenure_days,
       risk_score_0_100,
       ROUND(100 - risk_score_0_100, 1) AS health_score_0_100
FROM scored
ORDER BY risk_rank, customer_id;
-- >>> EXPORT: data/sql_exports/q37_customer_health_score.csv