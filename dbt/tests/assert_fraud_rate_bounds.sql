-- fraud_rate лежит в [0, 100].
select 'mart_fraud_by_category' as model, category as key, fraud_rate
from {{ ref('mart_fraud_by_category') }}
where fraud_rate < 0 or fraud_rate > 100

union all

select 'mart_fraud_by_state' as model, state_code as key, fraud_rate
from {{ ref('mart_fraud_by_state') }}
where fraud_rate < 0 or fraud_rate > 100
