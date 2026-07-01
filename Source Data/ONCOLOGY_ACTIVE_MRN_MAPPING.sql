CREATE OR REPLACE TABLE opsanalytics_adb_workspace01.oncology.oncology_active_mrn_mapping AS
SELECT DISTINCT MRN, 'Yes' AS ACTIVE_MRN
FROM opsanalytics_adb_workspace01.oncology.oncology_access_base
WHERE APPT_STATUS = 'Arrived'
  AND ASSOCIATIONLISTA = 'Treatment'
  AND APPT_DTTM >= DATE_FORMAT(add_months(current_date(), -3), 'yyyy-MM-01');