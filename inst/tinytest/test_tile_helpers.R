# Test parse_tile_path

# Valid tile paths
result <- rtileserver:::parse_tile_path("/tiles/10/512/384.pbf")
expect_equal(result$z, 10L)
expect_equal(result$x, 512L)
expect_equal(result$y, 384L)

# Another valid path
result <- rtileserver:::parse_tile_path("/tiles/0/0/0.pbf")
expect_equal(result$z, 0L)
expect_equal(result$x, 0L)
expect_equal(result$y, 0L)

# Invalid paths should return NULL
expect_null(rtileserver:::parse_tile_path("/invalid"))
expect_null(rtileserver:::parse_tile_path("/tiles/10/512"))
expect_null(rtileserver:::parse_tile_path("/tiles/a/b/c.pbf"))
expect_null(rtileserver:::parse_tile_path(""))

# Test find_available_port

# Should return a port number
port <- rtileserver:::find_available_port(start_port = 9000)
expect_true(is.numeric(port))
expect_true(port >= 9000)
expect_true(port < 9010)

# Test create_tile_query

# Basic query with all columns
query <- rtileserver:::create_tile_query("my_table")
expect_true(grepl("my_table", query))
expect_true(grepl("ST_AsMVT", query))
expect_true(grepl("ST_TileEnvelope", query))
expect_true(grepl("\\*", query))

# Query with specific properties
query <- rtileserver:::create_tile_query(
  "my_table",
  properties = c("id", "name")
)
expect_true(grepl("id", query))
expect_true(grepl("name", query))

# Query with custom geometry column
query <- rtileserver:::create_tile_query(
  "my_table",
  geometry_column = "geom"
)
expect_true(grepl("geom", query))

# Query with custom layer name
query <- rtileserver:::create_tile_query(
  "my_table",
  layer_name = "custom_layer"
)
expect_true(grepl("custom_layer", query))
