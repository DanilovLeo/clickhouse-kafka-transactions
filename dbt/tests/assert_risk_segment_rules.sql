-- Сегмент риска соответствует правилам HIGH / MEDIUM / LOW.
select customer_id, risk_segment, fraud_count, fraud_rate
from {{ ref('mart_customer_risk_profile') }}
where
    (risk_segment = 'LOW' and fraud_count > 0)
    or (risk_segment = 'MEDIUM' and (fraud_count = 0 or fraud_rate >= {{ var('risk_high_fraud_rate') }}))
    or (risk_segment = 'HIGH' and fraud_rate < {{ var('risk_high_fraud_rate') }})
