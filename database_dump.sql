--
-- PostgreSQL database dump
--

\restrict Odb6ncq21S3mnZoMtpAxuUl7VS83Aas1hjPVKMV8ng8IN7VCF7j2CQoCPFhkLQ4

-- Dumped from database version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: nerovad
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO nerovad;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: match_choice; Type: TYPE; Schema: public; Owner: nerovad
--

CREATE TYPE public.match_choice AS ENUM (
    'A',
    'B'
);


ALTER TYPE public.match_choice OWNER TO nerovad;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ballots; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ballots (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    user_id bigint,
    fingerprint_sha256 bytea,
    weight numeric(6,3) DEFAULT 1.0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ballots OWNER TO nerovad;

--
-- Name: ballots_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.ballots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ballots_id_seq OWNER TO nerovad;

--
-- Name: ballots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.ballots_id_seq OWNED BY public.ballots.id;


--
-- Name: channel_schedule; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.channel_schedule (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    film_id bigint,
    title text,
    scheduled_at timestamp with time zone NOT NULL,
    duration_seconds integer,
    status text DEFAULT 'scheduled'::text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    recurrence_type text DEFAULT 'once'::text,
    recurrence_days integer[],
    recurrence_end_date date,
    air_time time without time zone,
    CONSTRAINT channel_schedule_recurrence_type_check CHECK ((recurrence_type = ANY (ARRAY['once'::text, 'daily'::text, 'weekly'::text, 'weekdays'::text, 'weekends'::text]))),
    CONSTRAINT channel_schedule_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'airing'::text, 'completed'::text])))
);


ALTER TABLE public.channel_schedule OWNER TO nerovad;

--
-- Name: channel_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.channel_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.channel_schedule_id_seq OWNER TO nerovad;

--
-- Name: channel_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.channel_schedule_id_seq OWNED BY public.channel_schedule.id;


--
-- Name: channels; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.channels (
    id bigint NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    stream_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    stream_key text,
    ingest_app text DEFAULT 'live'::text,
    playback_path text,
    ingest_notes text,
    owner_id integer,
    display_name character varying(20),
    channel_number integer,
    description text,
    widgets jsonb,
    about_text text,
    first_live_at timestamp with time zone,
    tags text[],
    thumbnail text
);


ALTER TABLE public.channels OWNER TO nerovad;

--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.channels_id_seq OWNER TO nerovad;

--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.channels_id_seq OWNED BY public.channels.id;


--
-- Name: direct_messages; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.direct_messages (
    id bigint NOT NULL,
    sender_id integer NOT NULL,
    receiver_id integer NOT NULL,
    content text NOT NULL,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL
);


ALTER TABLE public.direct_messages OWNER TO nerovad;

--
-- Name: direct_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.direct_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.direct_messages_id_seq OWNER TO nerovad;

--
-- Name: direct_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.direct_messages_id_seq OWNED BY public.direct_messages.id;


--
-- Name: films; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.films (
    id bigint NOT NULL,
    title text NOT NULL,
    creator_user_id bigint,
    runtime_seconds integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.films OWNER TO nerovad;

--
-- Name: films_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.films_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.films_id_seq OWNER TO nerovad;

--
-- Name: films_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.films_id_seq OWNED BY public.films.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.follows (
    id integer NOT NULL,
    follower_id integer,
    following_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.follows OWNER TO nerovad;

--
-- Name: follows_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.follows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.follows_id_seq OWNER TO nerovad;

--
-- Name: follows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.follows_id_seq OWNED BY public.follows.id;


--
-- Name: match_votes; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY HASH (match_id);


ALTER TABLE public.match_votes OWNER TO nerovad;

--
-- Name: match_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

ALTER TABLE public.match_votes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.match_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: match_votes_p0; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p0 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p0 OWNER TO nerovad;

--
-- Name: match_votes_p1; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p1 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p1 OWNER TO nerovad;

--
-- Name: match_votes_p2; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p2 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p2 OWNER TO nerovad;

--
-- Name: match_votes_p3; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p3 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p3 OWNER TO nerovad;

--
-- Name: match_votes_p4; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p4 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p4 OWNER TO nerovad;

--
-- Name: match_votes_p5; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p5 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p5 OWNER TO nerovad;

--
-- Name: match_votes_p6; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p6 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p6 OWNER TO nerovad;

--
-- Name: match_votes_p7; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.match_votes_p7 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.match_votes_p7 OWNER TO nerovad;

--
-- Name: matches; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.matches (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    round integer NOT NULL,
    "position" integer NOT NULL,
    entry_a_id bigint NOT NULL,
    entry_b_id bigint NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    winner_entry_id bigint
);


ALTER TABLE public.matches OWNER TO nerovad;

--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matches_id_seq OWNER TO nerovad;

--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    user_id integer,
    content text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    session_id bigint,
    channel_id bigint
);


ALTER TABLE public.messages OWNER TO nerovad;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_id_seq OWNER TO nerovad;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
)
PARTITION BY HASH (session_id);


ALTER TABLE public.ratings OWNER TO nerovad;

--
-- Name: ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

ALTER TABLE public.ratings ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ratings_p0; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p0 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p0 OWNER TO nerovad;

--
-- Name: ratings_p1; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p1 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p1 OWNER TO nerovad;

--
-- Name: ratings_p2; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p2 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p2 OWNER TO nerovad;

--
-- Name: ratings_p3; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p3 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p3 OWNER TO nerovad;

--
-- Name: ratings_p4; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p4 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p4 OWNER TO nerovad;

--
-- Name: ratings_p5; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p5 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p5 OWNER TO nerovad;

