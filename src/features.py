"""Builds one row per customer using ONLY data available on or before ref_date."""
import pandas as pd
import numpy as np


def build_features(ref_date, tables, last_payment_date=None):
    """
    ref_date           the snapshot date; nothing after this date is used
    tables             dict of the clean tables (customers, subscriptions, ...)
    last_payment_date  payments stop earlier than viewing in this dataset, so payment windows
                       are measured back from min(ref_date, last_payment_date)
    """
    ref = pd.Timestamp(ref_date)
    pay_ref = ref if last_payment_date is None else min(ref, pd.Timestamp(last_payment_date))

    customers, subs, plans = tables["customers"], tables["subscriptions"], tables["subscription_plans"]
    viewing, payments = tables["viewing_activity"], tables["payments"]
    tickets, feedback, churn = tables["support_tickets"], tables["customer_feedback"], tables["churn_labels"]

    # ---- 1. Who is in the table: customers registered on or before the snapshot date -------------
    out = customers.loc[customers["registration_date"] <= ref,
                        ["customer_id", "age", "gender", "customer_segment",
                         "acquisition_channel", "country", "registration_date"]].copy()
    out["tenure_days"] = (ref - out["registration_date"]).dt.days
    out = out.drop(columns="registration_date")

    # ---- 2. Subscription as it was on the snapshot date ------------------------------------------
    started = subs[subs["subscription_start_date"] <= ref].sort_values("subscription_start_date")
    plan_changes = started.groupby("customer_id").size().sub(1).rename("plan_changes_to_date")
    in_force = started[started["subscription_end_date"].isna() | (started["subscription_end_date"] > ref)]
    in_force = (in_force.groupby("customer_id").last().reset_index()
                        .merge(plans[["plan_id", "plan_name"]], on="plan_id")
                        [["customer_id", "plan_name", "auto_renew"]])

    # ---- 3. Viewing behaviour: last 30 and 90 days before the snapshot ---------------------------
    v = viewing[viewing["viewing_date"] <= ref].copy()
    v["days_ago"] = (ref - v["viewing_date"]).dt.days
    v90 = v[v["days_ago"] < 90]
    view_90 = v90.groupby("customer_id").agg(
        sessions_90d=("viewing_id", "count"),
        minutes_90d=("watch_duration_minutes", "sum"),
        avg_completion_90d=("completion_percentage", "mean"),
        distinct_titles_90d=("content_id", "nunique"))
    sessions_30d = v[v["days_ago"] < 30].groupby("customer_id").size().rename("sessions_30d")
    days_since_last_view = v.groupby("customer_id")["days_ago"].min().clip(upper=90).rename("days_since_last_view")

    # ---- 4. Payments: last 12 months before the (payment) reference date -------------------------
    p = payments[payments["payment_date"] <= pay_ref].copy()
    p["days_ago"] = (pay_ref - p["payment_date"]).dt.days
    p["is_failed"] = (p["payment_status"] == "Failed").astype(int)
    pay_12m = p[p["days_ago"] < 365].groupby("customer_id").agg(
        payments_12m=("payment_id", "count"),
        failed_payments_12m=("is_failed", "sum"))
    pay_12m["failed_rate_12m"] = pay_12m["failed_payments_12m"] / pay_12m["payments_12m"]
    failed_90d = p[p["days_ago"] < 90].groupby("customer_id")["is_failed"].sum().rename("failed_payments_90d")

    # ---- 5. Support tickets (tickets with an unknown date are dropped by the comparison) ---------
    t = tickets[tickets["ticket_date"] <= ref]
    tick = t.groupby("customer_id").agg(
        tickets_total=("ticket_id", "count"),
        avg_csat=("customer_satisfaction_score", "mean"),
        avg_resolution_hours=("resolution_time_hours", "mean"))
    tickets_365d = t[(ref - t["ticket_date"]).dt.days < 365].groupby("customer_id").size().rename("tickets_365d")

    # ---- 6. Feedback ------------------------------------------------------------------------------
    f = feedback[feedback["feedback_date"] <= ref]
    fb = f.groupby("customer_id").agg(
        feedback_count=("feedback_id", "count"),
        avg_rating=("rating", "mean"),
        negative_feedback_share=("sentiment_from_rating", lambda s: (s == "Negative").mean()))

    # ---- 7. Put everything together --------------------------------------------------------------
    out = out.merge(in_force, on="customer_id", how="left").merge(plan_changes, on="customer_id", how="left")
    for part in [view_90, sessions_30d, days_since_last_view, pay_12m, failed_90d, tick, tickets_365d, fb]:
        out = out.merge(part, left_on="customer_id", right_index=True, how="left")

    # a customer with no rows in a table has a count of 0 (not "unknown")
    zero_fill = ["sessions_90d", "minutes_90d", "distinct_titles_90d", "sessions_30d", "payments_12m",
                 "failed_payments_12m", "failed_rate_12m", "failed_payments_90d", "tickets_total",
                 "tickets_365d", "feedback_count", "plan_changes_to_date"]
    out[zero_fill] = out[zero_fill].fillna(0)
    out["days_since_last_view"] = out["days_since_last_view"].fillna(90)     # never watched = the maximum, 90
    # avg_completion_90d, avg_csat, avg_resolution_hours, avg_rating, negative_feedback_share stay blank
    # when there is nothing to average. The model pipeline on Day 10 handles blanks.

    # ---- 8. The outcome (NEVER used as a feature) and who was still a customer on the snapshot date
    out = out.merge(churn[["customer_id", "churned", "churn_date"]], on="customer_id", how="left")
    out["active_at_snapshot"] = out["churn_date"].isna() | (out["churn_date"] > ref)
    out = out.drop(columns="churn_date")
    out.insert(1, "snapshot_date", ref)
    assert out["customer_id"].is_unique
    return out
