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
        los_code,

        cast(extract(year from appt_dttm) as string) as appt_year,
        upper(date_format(appt_dttm, 'E')) as appt_day,
        upper(date_format(appt_dttm, 'MMM')) as appt_month,
        date_format(appt_dttm, 'yyyy-MM') as appt_month_year,
        to_date(appt_dttm) as appt_date_year,
        (
            datediff(to_date(appt_dttm), to_date(appt_made_dttm))
            + (
                hour(appt_dttm) * 3600
                + minute(appt_dttm) * 60
                + second(appt_dttm)
                - hour(appt_made_dttm) * 3600
                - minute(appt_made_dttm) * 60
                - second(appt_made_dttm)
            ) / 86400.0
        ) as wait_time,
        to_date(appt_made_dttm) as appt_made_date_year,
        date_format(appt_made_dttm, 'yyyy-MM') as appt_made_month_year,

        regexp_substr(prc_name, 'NEW') as new_pt_scheduled,
        regexp_substr(los_name, 'NEW') as new_pt_arrived_raw,

        department_name as dept_name_dnu,
        department_id,
        site,
        department_type,

        mapped_prc_name as prc_name,
        associationlista,
        associationlistb,
        associationlistt,
        associationlistr,

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
          to_date(contact_date) between to_date('{{ var("oncology_access_start_date", "2019-01-01") }}', 'yyyy-MM-dd') and date_sub(current_date(), 1)
          or to_date(appt_made_dttm) between to_date('{{ var("oncology_access_start_date", "2019-01-01") }}', 'yyyy-MM-dd') and date_sub(current_date(), 1)
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

        deduplicated_access.* except (
            ethnicity_grouper,
            race,
            race_grouper,
            race_grouper_detail,
            mychart_status_grouper,
            referring_provider,
            dx_grouper,
            dx_detail,
            new_pt_scheduled
        ),

        case
            when deduplicated_access.ethnic_background is null then 'BLANK/UNKNOWN'
            else deduplicated_access.ethnicity_grouper
        end as ethnicity_grouper,
        coalesce(deduplicated_access.race, 'BLANK') as race,
        coalesce(deduplicated_access.race_grouper, 'BLANK/UNKNOWN') as race_grouper,
        coalesce(deduplicated_access.race_grouper_detail, 'BLANK/UNKNOWN') as race_grouper_detail,
        case
            when deduplicated_access.mychart_status is null then 'Not Activated'
            else deduplicated_access.mychart_status_grouper
        end as mychart_status_grouper,
        coalesce(deduplicated_access.referring_provider, 'Unknown/Blank') as referring_provider,
        coalesce(deduplicated_access.dx_grouper, 'Non-Cancer') as dx_grouper,
        coalesce(deduplicated_access.dx_detail, 'Non-Cancer') as dx_detail,
        coalesce(deduplicated_access.new_pt_scheduled, 'ESTABLISHED') as new_pt_scheduled,

        nvl(deduplicated_access.new_pt_arrived_raw, 'ESTABLISHED') as new_pt_arrived,

        count(*) over () as totalRows

    from deduplicated_access
)

select *
from final
