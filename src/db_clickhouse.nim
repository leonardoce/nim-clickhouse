import httpclient, uri, system, strutils, sequtils, httpcore

type
  DbConn* = ref object
    hostName: string ## We connect to this host name
    httpPort: int    ## and using this port
    client: HttpClient

  ## This error is raised when the query execution raised an error
  ## in the clickhouse engine
  DbError* = object of IOError

  ## A row
  Row* = seq[string]

## Encode a string in the TabSeparated format
proc encodeString*(arg: string): string =
  result = ""
  for i in 0..len(arg)-1:
    if arg[i] == '\t':
      result &= "\\t"
    elif arg[i] == '\b':
      result &= "\\b"
    elif arg[i] == '\f':
      result &= "\\f"
    elif arg[i] == '\r':
      result &= "\\r"
    elif arg[i] == '\n':
      result &= "\\n"
    elif arg[i] == '\0':
      result &= "\\0"
    elif arg[i] == '\'':
      result &= "\\'"
    elif arg[i] == '\\':
      result &= "\\\\"
    else:
      result &= arg[i]

## The following functions implement the TabSeparated format
## ---------------------------------------------------------

## Encode a row in the TabSeparated format
proc encodeRow*(args:varargs[string, `$`]): string =
  result = join(map(args, encodeString), "\t")

## Encode a row in the TabSeparated format
proc encodeRow*(args:seq[string]): string =
  result = join(map(args, encodeString), "\t")

## Encode a list of rows in the TabSeparated format
proc encodeRows*(data:seq[seq[string]]): string =
  result = join(map(data, encodeRow), "\n")

## Decode a string
proc decodeString*(content: string): string =
  if content == nil:
    return nil

  result = content
  while true:
    let idx = result.find("\\")
    if idx == -1:
      break
    if idx == result.len() - 1:
      break
    if result[idx+1] == 'n':
      result = result[0..<idx] & "\n" & result[idx+2..^1]
    elif result[idx+1] == 't':
      result = result[0..<idx] & "\t" & result[idx+2..^1]
    elif result[idx+1] == 'b':
      result = result[0..<idx] & "\b" & result[idx+2..^1]
    elif result[idx+1] == 'f':
      result = result[0..<idx] & "\f" & result[idx+2..^1]
    elif result[idx+1] == 'r':
      result = result[0..<idx] & "\r" & result[idx+2..^1]
    elif result[idx+1] == '0':
      result = result[0..<idx] & "\0" & result[idx+2..^1]
    elif result[idx+1] == '\'':
      result = result[0..<idx] & "\'" & result[idx+2..^1]
    elif result[idx+1] == '\\':
      result = result[0..<idx] & "\\" & result[idx+2..^1]

## Decode a row from a string
proc decodeRow*(row:string): Row =
  if row == nil:
    return nil

  result = row.split('\t').map(decodeString)

## Decode a list of rows in the TabSeparated format
proc decodeRows*(data:string): seq[Row] =
  if data == nil:
    return nil

  result = data.split('\n').map(decodeRow)

## Extract the first row of a TabSeparated query data
proc extractFirstRow*(data: string): string =
  if data == nil:
    return nil

  let idx = data.find("\n")
  if idx == -1:
    result = data
  else:
    result = data[0..<idx]

## Extract the first column of a TabSeparated query data
proc extractFirstCol*(data: string): string =
  if data == nil:
    return nil

  let idx = data.find("\t")
  if idx == -1:
    result = data
  else:
    result = data[0..<idx]


## The following functions implement the DbConn interface
## ------------------------------------------------------

## Create a new clickhouse client
proc open*(hostName: string, httpPort:int = 8123): DbConn =
  new result
  result.hostName = hostName
  result.httpPort = httpPort
  result.client = newHttpClient()

## Create a query URL, for internal use only
proc createQueryUrl*(self: DbConn, query: string): string =
  result = "http://" & self.hostName & ":" & $self.httpPort & "/?query=" & encodeUrl(query)

## Ping the clickhouse database issuing a simple query, to find if
## it's available or not
proc ping*(self: DbConn): bool =
  let url = self.createQueryUrl("SELECT 1")
  let test = self.client.getContent(url)
  result = (test.strip() == "1")

proc checkForErrors(response: Response) =
  if response.status[0] in {'3', '4', '5'}:
    raise newException(DbError, response.body.strip())

## Exec a query against the clickhouse database, without parsing the result
proc exec*(self: DbConn, query:string, args: varargs[string, `$`]) =
  let body = encodeRow(args)
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="POST",
    headers=xh)
  checkForErrors(response)

## Exec a query without formatting the input parameters and without parsing
## the output results. This is useful for bulk imports/exports, even if it
## doesn't behave to the original interface
proc execRaw*(self: DbConn, query:string, body:string = ""): string =
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="POST",
    headers=xh)
  checkForErrors(response)
  result = response.body

## Exec a query against the clickhouse database, without parsing the result
proc execMultiple*(self: DbConn, query:string, args: seq[seq[string]]) =
  let body = encodeRows(args)
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="POST",
    headers=xh)
  checkForErrors(response)

## Close the http client
proc close*(self: DbConn) =
  self.client.close()

## Executes the query and returns the whole result dataset
proc getAllRows*(self: DbConn, query: string, args: varargs[string, `$`]): seq[Row] =
  let body = encodeRow(args)
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="GET",
    headers=xh)
  checkForErrors(response)
  result = decodeRows(response.body)

## Executes the query and returns the first row of the dataset
proc getRow*(self: DbConn, query: string, args: varargs[string, `$`]): Row =
  let body = encodeRow(args)
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="GET",
    headers=xh)
  checkForErrors(response)

  result = decodeRow(extractFirstRow(response.body))

## Executes the query and returns the first column of the
## first row of the dataset
proc getValue*(self: DbConn, query: string, args: varargs[string, `$`]): string =
  let body = encodeRow(args)
  let xh = newHttpHeaders({
    "Content-Length": $len(body)
  })
  let response = self.client.request(
    self.createQueryUrl(query),
    body=body,
    httpMethod="GET",
    headers=xh)
  checkForErrors(response)

  result = extractFirstCol(extractFirstRow(response.body))
