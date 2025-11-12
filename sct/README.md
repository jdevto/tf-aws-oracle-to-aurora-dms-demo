# AWS Schema Conversion Tool (SCT)

This directory contains the converted schema from Oracle to PostgreSQL.

## Steps

1. Install AWS SCT locally
2. Connect to your Oracle source database
3. Convert the schema to PostgreSQL format
4. Export the converted SQL to `converted_schema.sql` in this directory
5. The schema will be automatically applied when you run `terraform apply` (if the file exists)

## Oracle CDC Prerequisites

Before running DMS, ensure your Oracle database is configured for CDC:

1. Enable supplemental logging:

   ```sql
   ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
   ```

2. Enable archiving:

   ```sql
   ALTER SYSTEM SET ARCHIVE_LOG_DEST_1='LOCATION=/path/to/archive';
   ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_1=ENABLE;
   ```

3. Create DMS user with required privileges:

   ```sql
   CREATE USER dms_user IDENTIFIED BY <password>;
   GRANT CONNECT TO dms_user;
   GRANT SELECT ANY TRANSACTION TO dms_user;
   GRANT SELECT ON SYS.DBA_LOGMNR_CONTENTS TO dms_user;
   GRANT EXECUTE ON SYS.DBMS_LOGMNR TO dms_user;
   GRANT EXECUTE ON SYS.DBMS_LOGMNR_D TO dms_user;
   ```

## Schema File

Place your converted schema SQL in `converted_schema.sql`. The file should include:

- Table definitions
- Views
- Indexes
- Any other database objects
