#This code conduct first stage analysis 
# Author: Yuiuan Gao, with help from James Ji, University of Florida
# This version: 10/4/2023

#pre-emble----
rm(list=ls())
library(magrittr)
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

# set up wd
code_dir = dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(code_dir)
setwd("../data")

# add administrative boundary to Nigeria shape file ----

DHS_location = st_read("../data/dhs_nigeria/Nigeria_DHS_location_all.shp")
# # transforming to UTM 32 (Nigeria falls into UTM 31-33). Unit is meter.
DHS_2018 = DHS_location %>% 
  filter(DHSYEAR %in% c(2018)) %>% 
  st_transform(32632)
admin_boundary_shapefile <- st_read("dhs_Nigeria/administrative boundary/local government area (LGA)/nga_admbnda_adm2_osgof_20170222.shp")
# Perform a spatial join
joined_shapefile <- st_join(DHS_location, admin_boundary_shapefile, join = st_intersects)
joined_shapefile1 <- joined_shapefile %>% dplyr::select(DHSYEAR,DHSCLUST,admin1Name,admin1Pcod,admin2Name,admin2Pcod)

# load weather data ----

# weather_1nn = read.csv("Climate_Data/monthly_interpolated/dhs_weather_1nn.csv")
# weather_3nn = read.csv("Climate_Data/monthly_interpolated/dhs_weather_3nn.csv")
weather_5nn = read.csv("Climate_Data/monthly_interpolated/dhs_weather_5nn.csv")
# weather_10nn = read.csv("Climate_Data/monthly_interpolated/dhs_weather_10nn.csv")

# monthly value - weather data

colums<-grep("Temperature_Air_2m_Mean_24h_.",names(weather_5nn),value=TRUE)
weather_5nn$temairbin<-rowSums(weather_5nn[colums])

weather_nm = weather_5nn %>% 
  group_by(DHSYEAR,DHSCLUST,year) %>%
  summarize(vapour_m = mean(Vapour_Pressure_Mean,na.rm=T),
            rain_s = sum(Precipitation_Rain_Duration_Fraction,na.rm=T),
            temair_m = mean(temairbin,na.rm=T),
            wind_m = mean(Wind_Speed_10m_Mean,na.rm=T),
            Precipatation_s = sum(Precipitation_Flux,na.rm=T),
            solar_m = mean(Solar_Radiation_Flux,na.rm=T),
            apptem_m = mean(Apparent_Temperature_2m_Mean,na.rm=T),
            wetbulbtem_m = mean(Wet_Bulb_Temperature_2m_Mean,na.rm=T))

# load gsm/lightning coverage data ----

setwd("../Interim_Data_Product")
gsm = read.csv("DHS_GSM_coverage.csv")
lightning = read.csv("DHS_lightning_coverage.csv")

# monthly value-lightning coverage

lightning$ltcovm<-rowMeans(lightning[,5:16]) #mean value
lightning$ltcov90per<-apply(lightning[,5:16],1,function(row){
quantile(row,probs=0.9)}) # 90th percentile