--
-- Name: ratings_p6; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p6 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p6 OWNER TO nerovad;

--
-- Name: ratings_p7; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.ratings_p7 (
    session_id bigint NOT NULL,
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_score_check CHECK (((score >= (1)::numeric) AND (score <= (10)::numeric)))
);


ALTER TABLE public.ratings_p7 OWNER TO nerovad;

--
-- Name: session_entries; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.session_entries (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    film_id bigint NOT NULL,
    order_index integer
);


ALTER TABLE public.session_entries OWNER TO nerovad;

--
-- Name: session_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.session_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_entries_id_seq OWNER TO nerovad;

--
-- Name: session_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.session_entries_id_seq OWNED BY public.session_entries.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    title text NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone,
    status text DEFAULT 'scheduled'::text NOT NULL,
    timezone text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_type character varying(50),
    tournament_bracket jsonb,
    is_active boolean DEFAULT true,
    voting_window jsonb DEFAULT '{"isActive": false, "currentRound": null}'::jsonb,
    updated_at timestamp with time zone DEFAULT now(),
    require_login boolean DEFAULT false,
    voting_mode character varying(20) DEFAULT 'ratings'::character varying,
    CONSTRAINT check_session_event_type CHECK (((event_type IS NULL) OR ((event_type)::text = ANY ((ARRAY['film_festival'::character varying, 'battle_royal'::character varying, 'tournament'::character varying])::text[]))))
);


ALTER TABLE public.sessions OWNER TO nerovad;

--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sessions_id_seq OWNER TO nerovad;

