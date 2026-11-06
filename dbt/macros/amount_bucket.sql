{# Сегмент суммы; границы в vars.amount_buckets #}
{% macro amount_bucket(column) -%}
    {%- set b = var('amount_buckets') -%}
    multiIf(
        {{ column }} < {{ b['micro'] }}, 'micro',
        {{ column }} < {{ b['small'] }}, 'small',
        {{ column }} < {{ b['medium'] }}, 'medium',
        {{ column }} < {{ b['large'] }}, 'large',
        'xlarge'
    )
{%- endmacro %}
