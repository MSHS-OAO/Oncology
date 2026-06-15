create or replace table ONCOLOGY_ETHNIC_BACKGROUND as
SELECT
  eb.PAT_ID,
  LISTAGG(zceb.NAME, '; ') WITHIN GROUP (ORDER BY eb.PAT_ID) as ETHNIC_BACKGROUND
FROM 
  datahub_dev_bronze.datahub_clarity.ethnic_background eb
  INNER JOIN datahub_dev_bronze.datahub_clarity.zc_ethnic_bkgrnd zceb ON eb.ETHNIC_BKGRND_C = zceb.ETHNIC_BKGRND_C
GROUP BY
  eb.PAT_ID