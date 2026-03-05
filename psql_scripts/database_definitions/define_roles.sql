/* 
================================================================================
  PSQL SCRIPT TO DEFINE ROLES AND USERS FOR THE ECOMMERCE SAMPLE APPLICATION
================================================================================
  OWNER: Superuser
  PURPOSE: Creates the roles and users for the eCommerce Sample Application
           databases. 
    PREREQUSITES: None
          
================================================================================

*/
-- master_dba will own the databases and be able to create other roles
DROP ROLE IF EXISTS master_dba;
CREATE ROLE master_dba WITH
    CREATEDB
    CREATEROLE
    LOGIN
    PASSWORD 'postgres';

--- this role will be used to create, schemas, tables, procedures and functions
--- master_dba will assign the create role to the database after creating
DROP ROLE IF EXISTS application_dba;
CREATE ROLE application_dba WITH
    LOGIN
    PASSWORD 'postgres';

--- this role will be used to create and run the replications
DROP ROLE IF EXISTS replication_user;
CREATE ROLE replication_user WITH
    LOGIN
    PASSWORD 'postgres';    

-- this role will define and manage products and brands
DROP ROLE IF EXISTS product_manager;
CREATE ROLE product_manager WITH
    LOGIN 
    PASSWORD 'postgres';
-- this role will manage product variant pricing
DROP ROLE IF EXISTS product_price_manager;
CREATE ROLE product_price_manager WITH
    LOGIN 
    PASSWORD 'postgres';
-- this role will manage inventory levels
DROP ROLE IF EXISTS inventory_manager;
CREATE ROLE inventory_manager WITH
    LOGIN
    PASSWORD 'postgres';

-- this role will be used by the eCommerce application
DROP ROLE IF EXISTS ecommerce_application;
CREATE ROLE ecommerce_application WITH
    LOGIN
    PASSWORD 'postgres';

-- this role will be used by analysts to access central analytics
DROP ROLE IF EXISTS analyst;
CREATE ROLE analyst WITH
    LOGIN
    PASSWORD 'postgres';

--- this role will be used by pgAudit
DROP ROLE IF EXISTS audit;
CREATE ROLE audit;    


