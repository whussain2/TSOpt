# =============================================================================
# TSOpt against TrainSel's own published training sets (Fernandez-Gonzalez et al. 2023)
#
# TrainSel is not run here. Fernandez-Gonzalez, Akdemir and Isidro y Sanchez (2023, Theor Appl Genet
# 136:30) optimised training sets with TrainSel on the same public panels and published every
# selected set, test set and candidate set:
#   github.com/TheRocinante-lab/Publications/tree/main/2023/Fernández-Gonzalez etal.TAG/Plots/Data
#   (<dataset>_training_optimization_results_merged.RData, 40 repetitions x 5 training-set sizes)
#
# For each repetition and size, on the identical candidate/test split and at the identical size:
#   * "TrainSel CDmean (targeted)"   the authors' published TrainSel set (CDtarg)
#   * "TrainSel CDmean (untargeted)" the authors' published TrainSel set (CD)
#   * "Random (published)"           the authors' published random set (RAND)
#   * "TSOpt default"                tso_design() targeted to the test set, nothing else set
#   * "TSOpt untargeted"             tso_design() without a target
# Every set is scored the same way: GBLUP (REML heritability) predictive ability and NDCG@10% on the test
# set, averaged over the panel's traits, and the exact CDmean (intercept projected) on the test set.
# Paired differences are taken within repetition and size; standard errors over the 40 repetitions.
#
# Alignment check: the published sets are row positions of the authors' relationship matrix. Before
# scoring, the script recomputes the authors' own criterion (CDmean without projection, their code) for the
# published TrainSel sets and requires it to reproduce TrainSel's reported BestVal; otherwise it stops.
#
# Get the published sets (six files, about 14 MB) into benchmark/external/fernandez2023/:
#   B="https://raw.githubusercontent.com/TheRocinante-lab/Publications/main/2023/Fern%C3%A1ndez-Gonzalez%20etal.TAG/Plots/Data"
#   for p in Maize Rice Rice_high_PS Sorghum Switchgrass Spruce; do
#     curl -L -o benchmark/external/fernandez2023/${p}_training_optimization_results_merged.RData "$B/${p}_training_optimization_results_merged.RData"; done
#
# Usage (needs TSOpt with a licence key, and the panels of Fernandez-Gonzalez et al. 2023):
#   TSO_BENCH_DATA=/path/to/Datasets Rscript benchmark/trainsel_published.R [Sorghum Maize ...]
# Writes benchmark/results/trainsel_published_<dataset>.csv and trainsel_published_summary.csv
# =============================================================================
suppressMessages(library(TSOpt))
data_dir <- Sys.getenv("TSO_BENCH_DATA", "reference_packages/Fernandez-Gonzalez_2022_Comparison/Datasets")
ext_dir <- Sys.getenv("TSO_TRAINSEL_SETS", "benchmark/external/fernandez2023")
out_dir <- Sys.getenv("TSO_BENCH_OUT", "benchmark/results")
reps_max <- as.integer(Sys.getenv("TSO_BENCH_REPS", "40"))
# our panel name = their file prefix
panels <- c(Maize = "Maize", Rice = "Rice", RicePS = "Rice_high_PS", Sorghum = "Sorghum",
            Switchgrass = "Switchgrass", Spruce = "Spruce")
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) panels <- panels[args]

ndcg_at <- function(pred, obs, top = 0.1) {
  k <- max(1, ceiling(top * length(obs))); g <- obs - min(obs)
  dcg <- function(o) sum(g[o] / log2(seq_along(o) + 1))
  dcg(order(pred, decreasing = TRUE)[seq_len(k)]) / dcg(order(obs, decreasing = TRUE)[seq_len(k)])
}
# the authors' criterion, copied from their Functions/Optimization_methods.R (CDmean_without_projection)
cd_authors <- function(soln, K, lambda, targ) {
  Vinv <- solve(K[soln, soln] + lambda * diag(length(soln)))
  ts <- c(targ, soln)
  out <- (K[ts, soln] %*% (Vinv - (Vinv %*% Vinv) / sum(Vinv)) %*% K[soln, ts]) / K[ts, ts]
  mean(diag(as.matrix(out[seq_along(targ), seq_along(targ)])))
}

