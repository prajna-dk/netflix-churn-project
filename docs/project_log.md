# Project Log

One entry per day. Write what you did and why.

## Day 1 - Setup and audit

- Created the project folder structure and PROJECT_ROOT.marker.
- Extracted 9 CSVs into data/raw with clean filenames.
- Extracted 4 project documents into docs/project_briefs.
- Created reusable path helper: docs/cell0_paths.py.
- Created audit files: docs/data_audit_tables.csv and docs/data_audit_columns.csv.
- Main activity period: 2025-07-01 to 2026-06-30.
- Project as-of date: 2026-06-30.

### Key data-quality findings
- customers: 48 duplicated rows/customer IDs.
- customers: 83 country labels versus approximately 20 expected countries.
- customers: 21 impossible ages.
- customers.state_or_region is completely missing.
- viewing_activity: 23 device labels versus 5 expected device types.
- viewing_activity: 161 sessions exceed 480 minutes.
- support_tickets: 61 dates could not be parsed.
- payments.subscription_id is completely blank across 110,735 rows.
- payments: 250 zero-value payment records.
- subscriptions: many end/cancellation fields are missing, likely reflecting active subscriptions.
- churn_labels: churn date/reason fields are missing for many non-churned customers.
- Overall churn rate: 24.9%.

### Project-document notes
- False negatives are more costly, so identifying true churn-risk customers is especially important.
- The project documents describe intentional data-quality issues including missing values, duplicate customers, inconsistent country/device labels, malformed dates, and extreme outliers.
- Churn is influenced by engagement, payment failures, support experience, plan type, and tenure.
- The dataset dictionary documents table relationships and expected cleaning approaches.
- The database schema documents table structures, relationships, and recommended load order.
- The SQL business-questions document provides the questions to answer during the SQL analysis phase.

Day 1 is an audit only. No raw data was modified or cleaned.

## Day 2 - Cleaning part 1
- customers: 48 duplicate rows removed (8,048 -> 8,000). Country spellings mapped to 20 countries.
- Missing country/city/language set to 'Unknown'. Impossible/missing ages filled with the median age of the segment.
- subscriptions: dates parsed, auto_renew -> 1/0. Every customer has exactly one open row. Prices left historical.
- churn_labels: churned -> 1/0. Proven consistent with subscription status.
- As-of date saved in data/clean/as_of_date.txt (2026-06-30).
- Helper file: src/cleaning_helpers.py. Cleaning log: docs/cleaning_log.csv.

## Day 3 - Cleaning part 2
- viewing_activity: 23 device spellings -> 5 (+Unknown). login_location standardised. Watch capped at 300, session at 360, session >= watch.
- customers.country: missing values recovered from the customer's most common login country (agreement test passed).
- payments: subscription_id resolved for all 110,735 rows (customer + date window; newer plan wins on change day).
- payments: rows where amount != plan price were corrected to the plan price. amount_original and amount_flag kept.
- support_tickets: invalid dates -> blank. Missing CSAT only on Pending/Escalated (expected).
- customer_feedback: added sentiment_from_rating and sentiment_mismatch (original label kept).
- 9 clean files in data/clean. Full list of actions: docs/cleaning_log.csv.

## Day 4 - MySQL database
- Installed MySQL Server 8 + Workbench, Google Drive for Desktop.
- Ran database/01_create_tables.sql, 02_load_data.sql, 03_indexes_and_reference.sql, 04_load_checks.sql.
- All 9 tables loaded; row counts match the clean files. ref_dates: as_of 2026-06-30, last payment 2026-05-31.
- Exported data/sql_exports/day04_row_counts.csv as proof.

## Day 5 - SQL section A (Q1-Q15)

### What I did
- Set Workbench to "Don't Limit" rows and ran the file with Ctrl+Enter, one question at a time.
- Created view v_customer_current (current plan + churn result per customer): 8,000 rows.
- Answered Q1-Q15 in database/05_section_a_intermediate.sql.
- Exported data/sql_exports/q04_churn_by_channel.csv and q06_top10_titles.csv.
- Business rules used: "last 12 months" ends at the last payment date (2026-05-31), not today;
  revenue = successful payments only; blank completion % and blank resolution time are ignored by AVG().

