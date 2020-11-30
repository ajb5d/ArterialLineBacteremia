library(tidyverse)

data <- read_rds("data/line_data.rds") 

data %>%
  mutate(surgical = admission_type == 'surgical') %>%
  group_by(any_arterial_line) %>%
  summarise_at(vars(sepsis, any_central_line, surgical), mean)

xtabs(~ any_central_line + any_arterial_line, data)
xtabs(~ any_central_line + any_arterial_line, data) %>% chisq.test()

xtabs(~ admission_type + any_arterial_line, data)
xtabs(~ admission_type + any_arterial_line, data) %>% chisq.test()

xtabs(~ sepsis + any_arterial_line, data)
xtabs(~ sepsis + any_arterial_line, data) %>% chisq.test()

data %>%
  group_by(any_arterial_line) %>%
  summarise_at(vars(sapsii, age_at_admission), median)

wilcox.test(sapsii ~ any_arterial_line, data)
wilcox.test(age_at_admission ~ any_arterial_line, data)
