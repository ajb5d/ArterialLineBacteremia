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
    method = 'nearest')

matched_data <- get_matches(match, data)

write_rds(matched_data, "data/matched_data.rds")
