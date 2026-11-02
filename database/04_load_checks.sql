-- FILE: database/04_load_checks.sql
USE netflix_churn;

-- Check 1: row counts must match the Python clean files (expected numbers come from Day 3)
SELECT t.table_name, t.actual_rows, t.expected_rows,
       IF(t.actual_rows = t.expected_rows, 'OK', 'MISMATCH') AS status
FROM (
    SELECT 'customers'          AS table_name, COUNT(*) AS actual_rows, 8000   AS expected_rows FROM customers
    UNION ALL SELECT 'subscription_plans',  COUNT(*), 3      FROM subscription_plans
    UNION ALL SELECT 'subscriptions',       COUNT(*), 8875   FROM subscriptions
    UNION ALL SELECT 'content',             COUNT(*), 500    FROM content
    UNION ALL SELECT 'viewing_activity',    COUNT(*), 66422  FROM viewing_activity
    UNION ALL SELECT 'payments',            COUNT(*), 110735 FROM payments
    UNION ALL SELECT 'support_tickets',     COUNT(*), 6120   FROM support_tickets
    UNION ALL SELECT 'customer_feedback',   COUNT(*), 5046   FROM customer_feedback
    UNION ALL SELECT 'churn_labels',        COUNT(*), 8000   FROM churn_labels
) AS t;

-- Check 2: blanks became real NULLs (not empty text). Every count below should be 0.
SELECT 'empty text in churn_reason'        AS check_name, COUNT(*) AS bad_rows FROM churn_labels   WHERE churn_reason = ''
UNION ALL SELECT 'empty text in failed_payment_reason',    COUNT(*) FROM payments         WHERE failed_payment_reason = ''
UNION ALL SELECT 'empty text in cancellation_reason',      COUNT(*) FROM subscriptions    WHERE cancellation_reason = ''
UNION ALL SELECT 'successful payment with a failure reason', COUNT(*) FROM payments       WHERE payment_status = 'Success' AND failed_payment_reason IS NOT NULL
UNION ALL SELECT 'churned = 1 without a churn_date',       COUNT(*) FROM churn_labels     WHERE churned = 1 AND churn_date IS NULL
UNION ALL SELECT 'payments without subscription_id',       COUNT(*) FROM payments         WHERE subscription_id IS NULL;

-- Check 3: a quick business sanity check (should be about 24.9)
SELECT ROUND(100 * AVG(churned), 1) AS churn_rate_pct FROM churn_labels;

-- Check 4: foreign keys hold (turn them back on and test one relationship by hand)
SELECT COUNT(*) AS payments_without_customer
FROM payments p LEFT JOIN customers c ON c.customer_id = p.customer_id
WHERE c.customer_id IS NULL;