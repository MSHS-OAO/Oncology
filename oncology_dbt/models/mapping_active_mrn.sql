{{ config(
    materialized='table'
) }}

with active_mrns as (
    select
        mrn,
        'Yes' as active_mrn

    from {{ ref('oncology_access_silver') }}
    where appt_status = 'Arrived'
      and associationlista = 'Treatment'
      and appt_dttm >= date_trunc('month', add_months(current_date(), -3))
),

final as (
    select distinct
        mrn,
        active_mrn

    from active_mrns
)

select *
from final
