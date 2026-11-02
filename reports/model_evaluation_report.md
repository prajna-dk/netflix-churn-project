# Churn Model Evaluation Report

*Generated from the project files. Training cutoff 2025-10-02, scoring date 2026-06-30.*

## 1. What the model does
It estimates, for each customer who is active on 2026-06-30, the probability of churning over a window of about
9 months. Features are measured on a snapshot date using only data available then (no leakage).

## 2. How good is it?
| Measure | Result |
|---|---|
| Model chosen | Gradient Boosting |
| Test AUC | 0.568 (95% interval 0.535 to 0.602) |
| Average precision | 0.300 (random guess = 0.245) |
| Riskiest 20% of customers | 31.2% churn (average 24.5%), reaching 25.6% of all churners |
| Calibration | average predicted 0.244 vs actual 0.245 |

**Plain reading:** the model has a real but modest ability to rank customers by churn risk. It is useful for
choosing *whom to contact first*, not for predicting an individual customer's decision.

## 3. Leakage check
Features computed on the scoring date instead of the cutoff gave an AUC of 0.648, higher than the honest
0.568. The higher number is not a better model; it is a model that has seen the future. The honest figure is the one reported.

## 4. Performance by group
The weakest group on the test set was **Affiliate Partner** (acquisition_channel, n=126) with AUC 0.503.
Groups of 100-400 customers are noisy; see `reports/model_performance_by_group.csv`.

## 5. Business case (illustrative assumptions)
Contact cost 2.0, save rate 20%, 12 months of value per saved customer.
The campaign size with the largest gain over random targeting is **top 50%** (details in `data/model_outputs/campaign_scenarios.csv`).
These assumptions are examples and must be replaced with real figures before any decision.

## 6. Customer value
Expected 12-month value is plan price x expected months paid, derived from the churn probability. Total value at risk across
active customers is about 151,335 out of 976,379
(15.5%).
A regression on historical spend was deliberately **not** built: the payments table holds at most 15 payments per customer, so
"future spend" cannot be learned from it.

## 7. Limitations
- Synthetic data with weak signals: AUC of about 0.57 is the honest ceiling here.
- Churn dates only exist from 2025-10-03, so one training snapshot is possible, and no out-of-time test.
- Viewing data covers 12 months only. Payments stop on 2026-05-31.
- `auto_renew` is stored as extracted, not as of the snapshot (it may carry slight future information).
- Probabilities are best used as ranks and tiers, not exact chances.

## 8. Recommended next steps
1. Use the High tier (top 20%) as the first retention list, sorted by value at risk (`customer_value.csv`).
2. Run a small controlled test (contact half of the High tier, hold out the other half) to measure the real save rate.
3. Replace the example campaign assumptions with real costs.
4. Re-train when more months of churn data are available.
