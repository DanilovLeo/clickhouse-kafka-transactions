-- П.3. Категория наибольшей транзакции по каждому штату.
-- argMax(cat_id, amount) возвращает cat_id из строки с максимальной суммой.
SELECT
    us_state,
    argMax(cat_id, amount) AS category,
    max(amount)            AS max_amount
FROM transactions
GROUP BY us_state
ORDER BY us_state