### Answers in one line each
- Q1  6,009 active customers. United States (1,134) and India (984) are the largest, together 35% of active customers.
- Q2  Revenue over the whole history: Standard 596,430 > Premium 479,630 > Basic 320,328 (total 1,396,388 = all successful payments).
- Q3  Churn rate 24.89% (1,991 of 8,000).
- Q4  Biggest channel Organic Search (1,786 customers, churn 24.9%). Highest churn Paid Social 25.9% and Direct 25.9%; lowest Partner Bundle 23.6% and Referral 24.0%.
- Q5  Average age is 32.5-32.7 for every plan.
- Q6  Top title "Iron Kingdom Part 6" with 8,406 minutes. All top 10 sit between 7,721 and 8,406 minutes.
- Q7  Average completion is about 70% in nearly every content type and genre (documentaries by genre range 68.7-72.6%).
- Q8  Failed payments per month, Jun 2025 - May 2026: between 66 (Feb 2026) and 98 (Oct 2025), about 85 on average, no clear trend.
- Q9  Resolution time is 17.3-18.6 hours in every category. Billing is fastest (17.3 h), Streaming Quality slowest (18.6 h).
- Q10 Satisfaction: score 3 is the most common (32.8%); 24.9% scored 1-2 and 42.4% scored 4-5.
- Q11 Smart TV 37.8% and Mobile 29.6% of watch minutes (67.4% together). Gaming Console 5.9%. "Unknown" device is 1.0%.
- Q12 Average rating: Positive label 4.40, Neutral 3.03, Negative 1.64, but every label has ratings from 1 to 5, which confirms the label noise.
- Q13 Signups per channel are steady across 2019-2025 (e.g. Organic Search 224-259 a year). 2026 is only a partial year (Jan-May).
- Q14 Auto-renew is off for 18.4% of all customers and 17.4% of active ones (so about 21% among churned customers).
- Q15 120 customers raised more than 3 tickets; the maximum is 7 tickets.

### Key findings (my reading)
1. Churn is similar in every acquisition channel (23.6%-25.9%, a spread of only 2.3 points), so the channel alone does not explain churn.
2. Revenue comes from Standard and Premium customers. Basic has the most customers (3,368) but the lowest revenue because of its price.
3. Nothing in viewing stands out: completion, resolution time and the top titles are all very flat. Differences between groups are small.
4. Customers who leave are slightly more likely to have auto-renew off (about 21% vs 17.4% of active customers). Worth checking again on Day 8.
5. Two thirds of viewing is on Smart TV and Mobile, so those are the devices that matter for app and quality issues.
6. A small group (120 customers) raised 4+ tickets. Check on Day 8 whether they churn more.

### Data caveats noticed
- Q2 averages over 89 months of payment history (2019 onward), not over the last 12 months.
- Q13: 2026 has only five months of signups.
- Sentiment labels are noisy (Q12); use sentiment_from_rating for any serious analysis.

### Next
- Day 6: window functions and cohorts (Q16-Q27), reusing v_customer_current.

## Day 6 - SQL section B (Q16-Q27)

### What I did
- Created view v_customer_month_watch (customer x month grid with zero months): 95,760 rows, months 2025-07 to 2026-06.
- Answered Q16-Q27 in database/06_section_b_advanced.sql using CTEs and window functions
  (RANK, DENSE_RANK, ROW_NUMBER, LAG, NTILE, running total, moving average).
- Exported data/sql_exports/q20_cohort_retention.csv (89 rows) and q21_top5_churn_countries.csv (5 rows).
- Business rules used: "active at month k" = had not churned by registration + k months; payments counted only when
  status = Success; churn is only recorded from 2025-10-03, so Jul-Sep 2025 churn is "not recorded", not "zero".

