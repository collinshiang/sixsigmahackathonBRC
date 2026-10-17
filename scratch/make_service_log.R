# Build a SIMULATED, staggered service_log.csv for a city and check dispatch output.
# Usage: Rscript scratch/make_service_log.R jersey_city 60
suppressMessages(library(dplyr))
args <- commandArgs(TRUE); city <- ifelse(length(args) > 0, args[1], "jersey_city")
interval_h <- ifelse(length(args) > 1, as.numeric(args[2]), 60)
source("bikemaintenance/service_code/qc.R")
d <- read.csv(gzfile(sprintf("data/%s.csv.gz", city)), colClasses = c(DOCID = "character"))
tm <- parse_time(d$time); t0 <- min(tm); t1 <- max(tm)
set.seed(42)
bikes <- sort(unique(d$BIKEID))
# Ride hours per bike over the window, to size the stagger realistically.
rh <- d %>% mutate(away = DOCID == "0") %>% group_by(BIKEID) %>% summarise(h = sum(away) * 5 / 60)
# Pick each bike's last service so its ride hours SINCE service are staggered
# uniformly in [0, 1.15 * interval]: most bikes are not due, a realistic minority are.
d$t <- tm; d$away <- d$DOCID == "0"
target <- setNames(runif(length(bikes), 0, 1.15 * interval_h), bikes)
pick <- function(g) {
  g <- g[order(g$t), ]
  cum_back <- rev(cumsum(rev(g$away))) * 5 / 60   # ride hours from each snapshot to the end
  i <- which(cum_back <= target[[g$BIKEID[1]]])[1]
  if (is.na(i)) g$t[nrow(g)] else g$t[i]
}
serv <- bikes
st <- as.POSIXct(vapply(split(d, d$BIKEID), function(g) as.numeric(pick(g)), numeric(1))[bikes],
                 origin = "1970-01-01", tz = "UTC")
log <- data.frame(BIKEID = serv, service_time = format(st, "%Y-%m-%dT%H:%M:%S%z", tz = "America/New_York"))
log <- log[order(log$BIKEID), ]
out <- sprintf("data/service_log_%s.csv", city)
write.csv(log, out, row.names = FALSE, quote = FALSE)
cat("wrote", out, nrow(log), "rows\n"); print(summary(rh$h))
s0 <- service_status(d, interval_h)
s1 <- service_status(d, interval_h, service_log = log)
cat(sprintf("due WITHOUT log: %d / %d\ndue WITH log:    %d / %d\n", sum(s0$due), nrow(s0), sum(s1$due), nrow(s1)))