lightning_lr = lightning %>% rename(ltdist=BUFFERDIST)%>%
  group_by(DHSYEAR,DHSCLUST,ltdist) %>%
  summarize(ltcovm_1021 = mean(ltcovm,na.rm=T),
            ltcov90per_1021 = mean(ltcov90per,na.rm=T))
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
#merge data
merged_data = gsm %>%
  left_join(lightning_lr %>% filter(ltdist == 10),by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(joined_shapefile1 %>% st_drop_geometry(),by=c("DHSYEAR","DHSCLUST"))
merged_data %<>% left_join(weather_lr,by=c("DHSYEAR","DHSCLUST"))
lightning <- lightning %>% filter(BUFFERDIST == 10 & (LTYEAR== 2012|LTYEAR== 2013|LTYEAR== 2017|LTYEAR== 2018))
lightning %<>% dplyr::select(DHSYEAR,DHSCLUST,ltcovm,LTYEAR)%>%rename(GSMYEAR=LTYEAR)
merged_data %<>% left_join(lightning,by=c("DHSYEAR","DHSCLUST","GSMYEAR"))

##remove data
rm(DHS_location)
rm(DHS_2018)
rm(admin_boundary_shapefile)
rm(joined_shapefile1)
rm(joined_shapefile)
rm(lightning_lr)
rm(lightning)
rm(gsm)
rm(weather_5nn)
rm(weather_lr)
rm(weather_nm)

## generate lightning percentiles ----

 merged_data %<>% mutate(GSMCOVER_dum = ifelse(GSMCOVER>0,1,0),
                         ltcovm_1021_dum = ifelse(ltcovm_1021>=median(merged_data$ltcovm_1021),1,0))
 merged_data %<>% 
   group_by(BUFFERDIST,admin2Pcod) %>% 
   mutate(ltcovm_1021_dum_2 = ifelse(ltcovm_1021 >= median(ltcovm_1021,na.rm=T),1,0),
          ltcov90per_1021_dum_2 = ifelse(ltcov90per_1021 >= median(ltcov90per_1021,na.rm=T),1,0))


#load DHS data
DHSIR<-read_dta("../processed/dhs/DHS_2013_2018.dta")
DHSIR %<>%arrange(DHSYEAR, DHSCLUST) %>%
  group_by(DHSYEAR, DHSCLUST) %>%
  mutate(cluster_id = row_number())
DHSIR = subset(DHSIR, select = -c(DHSCLUST))

merged_data%<>%filter(GSMYEAR <= 2018)
merged_data%<>%filter(BUFFERDIST==10|BUFFERDIST==30|BUFFERDIST==50)
merged_data%<>%arrange(DHSYEAR, DHSCLUST) %>%
  group_by(DHSYEAR, DHSCLUST) %>%
  mutate(cluster_id = row_number())

merged_data <- merged_data %>%
  left_join(DHSIR, by = c("cluster_id", "GSMYEAR"="DHSYEAR"))

rm(DHSIR)

write_dta(merged_data, "../processed/dhs/merged_data.dta")


# ## plot lightning density by cluster
 merged_data = gsm %>%
  left_join(lightning_lr,by=c("DHSYEAR","DHSCLUST"))
 merged_data %<>% left_join(joined_shapefile1 %>% st_drop_geometry(),by=c("DHSYEAR","DHSCLUST"))
# 
# #ltdist=20
# plot_data = merged_data %>%
#   filter(ltdist == 20) %>%
#   st_as_sf(coords=c("LONGNUM","LATNUM"),crs=st_crs(4326))
# 
 mapView(merged_data %>% filter(GSMYEAR == 2013),zcol="ltcovm_1021",at = quantile(plot_data$lltcovm_1021), legend=T,cex=3,layer.name="lightning density 2013")
# 
# mapView(plot_data %>% filter(GSMYEAR == 2017),zcol="ltcov90per_1021",at = quantile(plot_data$ltcov90per_1021), legend=T,cex=3,layer.name="lightning density 2017")
# 
# mapView(plot_data %>% filter(GSMYEAR == 2021),zcol="ltcov90per_1021",at = quantile(plot_data$ltcov90per_1021), legend=T,cex=3,layer.name="lightning density 2021")
# 
# mapView(plot_data %>% filter(GSMYEAR == 2013),zcol="GSMCOVER", at=c(0,0.1,0.5,1),legend=T,cex=3,layer.name="GSM Cover 2013")
# 
# mapView(plot_data %>% filter(GSMYEAR == 2017),zcol="GSMCOVER", at=c(0,0.1,0.5,1),legend=T,cex=3,layer.name="GSM Cover 2017")
# 
# mapView(plot_data %>% filter(GSMYEAR == 2021),zcol="GSMCOVER", at=c(0,0.1,0.5,1),legend=T,cex=3,layer.name="GSM Cover 2021")




