# Note: this code is converted from the markdown file "2sls_result.rmd". Conversion is completed using Autopilot, proofed by James Ji. 
# Author: Yujuan Gao and James Ji, University of Florida

# Set metadata ----
title <- "\\centering Mobile Internet Access and DHS"
author <- "\\centering Gao Yujuan, University of Florida, with edits from James Ji"
date <- format(Sys.time(), '%B %d, %Y')

# Set output options
rm(list = ls(all.names = TRUE))

output <- list(
    html_document = "default",
    latex_engine = "xelatex",
    includes = list(
        in_header = "longtable"
    )
)

# Load required libraries ----
library(magrittr)
library(gdata)
library(readstata13)
library(dplyr)
library(plm)
library(stargazer)
library(writexl)
library(sf)
library(raster)
library(tidyverse)
library(ggplot2)
library(maps)
library(exactextractr)
library(readxl)
library(sp)
library(ncdf4)
library(raster)
library(fixest)
library(sjPlot)
library(sjmisc)
library(sjlabelled)
library(fixest)
library(mapview)
library(texreg)
library(modelsummary)
library(openxlsx)
library(haven)
library(AER)

# Set working directory
code_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(code_dir)
setwd("../../data")

# Prepare data
# Add administrative boundary to Nigeria shape file
DHS_location <- st_read("../data/dhs_nigeria/Nigeria_DHS_location_all.shp")
DHS_2018 <- DHS_location %>%
    filter(DHSYEAR %in% c(2018)) %>%
    filter(LATNUM>0&LONGNUM>0)%>%
    st_transform(32632)
  
admin_boundary_shapefile <- st_read("../data/dhs_Nigeria/administrative boundary/local government area (LGA)/nga_admbnda_adm2_osgof_20170222.shp")
joined_shapefile <- st_join(DHS_location, admin_boundary_shapefile, join = st_intersects)%>%filter(LATNUM>0&LONGNUM>0)
joined_shapefile1 <- joined_shapefile %>% dplyr::select(DHSYEAR, DHSCLUST, admin1Name, admin1Pcod, admin2Name, admin2Pcod)

# write shape data to DTA ----
colnames(joined_shapefile1) = colnames(joined_shapefile1) %>%
  trimws(whitespace= "\\.") %>% 
  str_replace_all("\\.","\\_")

#joined_shapefile1 %<>% st_drop_geometry() %>%save.dta13(file="../Interim_Data_Product/shapefile.dta")
joined_shapefile1_no_geo <- st_drop_geometry(joined_shapefile1)
joined_shapefile1_no_geo %>% save.dta13(file = "../Interim_Data_Product/shapefile.dta")
# Load weather data ----
weather_5nn <- read_csv("../data/Climate_Data/monthly_interpolated/dhs_weather_5nn.csv")

# Calculate monthly weather values ----

tem_bins <- weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Temperature.Air.2m.Mean.24h_.'), ~sum(.x, na.rm = TRUE)))
colnames(tem_bins) = colnames(tem_bins) %>% str_replace('Temperature.Air.2m.Mean.24h_.','temair_')

wet_bulb_bins <- weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Wet.Bulb.Temperature.2m.Mean_.'), ~sum(.x, na.rm = TRUE)))
colnames(wet_bulb_bins) = colnames(wet_bulb_bins) %>% str_replace('Wet.Bulb.Temperature.2m.Mean_.','wetbulbtem_')

apparent_tem_bins = weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Apparent.Temperature.2m.Mean_.'), ~sum(.x, na.rm = TRUE)))
colnames(apparent_tem_bins) = colnames(apparent_tem_bins) %>% str_replace('Apparent.Temperature.2m.Mean_.','apptem_')

weather_nm <- weather_5nn %>%
    group_by(DHSYEAR, DHSCLUST, year) %>%
    summarize(
        vapour_m = mean(Vapour_Pressure_Mean, na.rm = TRUE),
        rain_s = sum(Precipitation_Rain_Duration_Fraction, na.rm = TRUE),
        temair_m = mean(Temperature_Air_2m_Mean_24h, na.rm = TRUE),
        wind_m = mean(Wind_Speed_10m_Mean, na.rm = TRUE),
        Precipatation_s = sum(Precipitation_Flux, na.rm = TRUE),
        solar_m = mean(Solar_Radiation_Flux, na.rm = TRUE),
        apptem_m = mean(Apparent_Temperature_2m_Mean, na.rm = TRUE),
        wetbulbtem_m = mean(Wet_Bulb_Temperature_2m_Mean, na.rm = TRUE)
    )

