with source as (

    select * from {{ source('transactions_db', 'transactions') }}

),

cleaned as (

    select
        toDateTime(transaction_time, 'UTC') as transaction_time,
        trim(merch) as merchant_raw,
        lower(trim(cat_id)) as category,
        toFloat64(amount) as amount,
        trim(name_1) as first_name,
        trim(name_2) as last_name,
        upper(trim(gender)) as gender,
        trim(street) as street,
        trim(one_city) as city,
        upper(trim(us_state)) as state_code,
        toUInt32(post_code) as post_code,
        toFloat64(lat) as customer_lat,
        toFloat64(lon) as customer_lon,
        toUInt32(population_city) as city_population,
        trim(jobs) as job,
        toFloat64(merchant_lat) as merchant_lat,
        toFloat64(merchant_lon) as merchant_lon,
        toUInt8(target) as is_fraud
    from source
    where transaction_time is not null
        and amount >= 0

),

enriched as (

    select
        -- в источнике нет ID транзакции и клиента
        {{ dbt_utils.generate_surrogate_key([
            'transaction_time', 'merchant_raw', 'first_name', 'last_name',
            'street', 'amount', 'category'
        ]) }} as transaction_id,
        {{ dbt_utils.generate_surrogate_key(['first_name', 'last_name', 'street', 'post_code']) }}
            as customer_id,

        transaction_time,
        toDate(transaction_time) as transaction_date,
        toHour(transaction_time) as transaction_hour,
        toDayOfWeek(transaction_time) as day_of_week,
        toDayOfWeek(transaction_time) in (6, 7) as is_weekend,

        -- префикс fraud_ есть у всех мерчантов
        replaceRegexpOne(merchant_raw, '^fraud_', '') as merchant,
        category,
        amount,
        {{ amount_bucket('amount') }} as amount_bucket,
        amount >= {{ var('large_amount_threshold') }} as is_large,

        first_name,
        last_name,
        gender,
        city,
        state_code,
        post_code,
        city_population,
        job,
        customer_lat,
        customer_lon,
        merchant_lat,
        merchant_lon,
        round(geoDistance(customer_lon, customer_lat, merchant_lon, merchant_lat) / 1000, 2)
            as distance_km,

        is_fraud
    from cleaned

)

select * from enriched
