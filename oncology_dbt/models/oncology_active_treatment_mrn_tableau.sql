{{ config(materialized='table') }}

select distinct mrn
from {{ ref('oncology_access_silver') }}
where appt_status = 'Arrived'
  and associationlista = 'Treatment'
