# postgres:<PG_MAJOR> with PL/Python and the laya extension installed.
#   docker build -t pg-laya .
#   docker run -e POSTGRES_PASSWORD=pw -e TYPESAFE_API_KEY=... -p 5432:5432 pg-laya
#   psql ... -c "CREATE EXTENSION laya CASCADE"
ARG PG_MAJOR=16
FROM postgres:${PG_MAJOR}
ARG PG_MAJOR
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-plpython3-${PG_MAJOR} ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY laya.control /usr/share/postgresql/${PG_MAJOR}/extension/
COPY sql/laya--*.sql /usr/share/postgresql/${PG_MAJOR}/extension/