## generate long-run weather series
weather_lr = weather_nm%>%
    group_by(DHSYEAR,DHSCLUST) %>%
    summarize(vapour_lr = mean(vapour_m,na.rm=T),
              rain_lr = mean(rain_s,na.rm=T),
              temair_lr = mean(temair_m,na.rm=T),
              wind_lr = mean(wind_m,na.rm=T),
              Precipatation_lr = mean(Precipatation_s,na.rm=T),
              solar_lr = mean(solar_m,na.rm=T),
              apptem_lr = mean(apptem_m,na.rm=T),
              wetbulbtem_lr = mean(wetbulbtem_m,na.rm=T))

tem_bins_lr = tem_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(tem_bins_lr) = colnames(tem_bins_lr) %>% str_replace('temair_','temair_lr_')


wet_bulb_bins_lr = wet_bulb_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(wet_bulb_bins_lr) = colnames(wet_bulb_bins_lr) %>% str_replace('wetbulbtem_','wetbulbtem_lr_')

apparent_tem_bins_lr = apparent_tem_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(apparent_tem_bins_lr) = colnames(apparent_tem_bins_lr) %>% str_replace('apptem_','apptem_lr_')

## lagged weather variables
weather_nm_l1 = weather_nm %>% mutate(year = year + 1) %>%
    rename(vapour_m_l1 = vapour_m,
           rain_s_l1 = rain_s,
           temair_m_l1 = temair_m,
           wind_m_l1 = wind_m,
           Precipatation_s_l1 = Precipatation_s,
           solar_m_l1 = solar_m,
           apptem_m_l1 = apptem_m,
           wetbulbtem_m_l1 = wetbulbtem_m)

tem_bins_l1 = tem_bins %>% mutate(year = year + 1)
colnames(tem_bins_l1) = colnames(tem_bins_l1) %>% str_replace('temair_','temair_l1_')

wet_bulb_bins_l1 = wet_bulb_bins %>% mutate(year = year + 1)
colnames(wet_bulb_bins_l1) = colnames(wet_bulb_bins_l1) %>% str_replace('wetbulbtem_','wetbulbtem_l1_')

apparent_tem_bins_l1 = apparent_tem_bins %>% mutate(year = year + 1)
colnames(apparent_tem_bins_l1) = colnames(apparent_tem_bins_l1) %>% str_replace('apptem_','apptem_l1_')

# Process GSM and lightning data ----
setwd("../Interim_Data_Product")
gsm <- read_csv("DHS_GSM_coverage.csv")
lightning <- read_csv("DHS_lightning_coverage.csv")

lightning$ltcovm <- rowMeans(lightning[, 5:16]) # mean value
lightning$ltcov90per <- apply(lightning[, 5:16], 1, function(row) {
    quantile(row, probs = 0.9)
})

lightning_lr = lightning %>% rename(ltdist=BUFFERDIST)%>%
    group_by(DHSYEAR,DHSCLUST,ltdist) %>%
    summarize(ltcovm_1021 = mean(ltcovm,na.rm=T),
                        ltcov90per_1021 = mean(ltcov90per,na.rm=T))

lightning_lr_wide = lightning_lr %>% 
    pivot_wider(names_from=ltdist,
                            values_from=c("ltcovm_1021","ltcov90per_1021"),
                            names_glue="{.value}_dist{ltdist}")

gsm_wide = gsm %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("GSMCOVER","GSMCOVER_2G"),
              names_glue="{.value}_dist{BUFFERDIST}")

lightning_select = lightning %>% dplyr::select(DHSYEAR,DHSCLUST,ltcovm,ltcov90per,LTYEAR,BUFFERDIST)

lightning_select_wide = lightning_select %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("ltcovm","ltcov90per"),
              names_glue="{.value}_dist{BUFFERDIST}")

