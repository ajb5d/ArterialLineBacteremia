library(odbc)
library(tidyverse)
library(lubridate)
library(magrittr)
library(dbplyr)

FOLLOW_UP_MAX = 24 * 30

dbConfig <- config::get("db")
con <- dbConnect(odbc::odbc(), 
                 .connection_string = dbConfig$ConnectionString, 
                 PWD = dbConfig$Password, 
                 timeout = 10)

data <- src_dbi(con) %>% 
  tbl(sql(read_file("query.sql"))) %>% 
  collect()

data %<>% 
  mutate_at(vars(culture_positive, icu_first, sepsis), ~.x==1) %>% 
  mutate_at(vars(data_source, admission_type, gender), as_factor) %>%
  mutate( duration = (event_time - intime) / dhours(1), 
          any_arterial_line = arterial_line > 0,
          any_central_line = central_line > 0,
          age_at_admission = case_when(age_at_admission < 100 ~ age_at_admission, TRUE ~ 91),
          group = case_when(
            !any_arterial_line & !any_central_line ~ "None",
            any_arterial_line & !any_central_line ~ "Arterial Line Only",
            !any_arterial_line & any_central_line ~ "Central Line Only",
            any_arterial_line & any_central_line ~ "Both Arterial and Central Line"),
          group = fct_relevel(group, "None", "Central Line Only", "Arterial Line Only", "Both Arterial and Central Line"),
          event = case_when(duration < FOLLOW_UP_MAX ~ culture_positive, TRUE ~ FALSE),
          time = pmin(duration, FOLLOW_UP_MAX))

data %>%
  filter(time > 4, !is.na(time)) %>%
  write_rds("data/line_data.rds")
