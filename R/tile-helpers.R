#' Parse tile coordinates from URL path
#'
#' Extracts z, x, y coordinates from a tile URL path.
#'
#' @param path Character string containing the URL path.
#' @return A list with z, x, y coordinates, or NULL if parsing fails.
#' @noRd
parse_tile_path <- function(path) {
  pattern <- "^/tiles/(\\d+)/(\\d+)/(\\d+)\\.pbf$"
  matches <- regmatches(path, regexec(pattern, path))[[1]]

  if (length(matches) == 4) {
    list(
      z = as.integer(matches[2]),
      x = as.integer(matches[3]),
      y = as.integer(matches[4])
    )
  } else {
    NULL
  }
}

#' Find an available port
#'
#' Searches for an available port starting from a given port number.
#'
#' @param start_port Integer port number to start searching from.
#' @param max_attempts Integer maximum number of ports to try.
#' @return An available port number.
#' @noRd
find_available_port <- function(start_port = 8000, max_attempts = 10) {
  for (i in 0:(max_attempts - 1)) {
    port <- start_port + i
    tryCatch(
      {
        test_server <- httpuv::startServer(
          "127.0.0.1",
          port,
          list(call = function(req) {
            list(status = 200L, body = "test")
          })
        )
        httpuv::stopServer(test_server)
        return(port)
      },
      error = function(e) {
        # Port in use, try next one
      }
    )
  }
  stop("Could not find available port")
}

#' Create tile query for database
#'
#' Generates an SQL query for retrieving a vector tile.
#'
#' @param table_name Character string with the table name.
#' @param geometry_column Character string with the geometry column name.
#' @param layer_name Character string with the MVT layer name.
#' @param properties Character vector of property columns to include.
#' @return Character string containing the SQL query.
#' @noRd
create_tile_query <- function(
  table_name,
  geometry_column = "geometry",
  layer_name = "layer",
  properties = NULL
) {
  # Build the property columns selection
  property_cols <- if (!is.null(properties)) {
    paste(properties, collapse = ",\n            ")
  } else {
    sprintf("* EXCLUDE (%s)", geometry_column)
  }

  sprintf(
    "
    SELECT ST_AsMVT(mvt_geom, '%s')
    FROM (
      SELECT
        %s,
        ST_AsMVTGeom(
          %s,
          (SELECT ST_Extent(ST_TileEnvelope(?, ?, ?)))
        ) AS geometry
      FROM %s
      WHERE ST_Intersects(%s, ST_TileEnvelope(?, ?, ?))
    ) AS mvt_geom
    ",
    layer_name,
    property_cols,
    geometry_column,
    table_name,
    geometry_column
  )
}
