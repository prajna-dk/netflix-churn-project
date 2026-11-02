# Presentation Notes

## 60-second talk track
"I built an end-to-end churn analysis on 8,000 Netflix-style customers. I cleaned nine tables in Python, loaded them into
MySQL and answered 37 business questions, then built a churn model and a segmentation, and put everything in a Power BI
dashboard. About 25% of customers have churned. The model is modest (AUC 0.57), but it
finds 31% churners in the riskiest 20% against 24% on average, and it shows where revenue at risk is concentrated.
I was careful to prevent data leakage and I am upfront about the limits of the data."

## Questions you should expect, and honest answers
**Why is the AUC only about 0.57?** The data is synthetic and churn depends on many weak signals. I checked that a much higher AUC
would come only from leakage: when I computed features after the churn dates, AUC rose to about 0.65, which is cheating. The honest
number is the one I report, with a 95% interval.

**How did you avoid data leakage?** All features are computed at a snapshot date (the day before the first churn) using only earlier data.
I proved it with a test that deletes all later data and rebuilds the features: the table did not change.

**Why no lifetime-value regression?** The payments table holds at most 15 payments per customer, and 83% of customers have no payments after
the training cutoff. A regression would learn that artefact. I used a transparent expected-value formula instead.

**How do you know the dashboard is right?** Totals match across three tools: SQL (8,000 customers, 24.89% churn), Python and Power BI.
I wrote the expected numbers down before building the pages and compared them.

**What would you do next?** Run a controlled retention test to measure the real save rate, add more months of churn data, and
use real campaign costs.

**What was the hardest part?** (Write your own answer: for many people it is matching each payment to the right subscription, or the leakage-safe snapshot.)

## Numbers to remember
- Customers 8,000; active 6,009; churn 24.9%
- Monthly recurring revenue 81,365; value at risk (12 months) 151,335
- High-risk customers 1,201
