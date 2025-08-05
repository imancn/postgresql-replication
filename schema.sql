--
-- PostgreSQL database dump
--

-- Dumped from database version 15.13 (Debian 15.13-1.pgdg120+1)
-- Dumped by pg_dump version 15.13 (Debian 15.13-1.pgdg120+1)

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: replication_bulk; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.replication_bulk (
    id integer NOT NULL,
    value integer
);


--
-- Name: replication_bulk_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.replication_bulk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replication_bulk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.replication_bulk_id_seq OWNED BY public.replication_bulk.id;


--
-- Name: replication_test; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.replication_test (
    id integer NOT NULL,
    data text
);


--
-- Name: replication_test_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.replication_test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replication_test_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.replication_test_id_seq OWNED BY public.replication_test.id;


--
-- Name: replication_bulk id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replication_bulk ALTER COLUMN id SET DEFAULT nextval('public.replication_bulk_id_seq'::regclass);


--
-- Name: replication_test id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replication_test ALTER COLUMN id SET DEFAULT nextval('public.replication_test_id_seq'::regclass);


--
-- Name: replication_bulk replication_bulk_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replication_bulk
    ADD CONSTRAINT replication_bulk_pkey PRIMARY KEY (id);


--
-- Name: replication_test replication_test_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replication_test
    ADD CONSTRAINT replication_test_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

