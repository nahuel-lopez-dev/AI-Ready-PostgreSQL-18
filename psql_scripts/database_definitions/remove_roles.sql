
/* 
================================================================================
  PSQL SCRIPT TO DROP ROLES AND USERS CREATED FOR THE ECOMMERCE SAMPLE APPLICATION
================================================================================
  OWNER: Superuser
  PURPOSE: Drops the roles and users for the eCommerce Sample Application
           databases. 
    PREREQUSITES: None
          
================================================================================
*/
DROP ROLE IF EXISTS master_dba;

DROP ROLE IF EXISTS application_dba;

DROP ROLE IF EXISTS replication_user;

DROP ROLE IF EXISTS product_manager;

DROP ROLE IF EXISTS product_price_manager;

DROP ROLE IF EXISTS inventory_manager;

DROP ROLE IF EXISTS ecommerce_application;

DROP ROLE IF EXISTS analyst;

DROP ROLE IF EXISTS audit;
  