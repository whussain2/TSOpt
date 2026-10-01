# TSOpt versus TrainSel, following benchmark/TRAINSEL_PROTOCOL.md.
#
# TrainSel's licence forbids use by for-profit organisations without the authors'
# written permission. This script runs only when TrainSel is installed and the
# environment variable TSO_TRAINSEL_LICENSED=yes confirms that you are licensed
# (a university, a non-profit, or with written permission).
#
#   TSO_TRAINSEL_LICENSED=yes TSO_BENCH_DATA=/path/to/Datasets Rscript benchmark/trainsel_comparison.R
if (!identical(Sys.getenv("TSO_TRAINSEL_LICENSED"), "yes"))
  stop("Set TSO_TRAINSEL_LICENSED=yes only if you are licensed to use TrainSel (see its LICENSE and the protocol).")
if (!requireNamespace("TrainSel", quietly = TRUE)) stop("TrainSel is not installed.")
suppressMessages({ library(TSOpt); library(TrainSel) })
data_dir <- Sys.getenv("TSO_BENCH_DATA", "Datasets")
datasets <- c("RicePS", "Rice", "Maize", "Sorghum", "Switchgrass", "Spruce")
rows <- list()
pa <- function(K, S, Tg, Y) mean(apply(Y, 2, function(y) {
  ok <- S[!is.na(y[S])]; p <- TSOpt:::.gblup(K, ok, y[ok])$pred; stats::cor(p[Tg], y[Tg], use = "complete.obs") }))
for (ds in datasets) {
  e <- new.env(); load(file.path(data_dir, paste0(ds, "_sorted.RData")), envir = e)
  K <- e$K; ids <- as.character(e$pheno$GID); dimnames(K) <- list(ids, ids); K <- K / mean(diag(K)); N <- nrow(K)
  Y <- as.matrix(e$pheno[, setdiff(names(e$pheno), "GID"), drop = FALSE])
  tp <- tso_data(kinship = K, verbose = FALSE)
  splits <- c(list(NULL), lapply(if (ds == "Spruce") 101:102 else 101:105, function(s) { set.seed(s); sort(sample(N, round(0.25 * N))) }))
  size <- if (N < 400) "small" else if (N < 1000) "medium" else "large"
  for (k in seq_along(splits)) {
    tg <- splits[[k]]; cand <- if (is.null(tg)) seq_len(N) else setdiff(seq_len(N), tg)
    n <- round(0.15 * length(cand)); Tg <- if (is.null(tg)) seq_len(N) else tg
    t1 <- system.time(s1 <- match(tso_design(tp, n = n, target = if (!is.null(tg)) ids[tg], verbose = FALSE)$selected$id, ids))[3]
    ctl <- SetControlDefault(size = size, verbose = FALSE)
    t2 <- system.time(r2 <- TrainSel(Data = MakeTrainSelData(K = K), Candidates = list(cand), setsizes = n,
                                     settypes = "UOS", Target = tg, control = ctl, Verbose = FALSE))[3]
    ctl3 <- ctl; ctl3$niterations <- 10 * ctl$niterations
    t3 <- system.time(r3 <- TrainSel(Data = MakeTrainSelData(K = K), Candidates = list(cand), setsizes = n,
                                     settypes = "UOS", Target = tg, control = ctl3, Verbose = FALSE))[3]
    rnd <- mean(vapply(1:20, function(i) pa(K, sample(cand, n), Tg, Y), 1))
    rows[[length(rows) + 1]] <- data.frame(panel = ds, scenario = if (is.null(tg)) "untargeted" else paste0("targeted_", k - 1),
      pa_tsopt = pa(K, s1, Tg, Y), pa_trainsel = pa(K, unlist(r2$BestSol_int), Tg, Y),
      pa_trainsel_long = pa(K, unlist(r3$BestSol_int), Tg, Y), pa_random = rnd,
      sec_tsopt = t1, sec_trainsel = t2, sec_trainsel_long = t3)
    cat(ds, k, "\n")
  }
}
out <- do.call(rbind, rows)
utils::write.csv(out, "benchmark/results/trainsel_comparison.csv", row.names = FALSE)
d <- out$pa_tsopt - out$pa_trainsel
ci <- mean(d) + c(-1, 1) * stats::qt(0.975, length(d) - 1) * stats::sd(d) / sqrt(length(d))
cat(sprintf("TSOpt - TrainSel (default): %+.4f, 95%% CI %+.4f to %+.4f, TSOpt better in %d of %d; sign test p = %.3f\n",
            mean(d), ci[1], ci[2], sum(d > 0), length(d), stats::binom.test(sum(d > 0), sum(d != 0))$p.value))
cat("Non-inferiority (lower limit > -0.01):", ci[1] > -0.01, " Superiority (lower limit > 0):", ci[1] > 0, "\n")
cat(sessionInfo()$otherPkgs$TrainSel$Version, "(TrainSel) ", as.character(packageVersion("TSOpt")), "(TSOpt)\n")
