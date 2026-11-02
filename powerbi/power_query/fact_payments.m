let
    Source = Csv.Document(
        CsvFiles{[Name = "fact_payments.csv"]}[Content],
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    ChangedTypes = Table.TransformColumnTypes(
        PromotedHeaders,
        {
        {"payment_id", type text},
        {"customer_id", type text},
        {"subscription_id", type text},
        {"payment_date", type date},
        {"amount", type number},
        {"payment_status", type text},
        {"payment_method", type text},
        {"failed_payment_reason", type text},
        {"amount_flag", type text}
        },
        "en-US")
in
    ChangedTypes
