# Complete test of tile server with mapgl integration
# This script tests the full workflow from data loading to map display

# Load the package from source
devtools::load_all(".")

# Clean environment - stop any existing servers
if (exists(".rtileserver_instances")) {
  for (srv in .rtileserver_instances) {
    try(stop_tile_server(srv), silent = TRUE)
  }
  rm(.rtileserver_instances)
}

# Load packages
library(DBI)
library(duckdb)
library(sf)
library(duckspatial)
library(mapgl)

cat("=== Step 1: Load and prepare data ===\n")
# Load NC data
nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
cat("Original CRS:", st_crs(nc)$input, "\n")
cat("Counties loaded:", nrow(nc), "\n")

# Transform to Web Mercator - CRITICAL!
nc_merc <- st_transform(nc, 3857)
cat("Transformed CRS:", st_crs(nc_merc)$input, "\n")
cat("Bounding box (Web Mercator):\n")
print(st_bbox(nc_merc))

cat("\n=== Step 2: Setup DuckDB ===\n")
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")
ddbs_install(con)
ddbs_load(con)
ddbs_write_vector(con, nc_merc, "nc_counties", overwrite = TRUE)

# Verify data in database
cat("Rows in database:", dbGetQuery(con, "SELECT COUNT(*) FROM nc_counties")[[1]], "\n")

# Create spatial index
dbExecute(con, "CREATE INDEX idx_nc_geom ON nc_counties USING RTREE (geometry)")
cat("Spatial index created\n")

cat("\n=== Step 3: Start tile server ===\n")
server <- start_tile_server(
  con,
  table_name = "nc_counties",
  geometry_column = "geometry",
  properties = c("NAME", "FIPS", "AREA"),
  port = NULL  # Auto-find available port
)

print(server)
cat("\n")

# Store server reference for cleanup
.rtileserver_instances <- list(server)

cat("=== Step 4: Test tile generation ===\n")
# Manually test a tile using database query
test_query <- sprintf("
  SELECT ST_AsMVT(mvt_geom, 'layer')
  FROM (
    SELECT
      NAME, FIPS, AREA,
      ST_AsMVTGeom(
        geometry,
        (SELECT ST_Extent(ST_TileEnvelope(5, 8, 12)))
      ) AS geometry
    FROM nc_counties
    WHERE ST_Intersects(geometry, ST_TileEnvelope(5, 8, 12))
  ) AS mvt_geom
")

result <- dbGetQuery(con, test_query)
tile_bytes <- result[[1]][[1]]
cat("Test tile (5/8/12) size:", length(tile_bytes), "bytes\n")

if (length(tile_bytes) > 0) {
  cat("✓ Tile generation working!\n")
} else {
  cat("✗ WARNING: Empty tile generated - check CRS!\n")
}

cat("\n=== Step 5: Test HTTP endpoint ===\n")
# Wait for server to be ready
Sys.sleep(1)

# Note: HTTP test from same R session may timeout due to event loop
# This is expected - the server will work from external clients (like browser/mapgl)
cat("Server should respond to external HTTP requests at:\n")
cat("  ", server$url, "\n")
cat("  Example: http://127.0.0.1:", server$port, "/tiles/5/8/12.pbf\n", sep = "")

cat("\n=== Step 6: Create mapgl map ===\n")
# Note: Using the exact same format as the working example
map <- maplibre(
  center = c(-79.5, 35.5),
  zoom = 6,
  style = carto_style("positron")
) |>
  add_vector_source(
    id = "nc-tiles",
    url = paste0("http://127.0.0.1:", server$port, "/tiles/{z}/{x}/{y}.pbf"),
    minzoom = 0,
    maxzoom = 14
  ) |>
  add_fill_layer(
    id = "nc-fill",
    source = "nc-tiles",
    source_layer = "layer",
    fill_color = "steelblue",
    fill_opacity = 0.6,
    tooltip = "NAME"
  ) |>
  add_line_layer(
    id = "nc-outline",
    source = "nc-tiles",
    source_layer = "layer",
    line_color = "white",
    line_width = 1
  )

cat("\n=== Step 7: Display map ===\n")
cat("Displaying map in viewer...\n")
print(map)

cat("\n=== Map displayed ===\n")
cat("The tile server is running at:", server$url, "\n")
cat("If you see errors in the browser console:\n")
cat("  - Check that port", server$port, "is accessible\n")
cat("  - Verify data is in EPSG:3857\n")
cat("  - Check browser console for specific errors\n")
cat("\nWhen done viewing, run: stop_tile_server(server, disconnect_db = TRUE)\n")

# Keep the server running
invisible(map)
