# Test start_tile_server and stop_tile_server
# Skip if duckdb is not available
tinytest::exit_if_not(requireNamespace("duckdb", quietly = TRUE))

library(tinytest)
library(duckdb)

# Create a test database connection
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")

# Create a simple test table with spatial data
# Note: This requires DuckDB spatial extension
tryCatch(
  {
    dbExecute(con, "INSTALL spatial")
    dbExecute(con, "LOAD spatial")

    # Create a test table with geometry
    dbExecute(
      con,
      "CREATE TABLE test_features (
        id INTEGER,
        name VARCHAR,
        geometry GEOMETRY
      )"
    )

    # Insert a test point (in Web Mercator)
    dbExecute(
      con,
      "INSERT INTO test_features VALUES (1, 'test', ST_Point(0, 0))"
    )

    # Test start_tile_server with valid connection

    # Should fail with non-existent table
    expect_error(
      start_tile_server(con, "nonexistent_table"),
      pattern = "does not exist"
    )

    # Should succeed with valid table
    server <- start_tile_server(
      con,
      "test_features",
      port = 9999
    )

    expect_inherits(server, "rtileserver")
    expect_equal(server$port, 9999)
    expect_equal(server$host, "127.0.0.1")
    expect_equal(server$table_name, "test_features")
    expect_true(grepl("tiles/\\{z\\}/\\{x\\}/\\{y\\}\\.pbf", server$url))

    # Test print method
    expect_silent(print(server))

    # Test stop_tile_server
    expect_silent(stop_tile_server(server, disconnect_db = FALSE))

    # Test with auto port detection
    server2 <- start_tile_server(con, "test_features")
    expect_inherits(server2, "rtileserver")
    expect_true(server2$port >= 8000)
    stop_tile_server(server2)

    # Test with custom properties
    server3 <- start_tile_server(
      con,
      "test_features",
      properties = c("id", "name")
    )
    expect_inherits(server3, "rtileserver")
    stop_tile_server(server3)

    # Clean up
    dbDisconnect(con)
  },
  error = function(e) {
    if (exists("con") && dbIsValid(con)) {
      dbDisconnect(con)
    }
    exit_file("DuckDB spatial extension not available or test setup failed")
  }
)

# Test error handling

# Should fail with non-DBI connection
expect_error(
  start_tile_server("not a connection", "table"),
  pattern = "DBI database connection"
)

# Should fail with invalid server object
expect_error(
  stop_tile_server("not a server"),
  pattern = "rtileserver object"
)
