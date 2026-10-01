# Forward validation in simulated programme histories.
#
# 20 programmes per heritability (0.3, 0.6), 6 cycles of 200 doubled haploids,
# parents selected on phenotype (so the history is not shaped by any
# training-set method). tso_backtest() replays each history:
#   within_cycle  choose 40 of this cycle's 200 candidates to phenotype, with
#                 every earlier cycle as history; predict the other 160
#   from_history  choose 100 historical lines as the training set; predict
#                 all 200 lines of the new cycle
# Methods: random (mean of 5), the default (robust CDmean), coverage, and
# the most-related heuristic (kinship).
#
# Run from the repository folder:  Rscript benchmark/forward_benchmark.R [programmes]
suppressMessages(library(TSOpt))
args <- commandArgs(TRUE); progs <- if (length(args)) as.integer(args[1]) else 20
cores <- as.integer(Sys.getenv("TSO_BENCH_CORES", max(1, parallel::detectCores() - 2)))
jobs <- expand.grid(programme = seq_len(progs), h2 = c(0.3, 0.6))
one <- function(i) {
  h2 <- jobs$h2[i]; s <- jobs$programme[i]
  hs <- tso_simulate_cycles(cycles = 6, n_candidates = 200, n_crosses = 20, n_parents = 20, markers = 1000,
                            n_qtl = 200, h2 = h2, seed = 100 * s + round(10 * h2))
  do.call(rbind, lapply(c("within_cycle", "from_history"), function(sch) {
    bt <- tso_backtest(hs$geno, hs$pheno, n = if (sch == "within_cycle") 40 else 100, scheme = sch,
                       methods = c("random", "default", "coverage", "kinship"), n_random = 5,
                       seed = s, verbose = FALSE)
    data.frame(h2 = h2, programme = s, scheme = sch, bt$results)
  }))
}
rows <- if (cores > 1 && .Platform$OS.type == "unix") {
  parallel::mclapply(seq_len(nrow(jobs)), one, mc.cores = cores)
} else lapply(seq_len(nrow(jobs)), one)
bad <- vapply(rows, inherits, TRUE, "try-error"); if (any(bad)) stop("A programme failed: ", rows[[which(bad)[1]]])
out <- do.call(rbind, rows)
dir.create("benchmark/results", showWarnings = FALSE)
utils::write.csv(out, "benchmark/results/forward_benchmark.csv", row.names = FALSE)
for (sch in unique(out$scheme)) {
  o <- out[out$scheme == sch, ]
  cat("\n==", sch, "==\n")
  print(stats::aggregate(cbind(pa, rank_cor, top10) ~ method + h2, o, mean), digits = 3)
  w <- reshape(o[, c("h2", "programme", "cycle", "method", "pa")], idvar = c("h2", "programme", "cycle"),
               timevar = "method", direction = "wide")
  for (m in c("default", "coverage", "kinship")) {
    d <- w[[paste0("pa.", m)]] - w$pa.random
    cat(sprintf("%-9s vs random: %+.4f (SE %.4f, t %.1f), better in %.0f%% of %d cycle tests\n", m, mean(d),
                sd(d) / sqrt(length(d)), mean(d) / (sd(d) / sqrt(length(d))), 100 * mean(d > 0), length(d)))
  }
}
