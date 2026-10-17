# Pure fleet replay helpers retained from the retired standalone Shiny demo.
# Called by tools/export_fleet_viz.R; dplyr is loaded by the exporter.
CAPACITY <- 30L

FLEET <- 405L

CITIES <- list(tampa = list(id = "tampa", name = "Tampa", state = "FL", label = "🌴 Tampa, FL", lat = 27.9486,
    lon = -82.4572, zoom = 15, tz = "America/New_York", sub = "Tampa Network · 405 Bikes · 27 Docks"),
    jersey_city = list(id = "jersey_city", name = "Jersey City", state = "NJ", label = "🏙️ Jersey City, NJ",
        lat = 40.7194, lon = -74.0446, zoom = 14, tz = "America/New_York", sub = "Jersey City Network · 405 Bikes · 27 Docks"),
    milwaukee = list(id = "milwaukee", name = "Milwaukee", state = "WI", label = "🍺 Milwaukee, WI",
        lat = 43.0389, lon = -87.9065, zoom = 14, tz = "America/Chicago", sub = "Milwaukee Network · 405 Bikes · 27 Docks"))

format_stations_payload <- function(st_df) {
    lapply(seq_len(nrow(st_df)), function(i) {
        list(id = as.integer(st_df$id[i]), dockID = as.character(st_df$dockID[i]), lat = as.numeric(st_df$lat[i]),
            lon = as.numeric(st_df$lon[i]), zone = as.character(st_df$zone[i]))
    })
}

city_data_cache <- list()

load_city_bundle <- function(city_key) {
    if (!is.null(city_data_cache[[city_key]])) {
        return(city_data_cache[[city_key]])
    }
    meta <- CITIES[[city_key]]
    st_file <- file.path(DATA_DIR, "stations", paste0(city_key, ".csv"))
    zn_file <- file.path(DATA_DIR, "zoning", paste0(city_key, ".csv"))
    dist_file <- file.path(DATA_DIR, "distances", paste0(city_key, ".csv"))
    mov_file <- file.path(DATA_DIR, paste0(city_key, ".rds"))
    message(sprintf("[fleet_viz] Loading & caching data bundle for %s (%s)…", meta$name, meta$state))
    stations <- read.csv(st_file, colClasses = "character")
    stations$lat <- as.numeric(stations$lat)
    stations$lon <- as.numeric(stations$lon)
    zones <- read.csv(zn_file, colClasses = "character")
    stations <- merge(stations, zones, by = "dockID", all.x = TRUE)
    stations$zone[is.na(stations$zone)] <- "unassigned"
    stations$id <- seq_len(nrow(stations)) - 1L
    N <- nrow(stations)
    route_list <- list()
    pair_to_route_idx <- list()
    route_counter <- 0L
    if (city_key == "tampa") {
        ew_names <- c("East Washington Street", "East Jackson Street", "East Kennedy Boulevard", "East Madison Street",
            "East Twiggs Street", "East Zack Street", "Polk Street")
        clean_dock <- function(dockID) {
            parts <- strsplit(dockID, " & ")[[1]]
            if (parts[1] %in% ew_names)
                c(ew = parts[1], ns = parts[2])
            else c(ew = parts[2], ns = parts[1])
        }
        p <- t(sapply(stations$dockID, clean_dock))
        stations$ew <- p[, 1]
        stations$ns <- p[, 2]
        grid_coords <- list()
        for (i in seq_len(N)) {
            key <- paste(stations$ew[i], stations$ns[i], sep = " | ")
            grid_coords[[key]] <- c(lat = stations$lat[i], lon = stations$lon[i])
        }
        for (i in seq_len(N)) {
            for (j in seq_len(N)) {
                pair_key <- paste(i - 1L, j - 1L, sep = "_")
                if (i == j) {
                  pair_to_route_idx[[pair_key]] <- -1L
                  next
                }
                st1 <- stations[i, ]
                st2 <- stations[j, ]
                if (st1$ew == st2$ew || st1$ns == st2$ns) {
                  route_list[[length(route_list) + 1L]] <- list(lats = c(st1$lat, st2$lat), lons = c(st1$lon,
                    st2$lon), n = 2L, w1 = 1)
                }
                else {
                  key1 <- paste(st1$ew, st2$ns, sep = " | ")
                  key2 <- paste(st2$ew, st1$ns, sep = " | ")
                  corner <- if (!is.null(grid_coords[[key1]]))
                    grid_coords[[key1]]
                  else grid_coords[[key2]]
                  d1_dist <- sqrt((corner["lat"] - st1$lat)^2 + (corner["lon"] - st1$lon)^2)
                  d2_dist <- sqrt((st2$lat - corner["lat"])^2 + (st2$lon - corner["lon"])^2)
                  w1 <- as.numeric(d1_dist/(d1_dist + d2_dist))
                  route_list[[length(route_list) + 1L]] <- list(lats = c(st1$lat, as.numeric(corner["lat"]),
                    st2$lat), lons = c(st1$lon, as.numeric(corner["lon"]), st2$lon), n = 3L, w1 = w1)
                }
                pair_to_route_idx[[pair_key]] <- route_counter
                route_counter <- route_counter + 1L
            }
        }
    }
    else {
        dist_df <- read.csv(dist_file, colClasses = c("character", "character", "numeric"))
        dmat <- matrix(Inf, N, N)
        diag(dmat) <- 0
        for (k in seq_len(nrow(dist_df))) {
            idx1 <- which(stations$dockID == dist_df$dockID1[k])
            idx2 <- which(stations$dockID == dist_df$dockID2[k])
            if (length(idx1) == 1L && length(idx2) == 1L) {
                dmat[idx1, idx2] <- dist_df$distance[k]
            }
        }
        for (i in seq_len(N)) {
            for (j in seq_len(N)) {
                pair_key <- paste(i - 1L, j - 1L, sep = "_")
                if (i == j) {
                  pair_to_route_idx[[pair_key]] <- -1L
                  next
                }
                st1 <- stations[i, ]
                st2 <- stations[j, ]
                d_direct <- dmat[i, j]
                best_diff <- Inf
                best_k <- -1L
                for (k in seq_len(N)) {
                  if (k != i && k != j) {
                    diff <- (dmat[i, k] + dmat[k, j]) - d_direct
                    if (diff < best_diff) {
                      best_diff <- diff
                      best_k <- k
                    }
                  }
                }
                if (best_diff < 0.05 && best_k > 0L) {
                  st_corner <- stations[best_k, ]
                  w1 <- as.numeric(dmat[i, best_k]/(dmat[i, best_k] + dmat[best_k, j]))
                  route_list[[length(route_list) + 1L]] <- list(lats = c(st1$lat, st_corner$lat, st2$lat),
                    lons = c(st1$lon, st_corner$lon, st2$lon), n = 3L, w1 = w1)
                }
                else {
                  route_list[[length(route_list) + 1L]] <- list(lats = c(st1$lat, st2$lat), lons = c(st1$lon,
                    st2$lon), n = 2L, w1 = 1)
                }
                pair_to_route_idx[[pair_key]] <- route_counter
                route_counter <- route_counter + 1L
            }
        }
    }
    movement <- readRDS(mov_file)
    movement$date <- as.Date(movement$time, tz = meta$tz)
    all_dates <- sort(unique(movement$date))
    all_bike_ids <- sort(unique(movement$BIKEID))
    dock_map <- setNames(seq_len(nrow(stations)) - 1L, stations$dockID)
    bike_map <- setNames(seq_len(length(all_bike_ids)) - 1L, all_bike_ids)
    dock_ts <- movement %>% filter(DOCID != "0") %>% count(DOCID, time, date, name = "bikes") %>% mutate(bikes = as.integer(bikes),
        fill_pct = bikes/CAPACITY)
    daily_dock <- dock_ts %>% group_by(date, DOCID) %>% summarise(mean_bikes = mean(bikes), mean_fill = mean(fill_pct),
        min_bikes = min(bikes), max_bikes = max(bikes), n_empty = sum(bikes == 0L), n_full = sum(bikes ==
            CAPACITY), .groups = "drop") %>% left_join(stations[, c("dockID", "zone")], by = c(DOCID = "dockID"))
    bundle <- list(city_key = city_key, meta = meta, stations = stations, stations_payload = format_stations_payload(stations),
        route_list = route_list, pair_to_route_idx = pair_to_route_idx, movement = movement, all_dates = all_dates,
        all_bike_ids = all_bike_ids, dock_map = dock_map, bike_map = bike_map, dock_ts = dock_ts, daily_dock = daily_dock)
    city_data_cache[[city_key]] <<- bundle
    bundle
}

