-- В staging не должно быть отрицательных сумм.
select *
from {{ ref('stg_transactions') }}
where amount < 0
