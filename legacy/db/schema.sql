--
-- PostgreSQL database dump
--

\restrict UVgg2J8YEJh6hTL0MOlPDKhbWyYoTM5K4ndqyqGEzpA9g3aahsqgNVPt0xdzaol

-- Dumped from database version 12.22 (Ubuntu 12.22-0ubuntu0.20.04.4)
-- Dumped by pg_dump version 14.19 (Ubuntu 14.19-0ubuntu0.22.04.1)

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: match_choice; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.match_choice AS ENUM (
    'A',
    'B'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ballots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ballots (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    user_id bigint,
    fingerprint_sha256 bytea,
    weight numeric(6,3) DEFAULT 1.0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ballots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ballots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ballots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ballots_id_seq OWNED BY public.ballots.id;


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
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
    channel_number integer
);


--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_id_seq OWNED BY public.channels.id;


--
-- Name: films; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.films (
    id bigint NOT NULL,
    title text NOT NULL,
    creator_user_id bigint,
    runtime_seconds integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: films_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.films_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: films_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.films_id_seq OWNED BY public.films.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.follows (
    id integer NOT NULL,
    follower_id integer,
    following_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: follows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.follows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: follows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.follows_id_seq OWNED BY public.follows.id;


--
-- Name: match_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY HASH (match_id);


--
-- Name: match_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: match_votes_p0; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p0 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p1 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p2 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p3; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p3 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p4; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p4 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p5; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p5 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p6; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p6 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: match_votes_p7; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.match_votes_p7 (
    match_id bigint NOT NULL,
    id bigint NOT NULL,
    ballot_id bigint NOT NULL,
    choice public.match_choice NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    user_id integer,
    content text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    session_id bigint,
    channel_id bigint
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: ratings_p0; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p1; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p2; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p3; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p4; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p5; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p6; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ratings_p7; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: session_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_entries (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    film_id bigint NOT NULL,
    order_index integer
);


--
-- Name: session_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.session_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: session_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.session_entries_id_seq OWNED BY public.session_entries.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    title text NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone,
    status text DEFAULT 'scheduled'::text NOT NULL,
    timezone text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: user_profile_awards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profile_awards (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    year integer,
    work text,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: user_profile_awards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profile_awards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profile_awards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profile_awards_id_seq OWNED BY public.user_profile_awards.id;


--
-- Name: user_profile_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profile_companies (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    role text DEFAULT ''::text,
    website text DEFAULT ''::text,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: user_profile_companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profile_companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profile_companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profile_companies_id_seq OWNED BY public.user_profile_companies.id;


--
-- Name: user_profile_film_links; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: user_profile_film_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profile_film_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profile_film_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profile_film_links_id_seq OWNED BY public.user_profile_film_links.id;


--
-- Name: user_profile_socials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profile_socials (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    label text NOT NULL,
    url text NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: user_profile_socials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profile_socials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profile_socials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profile_socials_id_seq OWNED BY public.user_profile_socials.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: match_votes_p0; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p0 FOR VALUES WITH (modulus 8, remainder 0);


--
-- Name: match_votes_p1; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p1 FOR VALUES WITH (modulus 8, remainder 1);


--
-- Name: match_votes_p2; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p2 FOR VALUES WITH (modulus 8, remainder 2);


--
-- Name: match_votes_p3; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p3 FOR VALUES WITH (modulus 8, remainder 3);


--
-- Name: match_votes_p4; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p4 FOR VALUES WITH (modulus 8, remainder 4);


--
-- Name: match_votes_p5; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p5 FOR VALUES WITH (modulus 8, remainder 5);


--
-- Name: match_votes_p6; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p6 FOR VALUES WITH (modulus 8, remainder 6);


--
-- Name: match_votes_p7; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes ATTACH PARTITION public.match_votes_p7 FOR VALUES WITH (modulus 8, remainder 7);


--
-- Name: ratings_p0; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p0 FOR VALUES WITH (modulus 8, remainder 0);


--
-- Name: ratings_p1; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p1 FOR VALUES WITH (modulus 8, remainder 1);


--
-- Name: ratings_p2; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p2 FOR VALUES WITH (modulus 8, remainder 2);


--
-- Name: ratings_p3; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p3 FOR VALUES WITH (modulus 8, remainder 3);


--
-- Name: ratings_p4; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p4 FOR VALUES WITH (modulus 8, remainder 4);


--
-- Name: ratings_p5; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p5 FOR VALUES WITH (modulus 8, remainder 5);


--
-- Name: ratings_p6; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p6 FOR VALUES WITH (modulus 8, remainder 6);


--
-- Name: ratings_p7; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ATTACH PARTITION public.ratings_p7 FOR VALUES WITH (modulus 8, remainder 7);


--
-- Name: ballots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots ALTER COLUMN id SET DEFAULT nextval('public.ballots_id_seq'::regclass);


--
-- Name: channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels ALTER COLUMN id SET DEFAULT nextval('public.channels_id_seq'::regclass);


--
-- Name: films id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films ALTER COLUMN id SET DEFAULT nextval('public.films_id_seq'::regclass);


--
-- Name: follows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows ALTER COLUMN id SET DEFAULT nextval('public.follows_id_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: session_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries ALTER COLUMN id SET DEFAULT nextval('public.session_entries_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: user_profile_awards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_awards ALTER COLUMN id SET DEFAULT nextval('public.user_profile_awards_id_seq'::regclass);


--
-- Name: user_profile_companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_companies ALTER COLUMN id SET DEFAULT nextval('public.user_profile_companies_id_seq'::regclass);


--
-- Name: user_profile_film_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_film_links ALTER COLUMN id SET DEFAULT nextval('public.user_profile_film_links_id_seq'::regclass);


--
-- Name: user_profile_socials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_socials ALTER COLUMN id SET DEFAULT nextval('public.user_profile_socials_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ballots ballots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_pkey PRIMARY KEY (id);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: channels channels_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_slug_key UNIQUE (slug);


--
-- Name: films films_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_pkey PRIMARY KEY (id);


--
-- Name: follows follows_follower_id_following_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_following_id_key UNIQUE (follower_id, following_id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (id);


--
-- Name: match_votes uniq_match_votes_one_per_ballot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes
    ADD CONSTRAINT uniq_match_votes_one_per_ballot UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p0 match_votes_p0_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p0
    ADD CONSTRAINT match_votes_p0_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes match_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes
    ADD CONSTRAINT match_votes_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p0 match_votes_p0_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p0
    ADD CONSTRAINT match_votes_p0_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p1 match_votes_p1_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p1
    ADD CONSTRAINT match_votes_p1_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p1 match_votes_p1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p1
    ADD CONSTRAINT match_votes_p1_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p2 match_votes_p2_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p2
    ADD CONSTRAINT match_votes_p2_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p2 match_votes_p2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p2
    ADD CONSTRAINT match_votes_p2_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p3 match_votes_p3_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p3
    ADD CONSTRAINT match_votes_p3_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p3 match_votes_p3_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p3
    ADD CONSTRAINT match_votes_p3_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p4 match_votes_p4_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p4
    ADD CONSTRAINT match_votes_p4_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p4 match_votes_p4_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p4
    ADD CONSTRAINT match_votes_p4_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p5 match_votes_p5_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p5
    ADD CONSTRAINT match_votes_p5_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p5 match_votes_p5_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p5
    ADD CONSTRAINT match_votes_p5_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p6 match_votes_p6_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p6
    ADD CONSTRAINT match_votes_p6_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p6 match_votes_p6_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p6
    ADD CONSTRAINT match_votes_p6_pkey PRIMARY KEY (match_id, id);


--
-- Name: match_votes_p7 match_votes_p7_match_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p7
    ADD CONSTRAINT match_votes_p7_match_id_ballot_id_key UNIQUE (match_id, ballot_id);


--
-- Name: match_votes_p7 match_votes_p7_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.match_votes_p7
    ADD CONSTRAINT match_votes_p7_pkey PRIMARY KEY (match_id, id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: matches matches_session_id_round_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_session_id_round_position_key UNIQUE (session_id, round, "position");


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p0 ratings_p0_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p0
    ADD CONSTRAINT ratings_p0_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings uniq_ratings_one_per_ballot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT uniq_ratings_one_per_ballot UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p0 ratings_p0_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p0
    ADD CONSTRAINT ratings_p0_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p1 ratings_p1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p1
    ADD CONSTRAINT ratings_p1_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p1 ratings_p1_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p1
    ADD CONSTRAINT ratings_p1_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p2 ratings_p2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p2
    ADD CONSTRAINT ratings_p2_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p2 ratings_p2_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p2
    ADD CONSTRAINT ratings_p2_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p3 ratings_p3_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p3
    ADD CONSTRAINT ratings_p3_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p3 ratings_p3_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p3
    ADD CONSTRAINT ratings_p3_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p4 ratings_p4_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p4
    ADD CONSTRAINT ratings_p4_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p4 ratings_p4_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p4
    ADD CONSTRAINT ratings_p4_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p5 ratings_p5_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p5
    ADD CONSTRAINT ratings_p5_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p5 ratings_p5_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p5
    ADD CONSTRAINT ratings_p5_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p6 ratings_p6_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p6
    ADD CONSTRAINT ratings_p6_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p6 ratings_p6_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p6
    ADD CONSTRAINT ratings_p6_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: ratings_p7 ratings_p7_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p7
    ADD CONSTRAINT ratings_p7_pkey PRIMARY KEY (session_id, id);


--
-- Name: ratings_p7 ratings_p7_session_id_entry_id_ballot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings_p7
    ADD CONSTRAINT ratings_p7_session_id_entry_id_ballot_id_key UNIQUE (session_id, entry_id, ballot_id);


--
-- Name: session_entries session_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_pkey PRIMARY KEY (id);


--
-- Name: session_entries session_entries_session_id_film_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_film_id_key UNIQUE (session_id, film_id);


--
-- Name: session_entries session_entries_session_id_order_index_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_order_index_key UNIQUE (session_id, order_index);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: ballots uniq_ballot_fp; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT uniq_ballot_fp UNIQUE (session_id, fingerprint_sha256);


--
-- Name: ballots uniq_ballot_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT uniq_ballot_user UNIQUE (session_id, user_id);


--
-- Name: sessions uniq_channel_start; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT uniq_channel_start UNIQUE (channel_id, starts_at);


--
-- Name: user_profile_awards user_profile_awards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_awards
    ADD CONSTRAINT user_profile_awards_pkey PRIMARY KEY (id);


--
-- Name: user_profile_companies user_profile_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_companies
    ADD CONSTRAINT user_profile_companies_pkey PRIMARY KEY (id);


--
-- Name: user_profile_film_links user_profile_film_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_film_links
    ADD CONSTRAINT user_profile_film_links_pkey PRIMARY KEY (id);


--
-- Name: user_profile_socials user_profile_socials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_socials
    ADD CONSTRAINT user_profile_socials_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_ballots_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ballots_session ON public.ballots USING btree (session_id);


--
-- Name: idx_ballots_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ballots_user ON public.ballots USING btree (user_id);


--
-- Name: idx_channels_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_channels_owner ON public.channels USING btree (owner_id);


--
-- Name: idx_match_votes_ballot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_match_votes_ballot ON ONLY public.match_votes USING btree (ballot_id);


--
-- Name: idx_match_votes_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_match_votes_match ON ONLY public.match_votes USING btree (match_id);


--
-- Name: idx_matches_session_round; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_session_round ON public.matches USING btree (session_id, round, "position");


--
-- Name: idx_messages_channel_int_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_channel_int_created ON public.messages USING btree (channel_id, created_at);


--
-- Name: idx_messages_session_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_session_created ON public.messages USING btree (session_id, created_at);


--
-- Name: idx_ratings_ballot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_ballot ON ONLY public.ratings USING btree (ballot_id);


--
-- Name: idx_ratings_session_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_session_entry ON ONLY public.ratings USING btree (session_id, entry_id);


--
-- Name: idx_session_entries_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_entries_session ON public.session_entries USING btree (session_id, order_index);


--
-- Name: idx_sessions_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_time ON public.sessions USING btree (channel_id, starts_at, ends_at);


--
-- Name: idx_user_profile_awards_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_profile_awards_user ON public.user_profile_awards USING btree (user_id);


--
-- Name: idx_user_profile_companies_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_profile_companies_user ON public.user_profile_companies USING btree (user_id);


--
-- Name: idx_user_profile_film_links_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_profile_film_links_user ON public.user_profile_film_links USING btree (user_id);


--
-- Name: idx_user_profile_socials_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_profile_socials_user ON public.user_profile_socials USING btree (user_id);


--
-- Name: match_votes_p0_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p0_ballot_id_idx ON public.match_votes_p0 USING btree (ballot_id);


--
-- Name: match_votes_p0_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p0_match_id_idx ON public.match_votes_p0 USING btree (match_id);


--
-- Name: match_votes_p1_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p1_ballot_id_idx ON public.match_votes_p1 USING btree (ballot_id);


--
-- Name: match_votes_p1_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p1_match_id_idx ON public.match_votes_p1 USING btree (match_id);


--
-- Name: match_votes_p2_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p2_ballot_id_idx ON public.match_votes_p2 USING btree (ballot_id);


--
-- Name: match_votes_p2_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p2_match_id_idx ON public.match_votes_p2 USING btree (match_id);


--
-- Name: match_votes_p3_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p3_ballot_id_idx ON public.match_votes_p3 USING btree (ballot_id);


--
-- Name: match_votes_p3_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p3_match_id_idx ON public.match_votes_p3 USING btree (match_id);


--
-- Name: match_votes_p4_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p4_ballot_id_idx ON public.match_votes_p4 USING btree (ballot_id);


--
-- Name: match_votes_p4_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p4_match_id_idx ON public.match_votes_p4 USING btree (match_id);


--
-- Name: match_votes_p5_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p5_ballot_id_idx ON public.match_votes_p5 USING btree (ballot_id);


--
-- Name: match_votes_p5_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p5_match_id_idx ON public.match_votes_p5 USING btree (match_id);


--
-- Name: match_votes_p6_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p6_ballot_id_idx ON public.match_votes_p6 USING btree (ballot_id);


--
-- Name: match_votes_p6_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p6_match_id_idx ON public.match_votes_p6 USING btree (match_id);


--
-- Name: match_votes_p7_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p7_ballot_id_idx ON public.match_votes_p7 USING btree (ballot_id);


--
-- Name: match_votes_p7_match_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX match_votes_p7_match_id_idx ON public.match_votes_p7 USING btree (match_id);


--
-- Name: ratings_p0_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p0_ballot_id_idx ON public.ratings_p0 USING btree (ballot_id);


--
-- Name: ratings_p0_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p0_session_id_entry_id_idx ON public.ratings_p0 USING btree (session_id, entry_id);


--
-- Name: ratings_p1_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p1_ballot_id_idx ON public.ratings_p1 USING btree (ballot_id);


--
-- Name: ratings_p1_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p1_session_id_entry_id_idx ON public.ratings_p1 USING btree (session_id, entry_id);


--
-- Name: ratings_p2_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p2_ballot_id_idx ON public.ratings_p2 USING btree (ballot_id);


--
-- Name: ratings_p2_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p2_session_id_entry_id_idx ON public.ratings_p2 USING btree (session_id, entry_id);


--
-- Name: ratings_p3_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p3_ballot_id_idx ON public.ratings_p3 USING btree (ballot_id);


--
-- Name: ratings_p3_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p3_session_id_entry_id_idx ON public.ratings_p3 USING btree (session_id, entry_id);


--
-- Name: ratings_p4_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p4_ballot_id_idx ON public.ratings_p4 USING btree (ballot_id);


--
-- Name: ratings_p4_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p4_session_id_entry_id_idx ON public.ratings_p4 USING btree (session_id, entry_id);


--
-- Name: ratings_p5_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p5_ballot_id_idx ON public.ratings_p5 USING btree (ballot_id);


--
-- Name: ratings_p5_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p5_session_id_entry_id_idx ON public.ratings_p5 USING btree (session_id, entry_id);


--
-- Name: ratings_p6_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p6_ballot_id_idx ON public.ratings_p6 USING btree (ballot_id);


--
-- Name: ratings_p6_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p6_session_id_entry_id_idx ON public.ratings_p6 USING btree (session_id, entry_id);


--
-- Name: ratings_p7_ballot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p7_ballot_id_idx ON public.ratings_p7 USING btree (ballot_id);


--
-- Name: ratings_p7_session_id_entry_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ratings_p7_session_id_entry_id_idx ON public.ratings_p7 USING btree (session_id, entry_id);


--
-- Name: match_votes_p0_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p0_ballot_id_idx;


--
-- Name: match_votes_p0_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p0_match_id_ballot_id_key;


--
-- Name: match_votes_p0_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p0_match_id_idx;


--
-- Name: match_votes_p0_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p0_pkey;


--
-- Name: match_votes_p1_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p1_ballot_id_idx;


--
-- Name: match_votes_p1_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p1_match_id_ballot_id_key;


--
-- Name: match_votes_p1_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p1_match_id_idx;


--
-- Name: match_votes_p1_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p1_pkey;


--
-- Name: match_votes_p2_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p2_ballot_id_idx;


--
-- Name: match_votes_p2_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p2_match_id_ballot_id_key;


--
-- Name: match_votes_p2_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p2_match_id_idx;


--
-- Name: match_votes_p2_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p2_pkey;


--
-- Name: match_votes_p3_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p3_ballot_id_idx;


--
-- Name: match_votes_p3_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p3_match_id_ballot_id_key;


--
-- Name: match_votes_p3_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p3_match_id_idx;


--
-- Name: match_votes_p3_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p3_pkey;


--
-- Name: match_votes_p4_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p4_ballot_id_idx;


--
-- Name: match_votes_p4_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p4_match_id_ballot_id_key;


--
-- Name: match_votes_p4_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p4_match_id_idx;


--
-- Name: match_votes_p4_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p4_pkey;


--
-- Name: match_votes_p5_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p5_ballot_id_idx;


--
-- Name: match_votes_p5_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p5_match_id_ballot_id_key;


--
-- Name: match_votes_p5_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p5_match_id_idx;


--
-- Name: match_votes_p5_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p5_pkey;


--
-- Name: match_votes_p6_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p6_ballot_id_idx;


--
-- Name: match_votes_p6_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p6_match_id_ballot_id_key;


--
-- Name: match_votes_p6_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p6_match_id_idx;


--
-- Name: match_votes_p6_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p6_pkey;


--
-- Name: match_votes_p7_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_ballot ATTACH PARTITION public.match_votes_p7_ballot_id_idx;


--
-- Name: match_votes_p7_match_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_match_votes_one_per_ballot ATTACH PARTITION public.match_votes_p7_match_id_ballot_id_key;


--
-- Name: match_votes_p7_match_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_match_votes_match ATTACH PARTITION public.match_votes_p7_match_id_idx;


--
-- Name: match_votes_p7_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.match_votes_pkey ATTACH PARTITION public.match_votes_p7_pkey;


--
-- Name: ratings_p0_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p0_ballot_id_idx;


--
-- Name: ratings_p0_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p0_pkey;


--
-- Name: ratings_p0_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p0_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p0_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p0_session_id_entry_id_idx;


--
-- Name: ratings_p1_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p1_ballot_id_idx;


--
-- Name: ratings_p1_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p1_pkey;


--
-- Name: ratings_p1_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p1_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p1_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p1_session_id_entry_id_idx;


--
-- Name: ratings_p2_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p2_ballot_id_idx;


--
-- Name: ratings_p2_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p2_pkey;


--
-- Name: ratings_p2_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p2_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p2_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p2_session_id_entry_id_idx;


--
-- Name: ratings_p3_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p3_ballot_id_idx;


--
-- Name: ratings_p3_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p3_pkey;


--
-- Name: ratings_p3_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p3_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p3_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p3_session_id_entry_id_idx;


--
-- Name: ratings_p4_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p4_ballot_id_idx;


--
-- Name: ratings_p4_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p4_pkey;


--
-- Name: ratings_p4_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p4_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p4_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p4_session_id_entry_id_idx;


--
-- Name: ratings_p5_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p5_ballot_id_idx;


--
-- Name: ratings_p5_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p5_pkey;


--
-- Name: ratings_p5_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p5_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p5_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p5_session_id_entry_id_idx;


--
-- Name: ratings_p6_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p6_ballot_id_idx;


--
-- Name: ratings_p6_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p6_pkey;


--
-- Name: ratings_p6_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p6_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p6_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p6_session_id_entry_id_idx;


--
-- Name: ratings_p7_ballot_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_ballot ATTACH PARTITION public.ratings_p7_ballot_id_idx;


--
-- Name: ratings_p7_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.ratings_pkey ATTACH PARTITION public.ratings_p7_pkey;


--
-- Name: ratings_p7_session_id_entry_id_ballot_id_key; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.uniq_ratings_one_per_ballot ATTACH PARTITION public.ratings_p7_session_id_entry_id_ballot_id_key;


--
-- Name: ratings_p7_session_id_entry_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ratings_session_entry ATTACH PARTITION public.ratings_p7_session_id_entry_id_idx;


--
-- Name: ballots ballots_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: ballots ballots_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ballots
    ADD CONSTRAINT ballots_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: films films_creator_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT films_creator_user_id_fkey FOREIGN KEY (creator_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: channels fk_channels_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT fk_channels_owner FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages fk_messages_channel_numeric; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_messages_channel_numeric FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: follows follows_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: follows follows_following_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_votes match_votes_ballot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.match_votes
    ADD CONSTRAINT match_votes_ballot_id_fkey FOREIGN KEY (ballot_id) REFERENCES public.ballots(id) ON DELETE CASCADE;


--
-- Name: match_votes match_votes_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.match_votes
    ADD CONSTRAINT match_votes_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: matches matches_entry_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_entry_a_id_fkey FOREIGN KEY (entry_a_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: matches matches_entry_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_entry_b_id_fkey FOREIGN KEY (entry_b_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: matches matches_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: matches matches_winner_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_winner_entry_id_fkey FOREIGN KEY (winner_entry_id) REFERENCES public.session_entries(id);


--
-- Name: messages messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;


--
-- Name: messages messages_session_id_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_session_id_fkey1 FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE SET NULL;


--
-- Name: messages messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_ballot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_ballot_id_fkey FOREIGN KEY (ballot_id) REFERENCES public.ballots(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.session_entries(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.ratings
    ADD CONSTRAINT ratings_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: session_entries session_entries_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.films(id) ON DELETE CASCADE;


--
-- Name: session_entries session_entries_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_entries
    ADD CONSTRAINT session_entries_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: user_profile_awards user_profile_awards_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_awards
    ADD CONSTRAINT user_profile_awards_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_companies user_profile_companies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_companies
    ADD CONSTRAINT user_profile_companies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_film_links user_profile_film_links_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_film_links
    ADD CONSTRAINT user_profile_film_links_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profile_socials user_profile_socials_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_socials
    ADD CONSTRAINT user_profile_socials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict UVgg2J8YEJh6hTL0MOlPDKhbWyYoTM5K4ndqyqGEzpA9g3aahsqgNVPt0xdzaol