--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: tournament_matchups; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.tournament_matchups (
    id integer NOT NULL,
    session_id integer NOT NULL,
    matchup_id character varying(50) NOT NULL,
    round_number integer NOT NULL,
    "position" integer NOT NULL,
    film1_id character varying(255),
    film2_id character varying(255),
    film1_votes integer DEFAULT 0,
    film2_votes integer DEFAULT 0,
    winner_id character varying(255),
    completed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tournament_matchups OWNER TO nerovad;

--
-- Name: tournament_matchups_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.tournament_matchups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tournament_matchups_id_seq OWNER TO nerovad;

--
-- Name: tournament_matchups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.tournament_matchups_id_seq OWNED BY public.tournament_matchups.id;


--
-- Name: tournament_votes; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.tournament_votes (
    id integer NOT NULL,
    matchup_id integer NOT NULL,
    user_id integer,
    film_id character varying(255) NOT NULL,
    voted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tournament_votes OWNER TO nerovad;

--
-- Name: tournament_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.tournament_votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tournament_votes_id_seq OWNER TO nerovad;

--
-- Name: tournament_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.tournament_votes_id_seq OWNED BY public.tournament_votes.id;


--
-- Name: user_profile_awards; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.user_profile_awards (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    year integer,
    work text,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.user_profile_awards OWNER TO nerovad;

--
-- Name: user_profile_awards_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.user_profile_awards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_profile_awards_id_seq OWNER TO nerovad;

--
-- Name: user_profile_awards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.user_profile_awards_id_seq OWNED BY public.user_profile_awards.id;


--
-- Name: user_profile_companies; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.user_profile_companies (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    role text DEFAULT ''::text,
    website text DEFAULT ''::text,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.user_profile_companies OWNER TO nerovad;

--
-- Name: user_profile_companies_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.user_profile_companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_profile_companies_id_seq OWNER TO nerovad;

--
-- Name: user_profile_companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.user_profile_companies_id_seq OWNED BY public.user_profile_companies.id;


--
-- Name: user_profile_film_links; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.user_profile_film_links (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    title text DEFAULT ''::text,
    url text NOT NULL,
    provider text DEFAULT 'Other'::text,
    thumbnail text DEFAULT ''::text,
    duration text DEFAULT ''::text,
    synopsis text DEFAULT ''::text,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.user_profile_film_links OWNER TO nerovad;

--
-- Name: user_profile_film_links_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.user_profile_film_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_profile_film_links_id_seq OWNER TO nerovad;

--
-- Name: user_profile_film_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.user_profile_film_links_id_seq OWNED BY public.user_profile_film_links.id;


--
-- Name: user_profile_socials; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.user_profile_socials (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    label text NOT NULL,
    url text NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.user_profile_socials OWNER TO nerovad;

--
-- Name: user_profile_socials_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.user_profile_socials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_profile_socials_id_seq OWNER TO nerovad;

--
-- Name: user_profile_socials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.user_profile_socials_id_seq OWNED BY public.user_profile_socials.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.user_profiles (
    user_id integer NOT NULL,
    display_name text DEFAULT ''::text,
    handle text DEFAULT ''::text,
    avatar_url text DEFAULT ''::text,
    banner_url text DEFAULT ''::text,
    location text DEFAULT ''::text,
    website text DEFAULT ''::text,
    bio text DEFAULT ''::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.user_profiles OWNER TO nerovad;

--
-- Name: users; Type: TABLE; Schema: public; Owner: nerovad
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    display_name text DEFAULT ''::text,
    bio text DEFAULT ''::text,
    location text DEFAULT ''::text,
    website text DEFAULT ''::text,
    avatar_url text DEFAULT ''::text,
    banner_url text DEFAULT ''::text,
    socials jsonb DEFAULT '[]'::jsonb,
    companies jsonb DEFAULT '[]'::jsonb,
    film_links jsonb DEFAULT '[]'::jsonb
);


ALTER TABLE public.users OWNER TO nerovad;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: nerovad
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO nerovad;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nerovad
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: match_votes_p0; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p0 FOR VALUES WITH (modulus 8, remainder 0);


--
-- Name: match_votes_p1; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p1 FOR VALUES WITH (modulus 8, remainder 1);


--
-- Name: match_votes_p2; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p2 FOR VALUES WITH (modulus 8, remainder 2);


--
-- Name: match_votes_p3; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p3 FOR VALUES WITH (modulus 8, remainder 3);


--
-- Name: match_votes_p4; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p4 FOR VALUES WITH (modulus 8, remainder 4);


--
-- Name: match_votes_p5; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p5 FOR VALUES WITH (modulus 8, remainder 5);


--
-- Name: match_votes_p6; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p6 FOR VALUES WITH (modulus 8, remainder 6);


--
-- Name: match_votes_p7; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p7 FOR VALUES WITH (modulus 8, remainder 7);


--
-- Name: ratings_p0; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p0 FOR VALUES WITH (modulus 8, remainder 0);


--
-- Name: ratings_p1; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p1 FOR VALUES WITH (modulus 8, remainder 1);


--
-- Name: ratings_p2; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p2 FOR VALUES WITH (modulus 8, remainder 2);


--
-- Name: ratings_p3; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p3 FOR VALUES WITH (modulus 8, remainder 3);


--
-- Name: ratings_p4; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p4 FOR VALUES WITH (modulus 8, remainder 4);


--
-- Name: ratings_p5; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p5 FOR VALUES WITH (modulus 8, remainder 5);


--
-- Name: ratings_p6; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p6 FOR VALUES WITH (modulus 8, remainder 6);


--
-- Name: ratings_p7; Type: TABLE ATTACH; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p7 FOR VALUES WITH (modulus 8, remainder 7);


--
-- Name: ballots id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots ALTER COLUMN id SET DEFAULT nextval('public.ballots_id_seq'::regclass);


--
-- Name: channel_schedule id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channel_schedule ALTER COLUMN id SET DEFAULT nextval('public.channel_schedule_id_seq'::regclass);


--
-- Name: channels id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channels ALTER COLUMN id SET DEFAULT nextval('public.channels_id_seq'::regclass);


--
-- Name: direct_messages id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.direct_messages ALTER COLUMN id SET DEFAULT nextval('public.direct_messages_id_seq'::regclass);


--
-- Name: films id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.films ALTER COLUMN id SET DEFAULT nextval('public.films_id_seq'::regclass);


--
-- Name: follows id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.follows ALTER COLUMN id SET DEFAULT nextval('public.follows_id_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: session_entries id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries ALTER COLUMN id SET DEFAULT nextval('public.session_entries_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: tournament_matchups id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_matchups ALTER COLUMN id SET DEFAULT nextval('public.tournament_matchups_id_seq'::regclass);


--
-- Name: tournament_votes id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_votes ALTER COLUMN id SET DEFAULT nextval('public.tournament_votes_id_seq'::regclass);


--
-- Name: user_profile_awards id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_awards ALTER COLUMN id SET DEFAULT nextval('public.user_profile_awards_id_seq'::regclass);


--
-- Name: user_profile_companies id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_companies ALTER COLUMN id SET DEFAULT nextval('public.user_profile_companies_id_seq'::regclass);


--
-- Name: user_profile_film_links id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_film_links ALTER COLUMN id SET DEFAULT nextval('public.user_profile_film_links_id_seq'::regclass);


--
-- Name: user_profile_socials id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_socials ALTER COLUMN id SET DEFAULT nextval('public.user_profile_socials_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: ballots; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ballots (id, session_id, user_id, fingerprint_sha256, weight, created_at) FROM stdin;
\.


--
-- Data for Name: channel_schedule; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.channel_schedule (id, channel_id, film_id, title, scheduled_at, duration_seconds, status, created_at, recurrence_type, recurrence_days, recurrence_end_date, air_time) FROM stdin;
3	53	\N	fdsf	2026-01-28 00:00:00+00	11044	scheduled	2026-01-28 04:14:12.550512+00	daily	\N	\N	03:04:00
\.


--
-- Data for Name: channels; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.channels (id, slug, name, stream_url, created_at, stream_key, ingest_app, playback_path, ingest_notes, owner_id, display_name, channel_number, description, widgets, about_text, first_live_at, tags, thumbnail) FROM stdin;
53	channel-29	channel_29	\N	2026-01-28 04:04:03.920553+00	86d207b8f25fb72cdd98097b120425f6	live	/hls/86d207b8f25fb72cdd98097b120425f6/index.m3u8	\N	1	Mtv	29	\N	[{"type": "about", "order": 0}, {"type": "now_playing", "order": 1}]	Music videos and Beavis and Butthead	\N	{mtv,"music videos"}	/uploads/thumbnails/channel-29-1769573043921.jpeg
\.


--
-- Data for Name: direct_messages; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.direct_messages (id, sender_id, receiver_id, content, read, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: films; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.films (id, title, creator_user_id, runtime_seconds, created_at) FROM stdin;
1	Test1	1	10	2025-11-05 18:48:00.783429+00
2	Test2	1	34	2025-11-05 18:48:00.783429+00
3	Test	1	34	2025-11-06 16:48:52.978055+00
4	Test3	1	54	2025-11-06 16:48:52.978055+00
5	Ters	1	23	2025-11-06 16:57:02.92913+00
6	Testr3	1	34	2025-11-06 17:30:02.794404+00
7	Ran	1	87	2025-11-06 17:30:02.794404+00
8	Bonkers	1	49	2025-11-06 20:56:22.752718+00
9	Pinky	1	495	2025-11-06 20:56:22.752718+00
10	Test4	1	34	2025-11-10 17:06:52.776135+00
11	Test5	1	94	2025-11-10 17:06:52.776135+00
12	Test6	1	34	2025-11-10 17:06:52.776135+00
13	Test7	1	34	2025-11-10 17:06:52.776135+00
14	Test8	1	\N	2025-11-10 17:06:52.776135+00
15	Clark	1	10	2025-11-13 17:27:20.675109+00
16	Spiderman	1	4	2025-11-13 17:27:20.675109+00
17	Wendy	1	5	2025-11-13 17:27:20.675109+00
18	Ralph	1	43	2025-11-13 17:27:20.675109+00
19	Frank	1	43	2025-11-13 17:27:20.675109+00
20	Lewis	1	65	2025-11-13 17:27:20.675109+00
21	Snoopy	1	76	2025-11-13 17:27:20.675109+00
22	Batman	1	45	2025-11-13 17:27:20.675109+00
23	Johnny	1	34	2025-11-13 21:27:07.426112+00
24	Far	1	45	2025-11-13 21:27:07.426112+00
25	Max	1	66	2025-11-13 21:27:07.426112+00
26	Kat	1	45	2025-11-13 21:27:07.426112+00
27	3434	1	43	2025-11-14 16:43:15.237547+00
28	3432fd	1	54	2025-11-14 16:43:15.237547+00
29	fdsf	1	45	2025-11-14 16:43:15.237547+00
30	rew	1	43	2025-11-14 17:00:45.230596+00
31	fds	1	45	2025-11-14 17:00:45.230596+00
32	iuy	1	45	2025-11-14 17:00:45.230596+00
33	cbv	1	34	2025-11-14 17:00:45.230596+00
36	Jaws	1	39	2025-11-18 22:41:07.995706+00
37	sfefg	1	45	2025-11-18 22:41:07.995706+00
38	fdsfgg	1	94	2025-11-18 22:41:07.995706+00
39	13	1	34	2025-11-18 22:45:15.858882+00
40	24	1	4	2025-11-18 22:45:15.858882+00
41	563	1	6	2025-11-18 22:45:15.858882+00
42	454	1	87	2025-11-18 22:45:15.858882+00
43	ref	1	34	2025-11-18 23:03:45.123919+00
44	sfd	1	54	2025-11-18 23:03:45.123919+00
45	Ren	1	34	2025-11-18 23:09:17.235127+00
46	Fer	1	34	2025-11-18 23:09:17.235127+00
47	fdsssss	1	33	2025-11-18 23:09:17.235127+00
48	Furpo	1	34	2025-11-18 23:24:09.402283+00
49	Whomp	1	43	2025-11-18 23:24:09.402283+00
50	Huj	1	2	2025-11-18 23:24:09.402283+00
51	jkl	1	1	2025-11-18 23:24:09.402283+00
52	Jawzzj	1	23	2025-11-19 04:05:46.883835+00
53	Clues Blues	1	34	2025-11-19 04:05:46.883835+00
54	Blurp	1	45	2025-11-19 04:05:46.883835+00
55	Yoyo	1	54	2025-11-19 04:05:46.883835+00
56	Won	1	32	2026-01-23 18:49:48.922168+00
57	Too	1	43	2026-01-23 18:49:48.922168+00
58	Tree	1	32	2026-01-23 18:49:48.922168+00
59	Fo	1	34	2026-01-23 18:49:48.922168+00
60	1	1	\N	2026-01-23 21:05:48.185036+00
61	2	1	\N	2026-01-23 21:05:48.185036+00
\.


--
-- Data for Name: follows; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.follows (id, follower_id, following_id, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p0; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p0 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p1; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p1 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p2; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p2 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p3; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p3 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p4; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p4 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p5; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p5 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p6; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p6 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: match_votes_p7; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.match_votes_p7 (match_id, id, ballot_id, choice, created_at) FROM stdin;
\.


--
-- Data for Name: matches; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.matches (id, session_id, round, "position", entry_a_id, entry_b_id, starts_at, ends_at, winner_entry_id) FROM stdin;
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.messages (id, user_id, content, created_at, session_id, channel_id) FROM stdin;
\.


--
-- Data for Name: ratings_p0; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p0 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p1; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p1 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p2; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p2 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p3; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p3 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p4; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p4 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p5; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p5 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p6; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p6 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: ratings_p7; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.ratings_p7 (session_id, id, entry_id, ballot_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: session_entries; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.session_entries (id, session_id, film_id, order_index) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.sessions (id, channel_id, title, starts_at, ends_at, status, timezone, created_at, event_type, tournament_bracket, is_active, voting_window, updated_at, require_login, voting_mode) FROM stdin;
\.


--
-- Data for Name: tournament_matchups; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.tournament_matchups (id, session_id, matchup_id, round_number, "position", film1_id, film2_id, film1_votes, film2_votes, winner_id, completed_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: tournament_votes; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.tournament_votes (id, matchup_id, user_id, film_id, voted_at) FROM stdin;
\.


--
-- Data for Name: user_profile_awards; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.user_profile_awards (id, user_id, name, year, work, "position") FROM stdin;
\.


--
-- Data for Name: user_profile_companies; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.user_profile_companies (id, user_id, name, role, website, "position") FROM stdin;
\.


--
-- Data for Name: user_profile_film_links; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.user_profile_film_links (id, user_id, title, url, provider, thumbnail, duration, synopsis, "position") FROM stdin;
\.


--
-- Data for Name: user_profile_socials; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.user_profile_socials (id, user_id, label, url, "position") FROM stdin;
\.


--
-- Data for Name: user_profiles; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.user_profiles (user_id, display_name, handle, avatar_url, banner_url, location, website, bio, created_at, updated_at) FROM stdin;
1			/src/assets/The_Thing_Avatar.png				Founder of Cinezoo.	2025-11-03 18:52:40.723482+00	2026-01-28 05:31:41.076453+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: nerovad
--

COPY public.users (id, username, email, password, created_at, display_name, bio, location, website, avatar_url, banner_url, socials, companies, film_links) FROM stdin;
1	nerovad	matthewdavoren@gmail.com	$2b$10$7d4MrBD3fRF01wIes0eyxeM60M/VZbUiMBa/K/oqeIqbEThEHYzli	2025-10-31 21:03:19.51907							[]	[]	[]
\.


--
-- Name: ballots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.ballots_id_seq', 1, false);


--
-- Name: channel_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.channel_schedule_id_seq', 3, true);


--
-- Name: channels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.channels_id_seq', 53, true);


--
-- Name: direct_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.direct_messages_id_seq', 1, false);


--
-- Name: films_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.films_id_seq', 61, true);


--
-- Name: follows_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.follows_id_seq', 1, false);


--
-- Name: match_votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.match_votes_id_seq', 1, false);


--
-- Name: matches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.matches_id_seq', 1, false);


--
-- Name: messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.messages_id_seq', 15, true);


--
-- Name: ratings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.ratings_id_seq', 1, false);


--
-- Name: session_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.session_entries_id_seq', 72, true);


--
-- Name: sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.sessions_id_seq', 20, true);


--
-- Name: tournament_matchups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.tournament_matchups_id_seq', 35, true);


--
-- Name: tournament_votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.tournament_votes_id_seq', 44, true);


--
-- Name: user_profile_awards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.user_profile_awards_id_seq', 1, false);


--
-- Name: user_profile_companies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.user_profile_companies_id_seq', 1, false);


--
-- Name: user_profile_film_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.user_profile_film_links_id_seq', 1, false);


--
-- Name: user_profile_socials_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.user_profile_socials_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: nerovad
--

SELECT pg_catalog.setval('public.users_id_seq', 2, true);


--
-- Name: ballots ballots_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_pkey PRIMARY KEY (id);


--
-- Name: channel_schedule channel_schedule_channel_id_scheduled_at_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channel_schedule
    ADD CONSTRAINT channel_schedule_channel_id_scheduled_at_key UNIQUE (channel_id, scheduled_at);


--
-- Name: channel_schedule channel_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channel_schedule
    ADD CONSTRAINT channel_schedule_pkey PRIMARY KEY (id);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: channels channels_slug_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_slug_key UNIQUE (slug);


--
-- Name: direct_messages direct_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT direct_messages_pkey PRIMARY KEY (id);


--
-- Name: films films_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_pkey PRIMARY KEY (id);


--
-- Name: follows follows_follower_id_following_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_following_id_key UNIQUE (follower_id, following_id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (id);


--
-- Name: match_votes uniq_match_votes_one_per_ballot; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes
    ADD CONSTRAINT uniq_match_votes_one_per_ballot UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p0 match_votes_p0_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p0
    ADD CONSTRAINT match_votes_p0_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes match_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes
    ADD CONSTRAINT match_votes_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p0 match_votes_p0_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p0
    ADD CONSTRAINT match_votes_p0_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p1 match_votes_p1_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p1
    ADD CONSTRAINT match_votes_p1_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p1 match_votes_p1_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p1
    ADD CONSTRAINT match_votes_p1_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p2 match_votes_p2_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p2
    ADD CONSTRAINT match_votes_p2_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p2 match_votes_p2_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p2
    ADD CONSTRAINT match_votes_p2_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p3 match_votes_p3_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p3
    ADD CONSTRAINT match_votes_p3_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p3 match_votes_p3_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p3
    ADD CONSTRAINT match_votes_p3_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p4 match_votes_p4_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p4
    ADD CONSTRAINT match_votes_p4_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p4 match_votes_p4_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p4
    ADD CONSTRAINT match_votes_p4_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p5 match_votes_p5_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p5
    ADD CONSTRAINT match_votes_p5_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p5 match_votes_p5_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p5
    ADD CONSTRAINT match_votes_p5_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p6 match_votes_p6_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p6
    ADD CONSTRAINT match_votes_p6_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p6 match_votes_p6_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p6
    ADD CONSTRAINT match_votes_p6_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p7 match_votes_p7_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p7
    ADD CONSTRAINT match_votes_p7_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p7 match_votes_p7_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.match_votes_p7
    ADD CONSTRAINT match_votes_p7_pkey PRIMARY KEY (match_id, id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: matches matches_session_id_round_position_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_session_id_round_position_key UNIQUE (session_id, round, "position");


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p0 ratings_p0_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p0
    ADD CONSTRAINT ratings_p0_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings uniq_ratings_one_per_ballot; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT uniq_ratings_one_per_ballot UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p0 ratings_p0_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p0
    ADD CONSTRAINT ratings_p0_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p1 ratings_p1_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p1
    ADD CONSTRAINT ratings_p1_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p1 ratings_p1_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p1
    ADD CONSTRAINT ratings_p1_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p2 ratings_p2_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p2
    ADD CONSTRAINT ratings_p2_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p2 ratings_p2_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p2
    ADD CONSTRAINT ratings_p2_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p3 ratings_p3_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p3
    ADD CONSTRAINT ratings_p3_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p3 ratings_p3_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p3
    ADD CONSTRAINT ratings_p3_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p4 ratings_p4_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p4
    ADD CONSTRAINT ratings_p4_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p4 ratings_p4_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p4
    ADD CONSTRAINT ratings_p4_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p5 ratings_p5_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p5
    ADD CONSTRAINT ratings_p5_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p5 ratings_p5_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p5
    ADD CONSTRAINT ratings_p5_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p6 ratings_p6_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p6
    ADD CONSTRAINT ratings_p6_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p6 ratings_p6_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p6
    ADD CONSTRAINT ratings_p6_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p7 ratings_p7_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p7
    ADD CONSTRAINT ratings_p7_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p7 ratings_p7_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ratings_p7
    ADD CONSTRAINT ratings_p7_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: session_entries session_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_pkey PRIMARY KEY (id);


--
-- Name: session_entries session_entries_session_id_film_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_film_id_key UNIQUE (session_id, film_id);


--
-- Name: session_entries session_entries_session_id_order_index_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_order_index_key UNIQUE (session_id, order_index);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: tournament_matchups tournament_matchups_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_matchups
    ADD CONSTRAINT tournament_matchups_pkey PRIMARY KEY (id);


--
-- Name: tournament_votes tournament_votes_matchup_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_votes
    ADD CONSTRAINT tournament_votes_matchup_id_user_id_key UNIQUE (matchup_id, user_id);


--
-- Name: tournament_votes tournament_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_votes
    ADD CONSTRAINT tournament_votes_pkey PRIMARY KEY (id);


--
-- Name: ballots uniq_ballot_fp; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT uniq_ballot_fp UNIQUE (session_id, fingerprint_sha256);


--
-- Name: ballots uniq_ballot_user; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT uniq_ballot_user UNIQUE (session_id, user_id);


--
-- Name: sessions uniq_channel_start; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT uniq_channel_start UNIQUE (channel_id, starts_at);


--
-- Name: user_profile_awards user_profile_awards_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_awards
    ADD CONSTRAINT user_profile_awards_pkey PRIMARY KEY (id);


--
-- Name: user_profile_companies user_profile_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_companies
    ADD CONSTRAINT user_profile_companies_pkey PRIMARY KEY (id);


--
-- Name: user_profile_film_links user_profile_film_links_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_film_links
    ADD CONSTRAINT user_profile_film_links_pkey PRIMARY KEY (id);


--
-- Name: user_profile_socials user_profile_socials_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_socials
    ADD CONSTRAINT user_profile_socials_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_ballots_session; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_ballots_session ON public.ballots USING btree (session_id);


--
-- Name: idx_ballots_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_ballots_user ON public.ballots USING btree (user_id);


--
-- Name: idx_channels_owner; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_channels_owner ON public.channels USING btree (owner_id);


--
-- Name: idx_channels_tags; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_channels_tags ON public.channels USING gin (tags);


--
-- Name: idx_dm_conversation; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_dm_conversation ON public.direct_messages USING btree (LEAST(sender_id, receiver_id), GREATEST(sender_id, receiver_id), created_at DESC);


--
-- Name: idx_dm_expires; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_dm_expires ON public.direct_messages USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: idx_dm_receiver_created; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_dm_receiver_created ON public.direct_messages USING btree (receiver_id, created_at DESC);


--
-- Name: idx_dm_unread; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_dm_unread ON public.direct_messages USING btree (receiver_id, read) WHERE (read = false);


--
-- Name: idx_dm_user_created; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_dm_user_created ON public.direct_messages USING btree (sender_id, created_at DESC);


--
-- Name: idx_match_votes_ballot; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_match_votes_ballot ON ONLY public.match_votes USING btree (ballot_id);


--
-- Name: idx_match_votes_match; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_match_votes_match ON ONLY public.match_votes USING btree (match_id);


--
-- Name: idx_matches_session_round; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_matches_session_round ON public.matches USING btree (session_id, round, "position");


--
-- Name: idx_messages_channel_int_created; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_messages_channel_int_created ON public.messages USING btree (channel_id, created_at);


--
-- Name: idx_messages_session_created; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_messages_session_created ON public.messages USING btree (session_id, created_at);


--
-- Name: idx_ratings_ballot; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_ratings_ballot ON ONLY public.ratings USING btree (ballot_id);


--
-- Name: idx_ratings_session_entry; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_ratings_session_entry ON ONLY public.ratings USING btree (session_id, entry_id);


--
-- Name: idx_schedule_channel_time; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_schedule_channel_time ON public.channel_schedule USING btree (channel_id, scheduled_at, status);


--
-- Name: idx_schedule_recurrence; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_schedule_recurrence ON public.channel_schedule USING btree (channel_id, recurrence_type) WHERE (recurrence_type <> 'once'::text);


--
-- Name: idx_session_entries_session; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_session_entries_session ON public.session_entries USING btree (session_id, order_index);


--
-- Name: idx_sessions_time; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_sessions_time ON public.sessions USING btree (channel_id, starts_at, ends_at);


--
-- Name: idx_sessions_tournament_bracket; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_sessions_tournament_bracket ON public.sessions USING gin (tournament_bracket);


--
-- Name: idx_sessions_voting_window; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_sessions_voting_window ON public.sessions USING gin (voting_window);


--
-- Name: idx_tournament_matchups_round; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_tournament_matchups_round ON public.tournament_matchups USING btree (round_number);


--
-- Name: idx_tournament_matchups_session; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_tournament_matchups_session ON public.tournament_matchups USING btree (session_id);


--
-- Name: idx_tournament_votes_matchup; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_tournament_votes_matchup ON public.tournament_votes USING btree (matchup_id);


--
-- Name: idx_tournament_votes_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_tournament_votes_user ON public.tournament_votes USING btree (user_id);


--
-- Name: idx_user_profile_awards_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_user_profile_awards_user ON public.user_profile_awards USING btree (user_id);


--
-- Name: idx_user_profile_companies_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_user_profile_companies_user ON public.user_profile_companies USING btree (user_id);


--
-- Name: idx_user_profile_film_links_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_user_profile_film_links_user ON public.user_profile_film_links USING btree (user_id);


--
-- Name: idx_user_profile_socials_user; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX idx_user_profile_socials_user ON public.user_profile_socials USING btree (user_id);


--
-- Name: match_votes_p0_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p0_ballot_id_idx ON public.match_votes_p0 USING btree (ballot_id);


--
-- Name: match_votes_p0_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p0_match_id_idx ON public.match_votes_p0 USING btree (match_id);


--
-- Name: match_votes_p1_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p1_ballot_id_idx ON public.match_votes_p1 USING btree (ballot_id);


--
-- Name: match_votes_p1_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p1_match_id_idx ON public.match_votes_p1 USING btree (match_id);


--
-- Name: match_votes_p2_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p2_ballot_id_idx ON public.match_votes_p2 USING btree (ballot_id);


--
-- Name: match_votes_p2_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p2_match_id_idx ON public.match_votes_p2 USING btree (match_id);


--
-- Name: match_votes_p3_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p3_ballot_id_idx ON public.match_votes_p3 USING btree (ballot_id);


--
-- Name: match_votes_p3_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p3_match_id_idx ON public.match_votes_p3 USING btree (match_id);


--
-- Name: match_votes_p4_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p4_ballot_id_idx ON public.match_votes_p4 USING btree (ballot_id);


--
-- Name: match_votes_p4_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p4_match_id_idx ON public.match_votes_p4 USING btree (match_id);


--
-- Name: match_votes_p5_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p5_ballot_id_idx ON public.match_votes_p5 USING btree (ballot_id);


--
-- Name: match_votes_p5_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p5_match_id_idx ON public.match_votes_p5 USING btree (match_id);


--
-- Name: match_votes_p6_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p6_ballot_id_idx ON public.match_votes_p6 USING btree (ballot_id);


--
-- Name: match_votes_p6_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p6_match_id_idx ON public.match_votes_p6 USING btree (match_id);


--
-- Name: match_votes_p7_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p7_ballot_id_idx ON public.match_votes_p7 USING btree (ballot_id);


--
-- Name: match_votes_p7_match_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX match_votes_p7_match_id_idx ON public.match_votes_p7 USING btree (match_id);


--
-- Name: ratings_p0_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p0_ballot_id_idx ON public.ratings_p0 USING btree (ballot_id);


--
-- Name: ratings_p0_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p0_session_id_entry_id_idx ON public.ratings_p0 USING btree (session_id, entry_id);


--
-- Name: ratings_p1_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p1_ballot_id_idx ON public.ratings_p1 USING btree (ballot_id);


--
-- Name: ratings_p1_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p1_session_id_entry_id_idx ON public.ratings_p1 USING btree (session_id, entry_id);


--
-- Name: ratings_p2_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p2_ballot_id_idx ON public.ratings_p2 USING btree (ballot_id);


--
-- Name: ratings_p2_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p2_session_id_entry_id_idx ON public.ratings_p2 USING btree (session_id, entry_id);


--
-- Name: ratings_p3_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p3_ballot_id_idx ON public.ratings_p3 USING btree (ballot_id);


--
-- Name: ratings_p3_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p3_session_id_entry_id_idx ON public.ratings_p3 USING btree (session_id, entry_id);


--
-- Name: ratings_p4_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p4_ballot_id_idx ON public.ratings_p4 USING btree (ballot_id);


--
-- Name: ratings_p4_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p4_session_id_entry_id_idx ON public.ratings_p4 USING btree (session_id, entry_id);


--
-- Name: ratings_p5_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p5_ballot_id_idx ON public.ratings_p5 USING btree (ballot_id);


--
-- Name: ratings_p5_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p5_session_id_entry_id_idx ON public.ratings_p5 USING btree (session_id, entry_id);


--
-- Name: ratings_p6_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p6_ballot_id_idx ON public.ratings_p6 USING btree (ballot_id);


--
-- Name: ratings_p6_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p6_session_id_entry_id_idx ON public.ratings_p6 USING btree (session_id, entry_id);


--
-- Name: ratings_p7_ballot_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p7_ballot_id_idx ON public.ratings_p7 USING btree (ballot_id);


--
-- Name: ratings_p7_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: nerovad
--

CREATE INDEX ratings_p7_session_id_entry_id_idx ON public.ratings_p7 USING btree (session_id, entry_id);


--
-- Name: match_votes_p0_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p0_ballot_id_idx;


--
-- Name: match_votes_p0_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p0_match_id_ballot_id_key;


--
-- Name: match_votes_p0_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p0_match_id_idx;


--
-- Name: match_votes_p0_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p0_pkey;


--
-- Name: match_votes_p1_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p1_ballot_id_idx;


--
-- Name: match_votes_p1_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p1_match_id_ballot_id_key;


--
-- Name: match_votes_p1_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p1_match_id_idx;


--
-- Name: match_votes_p1_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p1_pkey;


--
-- Name: match_votes_p2_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p2_ballot_id_idx;


--
-- Name: match_votes_p2_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p2_match_id_ballot_id_key;


--
-- Name: match_votes_p2_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p2_match_id_idx;


--
-- Name: match_votes_p2_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p2_pkey;


--
-- Name: match_votes_p3_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p3_ballot_id_idx;


--
-- Name: match_votes_p3_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p3_match_id_ballot_id_key;


--
-- Name: match_votes_p3_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p3_match_id_idx;


--
-- Name: match_votes_p3_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p3_pkey;


--
-- Name: match_votes_p4_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p4_ballot_id_idx;


--
-- Name: match_votes_p4_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p4_match_id_ballot_id_key;


--
-- Name: match_votes_p4_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p4_match_id_idx;


--
-- Name: match_votes_p4_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p4_pkey;


--
-- Name: match_votes_p5_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p5_ballot_id_idx;


--
-- Name: match_votes_p5_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p5_match_id_ballot_id_key;


--
-- Name: match_votes_p5_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p5_match_id_idx;


--
-- Name: match_votes_p5_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p5_pkey;


--
-- Name: match_votes_p6_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p6_ballot_id_idx;


--
-- Name: match_votes_p6_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p6_match_id_ballot_id_key;


--
-- Name: match_votes_p6_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p6_match_id_idx;


--
-- Name: match_votes_p6_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p6_pkey;


--
-- Name: match_votes_p7_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p7_ballot_id_idx;


--
-- Name: match_votes_p7_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p7_match_id_ballot_id_key;


--
-- Name: match_votes_p7_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p7_match_id_idx;


--
-- Name: match_votes_p7_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p7_pkey;


--
-- Name: ratings_p0_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p0_ballot_id_idx;


--
-- Name: ratings_p0_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p0_pkey;


--
-- Name: ratings_p0_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p0_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p0_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p0_session_id_entry_id_idx;


--
-- Name: ratings_p1_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p1_ballot_id_idx;


--
-- Name: ratings_p1_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p1_pkey;


--
-- Name: ratings_p1_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p1_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p1_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p1_session_id_entry_id_idx;


--
-- Name: ratings_p2_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p2_ballot_id_idx;


--
-- Name: ratings_p2_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p2_pkey;


--
-- Name: ratings_p2_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p2_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p2_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p2_session_id_entry_id_idx;


--
-- Name: ratings_p3_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p3_ballot_id_idx;


--
-- Name: ratings_p3_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p3_pkey;


--
-- Name: ratings_p3_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p3_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p3_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p3_session_id_entry_id_idx;


--
-- Name: ratings_p4_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p4_ballot_id_idx;


--
-- Name: ratings_p4_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p4_pkey;


--
-- Name: ratings_p4_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p4_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p4_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p4_session_id_entry_id_idx;


--
-- Name: ratings_p5_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p5_ballot_id_idx;


--
-- Name: ratings_p5_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p5_pkey;


--
-- Name: ratings_p5_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p5_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p5_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p5_session_id_entry_id_idx;


--
-- Name: ratings_p6_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p6_ballot_id_idx;


--
-- Name: ratings_p6_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p6_pkey;


--
-- Name: ratings_p6_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p6_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p6_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p6_session_id_entry_id_idx;


--
-- Name: ratings_p7_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p7_ballot_id_idx;


--
-- Name: ratings_p7_pkey; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p7_pkey;


--
-- Name: ratings_p7_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p7_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p7_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: nerovad
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p7_session_id_entry_id_idx;


--
-- Name: ballots ballots_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: ballots ballots_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: channel_schedule channel_schedule_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channel_schedule
    ADD CONSTRAINT channel_schedule_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: channel_schedule channel_schedule_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channel_schedule
    ADD CONSTRAINT channel_schedule_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.films(id) ON DELETE SET NULL;


--
-- Name: direct_messages direct_messages_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT direct_messages_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: direct_messages direct_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT direct_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: films films_creator_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_creator_user_id_fkey FOREIGN KEY (creator_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: channels fk_channels_owner; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT fk_channels_owner FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages fk_messages_channel_numeric; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_messages_channel_numeric FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: follows follows_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: follows follows_following_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_votes match_votes_ballot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE public.match_votes
    ADD CONSTRAINT match_votes_ballot_id_fkey FOREIGN KEY (ballot_id) REFERENCES public.ballots(id) ON DELETE CASCADE;


--
-- Name: match_votes match_votes_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE public.match_votes
    ADD CONSTRAINT match_votes_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: matches matches_entry_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_entry_a_id_fkey FOREIGN KEY (entry_a_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: matches matches_entry_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_entry_b_id_fkey FOREIGN KEY (entry_b_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: matches matches_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: matches matches_winner_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_winner_entry_id_fkey FOREIGN KEY (winner_entry_id) REFERENCES public.session_entries(id);


--
-- Name: messages messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;


--
-- Name: messages messages_session_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_session_id_fkey1 FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;


--
-- Name: messages messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_ballot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_ballot_id_fkey FOREIGN KEY (ballot_id) REFERENCES public.ballots(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: session_entries session_entries_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.films(id) ON DELETE CASCADE;


--
-- Name: session_entries session_entries_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: tournament_matchups tournament_matchups_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_matchups
    ADD CONSTRAINT tournament_matchups_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: tournament_votes tournament_votes_matchup_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_votes
    ADD CONSTRAINT tournament_votes_matchup_id_fkey FOREIGN KEY (matchup_id) REFERENCES public.tournament_matchups(id) ON DELETE CASCADE;


--
-- Name: tournament_votes tournament_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.tournament_votes
    ADD CONSTRAINT tournament_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_profile_awards user_profile_awards_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_awards
    ADD CONSTRAINT user_profile_awards_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_companies user_profile_companies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_companies
    ADD CONSTRAINT user_profile_companies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_film_links user_profile_film_links_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_film_links
    ADD CONSTRAINT user_profile_film_links_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_socials user_profile_socials_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profile_socials
    ADD CONSTRAINT user_profile_socials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: nerovad
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict Odb6ncq21S3mnZoMtpAxuUl7VS83Aas1hjPVKMV8ng8IN7VCF7j2CQoCPFhkLQ4

