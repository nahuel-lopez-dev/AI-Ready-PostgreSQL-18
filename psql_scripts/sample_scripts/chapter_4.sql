/* ============================================================================

                        Code samples for Chapter 4

============================================================================ */ 

/*

Section: Authorization, REVOKE, GRANT, and the Principle of Least Privilege 

*/

--- create a group for all product management users 
CREATE ROLE product_management; 
 
--- create a user 
CREATE USER jim_miller  
    IN ROLE product_management; 
 
--- create a sub-group to manage prices 
CREATE ROLE product_price_management 
    INHERIT --- automatically inherits the privileges of the product management 
    IN ROLE product_management;   
 
--- create a user who has the privileges of the price manager  
--- and implicitly inherits other rights from the product management group role 
CREATE USER jane_doe  
    IN ROLE product_price_management; 


-------------------------------------------------------------------------------
REVOKE CONNECT ON DATABASE ecommerce_reference_data FROM PUBLIC; 
REVOKE USAGE ON SCHEMA internal,product, api FROM PUBLIC; 
REVOKE EXECUTE ON PROCEDURE api.update_current_price_flags FROM PUBLIC; 
REVOKE EXECUTE ON FUNCTION  
    api.manage_product_price,  
    api.manage_product,  
    api.manage_brand,  
    api.manage_category  
    FROM PUBLIC; 


-------------------------------------------------------------------------------


--- allow the group role to connect to the reference data service 
--- product_price_management will automatically inherit that privilege 
GRANT CONNECT ON DATABASE ecommerce_reference_data TO product_management; 
 
--- allow the group role to see all the objects in the API schema 
GRANT USAGE ON SCHEMA api TO product_management; 
--- allow read access on all tables and views in the API schema  
GRANT SELECT ON ALL TABLES IN SCHEMA api TO product_management; 
 
--- only members of the product_price_management role can call the  
--- api.manage_product_price functions to change pricing 
--- these functions run with the SECURITY DEFINER property 
GRANT EXECUTE ON FUNCTION  
    api.manage_product_price,  
    TO product_price_management; 
GRANT EXECUTE ON PROCEDURE  
    api.update_current_price_flags  
    TO product_price_management;     


-------------------------------------------------------------------------------

/*

Section: Auditing

*/

CREATE EXTENSION pgaudit; 
CREATE ROLE auditor; 
ALTER SYSTEM SET pgaudit.role = 'auditor'; 
 
-- log all ddl operations on all objects 
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
ALTER DATABASE SET audit.pgaudit.log ='execute'; 

