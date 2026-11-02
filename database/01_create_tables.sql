-- FILE: database/01_create_tables.sql
-- Creates the netflix_churn database and its 9 tables.
-- Safe to re-run: it drops the old tables first.

CREATE DATABASE IF NOT EXISTS netflix_churn CHARACTER SET utf8mb4;
USE netflix_churn;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS churn_labels, customer_feedback, support_tickets, payments,
                     viewing_activity, content, subscriptions, subscription_plans, customers;
DROP TABLE IF EXISTS ref_dates;
SET FOREIGN_KEY_CHECKS = 1;

-- 1) customers: the hub table, every other table points to it
CREATE TABLE customers (
    customer_id          VARCHAR(12) NOT NULL,
    first_name           VARCHAR(50),
    last_name            VARCHAR(50),
    age                  SMALLINT,
    gender               VARCHAR(25),
    country              VARCHAR(60),
    state_or_region      VARCHAR(60),
    city                 VARCHAR(60),
    registration_date    DATE,
    acquisition_channel  VARCHAR(50),
    customer_segment     VARCHAR(30),
    preferred_language   VARCHAR(30),
    PRIMARY KEY (customer_id)
);

-- 2) subscription_plans
CREATE TABLE subscription_plans (
    plan_id         VARCHAR(10)   NOT NULL,
    plan_name       VARCHAR(30)   NOT NULL,
    monthly_price   DECIMAL(6,2)  NOT NULL,
    video_quality   VARCHAR(30),
    max_devices     SMALLINT,
    advertisements  VARCHAR(5),
    PRIMARY KEY (plan_id)
);

-- 3) subscriptions: one row per plan segment (a plan change creates a second row)
CREATE TABLE subscriptions (
    subscription_id          VARCHAR(12) NOT NULL,
    customer_id              VARCHAR(12) NOT NULL,
    plan_id                  VARCHAR(10) NOT NULL,
    subscription_start_date  DATE NOT NULL,
    subscription_end_date    DATE,
    subscription_status      VARCHAR(20),
    auto_renew               TINYINT(1),
    cancellation_date        DATE,
    cancellation_reason      VARCHAR(80),
    monthly_price            DECIMAL(6,2),
    PRIMARY KEY (subscription_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    FOREIGN KEY (plan_id)     REFERENCES subscription_plans (plan_id)
);

-- 4) content
CREATE TABLE content (
    content_id          VARCHAR(10)  NOT NULL,
    title               VARCHAR(150) NOT NULL,
    content_type        VARCHAR(30),
    genre               VARCHAR(30),
    release_year        SMALLINT,
    duration_minutes    SMALLINT,
    content_language    VARCHAR(30),
    production_country  VARCHAR(60),
    maturity_rating     VARCHAR(10),
    PRIMARY KEY (content_id)
);

-- 5) viewing_activity: the largest engagement table
CREATE TABLE viewing_activity (
    viewing_id                VARCHAR(14) NOT NULL,
    customer_id               VARCHAR(12) NOT NULL,
    content_id                VARCHAR(10) NOT NULL,
    viewing_date              DATE NOT NULL,
    watch_duration_minutes    SMALLINT,
    completion_percentage     DECIMAL(5,2),
    device_type               VARCHAR(30),
    login_location            VARCHAR(60),
    session_duration_minutes  SMALLINT,
    PRIMARY KEY (viewing_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    FOREIGN KEY (content_id)  REFERENCES content (content_id)
);

-- 6) payments (amount = corrected amount, amount_original = what the source file said)
CREATE TABLE payments (
    payment_id             VARCHAR(14) NOT NULL,
    customer_id            VARCHAR(12) NOT NULL,
    subscription_id        VARCHAR(12),
    payment_date           DATE NOT NULL,
    amount                 DECIMAL(7,2),
    payment_method         VARCHAR(30),
    payment_status         VARCHAR(15),
    failed_payment_reason  VARCHAR(60),
    amount_original        DECIMAL(7,2),
    amount_flag            VARCHAR(20),
    PRIMARY KEY (payment_id),
    FOREIGN KEY (customer_id)     REFERENCES customers (customer_id),
    FOREIGN KEY (subscription_id) REFERENCES subscriptions (subscription_id)
);

-- 7) support_tickets
CREATE TABLE support_tickets (
    ticket_id                    VARCHAR(12) NOT NULL,
    customer_id                  VARCHAR(12) NOT NULL,
    ticket_date                  DATE,
    issue_category               VARCHAR(40),
    issue_subcategory            VARCHAR(60),
    priority                     VARCHAR(15),
    ticket_status                VARCHAR(15),
    resolution_time_hours        DECIMAL(6,1),
    customer_satisfaction_score  SMALLINT,
    ticket_description           TEXT,
    support_agent_id             VARCHAR(10),
    PRIMARY KEY (ticket_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

-- 8) customer_feedback (sentiment_from_rating is our own check against the noisy label)
CREATE TABLE customer_feedback (
    feedback_id            VARCHAR(12) NOT NULL,
    customer_id            VARCHAR(12) NOT NULL,
    feedback_date          DATE,
    rating                 SMALLINT,
    feedback_text          TEXT,
    sentiment_label        VARCHAR(15),
    sentiment_from_rating  VARCHAR(15),
    sentiment_mismatch     TINYINT(1),
    PRIMARY KEY (feedback_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

-- 9) churn_labels: exactly one row per customer
CREATE TABLE churn_labels (
    customer_id   VARCHAR(12) NOT NULL,
    churned       TINYINT(1)  NOT NULL,
    churn_date    DATE,
    churn_reason  VARCHAR(80),
    PRIMARY KEY (customer_id),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

SHOW TABLES;