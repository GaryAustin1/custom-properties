-- Right now the schema is hard coded to user_groups....
-- NOT MUCH OF THIS IS TESTED YET!!!!!!!!!!!!!!!
-- This is very similar to properties but uses id's to allow changing names and individual group admin flag.

DROP SCHEMA IF EXISTS user_groups cascade;
CREATE SCHEMA user_groups;
GRANT USAGE ON SCHEMA user_groups TO postgres, authenticated, service_role;

CREATE TABLE user_groups.group_names (
    group_id serial primary key,
    group_name text unique
);
ALTER TABLE user_groups.group_names ENABLE ROW LEVEL SECURITY;

-- Adding admin role.  Postgres,service_role and an authenticated user with this role in the roles table can manage the table.
INSERT INTO user_groups.group_names (group_name) VALUES
    ('GroupAdmin');

CREATE TABLE user_groups.user_groups (
                                            user_id UUID not null,
                                            group_id int4,
                                            group_admin boolean,
                                            constraint fk_groupname foreign key (group_id) references user_groups.group_names(group_id) on update cascade on delete cascade,
                                            constraint fk_user foreign key (user_id) references auth.users(id) on delete cascade, --  If you have a profile table you can link to that instead
                                            primary key (user_id,group_id)
);
ALTER TABLE user_groups.user_groups ENABLE ROW LEVEL SECURITY;
GRANT ALL ON user_groups.user_groups TO postgres,service_role,authenticated;   -- note RLS also protects this table

-- These are example functions for use in RLS.
-- They depend on the auth.uid() of the user so are secure.
-- They must be called like (select user_groups.user_has_group_id(group_id)) with the outer parentheses and select or the performance will be greatly impacted.
-- See https://github.com/GaryAustin1/RLS-Performance for more info on performance of functions in RLS.

-- Match a group id for current user
CREATE FUNCTION user_groups.user_has_group_id(_group_id int4) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER SET search_path = user_groups,public
AS $$
select exists (select 1 from user_groups where user_id = auth.uid() and _group_id = group_id);
$$;

-- get group id for group name
CREATE FUNCTION user_groups.get_id_from_group_name(_group_name text) RETURNS int4
    LANGUAGE SQL SECURITY DEFINER SET search_path = user_groups,public
AS $$
select group_id from group_names where _group_name= group_name;
$$;

-- is this user admin for this group
CREATE FUNCTION user_groups.user_is_this_group_admin(_group_id int4) RETURNS boolean
    LANGUAGE SQL SECURITY DEFINER SET search_path = user_groups,public
AS $$
select exists (select 1 from user_groups where user_id = auth.uid() and group_admin = true);
$$;

-- get all group ids the current user has
-- called as (col = any (array(select user_groups.get_user_group_ids())) in RLS
CREATE FUNCTION user_groups.get_user_group_ids() RETURNS int4[]
    LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = user_groups,public
AS $$
begin
    return array (select group_id from user_groups where user_id = auth.uid());
end;
$$;


-- Typical policies to protect user_groups table and allow admin of it.
-- postgres and service role have access by default.
-- If you want to block service role you would need to remove grants for that role from the table.
CREATE policy "User can read own rows"
    ON user_groups.user_groups
    FOR select
    TO authenticated
    USING (auth.uid()=user_id);
CREATE policy "All Groups Admin can do all operations"
    ON user_groups.user_groups
    FOR all
    TO authenticated
    USING ((select user_groups.user_has_group_id(user_groups.get_id_from_group_name('GroupAdmin'))));
CREATE policy "Group Admin can do all operations on Group"
    ON user_groups.user_groups
    FOR all
    TO authenticated
    USING ((select user_groups.user_is_this_group_admin(group_id)))