all_rows <- list()
for (ds in names(panels)) {
  e <- new.env(); load(file.path(data_dir, paste0(ds, "_sorted.RData")), envir = e)
  K0 <- e$K                                           # the authors' matrix, in their row order
  ids <- as.character(e$pheno$GID); N <- nrow(K0)
  K <- K0; dimnames(K) <- list(ids, ids); K <- K / mean(diag(K))
  traits <- setdiff(names(e$pheno), "GID"); Y <- as.matrix(e$pheno[, traits, drop = FALSE])
  o <- new.env(); load(file.path(ext_dir, paste0(panels[[ds]], "_training_optimization_results_merged.RData")), envir = o)
  O <- o$Optimization_results; p <- panels[[ds]]
  CS <- O[[paste0(p, "Entire_CS")]]; TS <- O[[paste0(p, "TestSets")]]
  CDt <- O[[paste0(p, "CDtarg")]]; CDu <- O[[paste0(p, "CD")]]; RA <- O[[paste0(p, "RAND")]]
  nrep <- min(reps_max, length(TS))
  if (max(unlist(CS), unlist(TS)) != N || length(union(CS[[1]][[1]], TS[[1]])) != N)
    stop(ds, ": the published sets do not index a panel of ", N, " lines")

  # ---- alignment check: reproduce TrainSel's reported criterion values with the authors' formula ----
  # (lambda = 1, as in the authors' runs). The recomputed values must track the published ones almost
  # exactly; a wrong line order is shown by the same check on a shuffled matrix.
  g <- expand.grid(r = seq_len(min(5, nrep)), s = 1:2)
  pub <- mapply(function(r, s) CDt[[r]][[s]]$BestVal, g$r, g$s)
  rec <- mapply(function(r, s) cd_authors(CDt[[r]][[s]]$BestSol_int, K0, 1, TS[[r]]), g$r, g$s)
  set.seed(1); pm <- sample(N)
  shf <- mapply(function(r, s) cd_authors(CDt[[r]][[s]]$BestSol_int, K0[pm, pm], 1, TS[[r]]), g$r, g$s)
  rel <- max(abs(rec / pub - 1)); rel_shf <- max(abs(shf / pub - 1))
  message(sprintf("%s: N = %d; published TrainSel CDmean reproduced within %.2f%% (r = %.6f); shuffled line order: %.1f%%",
                  ds, N, 100 * rel, cor(rec, pub), 100 * rel_shf))
  if (rel > 0.01 || cor(rec, pub) < 0.999) stop(ds, ": published TrainSel values not reproduced; the line order of the panel may differ")

  tp <- tso_data(kinship = K, verbose = FALSE)
  rows <- list()
  for (r in seq_len(nrep)) {
    cand <- CS[[r]][[1]]; tst <- TS[[r]]
    for (s in seq_along(CDt[[r]])) {
      n <- length(CDt[[r]][[s]]$BestSol_int)
      score <- function(S, method, secs = NA) {
        S <- unique(S)
        ctr <- TSOpt:::.contrasts(K, tst, "centered")
        cd <- TSOpt:::.cd_direct(K, S, rep(1, N), ctr, project = TRUE)
        pa <- nd <- numeric(0)
        for (t in seq_along(traits)) {
          y <- Y[, t]; ok <- S[!is.na(y[S])]
          fit <- TSOpt:::.gblup(K, ok, y[ok])
          pr <- fit$pred[tst]; ob <- y[tst]; k <- !is.na(ob)
          pa <- c(pa, cor(pr[k], ob[k])); nd <- c(nd, ndcg_at(pr[k], ob[k]))
        }
        data.frame(dataset = ds, rep = r, size = s, n = length(S), method = method, seconds = secs,
                   cdmean = cd, pa = mean(pa), ndcg10 = mean(nd), stringsAsFactors = FALSE)
      }
      t0 <- proc.time()[["elapsed"]]
      ts_t <- match(tso_design(tp, n = n, target = ids[tst], candidates = ids[cand], n_random = 0, verbose = FALSE)$selected$id, ids)
      t1 <- proc.time()[["elapsed"]]
      ts_u <- match(tso_design(tp, n = n, candidates = ids[cand], n_random = 0, verbose = FALSE)$selected$id, ids)
      t2 <- proc.time()[["elapsed"]]
      rows[[length(rows) + 1]] <- rbind(
        score(CDt[[r]][[s]]$BestSol_int, "TrainSel CDmean (targeted, published)"),
        score(CDu[[r]][[s]]$BestSol_int, "TrainSel CDmean (untargeted, published)"),
        score(RA[[r]][[s]], "Random (published)"),
        score(ts_t, "TSOpt default (targeted)", t1 - t0),
        score(ts_u, "TSOpt (untargeted)", t2 - t1))
    }
    message(sprintf("%-12s rep %2d done", ds, r))
    write.csv(do.call(rbind, rows), file.path(out_dir, paste0("trainsel_published_", ds, ".csv")), row.names = FALSE)
  }
  all_rows[[ds]] <- do.call(rbind, rows)
}

# ---- summary: paired differences within dataset x repetition x size; SE over repetitions -------------
d <- do.call(rbind, lapply(list.files(out_dir, "^trainsel_published_(?!summary).*csv$", full.names = TRUE, perl = TRUE), read.csv))
pair <- function(m1, m2, col) {
  a <- d[d$method == m1, c("dataset", "rep", "size", col)]; b <- d[d$method == m2, c("dataset", "rep", "size", col)]
  x <- merge(a, b, by = c("dataset", "rep", "size")); x$diff <- x[[paste0(col, ".x")]] - x[[paste0(col, ".y")]]
  u <- aggregate(diff ~ dataset + rep, x, mean)                  # unit: one repetition of one panel
  data.frame(comparison = paste(m1, "minus", m2), metric = col, mean = mean(x$diff),
             se = sd(u$diff) / sqrt(nrow(u)), wins = mean(x$diff > 0), units = nrow(u),
             p_sign = binom.test(sum(u$diff > 0), sum(u$diff != 0))$p.value)
}
cmp <- list(c("TSOpt default (targeted)", "TrainSel CDmean (targeted, published)"),
            c("TSOpt (untargeted)", "TrainSel CDmean (untargeted, published)"),
            c("TSOpt default (targeted)", "Random (published)"),
            c("TrainSel CDmean (targeted, published)", "Random (published)"))
summ <- do.call(rbind, lapply(cmp, function(m) rbind(pair(m[1], m[2], "pa"), pair(m[1], m[2], "ndcg10"), pair(m[1], m[2], "cdmean"))))
by_ds <- aggregate(cbind(pa, ndcg10) ~ dataset + method, d, mean)
write.csv(summ, file.path(out_dir, "trainsel_published_summary.csv"), row.names = FALSE)
write.csv(by_ds, file.path(out_dir, "trainsel_published_by_dataset.csv"), row.names = FALSE)
print(summ, digits = 3)
