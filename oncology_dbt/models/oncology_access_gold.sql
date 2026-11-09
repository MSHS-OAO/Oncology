{{ config(materialized='table') }}

with access_base as (
    select *
    from {{ ref('oncology_access_silver') }}
),

active_mrn as (
    select *
    from {{ ref('mapping_active_mrn') }}
),

holidays as (
    select dates, holiday
    from {{ source('oncology', 'mapping_holidays') }}
),

final as (
    select
        access_base.*,
        active_mrn.active_mrn

    from access_base

    left join active_mrn
        on access_base.mrn = active_mrn.mrn

    where access_base.department_id != 8849025

    union all

    select
        access_base.*,
        active_mrn.active_mrn

    from access_base

    left join active_mrn
        on access_base.mrn = active_mrn.mrn

    where access_base.department_id = 8849025
      and access_base.epic_provider_id = '184137'
)

select
    final.*,
    holidays.holiday
from final
left join holidays
    on to_date(final.appt_dttm) = to_date(holidays.dates)
