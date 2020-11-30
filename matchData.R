library(tidyverse)
library(lubridate)
library(magrittr)
library(MatchIt)

data <- read_rds("data/line_data.rds") 

data %<>% select(
  any_arterial_line,
  any_central_line,
  arterial_line,
  central_line,
  age_at_admission,
  admission_type,
  sapsii,
  sepsis,
  culture_positive,
  duration
)

data %<>% drop_na()

match <-
  matchit(
    any_arterial_line ~ any_central_line + age_at_admission + admission_type + sepsis + sapsii,
    data,
    method = 'nearest',
    discard = 'both',
    caliper = 0.075)

summary(match, standardize=TRUE)

write_rds(match.data(match), "data/matched_data.rds")
