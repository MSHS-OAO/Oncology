with formatted_access as (
    select
        dept_specialty_name,
        prov_id as epic_provider_id,
        referring_prov_name_wid,
        mrn,
        pat_name as patient_name,
        zip_code,
        cast(cast(pat_enc_csn_id as bigint) as string) as pat_enc_csn_id,
        birth_date,
        finclass as coverage,
        appt_made_dttm,
        appt_dttm,
        prc_name as appt_type,
        appt_length as appt_dur,
        derived_status_desc as appt_status,
        appt_canc_dttm,
        cancel_reason_name as cancel_reason,
        signin_dttm,
        paged_dttm,
        checkin_dttm,
        arvl_list_remove_dttm as arrival_remove_dttm,
        roomed_dttm,
        first_room_assign_dttm as room_assigned_dttm,
        phys_enter_dttm as providerin_dttm,
        visit_end_dttm,
        checkout_dttm,
        time_in_room_minutes,
        cycle_time_minutes,
        visit_group_num as new_pt,
        los_name as class_pt,
        appt_entry_user_name_wid as appt_source,
        access_center_scheduled_yn as access_center,
        visit_method,
        visit_prov_staff_resource_c as resources,
        primary_dx_code,
        referring_prov_id,
        pat_id,
        excluded_los_code,

        cast(extract(year from appt_dttm) as string) as appt_year,
        extract(dayofweek from appt_dttm) as appt_day,
        extract(month from appt_dttm) as appt_month,
        cast(extract(year from appt_dttm) as string)
            || '-'
            || cast(extract(month from appt_dttm) as string)
            as appt_month_year,
        to_date(appt_dttm) as appt_date_year,
        datediff(appt_dttm, appt_made_dttm) as wait_time,
        to_date(appt_made_dttm) as appt_made_date_year,
        cast(extract(year from appt_made_dttm) as string)
            || '-'
            || cast(extract(month from appt_made_dttm) as string)
            as appt_made_month_year,

        regexp_substr(prc_name, 'NEW') as new_pt_scheduled,
        regexp_substr(los_name, 'NEW') as new_pt_arrived_raw,

        department_name as dept_name_dnu,
        department_id,
        site,

        associationlista,
        associationlistb,
        associationlistt,

        disease_group,
        disease_group_b as disease_group_detail,
        provider_type,

        description as dx_detail,
        replace(definition, 'Oncology-', '') as dx_grouper,

        race,
        mychart_status,
        ethnic_background,
        race_grouper,
        race_grouper_detail,
        mychart_status_grouper,
        ethnicity_grouper,

        trim(trailing from regexp_replace(
            prov_name_wid,
            '{{ var("oncology_access_provider_name_regex", "$^") }}',
            ''
        )) as provider,
        trim(trailing from regexp_replace(
            referring_prov_name_wid,
            '{{ var("oncology_access_provider_name_regex", "$^") }}',
            ''
        )) as referring_provider,

        row_number() over (
            partition by
                mrn,
                appt_dttm,
                prc_name,
                prov_id,
                derived_status_desc
            order by
                mrn,
                appt_dttm,
                prc_name,
                prov_id,
                derived_status_desc
        ) as row_counts

    from {{ ref('oncology_access_bronze') }}
    where excluded_los_code is null
      and (
          to_date(contact_date) between to_date('{{ var("oncology_access_start_date", "2019-01-01") }}', 'yyyy-MM-dd') and current_date()
          or to_date(appt_made_dttm) between to_date('{{ var("oncology_access_start_date", "2019-01-01") }}', 'yyyy-MM-dd') and current_date()
      )
),

deduplicated_access as (
    select *
    from formatted_access
    where row_counts = 1
),

final as (
    select
        case
            when deduplicated_access.dept_name_dnu like 'X_%'
                and deduplicated_access.appt_dttm >= to_date('2024-01-01', 'yyyy-MM-dd')
                and deduplicated_access.appt_dttm < to_date('2025-01-01', 'yyyy-MM-dd')
                then regexp_replace(deduplicated_access.dept_name_dnu, '^[X_]{2}', 'X_2024_')
            else deduplicated_access.dept_name_dnu
        end as department_name,

        deduplicated_access.*,

        nvl(deduplicated_access.new_pt_arrived_raw, 'ESTABLISHED') as new_pt_arrived,

        count(*) over () as total_rows

    from deduplicated_access
)

select *
from final
