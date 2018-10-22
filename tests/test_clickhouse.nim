import unittest, db_clickhouse, os, strutils

## To execute this suite of tests, you need to have a table generated
## by the following query:
##
##     CREATE TABLE test_table
##     (
##         test_column String,
##         test_column_two String
##     ) ENGINE Memory;
##
## You can choose the hostname of the ClickHouse server you want to use as
## testbed with the TEST_DB_HOSTNAME environment variable. The default
## behavior is to use `localhost`

## This function gets the hostname to use as a testing environment
proc getTestHostname(): string =
  let env = getEnv("TEST_DB_HOSTNAME")
  if env.len()==0:
    result = "localhost"
  else:
    result = env

suite "Clickhouse DB client tests":
  var client:DbConn = db_clickhouse.open(getTestHostname())

  test "create query URL":
    let u = "http://" & getTestHostname() & ":8123/?query=SELECT+1"
    check(client.createQueryUrl("SELECT 1") == u)

  test "ping":
    check(client.ping)

  test "a wrong query causes an exception":
    expect DbError:
      client.exec("SELECT COUNT(*) FROM unexistent_table")

  test "a legitimate query wan't cause any exception":
    client.exec("SELECT 1 FROM test_table")

  test "insert one row in the test table":
    client.exec("INSERT INTO test_table FORMAT TabSeparated", "first string", "second string")

  test "insert two rows in the test table":
    client.execMultiple(
      "INSERT INTO test_table FORMAT TabSeparated",
      @[@["one", "two"],
        @["three", "four"],
        @["0", "1"]])

  test "get all rows":
    let result = client.getAllRows("SELECT * FROM test_table ORDER BY test_column")
    check(result.len() > 0)
    check(result[0].len() == 2)
    check(result[0] == @["0", "1"])

  test "get first row":
    let row = client.getRow("SELECT * FROM test_table ORDER BY test_column")
    check(row.len() == 2)
    check(row == @["0", "1"])

  test "get first row":
    let value = client.getValue("SELECT * FROM test_table ORDER BY test_column")
    check(value == "0")

  test "exec raw data":
    discard client.execRaw("INSERT INTO test_table FORMAT TabSeparated", "first\tsecond")
    check(client.execRaw("SELECT * FROM test_table FORMAT TabSeparated").splitLines().len() > 2)


suite "TabSeparated encoding tests":
  test "basic string decoding":
    check(decodeString("ciao") == "ciao")
    check(decodeString("ci\\tao") == "ci\tao")

  test "basic row decoding":
    check(decodeRow("ciao\tda\tm\\te") == @["ciao", "da", "m\te"])

  test "basic data decoding":
    check(decodeRows("ciao\tda\tme\nprova\tper\tte") == @[@["ciao", "da", "me"], @["prova", "per", "te"]])

  test "basic string encoding":
    check(encodeString("cia\to") == "cia\\to")

  test "basic row encoding":
    check(encodeRow(1, "ciao", 3) == "1\tciao\t3")

  test "basic table encoding":
    check(encodeRows(@[@["one", "two"], @["three", "four"]]) == "one\ttwo\nthree\tfour")

  test "extract first row":
    check(extractFirstRow("test") == "test")
    check(extractFirstRow("test\ttwo\nthree\tfour") == "test\ttwo")

  test "extract first column":
    check(extractFirstCol("test") == "test")
    check(extractFirstCol("test\ttwo") == "test")