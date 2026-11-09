# Tableau ETL parity review

Checked 2026-11-09. Legacy comparator: [`Oncology_Data_Pull/main/tableau/data_pull_tableau.Rmd`](https://github.com/MSHS-OAO/Oncology_Data_Pull/blob/main/tableau/data_pull_tableau.Rmd). Replacement: this repository's `greg` branch, based on `development`. The `tableau/manifest.json` names `data_pull_tableau.Rmd` as its primary Rmd. The legacy Tableau script, rather than the repository's root `main.Rmd`, defines the dashboard tables.

## Code review

| Area | Current `greg` implementation | Verification status |
| --- | --- | --- |
| Access base | `oncology_access_bronze` joins the source and mappings; `oncology_access_silver` applies the legacy date window, LOS exclusion, visit-key deduplication, derived fields, and null fills. `LOS_CODE`, mapped `PRC_NAME`, `DEPARTMENT_TYPE`, `ASSOCIATIONLISTR`, and `totalRows` are carried through. | Code path reviewed; output data not compared. |
| Dashboard output | `oncology_access_gold` applies the department/provider exception, joins `ACTIVE_MRN`, and adds `HOLIDAY` by appointment date. | Code path reviewed; `ACTIVE_MRN` rule and output data not verified. |

The legacy script also creates `ONCOLOGY_FILTERS_UPDATED_TABLEAU` and `ONCOLOGY_ACTIVE_TREATMENT_MRN_TABLEAU`. The user excluded those side outputs from the replacement scope on 2026-11-09; neither feeds the legacy dashboard table, and no dbt model is retained for them.

A static comparison of the legacy Tableau access-base `SELECT` and the silver model found the same set of 74 output column names, including the fields added by deduplication and the final projection. Gold adds `ACTIVE_MRN` and `HOLIDAY`, as the legacy dashboard output does. This checks names only; column order, types, and values still need runtime validation.

## Accepted type decision

User decision, 2026-11-09: keep the Databricks `PAT_ENC_CSN_ID` output as text. Oracle selects a numeric `NUMBER(18,0)` source value, while the Databricks copy declares `decimal(38,18)` and silver converts it through `BIGINT` to string. This output-type difference is intentional.

## Open parity checks

1. **Mapping versions.** The user's Oracle audit found duplicate join keys in `ONCOLOGY_DEPARTMENT_GROUPINGS_TABLEAU`, `ONCOLOGY_PRC_GROUPINGS_TABLEAU`, `ONCOLOGY_DISEASE_GROUPINGS_TABLEAU`, and `ONCOLOGY_ETHNICITY_GROUPER_TABLEAU`. User-provided full-table counts show 195 department rows / 148 distinct IDs in both systems (47 excess rows); 1,398 procedure rows / 1,390 distinct names in Oracle (8 excess) versus 1,398 / 1,388 in Databricks (10 excess); and 121 unique holiday dates in both. Counts for the disease and ethnicity duplicates and the corresponding Databricks mappings are pending. Compare duplicate keys and Tableau grouping values before choosing a current-row or effective-date rule. The dbt source `unique` tests for these four mappings are selected and will fail wherever duplicate keys remain.

   The Tableau folder also contains [`pcr_production_population.R`](https://github.com/MSHS-OAO/Oncology_Data_Pull/blob/main/tableau/pcr_production_population.R), which reads a procedure-mapping spreadsheet and calls `dbWriteTable(..., append = TRUE)` on `ONCOLOGY_PRC_GROUPINGS_TABLEAU`. It has no deduplication guard and supplies `PRC_NAME` plus `ASSOCIATIONLISTA`, `ASSOCIATIONLISTB`, and `ASSOCIATIONLISTT`; it does not supply `ASSOCIATIONLISTR`. Whether or when this helper ran is unverified, so it is possible provenance rather than an established cause of the observed duplicates.

   The user's Oracle department duplicate export (2026-11-09) contains 92 rows across 45 duplicated `DEPARTMENT_ID` values: 43 IDs have two rows and two IDs have three rows, yielding 47 excess rows. Among these IDs, 43 have different combinations of `DEPARTMENT_NAME`, `DEPARTMENT_TYPE`, and `SITE` (41 differ in name, seven in site, none in type); two repeat the same mapping values. `DATE_ADDED` does not differ within any duplicate ID, so selecting the latest date cannot resolve them. This creates intermediate join fanout for appointments using those IDs. The legacy `ROW_NUMBER()` partitions by source visit fields and keeps one row, so these department duplicates alone do not multiply rows in `ONCOLOGY_ACCESS_TABLEAU`. The tie ordering uses the same visit fields and cannot choose a consistent mapping row; department names and sites in the final table can vary. The number of affected appointments and whether Databricks duplicates the same IDs remain unverified.
2. **`ACTIVE_MRN`.** Legacy gold joins Oracle view `OAO_PRODUCTION.ONCOLOGY_ACTIVE_MRN_MAPPING_TABLEAU`. Oracle metadata shows that view depends on `ONCOLOGY_ACCESS_BASE_TABLEAU`, but its SQL definition has not been reviewed. The dbt `mapping_active_mrn` model uses arrived treatment appointments in a rolling three-month window. Do not assume these rules match.
3. **Ethnic background.** Oracle `ONCOLOGY_ETHNIC_BACKGROUND_PULL` is a view depending on `ETHNIC_BACKGROUND` and `ZC_ETHNIC_BKGRND`. dbt `mapping_ethnic_background` rebuilds values from Databricks copies of those tables. The Oracle aggregation definition and value parity are unverified.
4. **Source freshness.** `datahub_dev_bronze.datahub_clarity.mv_dm_patient_access` is a stored Databricks copy of the Oracle access source; its row scope and refresh status are unverified. Compare source counts and latest source dates for the same run cutoff before claiming output parity.
5. **Job branch.** The user-provided staging job YAML points to Git branch `staging`, so it does not run `greg` automatically. It writes dbt models to `oncology_staging`; the preceding notebook writes its mapping output to the shared `oncology` schema.

## Aggregate output check

Run after rebuilding the legacy and replacement outputs for the same cutoff. These queries return no patient-level rows. The access base keeps one row per visit key (`MRN`, `APPT_DTTM`, `APPT_TYPE`, `EPIC_PROVIDER_ID`, `APPT_STATUS`); verify that the later `ACTIVE_MRN` join does not multiply rows. The ETL selects source rows when either `CONTACT_DATE` or `APPT_MADE_DTTM` falls from 2019-01-01 through the day before the run. Because the filter is not on `APPT_DTTM`, the output may contain future appointment dates. Use `row_count` as the denominator for rates calculated from the counts below.

Oracle:

```sql
SELECT COUNT(*) AS row_count,
       COUNT(DISTINCT PAT_ENC_CSN_ID) AS distinct_encounter_count,
       SUM(CASE WHEN PAT_ENC_CSN_ID IS NULL THEN 1 ELSE 0 END) AS null_encounter_count,
       SUM(CASE WHEN PRC_NAME IS NULL THEN 1 ELSE 0 END) AS unmatched_procedure_count,
       SUM(CASE WHEN DEPARTMENT_TYPE IS NULL THEN 1 ELSE 0 END) AS missing_department_type_count,
       SUM(CASE WHEN HOLIDAY IS NOT NULL THEN 1 ELSE 0 END) AS holiday_row_count,
       SUM(CASE WHEN ACTIVE_MRN IS NOT NULL THEN 1 ELSE 0 END) AS active_mrn_row_count,
       MIN(APPT_DTTM) AS first_appointment,
       MAX(APPT_DTTM) AS last_appointment
FROM OAO_PRODUCTION.ONCOLOGY_ACCESS_TABLEAU;
```

Databricks staging, after running a job against `greg`:

```sql
SELECT COUNT(*) AS row_count,
       COUNT(DISTINCT pat_enc_csn_id) AS distinct_encounter_count,
       SUM(CASE WHEN pat_enc_csn_id IS NULL THEN 1 ELSE 0 END) AS null_encounter_count,
       SUM(CASE WHEN prc_name IS NULL THEN 1 ELSE 0 END) AS unmatched_procedure_count,
       SUM(CASE WHEN department_type IS NULL THEN 1 ELSE 0 END) AS missing_department_type_count,
       SUM(CASE WHEN holiday IS NOT NULL THEN 1 ELSE 0 END) AS holiday_row_count,
       SUM(CASE WHEN active_mrn IS NOT NULL THEN 1 ELSE 0 END) AS active_mrn_row_count,
       MIN(appt_dttm) AS first_appointment,
       MAX(appt_dttm) AS last_appointment
FROM opsanalytics_adb_workspace01.oncology_staging.oncology_access_gold;
```

Matching totals are a first check, not proof of row or value parity. Review differences by appointment month and mapping status before accepting the replacement.
