# Nim Clickhouse Interface

## Introduction

This package let's you use the [Clickhouse](https://clickhouse.yandex/)
analytical database from the [Nim](https://nim-lang.org) language, using an
interface similar to the ones provided for SQLite and for PostgreSQL.

It contains only pure Nim code and doesn't require any external library.

Internally, it uses the HTTP interface of Clickhouse, since the TCP transport
is not meant to be used by client applications but only for cross-engine
communications, as you can see in
[this bug report](https://github.com/yandex/ClickHouse/issues/45).

## Usage

```nim
import db_clickhouse

var db:DbConn = db_clickhouse.open("clickhouse-server")

for row in db.getAllRows("SELECT * FROM test_table ORDER BY test_column"):
  echo row[0], row[1]

db.close()
```

You can find other examples in the unit tests of this package.

## Tests

If you want to run to unit tests included with this package, you will need to
have an available ClickHouse instance with a test table with the following
structure:

```sql
CREATE TABLE test_table
(
    test_column String,
    test_column_two String
) ENGINE Memory;
```

If you are using Docker, you can create a new ClickHouse instance with the
following command:

```
$ docker run -d \
    --name clickhouse-server \
    -P 9000:9000 \
    -P 8123:8123 \
    -v clickhouse:/var/lib/clickhouse \
    yandex/clickhouse-server
```

You can create the required table starting a clickhouse client like this:

```
$ docker run \
    -ti --rm \
    --link clickhouse-server:clickhouse-server \
    yandex/clickhouse-client \
    --host clickhouse-server

ClickHouse client version 1.1.54383.
Connecting to clickhouse-server:9000.
Connected to ClickHouse server version 1.1.54383.

dec0c5819f76 :) CREATE TABLE test_table
:-] (
:-]     test_column String,
:-]     test_column_two String
:-] ) ENGINE Memory;

CREATE TABLE test_table
(
    test_column String,
    test_column_two String
)
ENGINE = Memory

Ok.

0 rows in set. Elapsed: 0.099 sec.

dec0c5819f76 :)
```

You can then execute the unit tests using nimble:

```
$ nimble tests
```

If you want you can customize the host that will be used as ClickHouse server
during the unit tests using the `TEST_DB_HOSTNAME` environment variable, and
this will be needed if you are using Docker Machine.