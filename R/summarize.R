#' Create scenario level summary of simulation results.
#'
#' @import dplyr
#' @importFrom magrittr "%<>%"
#' @param simulation_results Simulation results dataframe
#' @export
#' @return Simulation results summarized by scenario
summarize_scenarios <- function(simulation_results) {
  scenario_summary <- simulation_results %>% group_by_("domain_id", "scenario_id") %>%
  summarise_(
    loss_events_mean = ~ mean(loss_events, na.rm = TRUE),
    loss_events_min = ~ min(loss_events, na.rm = TRUE),
    loss_events_max = ~ max(loss_events, na.rm = TRUE),
    loss_events_median = ~ median(loss_events, na.rm = TRUE),
    ale_median = ~ median(ale, na.rm = TRUE),
    ale_max = ~ max(ale, na.rm = TRUE),
    ale_var = ~ quantile(ale, 0.95),
    sle_mean = ~ mean(sle_median, na.rm = TRUE),
    sle_median = ~ median(sle_median, na.rm = TRUE),
    sle_max = ~ max(sle_max, na.rm = TRUE),
    sle_min = ~ min(sle_min, na.rm = TRUE),
    mean_tc_exceedance = ~ sum(mean_tc_exceedance * loss_events) / sum(loss_events),
    mean_diff_exceedance = ~sum(mean_diff_exceedance *
                                  (threat_events - loss_events)) /
      sum(threat_events - loss_events),
    mean_vuln = ~ mean(vuln, na.rm = TRUE)) %>%
  mutate_(sle_median = ~ ifelse(is.nan(sle_median), NA, sle_median)) %>%
  ungroup()

  # calculate z-score for ALE VaR and assign outliers as >= 2 SD
  scenario_summary %<>% mutate_(ale_var_zscore = ~ scale(ale_var),
                                outlier = ~ ale_var_zscore >= 2)

  scenario_summary

}

#' Create domain level summary of simulation results.
#'
#' @import dplyr
#' @param simulation_results Simulation results dataframe
#' @param domains Domain mappings
#' @export
#' @return Simulation results summarized by domain
summarize_domains <- function(simulation_results, domains) {
  simulation_results %>% group_by_("domain_id", "simulation") %>%
    summarise_(ale = ~ sum(ale)) %>%
    left_join(domains, by = c("domain_id" = "domain_id")) %>%
    select_("domain_id", "domain", "simulation", "ale", ~ everything())
}

#' Create all summary files and write to disk.
#'
#' This is a wrapper function around \code{summarize_scenarios} and
#' \code{summarize_domains}, calling both functions and writting the dataframes
#' to a location on disk.
#'
#' @importFrom magrittr "%>%"
#' @param simulation_results Simulation results dataframe
#' @param domains Domain mappings dataframe
#' @param results_dir Directory to place simulation files
#' @export
#' @return Simulation results summarized by domain
summarize_all <- function(simulation_results, domains, results_dir =
                            file.path(getwd(), "results")) {
  if (!dir.exists(results_dir)) dir.create(results_dir)

  scenario_summary <- summarize_scenarios(simulation_results)
  save(scenario_summary, file = file.path(results_dir, "scenario_summary.rda"))

  domain_summary <- summarize_domains(simulation_results, domains)
  save(domain_summary, file = file.path(results_dir, "domain_summary.rda"))

  file.info(c(file.path(results_dir, "scenario_summary.rda"),
              file.path(results_dir, "domain_summary.rda"))) %>%
    tibble::rownames_to_column("filename") %>% tibble::as_data_frame()
}
