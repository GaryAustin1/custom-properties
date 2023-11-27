-- This file is for testing table based roles versus jwt based roles peformance.
-- Right now most setup is being done by hand for user id, properties, etc.

DROP TABLE IF EXISTS test_posts cascade;
CREATE TABLE test_posts (
                               id            serial    primary key,
                               creator_id    uuid      not null,
                               title         text      not null,
                               body          text      not null,
                               for_role      text      not null,
                               publish_date  date      not null     default now()
);
ALTER TABLE test_posts ENABLE ROW LEVEL SECURITY;
INSERT INTO test_posts (creator_id,title,body,for_role)
select uuid_generate_v4(),'title-'||x,'body-'||x,'Student'
from generate_series(1, 90000) x;
INSERT INTO test_posts (creator_id,title,body,for_role)
select uuid_generate_v4(),'title-'||x,'body-'||x,'Teacher'
from generate_series(90000, 100000) x;
-- change policies here for testing

DROP POLICY IF EXISTS "Teacher role can read these posts" on test_posts;
CREATE POLICY "Teacher role can read these posts"
    on test_posts
    for select
    using (
        --  (select get_my_claim('role')::text) = '"Teacher"'
        --(select user_roles.user_has_property('Teacher'))
        -- (select user_roles.user_property_in('{"Teacher","Staff"}'))
        for_role = any (array(select user_roles.get_user_properties()))
    );
-- ADD roles for test
INSERT INTO user_roles.property_names(property_name) VALUES ('Teacher'),('Student'),('Administrator'),('Coach'),('Dean');
--Using existing UUIDs in my test instance
INSERT INTO user_roles.user_properties (user_id,property) VALUES
 ('d7124d4a-22e7-49d7-87a4-55ad09cd5783'::UUID,'Teacher'),
 ('c8fc722a-22fb-4483-aab7-6c2be88bc03c'::UUID,'Student'),
 ('2eaa730d-bbb0-478c-bde6-d51890e8bd28'::UUID,'Student'),
 ('679e25e3-5402-4c9f-87b3-793af97540ae'::UUID,'Student'),
 ('722498ac-0a23-4f94-b3c6-bed52f1d7f3d'::UUID,'Dean');

-- add teacher role to app metadata (to do)

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
set request.jwt.claims to '{"role":"authenticated", "sub":"722498ac-0a23-4f94-b3c6-bed52f1d7f3d", "app_metadata":{"role":"Teacher"}}';
--select user_roles.user_properties_match('{"Teacher"}');
explain analyze SELECT * FROM teacher_posts;

set session role postgres;
