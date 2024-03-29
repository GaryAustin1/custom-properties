# custom-properties
Custom roles/teams/groups/claims using tables and a setof functions for RLS in Supabase environment.

Roles and Properties code seem in good shape.  Groups is still a work in progress.

The goals:
Show a table based approach to roles/claims management, then group management with individual group admins.  
Have RLS functions use the roles/claims. 
Compare the RLS performance of using a roles table versus using a JWT custom-claims approach.  See [Performance](https://github.com/GaryAustin1/custom-properties/blob/main/Performance.md)

The concept is to have a simple property name table and user properties table for each type of property desired.
All management of user properties is done thru standard table management of the user properties table.
RLS by default allows postgres, service_role and an authenticated user with an admin property in the table to manage the user properties.
If the schema is added to the API schemas in the dashboard then a user can read their own properties but only the admin roles can modify.  

Many have turned to using the app_metadata column in auth.users and the user JWT for roles and claims management.
This repository https://github.com/supabase-community/supabase-custom-claims is popular for this.
This was mainly driven by the slow performance of RLS with table joins versus a function checking the JWT.
Recent testing has shown that RLS performance of generic functions and table joins can be greatly improved.
This repository also looks at that.  

A roles/claims table also has the advantage of easier admin using direct table manipulation and views.
It also allows changes in claims and roles to immediately take effect versus waiting for the JWT to refresh  

The initial approach here uses a meaningful schema name for the type of property being used.
This is in part because the goal is to make this a TLE in dbdev.  
One could certainly rename the functions and tables as desired instead of using a schema name.  

If it is desired to automatically populate properties this can be done with a typical auth.users
trigger function on user creation by just inserting desired user/property pairs into the user properties table.  

The code also has an optional trigger function that will update Supabase app_metadata on any change to the user's properties in the user property table.
This json object will be named after the schema name in the current version.  

properties.sql is the main code to set up a property in schema.  Right now this is hard coded to user_roles schema.  
roles.sql is a version with hard coded function and table names using 'role'.  Can be installed in public schema.  
test.sql is sample code used to test performance of this method versus the typical custom-claims method which uses claims in the JWT as the RLS test.    
There are two TLE directories for a custom-properties and custom-roles version of this repository.  These are available from https://database.dev/.

The RLS functions are called like (note the examples here are from custom-properties installed in the user_roles schema):

`USING ( (select user_roles.user_has_property('Teacher') )`  
`USING ( (select user_roles.user_property_in('{"Teacher","Staff"}') )` {} is string format for array in Postgres  
`USING ( (select user_roles.user_properties_match('{"Teacher","Staff"}') )` must match all roles in array  
`USING ( role_column = any (array(select user_roles.get_user_properties())) )` if user has over 1000 properties performance should be studied  
`USING ( (select user_roles.user_has_property('PropertyAdmin') )` default property for admin of the properties  

It is CRITICAL TO CALL THEM IN THE FORMAT SHOWN to get fast performance.  The wrapping with parenthesis and select: `(select function())`.  

Example of roles:

![img1.png](images%2Fimg1.png)
  
![img_1.png](images/img_1.png)

![img_2.png](images/img_2.png)

Foreign key property types link enforces choices:
![img_3.png](images/img_3.png)

And the real winner with just using tables for roles, groups, etc. is being able to just use table/view operations as part of joins.
```sql
create  view
    public.student_view with (security_invoker = true) as
select
    u.user_id,
    u.property,
    p.name,
    p.email
from
    user_roles.user_properties u
        join user_profiles as p on p.user_id = u.user_id
where
    u.property = 'Student'::text;
```
Yields:
![students.png](images%2Fstudents.png)

And:
```sql
create  view
    public.college_staff_view with (security_invoker = true) as
select
    u.user_id,
    u.property,
    p.name,
    p.email
from
    user_roles.user_properties u
        join user_profiles as p on p.user_id = u.user_id
where
        u.property =any ('{"Dean","Teacher"}');
```
Gives:
![staff.png](images%2Fstaff.png)


### Custom-properties for managing groups in the works.    
Same general idea but have the property_names table use an id for primary and fk so that group names can change.   
Add a group_admin column in the user_properties table for individual group admin in addition to an over all group admin role.  
Don't support app_metadata reflection as large jwt's can cause session and performance issues as well cookie size problems.
 
![imgg1.png](images/imgg1.png)
