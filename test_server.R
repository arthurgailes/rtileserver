# Quick diagnostic script to test the tile server
library(rtileserver)
library(DBI)
library(duckdb)
library(sf)
library(duckspatial)

# Reload package
devtools::load_all()

# Load North Carolina counties data
nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)

# Transform to Web Mercator
nc_merc <- st_transform(nc, 3857)

# Create DuckDB connection
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")

# Install and load spatial extension
ddbs_install(con)
ddbs_load(con)

# Write spatial data to DuckDB
ddbs_write_vector(con, nc_merc, "nc_counties", overwrite = TRUE)

# Create spatial index
dbExecute(con, "CREATE INDEX idx_nc_geom ON nc_counties USING RTREE (geometry)")

# Start tile server
server <- start_tile_server(
  con,
  table_name = "nc_counties",
  geometry_column = "geometry",
  properties = c("NAME", "FIPS", "AREA"),
  port = 8003  # Use the same port you had
)

print(server)
cat("\n")
cat("Testing tile endpoint...\n")
cat("Server URL:", server$url, "\n")

# Try to fetch a test tile manually
test_url <- "http://127.0.0.1:8003/tiles/5/8/12.pbf"
cat("Fetching:", test_url, "\n")

tryCatch({
  result <- httr::GET(test_url)
  cat("Status:", httr::status_code(result), "\n")
  cat("Headers:\n")
  print(httr::headers(result))
  cat("Content length:", length(httr::content(result, "raw")), "bytes\n")
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
})

# Keep server running
cat("\nServer is running. Press Ctrl+C to stop.\n")
Sys.sleep(1000)
