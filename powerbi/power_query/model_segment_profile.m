let
    Source = Csv.Document(
        CsvFiles{[Name = "model_segment_profile.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"segment_id", Int64.Type},
        {"segment_name", type text},
        {"customers", Int64.Type},
        {"avg_days_since_last_view", type number},
        {"avg_sessions_90d", type number},
        {"avg_lifetime_spend", type number},
        {"avg_plan_price", type number},
        {"avg_tenure_days", type number},
        {"avg_tickets_365d", type number},
        {"avg_failed_payments_12m", type number},
        {"avg_churn_probability", type number},
        {"high_risk_customers", Int64.Type},
        {"monthly_revenue", type number},
        {"expected_revenue_at_risk", type number},
        {"pct_high_risk", type number}
        },
        "en-US")
in
    ChangedTypes
