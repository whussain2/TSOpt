# =============================================================================
# TSOpt head-to-head benchmark
#
# Six public panels (Fernandez-Gonzalez et al. 2023 datasets: maize, two rice
# panels, sorghum, spruce, switchgrass), two scenarios (untargeted; targeted
# to a random 25% of lines that are never phenotyped), a tight budget (15% of
# the candidates), three replicates of the target split.
#
# Methods: TSOpt (default and variants), STPGA (genetic algorithm, CDMEAN),
# TSDFGS (exchange, CD and r-score), a genetic algorithm + simulated annealing
# in the style of TrainSel (TrainSel itself is not run: its licence forbids
# use by private organisations), and the usual baselines.
#
# Every set is scored the same way: exact CDmean on the targets, and the
# realised predictive ability / NDCG@10% of GBLUP (REML heritability) on the
# targets, averaged over all traits in the dataset. Run time is wall clock.
#
# Usage: Rscript run_benchmark.R <dataset names ...>   (writes results_<name>.csv)
# =============================================================================
lib_extra <- Sys.getenv("TSO_BENCH_LIB", "")          # where STPGA and TSDFGS are installed, if not in the default library
if (nzchar(lib_extra)) .libPaths(c(lib_extra, .libPaths()))
suppressMessages({ library(TSOpt); library(STPGA); library(TSDFGS); library(cluster) })
# TSDFGS 2.0 (CRAN) declares no useDynLib() in its NAMESPACE, so its compiled routines are
# never loaded; load them explicitly (its code is not changed)
if (!"TSDFGS" %in% vapply(getLoadedDLLs(), function(d) d[["name"]], ""))
  library.dynam("TSDFGS", "TSDFGS", dirname(system.file(package = "TSDFGS")))
quiet <- function(expr) { v <- NULL; utils::capture.output(v <- expr); v }   # TSDFGS prints every iteration
cat("TSOpt", as.character(packageVersion("TSOpt")), "| STPGA", as.character(packageVersion("STPGA")),
    "| TSDFGS", as.character(packageVersion("TSDFGS")), "\n")
data_dir <- Sys.getenv("TSO_BENCH_DATA", "Datasets")
out_dir <- Sys.getenv("TSO_BENCH_OUT", ".")
args <- commandArgs(trailingOnly = TRUE)
datasets <- if (length(args)) args else c("RicePS", "Rice", "Maize", "Sorghum", "Switchgrass", "Spruce")
reps <- as.integer(Sys.getenv("TSO_BENCH_REPS", "5"))
frac_n <- 0.15

ndcg_at <- function(pred, obs, top = 0.1) {
  k <- max(1, ceiling(top * length(obs))); g <- obs - min(obs)
  dcg <- function(o) sum(g[o] / log2(seq_along(o) + 1))
  dcg(order(pred, decreasing = TRUE)[seq_len(k)]) / dcg(order(obs, decreasing = TRUE)[seq_len(k)])
}

