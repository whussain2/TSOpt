# Size, time and memory limits of TSOpt designs, each measured in a fresh R
# process (peak resident memory from /usr/bin/time; macOS -l or GNU -v).
# Run from the repository folder:  Rscript benchmark/limits.R
cases <- list(
  list(name = "dense 1,000 lines",  code = "d <- tso_data(tso_simulate_panel(n = 1000, markers = 2000, seed = 1), verbose = FALSE); p <- tso_design(d, n = 150, n_random = 20, verbose = FALSE)"),
  list(name = "dense 2,000 lines",  code = "d <- tso_data(tso_simulate_panel(n = 2000, markers = 2000, seed = 1), verbose = FALSE); p <- tso_design(d, n = 300, n_random = 20, verbose = FALSE)"),
  list(name = "dense 5,000 lines",  code = "d <- tso_data(tso_simulate_panel(n = 5000, markers = 2000, seed = 1), verbose = FALSE); p <- tso_design(d, n = 500, n_random = 20, verbose = FALSE)"),
  list(name = "implicit 1,000 lines x 15 sites", code = "d <- tso_data(tso_simulate_panel(n = 1000, markers = 1500, seed = 3), envs = paste0('S', 1:15), env_cor = 0.6, verbose = FALSE); p <- tso_design(d, n = 1500, max_per_line = 3, n_random = 20, verbose = FALSE)"),
  list(name = "implicit 2,000 lines x 5 sites x 2 traits", code = "d <- tso_data(tso_simulate_panel(n = 2000, markers = 1500, seed = 3), envs = paste0('S', 1:5), traits = c('a', 'b'), gcor = matrix(c(1, .5, .5, 1), 2), verbose = FALSE); p <- tso_design(d, n = 1500, index = c(a = 1, b = 1), n_random = 20, verbose = FALSE)"),
  list(name = "tso_design_large 20,000 lines", code = "g <- tso_simulate_panel(n = 20000, markers = 3000, seed = 1); p <- tso_design_large(g, n = 1000, rank = 300, n_random = 5, verbose = FALSE)"))
gnu <- length(suppressWarnings(system("/usr/bin/time -v true 2>&1", intern = TRUE))) > 3
rows <- lapply(cases, function(cs) {
  f <- tempfile(fileext = ".R")
  writeLines(c("suppressMessages(library(TSOpt))", "t0 <- proc.time()[3]", cs$code,
               "cat('ELAPSED', proc.time()[3] - t0, '\\n')"), f)
  out <- suppressWarnings(system(paste(if (gnu) "/usr/bin/time -v" else "/usr/bin/time -l", "Rscript", f, "2>&1"), intern = TRUE))
  el <- as.numeric(sub(".*ELAPSED ", "", grep("ELAPSED", out, value = TRUE)[1]))
  rss <- if (gnu) as.numeric(sub(".*: ", "", grep("Maximum resident", out, value = TRUE))) / 1024
         else as.numeric(sub("^ *([0-9]+) .*", "\\1", grep("maximum resident set size", out, value = TRUE))) / 2^20
  cat(sprintf("%-45s %8.1f s %8.0f MB\n", cs$name, el, rss))
  data.frame(case = cs$name, seconds = el, peak_mb = rss)
})
res <- do.call(rbind, rows)
dir.create("benchmark/results", showWarnings = FALSE)
utils::write.csv(res, "benchmark/results/limits.csv", row.names = FALSE)
cat("machine:", Sys.info()[["sysname"]], Sys.info()[["machine"]], "\n")
