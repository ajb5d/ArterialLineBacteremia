library(tidyverse)
library(magrittr)
library(tidyverse)
library(survival)
library(scales)
library(broom)
library(glue)

data <- read_rds("data/line_data.rds")

## Total Admission Count
data %>%
  pull(icustay_id) %>%
  unique() %>%
  length()

## Total Hospitalization Count
data %>%
  pull(hadm_id) %>%
  unique() %>%
  length()

## Total Subject count
data %>%
  pull(subject_id) %>%
  unique() %>%
  length()

## Breakdown of admissions by line group
data %>%
  group_by(group) %>%
  summarise(n = n(),
            events = sum(event),
            .groups = 'drop') %>%
  mutate(pct_of_total_admissions = n / sum(n),
         binom_prop = map2(events, n, ~ binom.test(.x, .y)),
         event_rate = map_dbl(binom_prop, 'estimate'),
         lcl = map_dbl(binom_prop, ~ pluck(.x, 'conf.int', 1)),
         ucl = map_dbl(binom_prop, ~ pluck(.x, 'conf.int', 2)))

##matched analysis and sensitivity analysis
matched_data <- read_rds("data/matched_data.rds")

model0 <- coxph(Surv(duration, culture_positive) ~ any_arterial_line, matched_data)
model1 <- coxph(Surv(duration, culture_positive) ~ any_arterial_line + any_central_line + age_at_admission + admission_type + sepsis + sapsii, matched_data)
model2 <- coxph(Surv(duration, culture_positive) ~ any_arterial_line * any_central_line + age_at_admission + admission_type + sepsis + sapsii, matched_data)
model3 <- glm(culture_positive ~ any_arterial_line, matched_data, family = binomial)
model4 <- glm(culture_positive ~ any_arterial_line + any_central_line + age_at_admission + admission_type + sepsis + sapsii, matched_data, family = binomial)
model5 <- glm(culture_positive ~ arterial_line, matched_data, family = binomial)
model6 <- glm(culture_positive ~ arterial_line + any_central_line + age_at_admission + admission_type + sepsis + sapsii, matched_data, family = binomial)
model7 <- coxph(Surv(duration, culture_positive) ~ any_arterial_line, data)
model8 <- coxph(Surv(duration, culture_positive) ~ any_arterial_line + any_central_line + age_at_admission + admission_type + sepsis + sapsii, data)

n <- number_format(accuracy = 0.01)
p <- pvalue_format()

model_results <- tribble(
  ~ name, ~ model,
  "model0", model0,
  "model1", model1,
  "model2", model2,
  "model3", model3,
  "model4", model4,
  "model5", model5,
  "model6", model6,
  "model7", model7,
  "model8", model8
) %>% 
  mutate(terms = map(model, ~ tidy(.x, exponentiate = TRUE, conf.int = TRUE))) %>% 
  unnest(cols = 'terms') %>%
  filter(term != '(Intercept)') %>%
  mutate(display = glue("{n(estimate)} (95% CI {n(conf.low)} - {n(conf.high)}) {p(p.value)}")) %>%
  select(name, term, display) %>%
  mutate_all(as.character) %>% 
  pivot_wider(names_from = 'name', values_from = 'display') 

new_labels <- tibble::tribble(
  ~term, ~label, ~sort_order,
  "any_arterial_lineTRUE", "Arterial Line Use", 1,
  "any_central_lineTRUE", "Central Line Use", 4, 
  "age_at_admission", "Age At Admission (per year)", 5, 
  "admission_typesurgical", "Admission to Surgical Service", 6,
  "sepsisTRUE", "Sepsis Diagnosis", 7, 
  "sapsii", "SAPS II Score (per point)", 8, 
  "any_arterial_lineTRUE:any_central_lineTRUE", "Interaction of Arterial Line Use and Central Line Use", 2, 
  "arterial_line", "Arterial Line Duration (per Day)", 3
)

cohort_labels <- tibble::tribble(
  ~ label, ~ model0, ~ model1, ~ model2, ~ model3, ~ model4, ~ model5, 
  ~ model6, ~ model7, ~ model8, ~sort_order, 
  "Cohort", "Propensity-Matched", "Propensity-Matched", "Propensity-Matched",
  "Propensity-Matched", "Propensity-Matched", "Propensity-Matched",
  "Propensity-Matched", "Unmatched", "Unmatched", -1
)

model_table <- bind_rows(cohort_labels, 
                         new_labels %>% left_join(model_results, by = 'term'))

model_table %<>%
  arrange(sort_order) %>%
  select(-sort_order, -term)

colnames(model_table) <- c("Model Term", "Primary Model", "Model 1", "Model 2", "Model 3", "Model 4", 
                           "Model 5", "Model 6", "Model 7", "Model 8")

model_table %>% write_csv("data/table.csv", na = '')