# get lagged lightning set
lightning_select_l1 = lightning_select %>% 
    mutate(LTYEARl1 = LTYEAR+1) %>%
    rename(ltcovm_l1 = ltcovm,
           ltcov90per_l1 = ltcov90per)

lightning_select_l1_wide = lightning_select_l1 %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("ltcovm_l1","ltcov90per_l1"),
              names_glue="{.value}_dist{BUFFERDIST}")

# Load elevation data ----
elevation <- read_csv("../interim_data_product/DHS_Elevation_average.csv")
elevation <- elevation %>% dplyr::select("DHSYEAR", "DHSCLUST", "Elevation")
# merge data -----
merged_data = gsm_wide %>%
    left_join(lightning_lr_wide,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(elevation, by = c("DHSYEAR", "DHSCLUST"))

merged_data %<>% left_join(joined_shapefile1 %>% st_drop_geometry(),by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(lightning_select_wide,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="LTYEAR"))
merged_data %<>% left_join(lightning_select_l1_wide,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="LTYEAR"))

merged_data %<>% left_join(weather_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(tem_bins_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(wet_bulb_bins_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(apparent_tem_bins_lr,by=c("DHSYEAR","DHSCLUST"))

merged_data %<>% left_join(weather_nm,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(tem_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(wet_bulb_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(apparent_tem_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))

merged_data %<>% left_join(weather_nm_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(tem_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(wet_bulb_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(apparent_tem_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))


# write merged data to DTA ----
colnames(merged_data) = colnames(merged_data) %>%
  trimws(whitespace= "\\.") %>% 
  str_replace_all("\\.","\\_")
merged_data %>% filter(LATNUM>0&LONGNUM>0) %>%
  save.dta13(file="merged_GSM_lightning_weather.dta")

# Clean up ----
gdata::keep("merged_data",sure=T)
gc()


# Note: this code is converted from the markdown file "2sls_result.rmd". Conversion is completed using Autopilot, proofed by James Ji. 
# Author: Yujuan Gao and James Ji, University of Florida

# Set metadata ----
title <- "\\centering Mobile Internet Access and DHS"
author <- "\\centering Gao Yujuan, University of Florida, with edits from James Ji"
date <- format(Sys.time(), '%B %d, %Y')

# Set output options
rm(list = ls(all.names = TRUE))

output <- list(
    html_document = "default",
    latex_engine = "xelatex",
    includes = list(
        in_header = "longtable"
    )
)

# Load required libraries ----
library(magrittr)
library(gdata)
library(readstata13)
library(dplyr)
library(plm)
library(stargazer)
library(writexl)
library(sf)
library(raster)
library(tidyverse)
library(ggplot2)
library(maps)
library(exactextractr)
library(readxl)
library(sp)
library(ncdf4)
library(raster)
library(fixest)
library(sjPlot)
library(sjmisc)
library(sjlabelled)
library(fixest)
library(mapview)
library(texreg)
library(modelsummary)
library(openxlsx)
library(haven)
library(AER)

# Set working directory
code_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(code_dir)
setwd("../../data")

# Prepare data
# Add administrative boundary to Nigeria shape file
DHS_location <- st_read("../data/dhs_nigeria/Nigeria_DHS_location_all.shp")
DHS_2018 <- DHS_location %>%
    filter(DHSYEAR %in% c(2018)) %>%
    filter(LATNUM>0&LONGNUM>0)%>%
    st_transform(32632)
  
admin_boundary_shapefile <- st_read("../data/dhs_Nigeria/administrative boundary/local government area (LGA)/nga_admbnda_adm2_osgof_20170222.shp")
joined_shapefile <- st_join(DHS_location, admin_boundary_shapefile, join = st_intersects)%>%filter(LATNUM>0&LONGNUM>0)
joined_shapefile1 <- joined_shapefile %>% dplyr::select(DHSYEAR, DHSCLUST, admin1Name, admin1Pcod, admin2Name, admin2Pcod)

# write shape data to DTA ----
colnames(joined_shapefile1) = colnames(joined_shapefile1) %>%
  trimws(whitespace= "\\.") %>% 
  str_replace_all("\\.","\\_")

#joined_shapefile1 %<>% st_drop_geometry() %>%save.dta13(file="../Interim_Data_Product/shapefile.dta")
joined_shapefile1_no_geo <- st_drop_geometry(joined_shapefile1)
joined_shapefile1_no_geo %>% save.dta13(file = "../Interim_Data_Product/shapefile.dta")
# Load weather data ----
weather_5nn <- read_csv("../data/Climate_Data/monthly_interpolated/dhs_weather_5nn.csv")

# Calculate monthly weather values ----

tem_bins <- weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Temperature.Air.2m.Mean.24h_.'), ~sum(.x, na.rm = TRUE)))
colnames(tem_bins) = colnames(tem_bins) %>% str_replace('Temperature.Air.2m.Mean.24h_.','temair_')

wet_bulb_bins <- weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Wet.Bulb.Temperature.2m.Mean_.'), ~sum(.x, na.rm = TRUE)))
colnames(wet_bulb_bins) = colnames(wet_bulb_bins) %>% str_replace('Wet.Bulb.Temperature.2m.Mean_.','wetbulbtem_')

apparent_tem_bins = weather_5nn %>%
  group_by(DHSYEAR, DHSCLUST, year) %>%
  summarise(across(starts_with('Apparent.Temperature.2m.Mean_.'), ~sum(.x, na.rm = TRUE)))
colnames(apparent_tem_bins) = colnames(apparent_tem_bins) %>% str_replace('Apparent.Temperature.2m.Mean_.','apptem_')

weather_nm <- weather_5nn %>%
    group_by(DHSYEAR, DHSCLUST, year) %>%
    summarize(
        vapour_m = mean(Vapour_Pressure_Mean, na.rm = TRUE),
        rain_s = sum(Precipitation_Rain_Duration_Fraction, na.rm = TRUE),
        temair_m = mean(Temperature_Air_2m_Mean_24h, na.rm = TRUE),
        wind_m = mean(Wind_Speed_10m_Mean, na.rm = TRUE),
        Precipatation_s = sum(Precipitation_Flux, na.rm = TRUE),
        solar_m = mean(Solar_Radiation_Flux, na.rm = TRUE),
        apptem_m = mean(Apparent_Temperature_2m_Mean, na.rm = TRUE),
        wetbulbtem_m = mean(Wet_Bulb_Temperature_2m_Mean, na.rm = TRUE)
    )

## generate long-run weather series
weather_lr = weather_nm%>%
    group_by(DHSYEAR,DHSCLUST) %>%
    summarize(vapour_lr = mean(vapour_m,na.rm=T),
              rain_lr = mean(rain_s,na.rm=T),
              temair_lr = mean(temair_m,na.rm=T),
              wind_lr = mean(wind_m,na.rm=T),
              Precipatation_lr = mean(Precipatation_s,na.rm=T),
              solar_lr = mean(solar_m,na.rm=T),
              apptem_lr = mean(apptem_m,na.rm=T),
              wetbulbtem_lr = mean(wetbulbtem_m,na.rm=T))

tem_bins_lr = tem_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(tem_bins_lr) = colnames(tem_bins_lr) %>% str_replace('temair_','temair_lr_')


wet_bulb_bins_lr = wet_bulb_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(wet_bulb_bins_lr) = colnames(wet_bulb_bins_lr) %>% str_replace('wetbulbtem_','wetbulbtem_lr_')

apparent_tem_bins_lr = apparent_tem_bins %>%
  group_by(DHSYEAR,DHSCLUST) %>% 
  summarise(across(-year, ~mean(.x, na.rm = TRUE)))
colnames(apparent_tem_bins_lr) = colnames(apparent_tem_bins_lr) %>% str_replace('apptem_','apptem_lr_')

## lagged weather variables
weather_nm_l1 = weather_nm %>% mutate(year = year + 1) %>%
    rename(vapour_m_l1 = vapour_m,
           rain_s_l1 = rain_s,
           temair_m_l1 = temair_m,
           wind_m_l1 = wind_m,
           Precipatation_s_l1 = Precipatation_s,
           solar_m_l1 = solar_m,
           apptem_m_l1 = apptem_m,
           wetbulbtem_m_l1 = wetbulbtem_m)

tem_bins_l1 = tem_bins %>% mutate(year = year + 1)
colnames(tem_bins_l1) = colnames(tem_bins_l1) %>% str_replace('temair_','temair_l1_')

wet_bulb_bins_l1 = wet_bulb_bins %>% mutate(year = year + 1)
colnames(wet_bulb_bins_l1) = colnames(wet_bulb_bins_l1) %>% str_replace('wetbulbtem_','wetbulbtem_l1_')

apparent_tem_bins_l1 = apparent_tem_bins %>% mutate(year = year + 1)
colnames(apparent_tem_bins_l1) = colnames(apparent_tem_bins_l1) %>% str_replace('apptem_','apptem_l1_')

# Process GSM and lightning data ----
setwd("../Interim_Data_Product")
gsm <- read_csv("DHS_GSM_coverage.csv")
lightning <- read_csv("DHS_lightning_coverage.csv")

lightning$ltcovm <- rowMeans(lightning[, 5:16]) # mean value
lightning$ltcov90per <- apply(lightning[, 5:16], 1, function(row) {
    quantile(row, probs = 0.9)
})

lightning_lr = lightning %>% rename(ltdist=BUFFERDIST)%>%
    group_by(DHSYEAR,DHSCLUST,ltdist) %>%
    summarize(ltcovm_1021 = mean(ltcovm,na.rm=T),
                        ltcov90per_1021 = mean(ltcov90per,na.rm=T))

lightning_lr_wide = lightning_lr %>% 
    pivot_wider(names_from=ltdist,
                            values_from=c("ltcovm_1021","ltcov90per_1021"),
                            names_glue="{.value}_dist{ltdist}")

gsm_wide = gsm %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("GSMCOVER","GSMCOVER_2G"),
              names_glue="{.value}_dist{BUFFERDIST}")

lightning_select = lightning %>% dplyr::select(DHSYEAR,DHSCLUST,ltcovm,ltcov90per,LTYEAR,BUFFERDIST)

lightning_select_wide = lightning_select %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("ltcovm","ltcov90per"),
              names_glue="{.value}_dist{BUFFERDIST}")

# get lagged lightning set
lightning_select_l1 = lightning_select %>% 
    mutate(LTYEARl1 = LTYEAR-1) %>%
    rename(ltcovm_l1 = ltcovm,
           ltcov90per_l1 = ltcov90per)

lightning_select_l1_wide = lightning_select_l1 %>% 
  pivot_wider(names_from=BUFFERDIST,
              values_from=c("ltcovm_l1","ltcov90per_l1"),
              names_glue="{.value}_dist{BUFFERDIST}")

# Load elevation data ----
elevation <- read_csv("../interim_data_product/DHS_Elevation_average.csv")
elevation <- elevation %>% dplyr::select("DHSYEAR", "DHSCLUST", "Elevation")
# merge data -----
merged_data = gsm_wide %>%
    left_join(lightning_lr_wide,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(elevation, by = c("DHSYEAR", "DHSCLUST"))

merged_data %<>% left_join(joined_shapefile1 %>% st_drop_geometry(),by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(lightning_select_wide,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="LTYEAR"))
merged_data %<>% left_join(lightning_select_l1_wide,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="LTYEAR"))

merged_data %<>% left_join(weather_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(tem_bins_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(wet_bulb_bins_lr,by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(apparent_tem_bins_lr,by=c("DHSYEAR","DHSCLUST"))

merged_data %<>% left_join(weather_nm,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(tem_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(wet_bulb_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(apparent_tem_bins,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))

merged_data %<>% left_join(weather_nm_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(tem_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(wet_bulb_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))
merged_data %<>% left_join(apparent_tem_bins_l1,by=c("DHSYEAR","DHSCLUST","GSMYEAR"="year"))


# write merged data to DTA ----
colnames(merged_data) = colnames(merged_data) %>%
  trimws(whitespace= "\\.") %>% 
  str_replace_all("\\.","\\_")
merged_data %>% filter(LATNUM>0&LONGNUM>0) %>%
  save.dta13(file="merged_GSM_lightning_weather.dta")

# Clean up ----
gdata::keep("merged_data",sure=T)
gc()


