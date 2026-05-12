# KBC

## Developer Notes

- run the whole stack with `make up CONTAINERIZED=1` (or `make up-container` / `docker compose up --build`)
- local `make up` / `bin/dev` requires Valkey to already be listening on the configured Redis port

# README

## Database Setup

In PostgreSQL, create a kbcdev user and add the SUPERUSER role.

## The following is from the Rails template

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
