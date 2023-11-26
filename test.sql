-- This file is for testing table based roles versus jwt based roles peformance.
-- Right now most setup is being done by hand for user id, properties, etc.

drop table if exists teacher_posts cascade;
create table teacher_posts (
                               id            serial    primary key,
                               creator_id    uuid      not null,
                               title         text      not null,
                               body          text      not null,
                               publish_date  date      not null     default now(),
                               audience      uuid[]    null -- many to many table omitted for brevity
);
alter table teacher_posts ENABLE ROW LEVEL SECURITY;
INSERT INTO teacher_posts (creator_id,title,body)
select uuid_generate_v4(),'title-'||x,'body-'||x
from generate_series(1, 100000) x;

create policy "Teacher role can read these posts"
    on teacher_posts
    for select
                   using (
                   --  (select get_my_claim('role')::text) = '"Teacher"'
                   --  (select user_roles.user_has_property('Teacher'))
                   (select user_roles.user_property_in('{"Teacher","Staff"}'))
                   );


-- generate a user with teacher role
-- create user
-- add teacher role to roles table
-- add teacher role to app metadata

-- generate a custom_claims function for checking role.
CREATE OR REPLACE FUNCTION get_my_claim(claim TEXT) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
AS $$
select
    coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb -> 'app_metadata' -> claim, null)
        $$;



update auth.users set raw_app_meta_data =
                              raw_app_meta_data ||
                              json_build_object('role', 'Teacher')::jsonb where id = 'd7124d4a-22e7-49d7-87a4-55ad09cd5783'::UUID;

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"d7124d4a-22e7-49d7-87a4-55ad09cd5783", "app_metadata":{"role":"Teacher"}}';
--select user_roles.user_properties_match('{"Teacher"}');
explain analyze SELECT * FROM teacher_posts;

set session role postgres;
