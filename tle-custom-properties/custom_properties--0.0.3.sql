-- Note the schema name should reflect the type of property this is.  For example user_roles, user_groups, user_teams, user_claims.
-- The schema name is also used as the default value in the OPTIONAL jwt app_metadata update trigger for the property name.
-- This trigger is disabled by default.
-- You may want to change user_id fk to your profile table user_id if you have by dropping and adding the fk_user constraint.

GRANT USAGE ON SCHEMA @extschema@ TO postgres, authenticated, service_role;

-- This table is just used to enforce a set of names for properties.  It is a more flexible approach than Postgres enums.
CREATE TABLE @extschema@.property_names (
    property_name text primary key
);
ALTER TABLE @extschema@.property_names ENABLE ROW LEVEL SECURITY;

-- Adding admin role.  Postgres,service_role and an authenticated user with this property in the properties table can manage the table.
INSERT INTO @extschema@.property_names (property_name) VALUES
    ('PropertyAdmin');

CREATE TABLE @extschema@.user_properties (
                                            user_id UUID not null,
                                            property text ,
                                            constraint fk_propertyname foreign key (property) references @extschema@.property_names(property_name) on update cascade on delete cascade,
                                            constraint fk_user foreign key (user_id) references auth.users(id) on delete cascade, --  If you have a profile table you can link to that instead
                                            primary key (user_id,property)
);
ALTER TABLE @extschema@.user_properties ENABLE ROW LEVEL SECURITY;
GRANT ALL ON @extschema@.user_properties TO postgres,service_role,authenticated;   -- note RLS also protects this table

-- These are example functions for use in RLS.
-- They depend on the auth.uid() of the user so are secure.
-- They must be called like (select user_roles.user_has_property('PropertyName')) with the outer parentheses and select or the performance will be greatly impacted.
-- See https://github.com/GaryAustin1/RLS-Performance for more info on performance of functions in RLS.

-- Match a property for the current user
CREATE FUNCTION @extschema@.user_has_property(_property text) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER SET search_path = @extschema@,public
AS $$
select exists (select 1 from user_properties where user_id = auth.uid() and property = _property);
$$;

-- Match any properties in array for the current user
CREATE FUNCTION @extschema@.user_property_in(_properties text[]) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER STABLE SET search_path = @extschema@,public
AS $$
select exists (select 1 from user_properties where user_id = auth.uid() and property = any (_properties));
$$;

-- Match all properties in array for the current user
CREATE FUNCTION @extschema@.user_properties_match(_properties text[]) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = @extschema@,public
AS $$
declare matches int;
begin
    select count(*) into matches from user_properties where auth.uid() = user_id and property = any (_properties);
    return matches = array_length(_properties,1);
end;
$$;

-- get all properties the current user has
-- called as (col = any (array(select user_roles.get_user_properties())) in RLS

CREATE FUNCTION @extschema@.get_user_properties() RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = @extschema@,public
AS $$
begin
    return array (select property from user_properties where user_id = auth.uid());
end;
$$;
-- If for some reason you want the JWT and associated user object to also reflect the property(s) for the user then you can use a trigger function.
-- The JWT will reflect the current properties after it is refreshed from the client.
-- WARNING by default this codes sets the property type to the schema name
-- The trigger is initially DISABLED IN THE CODE so as to not pollute the jwt.
CREATE FUNCTION @extschema@.update_to_app_metadata() returns trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
as $$
declare
    _properties text[];
    _id UUID;
begin
    if (TG_OP = 'DELETE')  then _id = old.user_id;
    else _id = new.user_id;
    end if;
    select array_agg(property) into _properties from @extschema@.user_properties where user_id = _id;
    update auth.users set raw_app_meta_data = raw_app_meta_data || json_build_object('@extschema@', _properties)::jsonb where id = _id;
    return new;
end;
$$;
CREATE TRIGGER on_property_change
    after insert or update or delete on @extschema@.user_properties
    for each row execute function @extschema@.update_to_app_metadata();
ALTER TABLE @extschema@.user_properties DISABLE TRIGGER on_property_change; -- Enable the trigger in the Dashboard or remove this if desired

-- Typical policies to protect user_properites table and allow admin of it.
-- postgres and service role have access by default.
-- If you want to block service role you would need to remove grants for that role from the table.
CREATE policy "User can read own rows"
    ON @extschema@.user_properties
    FOR select
    TO authenticated
    USING (auth.uid()=user_id);
CREATE policy "PropertyAdmin can do all operations"
    ON @extschema@.user_properties
    FOR all
    TO authenticated
    USING ((select @extschema@.user_has_property('PropertyAdmin')));