### Answers in one line each
- Q16 Recurring revenue rank: Standard 35,255 (2,276 active) > Premium 28,760 (1,251) > Basic 17,349 (2,482). Total 81,365.
- Q17 4,408 of 8,000 customers (55%) have at least one ticket; each now shows only their most recent one.
- Q18 About 90 new customers a month in 2019-2025. The 3-month average stays between 84 and 96 in 2026 (88 in May 2026): flat, no growth.
- Q19 2,908 customers watched less in June 2026 than in May 2026; 1,521 of them watched nothing in June.
- Q20 Cohorts are 100% retained at 1, 3 and 6 months for 2019-2024 (churn dates start in 2025-10), while "still active today" is
  70-85% for old cohorts. Recent cohorts lose customers faster: 1-month retention 94.0% (Jan 2026), 92.2% (Mar), 88.6% (Apr), 83.1% (May).
- Q21 Top 5 churn countries: South Korea 29.3% (63 of 215), Germany 27.9%, Indonesia 26.9%, Nigeria 26.8%, France 26.1% (overall 24.9%).
- Q22 Running totals work: CUST000001 pays 22.99 a month and reaches 321.86 after 14 payments.
- Q23 430 customers watched less each month for three months in a row (latest month = June 2026).
- Q24 Monthly churn rate rises from 2.72% (Oct 2025) to 4.01% (Jun 2026). Jan 2026 spikes to 3.65%, Feb dips to 2.81%.
- Q25 Retention by channel: Partner Bundle 76.4%, Referral 76.0%, App Store 75.8% ... Direct and Paid Social 74.1%.
- Q26 Lifetime spend quartiles: top 25% average 297.95, bottom 25% average 74.45 (4 times lower). Maximum spend is 344.85.
- Q27 "Invoice question" is the top complaint in 5 of 20 countries and in the top 3 in 10; "Failed payment" is top in 4 and in the top 3 in 8.

### Key findings (my reading)
1. Monthly churn is rising: from about 2.7% in Oct 2025 to 4.0% in Jun 2026. This is the most important trend so far.
2. Newer customers leave faster: 1-month retention falls from about 99% (2025 cohorts) to 83% (May 2026 cohort).
   Some of this is because churn is only recorded recently, so be careful to say "recent cohorts" and not "all cohorts".
3. Standard is the revenue leader even though Premium costs more, because it has almost twice as many active customers.
4. Billing is the main support pain point (invoice questions and failed payments lead in many countries).
5. South Korea, Germany and Indonesia churn the most, but these are groups of 215-400 customers, so differences of 2-4 points are only a hint.
6. Customers in the top spend quartile spend four times as much as the bottom quartile, but spending is capped by the 15-payment history (see caveats).
7. A decline in monthly watch time is common (36% of viewers in the latest month), so one month's drop is a weak signal.

### Data caveats noticed
- Q24: July-September 2025 show 0% churn only because churn dates start on 2025-10-03. Use Oct 2025 - Jun 2026 for any trend.
- Q20: churn only exists from 2025-10, so retention at 1/3/6 months is always 100% for old cohorts. The newest cohort months are only partly measured.
- Q22/Q26: each customer has at most 15 monthly payments on record (max 344.85 = 15 x 22.99), so "lifetime spend" is capped.
- Q19 and Q23 compare single months of viewing, which are noisy (customers have about 8 sessions a year).
- Q17: tickets with an unknown date sort last, so a dated ticket always wins.

### Next
- Day 7: expert questions (Q28-Q37), risk score views, and win-back list. Reuses v_customer_current and v_customer_month_watch.

## Day 7 - SQL section C (Q28-Q37)

### What I did
- Agreed the business definitions first (as-of 2026-06-30; payment windows end 2026-05-31; high risk = top 20% of ACTIVE
  customers by risk score; upgrade/downgrade judged by plan LIST price; negative feedback = sentiment_from_rating).
