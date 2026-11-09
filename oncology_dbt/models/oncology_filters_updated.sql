{{ config(materialized='table') }}

select distinct
    site,
    department_name,
    provider,
    provider_type,
    disease_group,
    disease_group_detail,
    associationlista,
    associationlistb,
    associationlistt,
    referring_provider,
    referring_prov_id,
    dx_grouper,
    appt_status
from {{ ref('oncology_access_silver') }}
