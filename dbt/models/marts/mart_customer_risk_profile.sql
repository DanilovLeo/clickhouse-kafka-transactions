with transactions as (

    select * from {{ ref('stg_transactions') }}

),

by_customer as (

    select
        customer_id,
        any(first_name) as first_name,
        any(last_name) as last_name,
        any(gender) as gender,
        any(state_code) as state_code,
        any(city) as city,
        min(transaction_time) as first_transaction_at,
        max(transaction_time) as last_transaction_at,
        uniqExact(transaction_date) as active_days,
        count() as transaction_count,
        countIf(is_fraud = 1) as fraud_count,
        {{ safe_rate('countIf(is_fraud = 1)', 'count()') }} as fraud_rate,
        round(sum(amount), 2) as total_amount,
        round(avg(amount), 2) as avg_amount,
        round(max(amount), 2) as max_amount,
        uniqExact(category) as categories_used
    from transactions
    group by customer_id

)

select
    *,
    multiIf(
        fraud_rate >= {{ var('risk_high_fraud_rate') }}, 'HIGH',
        fraud_count > 0, 'MEDIUM',
        'LOW'
    ) as risk_segment
from by_customer
