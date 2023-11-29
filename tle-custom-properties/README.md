### TLE for custom-properties

Please see https://github.com/GaryAustin1/custom-properties for more info.

You can use the TLE install method to install custom-properties.  
You need to run the SQL here to install the TLE installer: [dbdev](https://supabase.github.io/dbdev/install-in-db-client/)  
Once you have the installer loaded:

Create a custom schema to load a copy of custom-properties into.   
Note this schema name should be meaningful like `roles`, `user_roles`, `custom_teams`, etc.  
The schema name will be used to call functions from RLS and as the name for the property in the app_metadata jwt if you decide to use that.  

In the SQL editor:
```sql
create extension user_roles;
```

The TLE will assign basic grants to service_role, authenticated and postgres roles.

Next install the TLE using the SQL editor:
```sql
select dbdev.install('garyaustin-custom_properties');
create extension "garyaustin-custom_properties"
    schema user_roles
    version '0.0.1';
```

Two tables will be created in the schema.  
property_names -- Has a property admin "role" added.  Add your property names in the table UI or with SQL inserts.  
user_properties -- You insert user UUID, property_name pairs into this table for one or more properties per user.  

Five functions will be created in the schema.  
user_has_property('Teacher') - returns boolean   
user_property_in('{"Teacher","Staff"}') - returns boolean - {} is string format for array in Postgres  
user_properties_match('{"Teacher","Staff"}') - returns boolean - must match all roles in array  
get_user_properties() - returns array - if user has over 1000 properties performance should be studied    
update_to_app_metadata() - trigger function - updates app_metadata with an array of properties for user  

Check the main readme for more info on how to add policies to your tables.  
You MUST use the example methods for calling the functions to have performant results.  

If you want your user JWTs updated with your property data, please enable the trigger function found in the custom schema you created.
This can be done in the UI or with SQL.

All management of your properties is done with standard table selects/inserts/updates/deletes and views.  
The user_properties table can only be updated by postgres, service_role and an authenticated user with the PropertyAdmin property.  
Authenticated users can only read their own properties.  
If you desire to access or manage the properties from the API you need to use the Dashboard and goto API settings.
Add your new schema to make it available thru the API.  