for (ds in datasets) {
  e <- new.env(); load(file.path(data_dir, paste0(ds, "_sorted.RData")), envir = e)
  K <- e$K; ids <- as.character(e$pheno$GID); dimnames(K) <- list(ids, ids)
  K <- K / mean(diag(K))
  N <- nrow(K)
  traits <- setdiff(names(e$pheno), "GID")
  Y <- as.matrix(e$pheno[, traits, drop = FALSE])
  clusters <- e$clusters
  tp <- tso_data(kinship = K, groups = setNames(paste0("C", clusters), ids), verbose = FALSE)
  scen_sel <- Sys.getenv("TSO_BENCH_SCEN", "")
  res_file <- file.path(out_dir, paste0("results_", ds, if (nzchar(scen_sel)) paste0("_s", gsub(",", "-", scen_sel)), ".csv"))
  rows <- list()
  scen <- c(list(list(name = "untargeted", tgt = NULL, rep = 1)),
            lapply(seq_len(reps), function(r) { set.seed(100 + r); list(name = "targeted", tgt = sort(sample(N, round(0.25 * N))), rep = r) }))
  if (nzchar(scen_sel)) scen <- scen[as.integer(strsplit(scen_sel, ",")[[1]])]
  for (sc in scen) {
    tgt <- sc$tgt
    cand <- if (is.null(tgt)) seq_len(N) else setdiff(seq_len(N), tgt)
    n <- round(frac_n * length(cand))
    npc <- min(30, n - 5)
    PCs <- e$PCs[, seq_len(npc), drop = FALSE]; rownames(PCs) <- ids
    tgt_ids <- if (is.null(tgt)) NULL else ids[tgt]
    score <- function(S, method, secs) {
      S <- unique(S)
      ev <- if (is.null(tgt)) setdiff(seq_len(N), S) else tgt
      ctr <- TSOpt:::.contrasts(K, ev, "centered")
      cd <- TSOpt:::.cd_direct(K, S, rep(1, N), ctr, project = TRUE)
      pa <- nd <- numeric(0)
      for (t in seq_along(traits)) {
        y <- Y[, t]; ok <- S[!is.na(y[S])]
        fit <- TSOpt:::.gblup(K, ok, y[ok])
        pr <- fit$pred[ev]; obs <- y[ev]; keep <- !is.na(obs)
        pa <- c(pa, cor(pr[keep], obs[keep])); nd <- c(nd, ndcg_at(pr[keep], obs[keep]))
      }
      data.frame(dataset = ds, N = N, scenario = sc$name, rep = sc$rep, n = length(S), method = method,
                 seconds = secs, cdmean = cd, pa = mean(pa), ndcg10 = mean(nd), stringsAsFactors = FALSE)
    }
    run <- function(method, expr) {
      t0 <- proc.time()[["elapsed"]]
      S <- tryCatch(expr, error = function(err) { message(method, ": ", conditionMessage(err)); NULL })
      secs <- proc.time()[["elapsed"]] - t0
      if (!is.null(S)) {
        r <- score(S, method, secs); rows[[length(rows) + 1]] <<- r
        message(sprintf("%-12s %-10s rep %d  %-34s %7.1f s  CD %.4f  PA %.3f", ds, sc$name, sc$rep, method, secs, r$cdmean, r$pa))
        write.csv(do.call(rbind, rows), res_file, row.names = FALSE)
      }
    }
    des <- function(...) match(tso_design(tp, n = n, target = tgt_ids, n_random = 0, verbose = FALSE, ...)$selected$id, ids)
    # ---- TSOpt ------------------------------------------------------------------------
    # the package default call: robust CDmean (h2 0.2/0.5/0.8), exact intercept, automatic stratification
    run(paste0("TSOpt default (v", packageVersion("TSOpt"), ")"), des())
    run("TSOpt robust CDmean, no stratification", des(stratify = "none"))
    run("TSOpt CDmean h2 = 0.5 (one assumed heritability)", des(stratify = "none", h2 = 0.5))
    run("TSOpt greedy only", des(stratify = "none", search = "greedy"))
    run("TSOpt greedy + exchange", des(stratify = "none", search = "greedy+exchange"))
    run("TSOpt CDmean without fixed intercept", des(stratify = "none", fixed = "none"))
    run("TSOpt worst-case CD (cdmin)", des(stratify = "none", criterion = "cdmin"))
    run("TSOpt coverage", des(stratify = "none", criterion = "coverage"))
    run("TSOpt D-optimality", des(stratify = "none", criterion = "dopt"))
    # ---- a genetic algorithm + SA from random starts (TrainSel-style search) ----------
    run("GA+SA from random start (TrainSel-style)", {
      ev <- if (is.null(tgt)) seq_len(N) else tgt
      ctr <- TSOpt:::.contrasts(K, ev, "centered")
      f <- function(S) TSOpt:::.cd_direct(K, S, rep(1, N), ctr, project = TRUE)
      set.seed(sc$rep); TSOpt:::.ga_search(f, cand, n, init = NULL, pop = 60, gens = 150, patience = 40)$chosen
    })
    # ---- STPGA ------------------------------------------------------------------------------
    run("STPGA GA (CDMEAN)", {
      set.seed(sc$rep)
      sol <- if (is.null(tgt)) GenAlgForSubsetSelectionNoTest(P = PCs, ntoselect = n,
               errorstat = "CDMEAN", npop = 100, nelite = 5, mutprob = .8, niterations = 300, lambda = 1 / npc,
               plotiters = FALSE, mc.cores = 1) else
             GenAlgForSubsetSelection(P = PCs, Candidates = ids[cand], Test = ids[tgt], ntoselect = n,
               errorstat = "CDMEAN", npop = 100, nelite = 5, mutprob = .8, niterations = 300, lambda = 1 / npc,
               plotiters = FALSE, mc.cores = 1)
      match(sol[[1]], ids)
    })
    # ---- TSDFGS ------------------------------------------------------------------------------
    it <- min(20000, round(sqrt(length(cand) * n) * 65))
    run("TSDFGS CD", { set.seed(sc$rep); quiet(optTrain(PCs, cand = cand, n.train = n, test = tgt, method = "CD",
                                                  min.iter = it))$OPTtrain })
    run("TSDFGS r-score", { set.seed(sc$rep); quiet(optTrain(PCs, cand = cand, n.train = n, test = tgt, method = "rScore",
                                                       min.iter = it))$OPTtrain })
    # ---- baselines ----------------------------------------------------------------------------
    for (b in 1:5) run(paste0("Random #", b), { set.seed(1000 * sc$rep + b); sample(cand, n) })
    run("Stratified random (dataset clusters)", {
      set.seed(sc$rep); cl <- clusters[cand]; share <- table(cl) / length(cl)
      q <- TSOpt:::.allocate(n, as.numeric(share), as.numeric(table(cl)))
      unlist(mapply(function(l, k) { p <- cand[cl == l]; p[sample.int(length(p), k)] }, names(share), q))
    })
    run("PAM medoids", des(stratify = "none", criterion = "pam"))
    run("Most related to target", des(stratify = "none", criterion = "kinship"))
  }
}
