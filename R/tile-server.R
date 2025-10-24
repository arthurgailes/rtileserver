#' Start a vector tile server
#'
#' Starts an HTTP server that serves Mapbox Vector Tiles (MVT) from a spatial
#' database connection. The server uses the database's `ST_AsMVT` function to
#' generate tiles on demand.
#'
#' @param con A database connection object (DBI-compatible).
#' @param table_name Character string with the name of the spatial table.
#' @param geometry_column Character string with the geometry column name.
#'   Default is "geometry".
#' @param layer_name Character string with the MVT layer name. Default is
#'   "layer".
#' @param properties Character vector of property columns to include in tiles.
#'   If `NULL` (default), all columns are included.
#' @param host Character string with the host address. Default is "127.0.0.1".
#' @param port Integer port number. If `NULL` (default), an available port is
#'   automatically found starting from 8000.
#'
#' @return A list with class "rtileserver" containing:
#'   \item{server}{The httpuv server object}
#'   \item{port}{The port number}
#'   \item{host}{The host address}
#'   \item{con}{The database connection}
#'   \item{table_name}{The table name}
#'   \item{url}{The base URL for tiles}
#'
#' @examples
#' \dontrun{
#' library(DBI)
#' library(duckdb)
#'
#' con <- dbConnect(duckdb::duckdb())
#' # Load spatial data into DuckDB...
#'
#' server <- start_tile_server(
#'   con,
#'   table_name = "features",
#'   properties = c("id", "name")
#' )
#'
#' # Use tiles at: http://127.0.0.1:PORT/tiles/{z}/{x}/{y}.pbf
#' print(server$url)
#'
#' # Stop the server when done
#' stop_tile_server(server)
#' }
#'
#' @export
start_tile_server <- function(
  con,
  table_name,
  geometry_column = "geometry",
  layer_name = "layer",
  properties = NULL,
  host = "127.0.0.1",
  port = NULL
) {
  if (!inherits(con, "DBIConnection")) {
    stop("con must be a DBI database connection")
  }

  if (!DBI::dbExistsTable(con, table_name)) {
    stop(sprintf("Table '%s' does not exist in the database", table_name))
  }

  if (is.null(port)) {
    port <- find_available_port()
  }

  tile_query <- create_tile_query(
    table_name,
    geometry_column,
    layer_name,
    properties
  )

  tile_app <- list(
    call = function(req) {
      path <- req$PATH_INFO

      if (req$REQUEST_METHOD == "OPTIONS") {
        return(list(
          status = 200L,
          headers = list(
            "Access-Control-Allow-Origin" = "*",
            "Access-Control-Allow-Methods" = "GET, OPTIONS",
            "Access-Control-Allow-Headers" = "*"
          ),
          body = ""
        ))
      }

      tile_coords <- parse_tile_path(path)

      if (!is.null(tile_coords)) {
        tryCatch(
          {
            result <- DBI::dbGetQuery(
              con,
              tile_query,
              params = list(
                tile_coords$z,
                tile_coords$x,
                tile_coords$y,
                tile_coords$z,
                tile_coords$x,
                tile_coords$y
              )
            )

            tile_blob <- if (!is.null(result[[1]][[1]])) {
              result[[1]][[1]]
            } else {
              raw(0)
            }

            list(
              status = 200L,
              headers = list(
                "Content-Type" = "application/x-protobuf",
                "Access-Control-Allow-Origin" = "*"
              ),
              body = tile_blob
            )
          },
          error = function(e) {
            list(
              status = 500L,
              headers = list(
                "Content-Type" = "text/plain",
                "Access-Control-Allow-Origin" = "*"
              ),
              body = paste("Error generating tile:", e$message)
            )
          }
        )
      } else {
        list(
          status = 404L,
          headers = list(
            "Content-Type" = "text/plain",
            "Access-Control-Allow-Origin" = "*"
          ),
          body = "Not Found"
        )
      }
    }
  )

  server <- httpuv::startDaemonizedServer(host, port, tile_app)

  tile_url <- sprintf("http://%s:%d/tiles/{z}/{x}/{y}.pbf", host, port)

  message(sprintf("Tile server running at http://%s:%d/", host, port))
  message(sprintf("Tiles available at: %s", tile_url))

  structure(
    list(
      server = server,
      port = port,
      host = host,
      con = con,
      table_name = table_name,
      url = tile_url
    ),
    class = "rtileserver"
  )
}

#' Stop a vector tile server
#'
#' Stops a running tile server and optionally disconnects the database
#' connection.
#'
#' @param server An rtileserver object returned by [start_tile_server()].
#' @param disconnect_db Logical indicating whether to disconnect the database
#'   connection. Default is `FALSE`.
#'
#' @return `NULL`, invisibly.
#'
#' @examples
#' \dontrun{
#' server <- start_tile_server(con, "features")
#' stop_tile_server(server)
#' }
#'
#' @export
stop_tile_server <- function(server, disconnect_db = FALSE) {
  if (!inherits(server, "rtileserver")) {
    stop("server must be an rtileserver object")
  }

  httpuv::stopDaemonizedServer(server$server)
  message("Tile server stopped")

  if (disconnect_db) {
    DBI::dbDisconnect(server$con)
    message("Database disconnected")
  }

  invisible(NULL)
}

#' Print method for rtileserver objects
#'
#' @param x An rtileserver object.
#' @param ... Additional arguments (ignored).
#'
#' @return The rtileserver object, invisibly.
#' @export
print.rtileserver <- function(x, ...) {
  cat("<rtileserver>\n")
  cat(sprintf("  Server: http://%s:%d/\n", x$host, x$port))
  cat(sprintf("  Tiles:  %s\n", x$url))
  cat(sprintf("  Table:  %s\n", x$table_name))
  invisible(x)
}
