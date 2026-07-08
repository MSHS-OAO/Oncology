with patient_data as (
    select *
    from {{ source('msx_clarity', 'mv_dm_patient_access') }}
),

department as (
    select *
    from {{ source('oncology', 'mapping_department') }}
),

procedure as (
    select *
    from {{ source('oncology', 'mapping_procedure') }}
),

disease as (
    select *
    from {{ source('oncology', 'mapping_disease') }}
),

icd10 as (
    select *
    from {{ source('oncology', 'mapping_vizient_icd10') }}
),

demographics as (
    select *
    from {{ source('oncology', 'mapping_mv_patient_select_demographics') }}
),

ethnic_background as (
    select *
    from {{ ref('mapping_ethnic_background') }}
),

los_exclusions as (
    select *
    from {{ source('oncology', 'mapping_los_exclusions') }}
),

race as (
    select *
    from {{ source('oncology', 'mapping_race') }}
),

mychart_status as (
    select *
    from {{ source('oncology', 'mapping_mychart_status') }}
),

ethnicity as (
    select *
    from {{ source('oncology', 'mapping_ethnicity') }}
),

final as (
    select
        patient_data.dept_specialty_name,
        patient_data.prov_id,
        patient_data.prov_name_wid,
        patient_data.referring_prov_name_wid,
        patient_data.mrn,
        patient_data.pat_name,
        patient_data.zip_code,
        patient_data.pat_enc_csn_id,
        patient_data.birth_date,
        patient_data.finclass,
        patient_data.appt_made_dttm,
        patient_data.appt_dttm,
        patient_data.prc_name,
        patient_data.appt_length,
        patient_data.derived_status_desc,
        patient_data.appt_canc_dttm,
        patient_data.cancel_reason_name,
        patient_data.signin_dttm,
        patient_data.paged_dttm,
        patient_data.checkin_dttm,
        patient_data.arvl_list_remove_dttm,
        patient_data.roomed_dttm,
        patient_data.first_room_assign_dttm,
        patient_data.phys_enter_dttm,
        patient_data.visit_end_dttm,
        patient_data.checkout_dttm,
        patient_data.time_in_room_minutes,
        patient_data.cycle_time_minutes,
        patient_data.visit_group_num,
        patient_data.los_name,
        patient_data.appt_entry_user_name_wid,
        patient_data.access_center_scheduled_yn,
        patient_data.visit_method,
        patient_data.visit_prov_staff_resource_c,
        patient_data.primary_dx_code,
        patient_data.referring_prov_id,
        patient_data.pat_id,
        patient_data.los_code,
        patient_data.contact_date,

        department.department_name,
        department.department_id,
        department.site,

        procedure.associationlista,
        procedure.associationlistb,
        procedure.associationlistt,

        disease.disease_group,
        disease.disease_group_b,
        disease.provider_type,

        icd10.description,
        icd10.definition,

        demographics.race,
        demographics.mychart_status,

        ethnic_background.ethnic_background,

        los_exclusions.los_code as excluded_los_code,

        race.race_grouper,
        race.race_grouper_detail,

        mychart_status.mychart_status_grouper,

        ethnicity.ethnicity_grouper

    from patient_data

    inner join department
        on patient_data.department_id = department.department_id

    left join procedure
        on patient_data.prc_name = procedure.prc_name

    left join disease
        on patient_data.prov_id = disease.epic_provider_id

    left join icd10
        on patient_data.primary_dx_code = icd10.epic_icd10_code

    left join demographics
        on patient_data.pat_id = demographics.pat_id

    left join ethnic_background
        on patient_data.pat_id = ethnic_background.pat_id

    left join los_exclusions
        on patient_data.los_code = los_exclusions.los_code

    left join race
        on lower(demographics.race) = lower(race.race)

    left join mychart_status
        on lower(demographics.mychart_status) = lower(mychart_status.mychart_status)

    left join ethnicity
        on lower(ethnic_background.ethnic_background) = lower(ethnicity.ethnic_background)
)

select *
from final
