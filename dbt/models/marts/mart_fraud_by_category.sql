with transactions as (

    select * from {{ ref('stg_transactions') }}

),

by_category as (

    select
        category,
        count() as transaction_count,
        countIf(is_fraud = 1) as fraud_count,
        {{ safe_rate('countIf(is_fraud = 1)', 'count()') }} as fraud_rate,
        round(sum(amount), 2) as total_amount,
        round(sumIf(amount, is_fraud = 1), 2) as fraud_amount,
        round(avgIf(amount, is_fraud = 1), 2) as avg_fraud_amount,
        round(avgIf(amount, is_fraud = 0), 2) as avg_legit_amount
    from transactions
    group by category

)

select
    category,
    transaction_count,
    fraud_count,
    fraud_rate,
    total_amount,
    fraud_amount,
    {{ safe_rate('fraud_amount', 'total_amount') }} as fraud_amount_share_pct,
    avg_fraud_amount,
    avg_legit_amount,
    toUInt32(row_number() over (order by fraud_rate desc, category)) as fraud_rank
from by_category
