-- This is a hardcoded version of custom_properties just for roles.
--  NOT CHECKED YET

-- This table is just used to enforce a set of names for properties.  It is a more flexible approach than Postgres enums.
CREATE TABLE custom_role_names (
    role_name text primary key
);
ALTER TABLE custom_role_names ENABLE ROW LEVEL SECURITY;

-- Adding admin role.  Postgres,service_role and an authenticated user with this property in the properties table can manage the table.
INSERT INTO custom_role_names (role_name) VALUES
    ('RoleAdmin');

CREATE TABLE custom_user_roles (
                                            user_id UUID not null,
                                            role text ,
                                            constraint fk_rolename foreign key (role) references custom_role_names(role_name) on update cascade on delete cascade,
                                            constraint fk_user foreign key (user_id) references auth.users(id) on delete cascade, --  If you have a profile table you can link to that instead
                                            primary key (user_id,role)
);
ALTER TABLE custom_user_roles ENABLE ROW LEVEL SECURITY;
--GRANT ALL ON custom_user_properties TO postgres,service_role,authenticated;   -- note RLS also protects this table

-- These are example functions for use in RLS.
-- They depend on the auth.uid() of the user so are secure.
-- They must be called like (select user_has_role('Role')) with the outer parentheses and select or the performance will be greatly impacted.
-- See https://github.com/GaryAustin1/RLS-Performance for more info on performance of functions in RLS.

-- Match a role for the current user
CREATE FUNCTION user_has_role(_role text) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$
select exists (select 1 from custom_user_roles where user_id = auth.uid() and role = _role);
$$;

-- Match any roles in array for the current user
CREATE FUNCTION user_role_in(_roles text[]) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER STABLE SET search_path = public
AS $$
select exists (select 1 from custom_user_roles where user_id = auth.uid() and role = any (_roles));
$$;

-- Match all roles in array for the current user
CREATE FUNCTION user_roles_match(_roles text[]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
declare matches int;
begin
    select count(*) into matches from custom_user_roles where auth.uid() = user_id and role = any (_roles);
    return matches = array_length(_roles,1);
end;
$$;

-- get all roles the current user has
-- called as (col = any (array(select get_user_roles())) in RLS

CREATE FUNCTION get_user_roles() RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
begin
    return array (select role from custom_user_roles where user_id = auth.uid());
end;
$$;
-- If for some reason you want the JWT and associated user object to also reflect the roles(s) for the user then you can use a trigger function.
-- The JWT will reflect the current roles after it is refreshed from the client.
-- WARNING by default this codes sets the role type to the schema name
-- The trigger is initially DISABLED IN THE CODE so as to not pollute the jwt.
CREATE FUNCTION custom_roles_update_to_app_metadata() returns trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
as $$
declare
    _roles text[];
    _id UUID;
begin
    if (TG_OP = 'DELETE')  then _id = old.user_id;
    else _id = new.user_id;
    end if;
    select array_agg(role) into _roles from custom_user_roles where user_id = new.user_id;
    update auth.users set raw_app_meta_data = raw_app_meta_data || json_build_object('user_roles', _roles)::jsonb where id = new.user_id;
    return new;
end;
$$;
CREATE TRIGGER on_role_change
    after insert or update or delete on custom_user_roles
    for each row execute function custom_roles_update_to_app_metadata();
ALTER TABLE custom_user_roles DISABLE TRIGGER on_role_change; -- Enable the trigger in the Dashboard or remove this if desired

-- Typical policies to protect user_roles table and allow admin of it.
-- postgres and service role have access by default.
-- If you want to block service role you would need to remove grants for that role from the table.
CREATE policy "User can read own rows"
    ON custom_user_roles
    FOR select
    TO authenticated
    USING (auth.uid()=user_id);
CREATE policy "RoleAdmin can do all operations"
    ON custom_user_roles
    FOR all
    TO authenticated
    USING ((select user_has_role('RoleAdmin')));