- Created views v_customer_risk_signals and v_customer_risk_score (8,000 rows each; 1,201 active customers in the High tier).
- Answered Q28-Q37 in database/07_section_c_expert.sql. All 37 SQL questions are now done.
- Exported to data/sql_exports: q30_country_churn_summary, q31_at_risk_revenue_top50, q33_winback_candidates,
  q34_plan_migration, q35_wau_mau, q36_outreach_list, q37_customer_health_score.

### Answers in one line each
- Q28 Only 4 customers are active, have 2+ failed payments in the last 90 days AND are High risk (CUST002514, CUST005057, CUST004108, CUST000439).
      Only 5 active customers have 2+ failed payments at all, and 150 of 6,009 (2.5%) have at least one.
- Q29 570 customers moved to a plan with a different list price, but only 45 have viewing in both 30-day windows.
      Average minutes per session: 46.5 before, 49.1 after (+5.7%). Individual changes range from -92% to +300%.
- Q30 Country scorecard: same top churn countries as Q21 (South Korea 29.3%, Germany 27.9%, Indonesia 26.9%); lowest Poland 20.5%.
      Most common churn reason is "Too expensive" in 11 of 20 countries, "Found alternative platform" in 6, "No longer needed" in 3.
      Average lifetime value of churned customers ranges from 143 to 197 by country.
- Q31 Top 50 at-risk revenue customers: 42 Premium and 8 Standard. At-risk revenue is 6.86 to 12.87 per customer per month.
      The top 3 are customers who never watched anything (recency set to 365 days).
- Q32 Most recent completed quarter = 2026-04-01 to 2026-06-30. Across the country top-5 lists the most frequent complaints
      are Buffering (54 tickets), App crashing (39), Failed payment (35) and Refund request (34).
- Q33 498 win-back candidates (top spending quarter of churned customers, lifetime value 217 to 345). Last engagement before leaving:
      High 18, Medium 162, Low 190, None 128. Reasons: Found alternative platform 83, Too expensive 66, No longer needed 58, Technical issues 56.
- Q34 Most common real plan changes are downgrades: Standard to Basic 119 and Premium to Basic 114. Upgrades: Basic to Standard 101,
      Basic to Premium 74, Standard to Premium 56. Churn: Upgraded 27.7%, Downgraded 26.5%, Changed at the same price 27.9%, Never changed 24.6%.
- Q35 Monthly active customers Jan-Jun 2026: 3,672 / 3,513 / 3,210 / 3,191 / 4,302 / 4,235. Stickiness (WAU/MAU) between 0.28 and 0.39,
      highest in May-June 2026 (0.38 and 0.39).
- Q36 Outreach list: 28 active customers with negative feedback within 14 days of a trigger. 25 were triggered by a failed payment, 3 by a low-CSAT ticket.
- Q37 Health score for all 8,000 customers. Average risk score 26.9 out of 100 (range 1 to 71): churned customers 29.7, customers who stayed 26.0.

### Key findings (my reading)
1. The hand-built risk score separates churned from stayed only weakly (29.7 vs 26.0 on a 0-100 scale), so the SQL score is a rough screen, not a prediction.
2. Customers who changed plan churn a bit more than those who never did (26.5-27.9% vs 24.6%). Basic to Premium upgraders churn most (32.4%) and
   Standard to Premium upgraders least (17.9%), but those groups have only 56-74 customers.
3. "Too expensive" is the leading churn reason in over half the countries, and downgrades (Premium or Standard to Basic) are the most common plan change. Price pressure is a real theme.
4. Billing is a recurring issue: failed payments trigger 25 of the 28 outreach cases, and failed payments appear in the top complaints.
5. Buffering and app crashing are the top complaints in the latest quarter, which links to the technical-issue churn reason.
6. Win-back: 128 high-value churned customers had no viewing in their last 90 days, so engagement was already gone before they left. 83 left for another platform.
7. Engagement jumped in May 2026 (monthly active customers from 3,191 to 4,302). Check on Day 8 whether this is real or a data artefact.

