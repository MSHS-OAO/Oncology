{{ config(
    materialized='table'
) }}

with ethnic_background as (
    select *
    from {{ source('msx_clarity', 'ethnic_background') }}
),

zc_ethnic_background as (
    select *
    from {{ source('msx_clarity', 'zc_ethnic_bkgrnd') }}
),

final as (
    select
        ethnic_background.pat_id,
        listagg(zc_ethnic_background.name, '; ') within group (
            order by ethnic_background.pat_id
        ) as ethnic_background

    from ethnic_background

    inner join zc_ethnic_background
        on ethnic_background.ethnic_bkgrnd_c = zc_ethnic_background.ethnic_bkgrnd_c

    group by
        ethnic_background.pat_id
)

select *
from final
