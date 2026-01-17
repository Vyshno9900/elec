# Data Processing Module
# Handles all data transformation, cleaning, and preparation

library(tidyverse)
library(lubridate)

#' Clean and validate voting data
#' @param raw_data Raw voting data frame
#' @return Cleaned and validated data frame
clean_voting_data <- function(raw_data) {
  cleaned <- raw_data %>%
    # Remove duplicates
    distinct() %>%
    # Handle missing values
    filter(!is.na(votes), !is.na(party), !is.na(constituency_name)) %>%
    # Ensure positive vote counts
    filter(votes >= 0) %>%
    # Standardize party names
    mutate(party = str_trim(party),
           constituency_name = str_trim(constituency_name)) %>%
    # Add calculated fields
    group_by(constituency_name) %>%
    mutate(
      total_constituency_votes = sum(votes),
      vote_share_pct = (votes / total_constituency_votes) * 100
    ) %>%
    ungroup()
  
  return(cleaned)
}

#' Calculate descriptive statistics for vote data
#' @param vote_data Vote data frame
#' @param group_by_col Column to group by (party, region, etc.)
#' @return Data frame with descriptive statistics
calculate_descriptive_stats <- function(vote_data, group_by_col = "party") {
  stats <- vote_data %>%
    group_by(across(all_of(group_by_col))) %>%
    summarise(
      total_votes = sum(votes, na.rm = TRUE),
      mean_votes = mean(votes, na.rm = TRUE),
      median_votes = median(votes, na.rm = TRUE),
      sd_votes = sd(votes, na.rm = TRUE),
      min_votes = min(votes, na.rm = TRUE),
      max_votes = max(votes, na.rm = TRUE),
      q1_votes = quantile(votes, 0.25, na.rm = TRUE),
      q3_votes = quantile(votes, 0.75, na.rm = TRUE),
      iqr_votes = IQR(votes, na.rm = TRUE),
      cv_votes = sd(votes, na.rm = TRUE) / mean(votes, na.rm = TRUE),
      n_constituencies = n_distinct(constituency_name),
      .groups = "drop"
    ) %>%
    mutate(
      vote_share_pct = (total_votes / sum(total_votes)) * 100,
      mean_vote_share = (mean_votes / sum(mean_votes)) * 100
    )
  
  return(stats)
}

#' Calculate regional performance metrics
#' @param vote_data Vote data frame
#' @return Data frame with regional metrics
calculate_regional_metrics <- function(vote_data) {
  regional_stats <- vote_data %>%
    group_by(region, party) %>%
    summarise(
      total_votes = sum(votes, na.rm = TRUE),
      avg_vote_share = mean(vote_share_pct, na.rm = TRUE),
      constituencies_won = sum(votes == max(votes)),
      .groups = "drop"
    ) %>%
    group_by(region) %>%
    mutate(
      regional_vote_share = (total_votes / sum(total_votes)) * 100,
      leading_party = party[which.max(total_votes)]
    ) %>%
    ungroup()
  
  return(regional_stats)
}

