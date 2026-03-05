
/*
================================================================================
 SQL script file to set up analytics star schemas in the central_analytics database.
================================================================================
  OWNER: Superuser
  PURPOSE: Explain how to create a star schemas for reporting
           on the central_analytics database.
  Details:
            * load the auxiliary data and functions into schema 'auxiliary'
                - tables for state and territory codes and names
                - table for sales organization employees
                - function to parse zip codes and postal codes
            * create three star schemas:
                - view-only schema 'vo_analytics' using views only
                - materialized-view based schema 'mv_analytics'
                - trigger-table based schema 'tt_analytics'
            * each schame has
                - 3 dimensions: date, product, customer location
                - 1 fact table: sales     

  This script is executed as part of the master setup script in
  psql_scripts/database_definitions/master_setup.sql                               
================================================================================
*/

\echo 'Setting up central_analytics star schemas...'
\i database_definitions/central_analytics_stars/auxiliary_definitions.sql
\i database_definitions/central_analytics_stars/vo_analytics.sql
\i database_definitions/central_analytics_stars/mv_analytics.sql
\i database_definitions/central_analytics_stars/tt_analytics.sql

 





