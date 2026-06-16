CREATE OR REPLACE TABLE opsanalytics_adb_workspace01.oncology.oncology_access AS
SELECT 
    a.*, 
    b.ACTIVE_MRN 
FROM opsanalytics_adb_workspace01.oncology.oncology_access_base a
LEFT JOIN opsanalytics_adb_workspace01.oncology.oncology_active_mrn_mapping b
    ON a.MRN = b.MRN
WHERE a.DEPARTMENT_ID != 8849025

UNION ALL

SELECT 
    a.*, 
    b.ACTIVE_MRN 
FROM opsanalytics_adb_workspace01.oncology.oncology_access_base a
LEFT JOIN opsanalytics_adb_workspace01.oncology.oncology_active_mrn_mapping b
    ON a.MRN = b.MRN
WHERE a.DEPARTMENT_ID = 8849025 AND 
      a.EPIC_PROVIDER_ID = '184137';