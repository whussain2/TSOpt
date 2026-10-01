# =============================================================================
# Summarise the head-to-head benchmark: tables and publication figures.
# Usage: Rscript analyse_benchmark.R <results folder> <output folder>
# =============================================================================
suppressMessages({ library(data.table); library(ggplot2); library(TSOpt) })
a <- commandArgs(trailingOnly = TRUE)
in_dir <- if (length(a) >= 1) a[1] else "."
out_dir <- if (length(a) >= 2) a[2] else "."
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
d <- rbindlist(lapply(list.files(in_dir, "^results_.*csv$", full.names = TRUE), fread))
d[grepl("^Random #", method), method := "Random"]
ref <- unique(d$method[grepl("^TSOpt default \\(v", d$method)])     # the package default of the version run
stopifnot(length(ref) == 1)
# average the five random sets within a scenario/rep first
d <- d[, .(seconds = mean(seconds), cdmean = mean(cdmean), pa = mean(pa), ndcg10 = mean(ndcg10)),
       by = .(dataset, N, scenario, rep, method)]
# gain over random in the same dataset/scenario/rep
rnd <- d[method == "Random", .(dataset, scenario, rep, cd_r = cdmean, pa_r = pa, nd_r = ndcg10)]
d <- merge(d, rnd, by = c("dataset", "scenario", "rep"))
d[, `:=`(d_cd = cdmean - cd_r, d_pa = pa - pa_r, d_nd = ndcg10 - nd_r)]
# rank within each dataset/scenario/rep (1 = best)
d[, `:=`(rank_cd = frank(-cdmean), rank_pa = frank(-pa)), by = .(dataset, scenario, rep)]

family <- function(m) fifelse(grepl("^TSOpt", m), "TSOpt",
                       fifelse(grepl("STPGA|TSDFGS|TrainSel", m), "Other packages", "Baselines"))
d[, family := family(method)]

summ <- d[method != "Random", .(
  cases = .N,
  cdmean_gain = mean(d_cd), pa_gain = mean(d_pa), pa_gain_se = sd(d_pa) / sqrt(.N),
  ndcg_gain = mean(d_nd), win_rate_pa = mean(d_pa > 0),
  mean_rank_cd = mean(rank_cd), mean_rank_pa = mean(rank_pa),
  median_seconds = median(seconds)), by = .(method, family)][order(-pa_gain)]
fwrite(summ, file.path(out_dir, "benchmark_summary.csv"))
by_ds <- dcast(d[method != "Random"], method ~ dataset, value.var = "d_pa", fun.aggregate = mean)
fwrite(by_ds, file.path(out_dir, "benchmark_pa_gain_by_dataset.csv"))
print(summ, digits = 3)

cols <- c(TSOpt = "#D65F0E", `Other packages` = "#8C6BB1", Baselines = "grey55")
lev <- summ[order(pa_gain), method]
p1 <- ggplot(summ, aes(pa_gain, factor(method, lev), colour = family)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "grey50") +
  geom_errorbarh(aes(xmin = pa_gain - 2 * pa_gain_se, xmax = pa_gain + 2 * pa_gain_se), height = 0) +
  geom_point(size = 2.4) + scale_colour_manual(values = cols, name = NULL) +
  labs(x = "Predictive ability gain over random training sets (mean +/- 2 SE)", y = NULL,
       title = sprintf("Realised accuracy on %d public panels (%d scenarios, TSOpt %s)", uniqueN(d$dataset),
                       uniqueN(d[, .(dataset, scenario, rep)]), sub("^TSOpt default \\((.*)\\)$", "\\1", ref)),
       subtitle = "GBLUP, all traits, untargeted and targeted scenarios, n = 15% of candidates") +
  tso_theme()
for (ext in c("pdf", "png")) ggsave(paste0(file.path(out_dir, "fig_pa_gain"), ".", ext), p1, width = 180, height = 120, units = "mm", dpi = 300)

summ[, secs_plot := pmax(median_seconds, 0.005)]
key <- c(ref, "TSOpt CDmean h2 = 0.5 (one assumed heritability)", "GA+SA from random start (TrainSel-style)",
         "STPGA GA (CDMEAN)", "TSDFGS r-score", "TSDFGS CD", "TSOpt coverage", "Stratified random (dataset clusters)", "Most related to target")
p2 <- ggplot(summ, aes(secs_plot, pa_gain, colour = family)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey50") +
  geom_point(size = 2.4) + scale_x_log10(labels = function(x) format(x, scientific = FALSE, drop0trailing = TRUE)) + scale_colour_manual(values = cols, name = NULL) +
  labs(x = "Median run time (seconds, log scale)", y = "PA gain over random",
       title = "Accuracy against run time") + tso_theme()
if (requireNamespace("ggrepel", quietly = TRUE))
  p2 <- p2 + ggrepel::geom_text_repel(data = summ[method %in% key], aes(label = method), size = 2.4, show.legend = FALSE, max.overlaps = 30)
for (ext in c("pdf", "png")) ggsave(paste0(file.path(out_dir, "fig_time_vs_gain"), ".", ext), p2, width = 180, height = 120, units = "mm", dpi = 300)

p3 <- ggplot(d[method != "Random"], aes(d_cd, factor(method, summ[order(cdmean_gain), method]), colour = family)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "grey50") +
  geom_boxplot(outlier.size = 0.6) + scale_colour_manual(values = cols, name = NULL) +
  labs(x = "Exact CDmean gain over random", y = NULL, title = "The design criterion itself") + tso_theme()
for (ext in c("pdf", "png")) ggsave(paste0(file.path(out_dir, "fig_cdmean_gain"), ".", ext), p3, width = 180, height = 120, units = "mm", dpi = 300)

# ---- paired comparison: the TSOpt default against every other method -------------------
w <- dcast(d, dataset + scenario + rep ~ method, value.var = "pa")
pair <- rbindlist(lapply(setdiff(unique(d$method), ref), function(m) {
  x <- w[[ref]] - w[[m]]; x <- x[!is.na(x)]
  data.table(versus = m, cases = length(x), pa_advantage = mean(x), se = sd(x) / sqrt(length(x)),
             default_wins = mean(x > 0), p_sign = stats::binom.test(sum(x > 0), sum(x != 0))$p.value)
}))[order(-pa_advantage)]
fwrite(pair, file.path(out_dir, "benchmark_paired_vs_default.csv"))
cat("\nPaired: TSOpt default minus each method (realised PA)\n"); print(pair, digits = 3)
