# Load required libraries
library(raster)
library(exactextractr)
library(tidyverse)

###################### Task 1 ###################### 

#Import rasters
area_raster <- raster("data/input/SPAM_2005_v3.2/SPAM2005V3r2_global_A_TA_WHEA_A.tif")
yield_raster <- raster("data/input/SPAM_2005_v3.2/SPAM2005V3r2_global_Y_TA_WHEA_A.tif")
harvested_raster <- raster("data/input/SPAM_2005_v3.2/SPAM2005V3r2_global_H_TA_WHEA_A.tif")

#area_raster

production_raster <-  yield_raster * harvested_raster

#Write Raster (just in case)

production_raster_mt <- production_raster/1000
writeRaster(production_raster_mt, "data/output/production_raster_mt.tif", format = "GTiff", overwrite = TRUE)


###################### Task 2 ###################### 

gaul <- rgdal::readOGR("data/input/GAUL/g2015_2005_2.shp")

# Aggregate wheat production to country level (exact_extract faster than raster)
production_country <- exact_extract(production_raster_mt, gaul, fun="sum")

# Create a data frame with country names and production values
prod_country_agr <- data.frame(Country = gaul$ADM0_NAME, Production_mt = production_country) %>%
  group_by(Country) %>%
  summarise(Production_mt = sum(Production_mt))

# Export aggregated data to CSV
write.csv(prod_country_agr, "data/output/wheat_production_country.csv", row.names = FALSE)



###################### Task 3 ###################### 

# Calculate nitrogen output raster (assuming 2% of harvested wheat yield consists of nitrogen)
nitrogen_output <- production_raster_mt * 0.02 

# Save the nitrogen output raster as GeoTIFF
writeRaster(nitrogen_output, "data/output/nitrogen_output.tif", format = "GTiff", overwrite = TRUE)

plot(nitrogen_output)




###################### Task 4 ###################### 

# Load the dataset of country-level nitrogen use efficiency (NUE) from Zhang et al 2015
nue_data <- read.csv("data/input/NUE_Zhang_et_al_2015/Country_NUE_assumption.csv")


# Sort the data to get the top 10 wheat producers

top_10_producers <- head(prod_country_agr[order(-prod_country_agr$Production_mt), ], 10) %>%
  mutate(Country = case_when(Country == "Iran  (Islamic Republic of)" ~ "Iran",
                             Country == "United States of America" ~ "USA",
                             Country == "Russian Federation" ~ "RussianFed",
                             TRUE ~ Country))

# Merge production data
top_10_producers <- merge(top_10_producers, nue_data, by = "Country")


# Calculate N Output, Total N Inputs, and N Losses
top_10_producers <- top_10_producers %>%
  mutate(N_Output = Production_mt * NUE,
         Total_N_Input = Production_mt/NUE) %>%
  mutate(N_Losses = Total_N_Input - N_Output)

# Export the dataset to CSV
write.csv(top_10_producers, "data/output/top_10_producers_n_data.csv", row.names = FALSE)

# Pivot data for plotting
top_10_producers %>%
  select(-Production_mt, -Total_N_Input, -NUE) %>%
  pivot_longer(cols = c(N_Output, N_Losses), 
               names_to = "Variable", 
               values_to = "Value") %>%
# Create a bar plot for N Output and N Losses
ggplot(aes(x = Country, fill = factor(Variable))) +
  geom_bar(aes(y = Value), stat = "identity", position = "dodge") +
  ylab("Nitrogen (Mt)") +
  ggtitle("N Output and N Losses for Top 10 Wheat Producers") +
  scale_fill_manual(values = c("N_Output" = "#1DACE8", "N_Losses" = "#F24D29")) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(fill = "")
  
# Save the plot as PDF
ggsave("data/output/n_output_and_losses_plot.pdf", width = 10, height = 6)



#### Extra code for Readme.md ####

top_10_producers %>%
  select(-Production_mt, -Total_N_Input, -NUE) %>%
  pivot_longer(cols = c(N_Output, N_Losses), 
               names_to = "Variable", 
               values_to = "Value") %>%
  ggplot(aes(x = Country, fill = factor(Variable))) +
  geom_bar(aes(y = Value), stat = "identity", position = "dodge") +
  ylab("Nitrogen (Mt)") +
  ggtitle("N Output and N Losses for Top 10 Wheat Producers") +
  scale_fill_manual(values = c("N_Output" = "#1DACE8", "N_Losses" = "#F24D29")) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(fill = "")

ggsave("images/top_10_LO.png")


top_10_producers %>%
  select(-N_Output, -N_Losses, -Total_N_Input) %>%
  pivot_longer(cols = c(Production_mt, NUE), 
               names_to = "Variable", 
               values_to = "Value") %>%
  ggplot(aes(x = Country, fill = factor(Variable))) +
  geom_bar(aes(y = Value), stat = "identity", position = "dodge") +
  ylab("") +
  ggtitle("Production and NUE for Top 10 Wheat Producers") +
  scale_fill_manual(values = c("Production_mt" = "#EDCB64", "NUE" = "#456355")) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_blank()) +
  labs(fill = "") +
  facet_wrap(~Variable, scales = "free_y", ncol = 1)

ggsave("images/top_10_PN.png")
