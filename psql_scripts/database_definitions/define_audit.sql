/* 
================================================================================
  PSQL SCRIPT TO ILLUSTRATE AUDIT DEFINITIONS
================================================================================
  OWNER: Superuser
  PURPOSE: Creates the audit definitions for the eCommerce Sample Application
           databases. 
  PREREQUSITES: The pgAudit extension must be installed
               and the role 'audit' must exist.
          
================================================================================

The following are samples for illustration purpose only.

We will define sample audits for the following operations:

1) All DDL in all databases

eCommerce Reference Data

1) all changes to the product brand and price definitions
2) all function and stored procedure calls

east/west eCommerce Services
1) changes of the inventory information 
2) all function and stored procedure calls

Analytics Service
1) access of any of the analytics queries in central analytics    

*/

\c postgres

ALTER SYSTEM SET pgaudit.role = 'auditor';

ALTER SYSTEM SET audit.pgaudit.log ='ddl';

\c ecommerce_reference_data

-- use object-level auditing for DML on product related tables
GRANT INSERT, UPDATE, DELETE
    ON 
        product.product,
        product.brand,
        product.category,
        product.product_variant,
        product.product_variant_price
    TO auditor;

-- pgAudit does not support object-level auditing for functions or procedures
-- audit all function and procedure calls for this database
ALTER DATABASE SET audit.pgaudit.log ='function';


\c east_ecommerce_data

-- use object-level auditing for DML on inventory information
GRANT INSERT, UPDATE, DELETE 
    ON inventory.product_variant_inventory;

-- pgAudit does not support object-level auditing for functions or procedures
-- audit all function and procedure calls for this database
ALTER DATABASE SET audit.pgaudit.log ='function';    

\c west_ecommerce_data
-- use object-level auditing for DML on inventory information
GRANT INSERT, UPDATE, DELETE 
    ON inventory.product_variant_inventory;
-- pgAudit does not support object-level auditing for functions or procedures
-- audit all function and procedure calls for this database
ALTER DATABASE SET audit.pgaudit.log ='function';    

\c central_analytics

--- to be added when the central analytics API is defined






