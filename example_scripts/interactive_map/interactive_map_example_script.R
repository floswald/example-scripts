# install.packages("tidyverse")
# install.paackages("sf")
# install.packages("leaflet")
# install.paackages("htmlwidgets")
library(tidyverse)
library(sf)
library(leaflet)
library(htmlwidgets)

### FILL THIS LINE BEFORE RUNNING
dir.sci_dat_gadm1_nuts3_counties <- ""

# Read in the detailed GADM SCI data (this dataset is quite large and 
# this line of code will likely take a minute or so)
sci_dat <- read_tsv(dir.sci_dat_gadm1_nuts3_counties)
sci_dat <- rename(sci_dat, sci=scaled_sci)

# Read in the detailed GADM shapes
shapes_in <- readRDS("../../gadm_based_shapefiles/rds_format/gadm1_nuts3_counties.Rds")

# Simplify the shapes to make it possible to generate maps
# This will make the shapes look weird sometimes when we zoom very far in
# but is necessary to get this front-end only html file to render reasonably.
shapes_simple <- st_simplify(shapes_in, dTolerance = .015)

regions <- c("USA06075", # San Francisco County, CA, USA
             "USA06029", # Kern County, CA, USA
             "USA26125") # Oakland County, MI, USA

# Create measures to scale up from the overall 50th percentile location pair
x1 <- quantile(sci_dat$sci, .5)
x2 <- x1 * 2
x3 <- x1 * 3
x5 <- x1 * 5
x10 <- x1 * 10
x25 <- x1 * 25
x100 <- x1 * 100

for(i in 1:length(regions)){
  # Get the data for the ith region
  dat <- filter(sci_dat, user_loc == regions[i])
  
  # Merge with shape files
  dat_map <- 
    inner_join(dat,
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
    
  # Create labels for mouse over
  labels <- sprintf(
    "<strong>Key: </strong>%s<br/>
      <strong>Name: </strong>%s<br/>
      <strong>Country: </strong>%s<br/>
      <strong>SCI: </strong>%s<br/>",
    dat_map$fr_loc,
    dat_map$name,
    dat_map$country,
    dat_map$sci_bkt) %>%
    lapply(htmltools::HTML)
  
  # We do this again so that there is a label on the home district as well
  labels2 <- sprintf(
    "<strong>Key: </strong>%s<br/>
      <strong>Name: </strong>%s<br/>
      <strong>Country: </strong>%s<br/>",
    curr_region_outline$fr_loc,
    curr_region_outline$name,
    curr_region_outline$country) %>%
    lapply(htmltools::HTML)
  
  pal <- colorFactor(palette="GnBu", domain=dat_map$sci_bkt)
  
  m <- leaflet() %>%
    addProviderTiles(
      "Esri.WorldStreetMap",
      options = leafletOptions()
    ) %>%
    addPolygons(
      data=dat_map,
      weight=2,
      fillOpacity=0.9,
      color= ~pal(sci_bkt),
      fillColor = ~pal(sci_bkt),
      group = "shapes1",
      label = labels,
      highlight = highlightOptions(
        weight = 4,
        color = "black"
      )
    ) %>%
    addPolygons(
      data=curr_region_outline,
      fillColor="Red",
      fillOpacity = 1,
      label = labels2,
      color = "Red",
      weight = 0.6
    )
  
  # htmlWidgets will often fail if not saving to current wd.
  # We reset it here then move it back.
  setwd("output")
  saveWidget(m, paste0(regions[i], "_interactive.html"))
  setwd("..")
}
