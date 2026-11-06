with transactions as (

    select * from {{ ref('stg_transactions') }}

),

states as (

    select * from {{ ref('states') }}

),

by_state as (

    select
        state_code,
        count() as transaction_count,
        countIf(is_fraud = 1) as fraud_count,
        {{ safe_rate('countIf(is_fraud = 1)', 'count()') }} as fraud_rate,
        uniqExact(customer_id) as unique_customers,
        uniqExactIf(customer_id, is_fraud = 1) as customers_with_fraud,
        uniqExact(merchant) as unique_merchants,
        round(sum(amount), 2) as total_amount,
        round(sumIf(amount, is_fraud = 1), 2) as fraud_amount
    from transactions
    group by state_code

)

select
    by_state.state_code,
    states.state_name,
    states.region,
    by_state.transaction_count,
    by_state.fraud_count,
    by_state.fraud_rate,
    by_state.unique_customers,
    by_state.customers_with_fraud,
    by_state.unique_merchants,
    by_state.total_amount,
    by_state.fraud_amount,
    toUInt32(row_number() over (order by by_state.fraud_rate desc, by_state.state_code))
        as fraud_rank
from by_state
left join states on by_state.state_code = states.state_code
