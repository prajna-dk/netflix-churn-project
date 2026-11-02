-- FILE: database/05_section_a_intermediate.sql
-- Section A: intermediate questions (Q1 - Q15)

USE netflix_churn;

-- "Today" for the whole project comes from the data (see Day 4), never from CURDATE()
SET @as_of    = (SELECT as_of_date        FROM ref_dates);   -- 2026-06-30
SET @last_pay = (SELECT last_payment_date FROM ref_dates);   -- 2026-05-31

-- ---------------------------------------------------------------------------
-- VIEW: one row per customer with their CURRENT plan and churn result
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_customer_current AS
SELECT c.customer_id,
       c.country,
       c.age,
       c.acquisition_channel,
       c.customer_segment,
       c.registration_date,
       s.subscription_id AS current_subscription_id,
       s.plan_id,
       p.plan_name,
       s.monthly_price,
       s.subscription_status,
       s.auto_renew,
       cl.churned,
       cl.churn_date,
       cl.churn_reason
FROM customers c
JOIN subscriptions      s  ON s.customer_id = c.customer_id AND s.subscription_end_date IS NULL
JOIN subscription_plans p  ON p.plan_id     = s.plan_id
JOIN churn_labels       cl ON cl.customer_id = c.customer_id;

-- check: must return 8000
SELECT COUNT(*) AS rows_in_view FROM v_customer_current;


-- ---------------------------------------------------------------------------
-- Q1. How many active customers does the platform have, by country?
-- ---------------------------------------------------------------------------
SELECT country,
       COUNT(*) AS active_customers
FROM v_customer_current
WHERE subscription_status = 'Active'
GROUP BY country
ORDER BY active_customers DESC;


-- ---------------------------------------------------------------------------
-- Q2. Total and average monthly revenue for each subscription plan
--     Step 1 (CTE): revenue of every plan in every month (successful payments only)
--     Step 2: total across all months, and the average month
-- ---------------------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT sp.plan_name,
           DATE_FORMAT(pay.payment_date, '%Y-%m') AS revenue_month,
           SUM(pay.amount)                        AS revenue
    FROM payments pay
    JOIN subscriptions      s  ON s.subscription_id = pay.subscription_id
    JOIN subscription_plans sp ON sp.plan_id        = s.plan_id
    WHERE pay.payment_status = 'Success'
    GROUP BY sp.plan_name, revenue_month
)
SELECT plan_name,
       ROUND(SUM(revenue), 2)  AS total_revenue,
       ROUND(AVG(revenue), 2)  AS avg_monthly_revenue,
       COUNT(*)                AS months_counted
FROM monthly_revenue
GROUP BY plan_name
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------------------
-- Q3. Overall churn rate (% of customers with churned = 1)
--     churned is 0/1, so its average IS the share of 1s.
-- ---------------------------------------------------------------------------
SELECT COUNT(*)                         AS customers,
       SUM(churned)                     AS churned_customers,
       ROUND(100 * AVG(churned), 2)     AS churn_rate_pct
FROM churn_labels;


-- ---------------------------------------------------------------------------
-- Q4. Which acquisition channel brought the most customers, and what is each channel's churn rate?
-- ---------------------------------------------------------------------------
SELECT c.acquisition_channel,
       COUNT(*)                       AS customers,
       SUM(cl.churned)                AS churned_customers,
       ROUND(100 * AVG(cl.churned), 2) AS churn_rate_pct
FROM customers c
JOIN churn_labels cl ON cl.customer_id = c.customer_id
GROUP BY c.acquisition_channel
ORDER BY customers DESC;
-- >>> EXPORT this result: data/sql_exports/q04_churn_by_channel.csv


-- ---------------------------------------------------------------------------
-- Q5. Average customer age by (current) subscription plan
-- ---------------------------------------------------------------------------
SELECT plan_name,
       ROUND(AVG(age), 1) AS avg_age,
       COUNT(*)           AS customers
FROM v_customer_current
GROUP BY plan_name
ORDER BY avg_age DESC;


-- ---------------------------------------------------------------------------
-- Q6. Top 10 most-watched titles by total minutes watched
-- ---------------------------------------------------------------------------
SELECT ct.title,
       ct.content_type,
       ct.genre,
       SUM(v.watch_duration_minutes) AS total_minutes_watched,
       COUNT(*)                      AS sessions
FROM viewing_activity v
JOIN content ct ON ct.content_id = v.content_id
GROUP BY ct.content_id, ct.title, ct.content_type, ct.genre
ORDER BY total_minutes_watched DESC
LIMIT 10;
-- >>> EXPORT this result: data/sql_exports/q06_top10_titles.csv


