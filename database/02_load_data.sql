-- FILE: database/02_load_data.sql
-- Loads the 9 clean CSV files. Run 01_create_tables.sql first.
-- BEFORE RUNNING: replace {{DATA_FOLDER}} everywhere with the path of data/clean on YOUR computer,
-- ending with a slash, for example  G:/My Drive/netflix_churn_project/data/clean/

USE netflix_churn;
SET FOREIGN_KEY_CHECKS = 0;      -- the tables are loaded in a safe order; Check 4 in step 04 verifies the links afterwards

-- customers (state_or_region is blank in every row)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, first_name, last_name, age, gender, country, @state_or_region, city,
 registration_date, acquisition_channel, customer_segment, preferred_language)
SET state_or_region = NULLIF(@state_or_region, '');

-- subscription_plans
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/subscription_plans.csv'
INTO TABLE subscription_plans
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- subscriptions (end date, cancellation date and reason can be blank)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/subscriptions.csv'
INTO TABLE subscriptions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(subscription_id, customer_id, plan_id, subscription_start_date, @end_date, subscription_status,
 auto_renew, @cancel_date, @cancel_reason, monthly_price)
SET subscription_end_date = NULLIF(@end_date, ''),
    cancellation_date     = NULLIF(@cancel_date, ''),
    cancellation_reason   = NULLIF(@cancel_reason, '');

-- content
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/content.csv'
INTO TABLE content
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- viewing_activity (completion_percentage can be blank)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/viewing_activity.csv'
INTO TABLE viewing_activity
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(viewing_id, customer_id, content_id, viewing_date, watch_duration_minutes, @completion,
 device_type, login_location, session_duration_minutes)
SET completion_percentage = NULLIF(@completion, '');

-- payments (failed_payment_reason is blank for successful payments)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/payments.csv'
INTO TABLE payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(payment_id, customer_id, subscription_id, payment_date, amount, payment_method, payment_status,
 @fail_reason, amount_original, amount_flag)
SET failed_payment_reason = NULLIF(@fail_reason, '');

-- support_tickets (ticket_date, resolution time and CSAT can be blank)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/support_tickets.csv'
INTO TABLE support_tickets
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(ticket_id, customer_id, @ticket_date, issue_category, issue_subcategory, priority, ticket_status,
 @resolution, @csat, ticket_description, support_agent_id)
SET ticket_date                 = NULLIF(@ticket_date, ''),
    resolution_time_hours       = NULLIF(@resolution, ''),
    customer_satisfaction_score = NULLIF(@csat, '');

-- customer_feedback
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/customer_feedback.csv'
INTO TABLE customer_feedback
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- churn_labels (churn_date and churn_reason are blank for customers who stayed)
LOAD DATA LOCAL INFILE 'C:/Main/internmo/netflix_churn_project/data/clean/churn_labels.csv'
INTO TABLE churn_labels
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, churned, @churn_date, @churn_reason)
SET churn_date   = NULLIF(@churn_date, ''),
    churn_reason = NULLIF(@churn_reason, '');

SET FOREIGN_KEY_CHECKS = 1;
SELECT 'load finished' AS status;