#' Calculate voter turnout statistics
#' @param vote_data Vote data with total_voters column
#' @return Data frame with turnout statistics
calculate_turnout_stats <- function(vote_data) {
  turnout_stats <- vote_data %>%
    group_by(constituency_name, region) %>%
    summarise(
      total_voters = first(total_voters),
      votes_cast = sum(votes, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      turnout_pct = (votes_cast / total_voters) * 100,
      turnout_category = case_when(
        turnout_pct >= 75 ~ "Very High (75%+)",
        turnout_pct >= 60 ~ "High (60-75%)",
        turnout_pct >= 45 ~ "Medium (45-60%)",
        TRUE ~ "Low (<45%)"
      )
    ) %>%
    arrange(desc(turnout_pct))
  
  return(turnout_stats)
}

#' Identify winning party by constituency
#' @param vote_data Vote data frame
#' @return Data frame with winners
identify_winners <- function(vote_data) {
  winners <- vote_data %>%
    group_by(constituency_name, region) %>%
    arrange(desc(votes)) %>%
    slice(1) %>%
    ungroup() %>%
    select(constituency_name, region, winning_party = party, 
           winning_votes = votes, vote_share = vote_share_pct) %>%
    arrange(constituency_name)
  
  return(winners)
}

#' Calculate vote margins
#' @param vote_data Vote data frame
#' @return Data frame with margin analysis
calculate_vote_margins <- function(vote_data) {
  margins <- vote_data %>%
    group_by(constituency_name) %>%
    arrange(desc(votes)) %>%
    slice(1:2) %>%
    summarise(
      first_party = first(party),
      first_votes = first(votes),
      second_party = nth(party, 2),
      second_votes = nth(votes, 2),
      .groups = "drop"
    ) %>%
    mutate(
      margin_votes = first_votes - second_votes,
      margin_pct = (margin_votes / (first_votes + second_votes)) * 100,
      margin_category = case_when(
        margin_pct >= 20 ~ "Landslide (20%+)",
        margin_pct >= 10 ~ "Comfortable (10-20%)",
        margin_pct >= 5 ~ "Moderate (5-10%)",
        TRUE ~ "Close (<5%)"
      )
    )
  
  return(margins)
}

#' Detect anomalies in voting data
#' @param vote_data Vote data frame
#' @return Data frame with potential anomalies
detect_anomalies <- function(vote_data) {
  # Calculate z-scores
  anomalies <- vote_data %>%
    group_by(party) %>%
    mutate(
      z_score = (votes - mean(votes)) / sd(votes),
      is_outlier = abs(z_score) > 3
    ) %>%
    ungroup() %>%
    filter(is_outlier) %>%
    select(constituency_name, region, party, votes, z_score) %>%
    arrange(desc(abs(z_score)))
  
  return(anomalies)
}

#' Aggregate data by time period
#' @param vote_data Vote data with timestamp
#' @param period Period to aggregate by (hour, day, week)
#' @return Aggregated data frame
aggregate_by_time <- function(vote_data, period = "hour") {
  if (!"timestamp" %in% names(vote_data)) {
    vote_data$timestamp <- Sys.time()
  }
  
  aggregated <- vote_data %>%
    mutate(
      time_period = case_when(
        period == "hour" ~ floor_date(timestamp, "hour"),
        period == "day" ~ floor_date(timestamp, "day"),
        period == "week" ~ floor_date(timestamp, "week"),
        TRUE ~ floor_date(timestamp, "hour")
      )
    ) %>%
    group_by(time_period, party) %>%
    summarise(
      total_votes = sum(votes, na.rm = TRUE),
      avg_votes = mean(votes, na.rm = TRUE),
      .groups = "drop"
    )
  
  return(aggregated)
}

#' Calculate swing analysis (change from previous election)
#' @param current_data Current election data
#' @param previous_data Previous election data
#' @return Swing analysis data frame
calculate_swing <- function(current_data, previous_data) {
  swing <- current_data %>%
    select(constituency_name, party, current_votes = votes) %>%
    left_join(
      previous_data %>% select(constituency_name, party, previous_votes = votes),
      by = c("constituency_name", "party")
    ) %>%
    mutate(
      vote_change = current_votes - coalesce(previous_votes, 0),
      swing_pct = (vote_change / coalesce(previous_votes, 1)) * 100,
      swing_direction = case_when(
        swing_pct > 5 ~ "Strong Gain",
        swing_pct > 0 ~ "Gain",
        swing_pct > -5 ~ "Loss",
        TRUE ~ "Strong Loss"
      )
    )
  
  return(swing)
}

#' Export data in various formats
#' @param data Data frame to export
#' @param filename Output filename
#' @param format Export format (csv, xlsx, json)
export_data <- function(data, filename, format = "csv") {
  if (format == "csv") {
    write_csv(data, filename)
  } else if (format == "xlsx") {
    writexl::write_xlsx(data, filename)
  } else if (format == "json") {
    jsonlite::write_json(data, filename, pretty = TRUE)
  }
  
  return(filename)
}
