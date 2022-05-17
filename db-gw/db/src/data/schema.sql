drop schema if exists data cascade;
create schema data;
set search_path = data, public;

-- import our application models
\ir user.sql
\ir jobs.sql
\ir user_jobs_rel.sql
