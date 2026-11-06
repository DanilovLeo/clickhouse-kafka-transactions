{# Процент с защитой от деления на ноль #}
{% macro safe_rate(numerator, denominator) -%}
    round(if({{ denominator }} = 0, 0, 100.0 * {{ numerator }} / {{ denominator }}), 4)
{%- endmacro %}
