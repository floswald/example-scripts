# install.packages("tidyverse")
# install.paackages("sf")
library(tidyverse)
library(sf)

### FILL THIS LINE BEFORE RUNNING
dir.sci_dat_gadm1_nuts3_counties <- ""

# Read in the detailed GADM SCI data (this dataset is quite large and 
# this line of code will likely take a minute or so)
sci_dat <- read_tsv(dir.sci_dat_gadm1_nuts3_counties)
sci_dat <- rename(sci_dat, sci=scaled_sci)

# Read in the detailed GADM shapes
shapes_in <- readRDS("../../gadm_based_shapefiles/rds_format/gadm1_nuts3_counties.Rds")

# Simplify the shapes to make it possible to generate maps
shapes_simple <- st_simplify(shapes_in, dTolerance = .015)

# Read in a map of all the land in the world to serve as background
# Download nto a temp directory, unzip and use
download.file(
  "https://thematicmapping.org/downloads/TM_WORLD_BORDERS-0.3.zip",
  "/tmp/countries.zip"
)
dir.create("/tmp/countries/", showWarnings = FALSE)
unzip("/tmp/countries.zip", exdir="/tmp/countries")
background_map <- st_read("/tmp/countries/TM_WORLD_BORDERS-0.3.shp") %>% 
  filter(!ISO3 %in% c("ATF", "ATA")) %>% 
  st_transform("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")

# Make a vector of regions to generate maps for
regions <- c("USA06075", # San Francisco County, USA
             "USA06029", # Kern County, USA
             "ZAF7", # Gauteng, South Africa
             "UKI42", # Tower Hamlets (London), UK
             "UKI72", # Brent (London), UK
             "IND20_357", # Mumbai City, India
             "FR101") # Paris, France

# Create measures to scale up from the overall 50th percentile location pair
x1 <- quantile(sci_dat$sci, .5)
x2 <- x1 * 2
x3 <- x1 * 3
x5 <- x1 * 5
x10 <- x1 * 10
x25 <- x1 * 25
x100 <- x1 * 100

# Create the graph for each of the regions in the list of regions
for(i in 1:length(regions)){
  
  # Get the data for the ith region
  dat <- filter(sci_dat, user_loc == regions[i])
  
  # Merge with shape files
  dat_map <- 
    right_join(dat,
               shapes_simple,
               by=c("fr_loc"="key")) %>% 
    st_as_sf
  
  # Create clean buckets for these levels
  dat_map <- dat_map %>% 
    mutate(sci_bkt = case_when(
      sci < x1 ~ "< 1x (Overall 50th percentile)",
      sci < x2 ~ "1-2x",
      sci < x3 ~ "2-3x",
      sci < x5 ~ "3-5x",
      sci < x10 ~ "5-10x",
      sci < x25 ~ "10-25x",
      sci < x100 ~ "25-100x",
      sci >= x100 ~ ">= 100x")) %>% 
    mutate(sci_bkt = factor(sci_bkt, levels=c("< 1x (Overall 50th percentile)", "1-2x", "2-3x", "3-5x",
                                              "5-10x", "10-25x", "25-100x", ">= 100x")))
  
  # Get the map of the region you are in
  curr_region_outline <- dat_map %>% 
    filter(fr_loc == regions[i])
  
  # Plot the data
  ggplot(st_transform(dat_map, "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) +
    geom_sf(data=background_map, fill="#F5F5F5", colour="#F5F5F5") +
    geom_sf(aes(fill = sci_bkt), colour="#ADADAD", lwd=0) +
    geom_sf(data=curr_region_outline, fill="#A00000", colour="#A00000", size=1) +
    labs(fill = "SCI") +
    theme_void() +
    scale_fill_brewer(palette = "GnBu", na.value="#F5F5F5", drop=FALSE) +
    theme(legend.title = element_blank(), 
          legend.text  = element_text(size = 8),
          legend.key.size = unit(0.8, "lines"),
          legend.position = "bottom", legend.box = "horizontal") +
    guides(fill = guide_legend(nrow = 1, title.hjust = 0.5))
  
  # Save output to the folder "output/gadm_output"
  ggsave(paste0("output/sci_", regions[i], ".jpg"),
         width = 6.5, height = 3.8, units = "in", dpi = 800, last_plot())
  
}

#############################################
# Analyses for the Indian subcontinent only #
#############################################

regions <- c("IND25_415", # Western Delhi
             "IND20_357", # Mumbai
             "BGD3_18") # Dhaka

ind_sci_dat <- sci_dat %>% 
  filter(substr(user_loc, 1, 3) %in% c("BGD", "IND", "NPL",
                                       "PAK", "LKA", "MDV")) %>% 
  filter(substr(fr_loc, 1, 3) %in% c("BGD", "IND", "NPL",
                                     "PAK", "LKA", "MDV"))

# The measures are scaled up from the 25th percentile in the Subcontinent
x1 <- quantile(ind_sci_dat$sci, .25)
x2 <- x1 * 2
x3 <- x1 * 3
x5 <- x1 * 5
x10 <- x1 * 10
x25 <- x1 * 25
x100 <- x1 * 100

for(i in 1:length(regions)){
  
  # Get the data for the ith region
  dat <- filter(ind_sci_dat, user_loc == regions[i])
  
  # Merge with shape files
  dat_map <- 
    inner_join(dat,
               shapes_simple,
               by=c("fr_loc"="key")) %>% 
    st_as_sf
  
  # Create clean buckets for these levels
  dat_map <- dat_map %>% 
    mutate(sci_bkt = case_when(
      sci < x1 ~ "< 1x (Ind. Subcont. 25th percentile)",
      sci < x2 ~ "1-2x",
      sci < x3 ~ "2-3x",
      sci < x5 ~ "3-5x",
      sci < x10 ~ "5-10x",
      sci < x25 ~ "10-25x",
      sci < x100 ~ "25-100x",
      sci >= x100 ~ ">= 100x")) %>% 
    mutate(sci_bkt = factor(sci_bkt, levels=c("< 1x (Ind. Subcont. 25th percentile)", "1-2x", "2-3x", "3-5x",
                                              "5-10x", "10-25x", "25-100x", ">= 100x")))
  
  # Get the map of the region you are in
  curr_region_outline <- dat_map %>% 
    filter(fr_loc == regions[i])
  
  # Plot the data
  ggplot(st_transform(dat_map, "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) +
    geom_sf(aes(fill = sci_bkt), colour="#DADADA", size=0.02) +
    # geom_sf(data=country_shapes, fill="transparent", colour="#444444") +
    geom_sf(data=curr_region_outline, fill="#A00000", colour="#A00000", size=0.5) +
    labs(fill = "SCI") +
    theme_void() +
    scale_fill_brewer(palette = "GnBu", na.value="#F5F5F5", drop=FALSE) +
    theme(legend.title = element_blank(), 
          legend.text  = element_text(size = 8),
          legend.key.size = unit(0.8, "lines"),
          legend.position = "bottom", legend.box = "horizontal") +
    guides(fill = guide_legend(nrow = 1, title.hjust = 0.5))
  
  ggsave(paste0("output/sci_indian_cont_", regions[i], ".jpg"),
         width = 6.5, height = 3.8, units = "in", dpi = 800, last_plot())
  
}