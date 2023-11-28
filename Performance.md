# Performance Results

Run on a Supabase free instance.
100k and 1M row table protected with various RLS.  
All times in Msec

See the test.sql for some info on table and tests.
Note the test.sql is just various tables,policies and jwt claims code for doing a variety of tests.
It is not a complete packaged test suit.  
See https://github.com/GaryAustin1/RLS-Performance for better performance analysis with improved RLS methods used here.  

###100k rows
custom-properties table RLS of versus JWT with get_my_claim in auth.app_metadata.  

|RLS| SQL | REST API |
|--|-----|----------|
|(select user_roles.user_has_property('Teacher'))| 13  | 30 |
|(select get_my_claim('role')::text) = '"Teacher"'| 17  | 29|

###1M rows
custom-properties table RLS of versus JWT with get_my_claim in auth.app_metadata.  

|RLS|SQL|REST API|
|--|--|--|
|(select user_roles.user_has_property('Teacher'))|133|315|
|(select get_my_claim('role')::text) = '"Teacher"'|166|290|

###1M rows with 900k for role Student, 100K for Teacher and 1000 for Dean   
Only has a user with 1 role and change the role for each test.        
I would not recommend this method using jwt if over 10 roles per user.    
NO INDEXING on for_role column.   

Uses RLS policies:  
for_role = any (array(select user_roles.get_user_properties()))  
for_role = (select get_my_claim('role')->>0)  

| RLS                           | SQL-table | SQL-jwt | REST API-table | REST API-jwt |
|-------------------------------|-----------|---------|----------------|--------------|
| Dean (1k)                     | 127       | 112     | 135            | 145          |
| Teacher (100K)                | 169       | 131     | 427            | 425          |
| Student (900K) API limit 100k | 231 |208|302|292|
| Student (900k) API limit 1M   |231|208|2840|2704|

### 100k rows  without RLS tuning
This is why jwt method became popular.  

|RLS| SQL  | REST API |
|--|------|----------|
|select user_roles.user_has_property('Teacher')| 1874 | 3005     |
|select get_my_claim('role')::text = '"Teacher"'| 195  | 1158     |
