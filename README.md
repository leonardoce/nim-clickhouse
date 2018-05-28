# Nim Clickhouse Interface

## Introduction

This package let's you use the [Clickhouse](https://clickhouse.yandex/)
analytical database from the [Nim](https://nim-lang.org) language, using an
interface similar to the ones provided for SQLite and for PostgreSQL.

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