### Data caveats noticed
- Q29 rests on 45 customers, so the +5.7% is a hint, not a result.
- Q31: customers with no viewing at all get recency = 365, which pushes them to the top. The list is partly a "never watched" list.
- subscriptions.monthly_price is not always the plan price (570 rows differ); list prices were used for upgrade/downgrade.
- Payment windows end 2026-05-31 while viewing ends 2026-06-30, so each uses its own anchor date.
- Q36 uses sentiment_from_rating because the original label is about 5% wrong.
- Lifetime value is capped by the 15-payment history (max 344.85).

### Next
- Day 8: exploratory analysis in Python on the clean CSVs (about 30 charts), cross-checked against SQL Q4, Q20 and Q37.## Day 8 - EDA
- Built reports/figures (33 charts), reports/eda_churn_by_group.csv, docs/eda_findings.md.
- Python churn counts per channel match SQL (Q4).
- Next: features for the model (Day 9).

## Day 9 - Feature engineering
- src/features.py builds features for any snapshot date using only data on or before it.
- Training snapshot = 2025-10-02 (day before the first churn). Scoring snapshot = 2026-06-30.
- data/features/customer_features_train.csv (7277 rows, 26 features) and customer_features_scoring.csv.
- Leakage test passed. Banned columns: subscription_status, cancellation_*, churn_date, churn_reason.
- Caveat: auto_renew is as-extracted; Day 10 checks its influence.

## Day 10 - Churn model
- Compared Logistic Regression, Random Forest and Gradient Boosting by 5-fold cross-validation. Chosen: Gradient Boosting.
- Locked test set: AUC 0.568, average precision 0.300. Riskiest 20% churn at 31.2% (average 24.5%).
- Leakage demo: honest AUC 0.578 vs leaky 0.648.
- Saved models/churn_model.joblib and data/model_outputs/churn_predictions.csv (6009 active customers).

## Day 11 - Segmentation
- K-Means with k=5 on 9 behaviour/value features (log + standard scaling). Silhouette about 0.249 (weak separation, k chosen for business usefulness).
- Stability (ARI vs other seeds): 1.0 on average.
- Segments: Budget Regulars, Dormant, High-Value Loyalists, New & Highly Engaged, Payment Trouble.
- Saved models/segment_model.joblib, data/model_outputs/customer_segments.csv, segment_profile.csv.

## Day 12 - Customer value and evaluation
- No CLV regression: payments are capped at 15 per customer. Built a formula-based expected 12-month value instead.
- Test AUC 0.568 (95% interval 0.535-0.602). Riskiest 20% churn at 31.2% vs 24.5% average.
- Saved customer_value.csv, campaign_scenarios.csv, model_evaluation_report.md, model_performance_by_group.csv.

## Day 13 - Text themes and BI package
- Feedback themes by keyword rules (7 themes); ticket themes by TF-IDF + K-Means, agreement with human categories ARI 0.26.
- NOTE: text is templated (32 ticket descriptions, 13 feedback comments), so results are cleaner than real text would be.
- data/bi_ready now holds 20 CSV tables (star schema + model_ and sql_ tables). Integrity checks passed.
- docs/bi_data_dictionary.csv and docs/bi_relationships.csv describe the package.

## Day 14 - Power BI setup
- Generated powerbi/power_query/*.m (19 scripts), powerbi/dax_measures.dax, powerbi/expected_numbers.csv.
- Power BI reads ONLY data/bi_ready; the folder path lives in one parameter (DataFolder).
- Built pages 1-3 (Executive Overview, Revenue & Payments, Engagement) in powerbi/netflix_churn_dashboard.pbix.

## Day 15 - Finish and deliver
- Dashboard pages 4-7, theme, PDF export. Portability test (changed DataFolder) passed.
- Final report, presentation notes, README and manifest written. {int(manifest['exists'].sum())} of {len(manifest)} expected files present.
- PROJECT COMPLETE.