format_trips_payload <- function(trips_df) {
    list(b_id = as.integer(unname(trips_df$b_id)), d1 = as.integer(unname(trips_df$d1)), d2 = as.integer(unname(trips_df$d2)),
        start_step = as.integer(unname(trips_df$start_step)), end_step = as.integer(unname(trips_df$end_step)),
        r_idx = as.integer(unname(trips_df$r_idx)), n = as.integer(nrow(trips_df)))
}

get_day_payload <- function(bundle, target_date) {
    day_mov <- bundle$movement %>% filter(date == target_date) %>% arrange(time)
    t_start <- as.POSIXct(paste(target_date, "00:00:00"), tz = bundle$meta$tz)
    day_mov$step <- as.integer(difftime(day_mov$time, t_start, units = "mins")/5) + 1L
    day_trips <- day_mov %>% filter(DOCID != "0") %>% arrange(BIKEID, time) %>% group_by(BIKEID) %>%
        mutate(prev_dock = lag(DOCID), start_step = lag(step), end_step = step) %>% filter(!is.na(prev_dock) &
        DOCID != prev_dock) %>% ungroup() %>% mutate(b_id = as.integer(unname(bundle$bike_map[BIKEID])),
        d1 = as.integer(unname(bundle$dock_map[prev_dock])), d2 = as.integer(unname(bundle$dock_map[DOCID])),
        pair_k = paste(d1, d2, sep = "_"), r_idx = as.integer(unname(unlist(bundle$pair_to_route_idx[pair_k])))) %>%
        select(b_id, d1, d2, start_step, end_step, r_idx)
    day_dock_counts <- day_mov %>% filter(DOCID != "0") %>% count(DOCID, step, name = "bikes")
    dock_mat <- matrix(0L, nrow = 288, ncol = nrow(bundle$stations))
    for (k in seq_len(nrow(day_dock_counts))) {
        s_idx <- bundle$dock_map[day_dock_counts$DOCID[k]] + 1L
        st_idx <- day_dock_counts$step[k]
        if (!is.na(s_idx) && st_idx >= 1L && st_idx <= 288L) {
            dock_mat[st_idx, s_idx] <- day_dock_counts$bikes[k]
        }
    }
    day_trips_df <- as.data.frame(day_trips)
    list(trips = format_trips_payload(day_trips_df), trips_df = day_trips_df, dock_mat = dock_mat)
}
