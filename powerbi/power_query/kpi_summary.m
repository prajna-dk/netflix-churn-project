let
    Source = Csv.Document(
        CsvFiles{[Name = "kpi_summary.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"as_of_date", type date},
        {"total_customers", Int64.Type},
        {"active_customers", Int64.Type},
        {"churned_customers", Int64.Type},
        {"churn_rate_pct", type number},
        {"monthly_recurring_revenue", type number},
        {"revenue_last_12m_payments", type number},
        {"high_risk_customers", Int64.Type},
        {"value_at_risk_12m", type number},
        {"churn_model_test_auc", type number}
        },
        "en-US")
in
    ChangedTypes
