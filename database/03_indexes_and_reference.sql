-- FILE: database/03_indexes_and_reference.sql
USE netflix_churn;

CREATE INDEX idx_subscriptions_customer ON subscriptions (customer_id);
CREATE INDEX idx_subscriptions_plan     ON subscriptions (plan_id);
CREATE INDEX idx_subscriptions_status   ON subscriptions (subscription_status);
CREATE INDEX idx_viewing_customer       ON viewing_activity (customer_id);
CREATE INDEX idx_viewing_content        ON viewing_activity (content_id);
CREATE INDEX idx_viewing_date           ON viewing_activity (viewing_date);
CREATE INDEX idx_payments_customer      ON payments (customer_id);
CREATE INDEX idx_payments_date          ON payments (payment_date);
CREATE INDEX idx_payments_status        ON payments (payment_status);
CREATE INDEX idx_tickets_customer       ON support_tickets (customer_id);
CREATE INDEX idx_tickets_category       ON support_tickets (issue_category);
CREATE INDEX idx_tickets_date           ON support_tickets (ticket_date);
CREATE INDEX idx_feedback_customer      ON customer_feedback (customer_id);
CREATE INDEX idx_feedback_sentiment     ON customer_feedback (sentiment_label);
CREATE INDEX idx_customers_country      ON customers (country);
CREATE INDEX idx_customers_segment      ON customers (customer_segment);

-- The project's "today". Taken from the data, NOT from CURDATE(), so results never change.
CREATE TABLE ref_dates AS
SELECT MAX(viewing_date)                         AS as_of_date,
       (SELECT MAX(payment_date) FROM payments)  AS last_payment_date
FROM viewing_activity;

SELECT * FROM ref_dates;