-- ---------------------------------------------------------------------------
-- Q7. Average completion percentage by content type and genre
--     AVG() ignores the NULL completion values we deliberately left blank.
-- ---------------------------------------------------------------------------
SELECT ct.content_type,
       ct.genre,
       ROUND(AVG(v.completion_percentage), 1) AS avg_completion_pct,
       COUNT(*)                               AS sessions
FROM viewing_activity v
JOIN content ct ON ct.content_id = v.content_id
GROUP BY ct.content_type, ct.genre
ORDER BY ct.content_type, avg_completion_pct DESC;


-- ---------------------------------------------------------------------------
-- Q8. Failed payments in each of the last 12 months
--     "Last 12 months" ends at the last payment date in the data (2026-05-31), not at today.
-- ---------------------------------------------------------------------------
SELECT DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
       COUNT(*)                           AS failed_payments
FROM payments
WHERE payment_status = 'Failed'
  AND payment_date >  DATE_SUB(@last_pay, INTERVAL 12 MONTH)
  AND payment_date <= @last_pay
GROUP BY payment_month
ORDER BY payment_month;


-- ---------------------------------------------------------------------------
-- Q9. Average resolution time (hours) by issue category
--     Pending/Escalated tickets have NULL resolution time and are ignored by AVG().
-- ---------------------------------------------------------------------------
SELECT issue_category,
       ROUND(AVG(resolution_time_hours), 1) AS avg_resolution_hours,
       COUNT(resolution_time_hours)         AS resolved_tickets
FROM support_tickets
GROUP BY issue_category
ORDER BY avg_resolution_hours DESC;


-- ---------------------------------------------------------------------------
-- Q10. Distribution of satisfaction scores across resolved / closed tickets
--      SUM(COUNT(*)) OVER () = the grand total, so every row can show its percentage.
-- ---------------------------------------------------------------------------
SELECT customer_satisfaction_score AS csat_score,
       COUNT(*)                                          AS tickets,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_of_tickets
FROM support_tickets
WHERE ticket_status IN ('Resolved', 'Closed')
GROUP BY customer_satisfaction_score
ORDER BY csat_score;


-- ---------------------------------------------------------------------------
-- Q11. Which device type generates the most viewing minutes?
-- ---------------------------------------------------------------------------
SELECT device_type,
       SUM(watch_duration_minutes) AS total_minutes,
       ROUND(100 * SUM(watch_duration_minutes) / SUM(SUM(watch_duration_minutes)) OVER (), 1) AS pct_of_all_minutes
FROM viewing_activity
GROUP BY device_type
ORDER BY total_minutes DESC;


-- ---------------------------------------------------------------------------
-- Q12. Average rating by sentiment label
--      If the labels were perfect, Negative would sit near 1-2 and Positive near 4-5.
--      The overlap shows the noise in the labels.
-- ---------------------------------------------------------------------------
SELECT sentiment_label,
       ROUND(AVG(rating), 2) AS avg_rating,
       MIN(rating)           AS lowest_rating,
       MAX(rating)           AS highest_rating,
       COUNT(*)              AS feedback_rows
FROM customer_feedback
GROUP BY sentiment_label
ORDER BY avg_rating DESC;


-- ---------------------------------------------------------------------------
-- Q13. Customers signed up through each acquisition channel in each calendar year
--      (one row per channel, one column per year)
-- ---------------------------------------------------------------------------
SELECT acquisition_channel,
       SUM(YEAR(registration_date) = 2019) AS y2019,
       SUM(YEAR(registration_date) = 2020) AS y2020,
       SUM(YEAR(registration_date) = 2021) AS y2021,
       SUM(YEAR(registration_date) = 2022) AS y2022,
       SUM(YEAR(registration_date) = 2023) AS y2023,
       SUM(YEAR(registration_date) = 2024) AS y2024,
       SUM(YEAR(registration_date) = 2025) AS y2025,
       SUM(YEAR(registration_date) = 2026) AS y2026,
       COUNT(*)                            AS total
FROM customers
GROUP BY acquisition_channel
ORDER BY total DESC;


-- ---------------------------------------------------------------------------
-- Q14. What percentage of customers have auto-renew turned off?
--      Shown for everyone and for customers who are still active.
-- ---------------------------------------------------------------------------
SELECT ROUND(100 * AVG(auto_renew = 0), 1)                                          AS pct_off_all_customers,
       ROUND(100 * AVG(CASE WHEN subscription_status = 'Active' THEN auto_renew = 0 END), 1) AS pct_off_active_customers
FROM v_customer_current;


-- ---------------------------------------------------------------------------
-- Q15. Customers with MORE THAN 3 support tickets, with their ticket count
--      WHERE filters rows before grouping. HAVING filters the groups after counting.
-- ---------------------------------------------------------------------------
SELECT customer_id,
       COUNT(*) AS ticket_count
FROM support_tickets
GROUP BY customer_id
HAVING COUNT(*) > 3
ORDER BY ticket_count DESC, customer_id;