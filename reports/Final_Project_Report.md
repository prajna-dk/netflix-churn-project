# Netflix Customer Churn Intelligence: Final Project Report

*Draft generated from the project files. Read it, check each claim against the dashboard, and rewrite the
summary and recommendations in your own words before sharing.*

## 1. Executive summary
- **24.9%** of the 8,000 customers have churned (1,991); 6,009 are still active, paying **81,365** per month.
- A churn model ranks active customers by risk. It is **modest but real**: test AUC 0.568; the riskiest 20% churn at **31.2%** versus 24.5% on average.
- 1,201 active customers are in the High-risk tier. Estimated 12-month revenue at risk across all active customers is **151,335**.
- Customers who commented about **App stability** churn at **33.2%**, the highest of any feedback theme.
- The segment with the most expected revenue at risk is **High-Value Loyalists**.

## 2. Business question
Which customers are likely to leave, why, how much revenue is at stake, and where should a retention team act first?

## 3. Data
Nine tables for 8,000 customers (customers, subscriptions, plans, payments, viewing activity, content, support tickets, feedback, churn labels).
The data is synthetic. Analysis date (as-of) is **2026-06-30**. Raw files were never edited; 23 cleaning actions are listed in `docs/cleaning_log.csv`.

## 4. Method (what was done, in order)
1. **Audit and clean (Python):** duplicates removed, country and device names standardised, impossible ages and outliers handled, payment `subscription_id` recovered by date matching, odd payment amounts corrected (originals kept).
2. **SQL (MySQL):** database built from the clean files; all 37 business questions answered (views for the current plan, risk signals and monthly viewing).
3. **Exploratory analysis (Python):** 33 charts; Python and SQL results cross-checked.
4. **Features:** built at a snapshot date (the day before the first recorded churn) so no feature uses future information; a leakage test proved it.
5. **Churn model:** three models compared by cross-validation, tuned, and evaluated once on a locked test set.
6. **Segmentation:** K-Means with 5 behavioural segments.
7. **Customer value:** expected 12-month value from plan price and churn probability.
8. **Text themes:** keyword rules for feedback, TF-IDF clustering for tickets (free tools only).
9. **Dashboard:** Power BI reads only `data/bi_ready`; SQL and Python results are displayed, not recalculated.

## 5. Key findings
**Where churn differs most from the overall rate (24.9%):**
- **tickets_group = 3 or more**: 35.4% churn (+10.5 points vs overall, 398 customers)
- **gender = Other**: 20.2% churn (-4.7 points vs overall, 247 customers)
- **tenure_band = under 1 yr**: 29.4% churn (+4.5 points vs overall, 999 customers)
- **country = South Korea**: 29.3% churn (+4.4 points vs overall, 215 customers)
- **tenure_band = 1-2 yrs**: 29.2% churn (+4.3 points vs overall, 1,076 customers)

**Highest-churn countries (SQL Q30):** South Korea (29.3%), Germany (27.9%), Indonesia (26.9%).

**Model.** AUC 0.568. A leaky version scored higher (see `reports/churn_model_metrics.csv`), which is why feature timing mattered more than the choice of algorithm.

**Segments.** High-Value Loyalists carries the most expected monthly revenue at risk (9,889). See `data/model_outputs/segment_profile.csv`.

**Retention campaign (illustrative assumptions).** Model-targeting beats random targeting most for the **top 50%** campaign (extra net value 3,175).

**YOUR OWN FINDINGS:** (add 3 sentences from `docs/eda_findings.md` in your own words)

## 6. Recommendations
1. Start retention outreach with the High-risk tier, sorted by value at risk (`customer_value.csv`, dashboard page 4).
2. Fix app stability and payment failures first. Customers who complain about the app churn most, and failed payments are the strongest numeric signal in the model.
3. Run a **controlled test** (contact half of the High tier, hold out the rest) to measure the real save rate before scaling.
4. Replace the example campaign costs and save rate with real figures.
5. Re-train as more months of churn data arrive.

## 7. Limitations (be upfront about these)
- Synthetic data with weak signals; AUC around 0.57 is the honest ceiling here.
- Churn dates exist only from 2025-10-03, so there is one training snapshot and no out-of-time test.
- Viewing data covers 12 months; payments stop on 2026-05-31 and hold at most 15 payments per customer. For this reason no lifetime-value regression was built.
- `auto_renew` is stored as extracted, not as of the snapshot.
- Text is templated (13 feedback comments, 32 ticket descriptions); theme results are cleaner than real text would be.
- Theme and segment churn rates are descriptive, not causal.

## 8. Reproducibility
Run order and file locations are in `README.md`. All paths are found automatically from the project folder; the only typed paths are the folder placeholder
in `database/02_load_data.sql` (replaced once) and the `DataFolder` parameter in Power BI.
