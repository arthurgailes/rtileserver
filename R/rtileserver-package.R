#' @keywords internal
"_PACKAGE"

#' rtileserver: Vector Tile Server for Spatial Databases
#'
#' The rtileserver package provides a lightweight HTTP tile server for serving
#' Mapbox Vector Tiles (MVT) from spatial databases including DuckDB and
#' PostgreSQL/PostGIS. The package uses httpuv for serving tiles and supports
#' the ST_AsMVT function for efficient tile generation.
#'
#' @section Main functions:
#' - [start_tile_server()]: Start a vector tile server
#' - [stop_tile_server()]: Stop a running tile server
#'
#' @section Workflow:
#' 1. Create a database connection with spatial data
#' 2. Start the tile server with `start_tile_server()`
#' 3. Use the tiles in your mapping application
#' 4. Stop the server with `stop_tile_server()`
#'
#' @examples
#' \dontrun{
#' library(DBI)
#' library(duckdb)
#' library(rtileserver)
#'
#' # Connect to database
#' con <- dbConnect(duckdb::duckdb())
#'
#' # Load spatial data (requires DuckDB spatial extension)
#' dbExecute(con, "INSTALL spatial")
#' dbExecute(con, "LOAD spatial")
#'
#' # Start tile server
#' server <- start_tile_server(con, "my_spatial_table")
#'
#' # Tiles are now available at the URL shown in server$url
#' print(server)
#'
#' # Stop when done
#' stop_tile_server(server)
#' }
#'
#' @docType package
#' @name rtileserver-package
NULL
