with transactions as (

    select * from {{ ref('stg_transactions') }}

),

states as (

    select * from {{ ref('states') }}

),

daily as (

    select
        transaction_date,
        state_code,
        count() as transaction_count,
        round(sum(amount), 2) as total_amount,
        round(avg(amount), 2) as avg_amount,
        round(quantile(0.95)(amount), 2) as p95_amount,
        {{ safe_rate('countIf(is_large)', 'count()') }} as large_transaction_share_pct,
        countIf(is_fraud = 1) as fraud_count
    from transactions
    group by transaction_date, state_code

)

select
    daily.transaction_date,
    {{ dbt_date.day_name('daily.transaction_date', short=false) }} as day_name,
    daily.state_code,
    states.state_name,
    states.region,
    daily.transaction_count,
    daily.total_amount,
    daily.avg_amount,
    daily.p95_amount,
    daily.large_transaction_share_pct,
    daily.fraud_count
from daily
left join states on daily.state_code = states.state_code
