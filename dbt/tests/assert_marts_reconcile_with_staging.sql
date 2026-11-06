-- Суммы транзакций и фродов в витринах совпадают со staging.
with stg as (
    select count() as transactions, countIf(is_fraud = 1) as frauds
    from {{ ref('stg_transactions') }}
),

marts as (
    select 'mart_fraud_by_category' as model, sum(transaction_count) as transactions, sum(fraud_count) as frauds
    from {{ ref('mart_fraud_by_category') }}
    union all
    select 'mart_fraud_by_state', sum(transaction_count), sum(fraud_count)
    from {{ ref('mart_fraud_by_state') }}
    union all
    select 'mart_daily_state_metrics', sum(transaction_count), sum(fraud_count)
    from {{ ref('mart_daily_state_metrics') }}
    union all
    select 'mart_customer_risk_profile', sum(transaction_count), sum(fraud_count)
    from {{ ref('mart_customer_risk_profile') }}
)

select marts.*, stg.transactions as stg_transactions, stg.frauds as stg_frauds
from marts
cross join stg
where marts.transactions != stg.transactions or marts.frauds != stg.frauds
