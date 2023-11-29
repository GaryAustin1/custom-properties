### TLE for custom-roles

Please see https://github.com/GaryAustin1/custom-properties for more info.

This is a role specific version of custom-properties.  It runs in public or any schema you select.

You can use the TLE install method to install custom-roles.  
You need to run the SQL here to install the TLE installer: [dbdev](https://supabase.github.io/dbdev/install-in-db-client/)  
Once you have the installer loaded:

Install the TLE using the SQL editor:
```sql
select dbdev.install('garyaustin-custom_roles');
create extension "garyaustin-custom_roles"
    schema public
    version '0.0.2';
```

Two tables will be created in the schema.  
custom_role_names -- Has a role admin "role" added.  Add your role names in the table UI or with SQL inserts.  
custom_user_roles -- You insert user UUID, role_name pairs into this table for one or more roles per user.

Five functions will be created in the schema.  
user_has_role('Teacher') - returns boolean   
user_role_in('{"Teacher","Staff"}') - returns boolean - {} is string format for array in Postgres  
user_roles_match('{"Teacher","Staff"}') - returns boolean - must match all roles in array  
get_user_roles() - returns array - if user has over 1000 roles performance should be studied    
custom_roles_update_to_app_metadata() - trigger function - updates app_metadata with an array of roles for user

Check the main readme for more info on how to add policies to your tables.  
You MUST use the example methods for calling the functions to have performant results.

If you want your user JWTs updated with your role data, please enable the trigger custom_role_change.  
This can be done in the UI or with SQL.

All management of your roles is done with standard table selects/inserts/updates/deletes and views.  
The custom_user_roles table can only be updated by postgres, service_role and an authenticated user with the RoleAdmin role.  
Authenticated users can only read their own roles.  






