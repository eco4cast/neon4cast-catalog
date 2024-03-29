## MODEL level functions

generate_authors <- function(metadata_available, model_docs){
  if (metadata_available == TRUE){
    f_name_cols <- c('first.name.one','first.name.two','first.name.three','first.name.four','first.name.five','first.name.six','first.name.seven',
                     'first.name.eight','first.name.nine','first.name.ten')
    l_name_cols <- c('last.name.one','last.name.two','last.name.three','last.name.four','last.name.five','last.name.six','last.name.seven',
                     'last.name.eight','last.name.nine','last.name.ten')

    model_first_names <- unlist(model_docs[idx, names(model_docs) %in% f_name_cols], use.names = FALSE)[!is.na(model_docs[idx, names(model_docs) %in% f_name_cols])]
    model_last_names <- unlist(model_docs[idx, names(model_docs) %in% l_name_cols], use.names = FALSE)[!is.na(model_docs[idx, names(model_docs) %in% l_name_cols])]

    x <- purrr::map(seq.int(1:length(model_first_names)), function(i)
      list(
        "url" = 'not provided',
        'name'= paste(model_first_names[i], model_last_names[i]),
        'roles' = list("producer")
      )
    )
    ## SET FIRST AUTHOR INFO
    x[[1]]$url <- unlist(model_docs[idx,'email.one'], use.names = FALSE)
    x[[1]]$roles <- list(
      "producer",
      "processor",
      "licensor"
    )
  } else{
    x <- list(list('url' = 'pending',
                   'name' = 'pending',
                   'roles' = list("producer",
                                  "processor",
                                  "licensor"))
    )
  }
  return(x)
}



build_model <- function(model_id,
                        theme_id,
                        team_name,
                        model_description,
                        start_date,
                        end_date,
                        use_metadata,
                        var_values,
                        var_keys,
                        site_values,
                        model_documentation,
                        destination_path,
                        description_path,
                        aws_download_path,
                        theme_title,
                        collection_name,
                        thumbnail_image_name,
                        table_schema,
                        table_description) {


  preset_keywords <- list("Forecasting", "NEON")
  variables_reformat <- paste(var_values, collapse = ", ")
  site_reformat <- paste(site_values, collapse = ", ")

  aws_asset_link <- paste0("s3://anonymous@bio230014-bucket01/",
                           aws_download_path,
         "/model_id=", model_id,
         "?endpoint_override=sdsc.osn.xsede.org")

  aws_asset_description <- paste0("Use `arrow` for remote access to the database. This R code will return results for this model within the NEON Ecological Forecasting Aquatics theme.\n\n### R\n\n```{r}\n# Use code below\n\nall_results <- arrow::open_dataset(",aws_asset_link,")\ndf <- all_results |> dplyr::collect()\n\n```
       \n\nYou can use dplyr operations before calling `dplyr::collect()` to `summarise`, `select` columns, and/or `filter` rows prior to pulling the data into a local `data.frame`. Reducing the data that is pulled locally will speed up the data download speed and reduce your memory usage.\n\n\n")

  meta <- list(
    "stac_version"= "1.0.0",
    "stac_extensions"= list('https://stac-extensions.github.io/table/v1.2.0/schema.json'),
    "type"= "Feature",
    "id"= model_id,
    "bbox"=
      list(-156.6194, 17.9696, -66.7987,  71.2824),
    "geometry"= list(
      "type"= "MultiPoint",
      "coordinates"= get_site_coords(theme_id, bucket = NULL, model_id)[[1]]
    ),
    "properties"= list(
      #'description' = model_description,
      "description" = glue::glue('

    model info: {model_description}

    Sites: {site_reformat}

    Variables: {variables_reformat}
'),
      "start_datetime" = start_date,
      "end_datetime" = end_date,
      "providers"= c(generate_authors(metadata_available = use_metadata, model_docs = model_documentation),list(
        list(
          "url"= "https://ecoforecast.org",
          "name"= "Ecoforecast Challenge",
          "roles"= list(
            "host"
          )
        )
      )
      ),
      "license"= "CC0-1.0",
      "keywords"= c(preset_keywords, var_keys),
      "table:columns" = stac4cast::build_table_columns(table_schema, table_description)
    ),
    "collection"= collection_name,
    "links"= list(
      list(
        "rel"= "collection",
        'href' = '../collection.json',
        "type"= "application/json",
        "title"= theme_title
      ),
      list(
        "rel"= "root",
        'href' = '../../../catalog.json',
        "type"= "application/json",
        "title"= "EFI Forecast Catalog"
      ),
      list(
        "rel"= "parent",
        'href' = '../collection.json',
        "type"= "application/json",
        "title"= theme_title
      ),
      list(
        "rel"= "self",
        "href" = paste0(model_id,'.json'),
        "type"= "application/json",
        "title"= "Model Forecast"
      )),
    "assets"= c(list(
        "1"= list(
        "href"= aws_asset_link,
        "type"= "application/x-parquet",
        "title"= 'Database Access',
        "description"= aws_asset_description
      )
      ),
      pull_images(theme_id,model_id,thumbnail_image_name)
    )
  )


  dest <- destination_path
  json <- file.path(dest, paste0(model_id, ".json"))

  jsonlite::write_json(meta,
                       json,
                       pretty=TRUE,
                       auto_unbox=TRUE)
  stac4cast::stac_validate(json)

  rm(meta)
}

get_grouping <- function(s3_inv,
                         theme,
                         collapse=TRUE,
                         endpoint="data.ecoforecast.org") {

  groups <- arrow::open_dataset(s3_inv$path("neon4cast-forecasts")) |>
    dplyr::filter(...1 == "parquet", ...2 == {theme}) |>
    dplyr::select(model_id = ...3, reference_datetime = ...4, date = ...5) |>
    dplyr::mutate(model_id = gsub("model_id=", "", model_id),
                  reference_datetime =
                    gsub("reference_datetime=", "", reference_datetime),
                  date = gsub("date=", "", date)) |>
    dplyr::collect()

}


generate_vars_sites <- function(m_id, theme){

  # if (m_id %in%  c('GLEON_JRabaey_temp_physics','GLEON_lm_lag_1day','GLEON_physics','USGSHABs1','air2waterSat_2','fARIMA')){
  #   output_info <- c('pending','pending')
  # } else{

  # do this for each theme / model
  info_df <- arrow::open_dataset(info_extract$path(glue::glue("{theme}/model_id={m_id}/"))) |>
    #filter(reference_datetime == "2023-06-18")|> #just grab one EM to limit processing
    collect()

  if ('siteID' %in% names(info_df)){
    info_df <- info_df |>
      rename(site_id = siteID)
  }

  vars_vector <- sort(unique(info_df$variable))
  sites_vector <- sort(unique(info_df$site_id))

  vars_list <- as.list(sort(unique(info_df$variable)))
  sites_list <- as.list(sort(unique(info_df$site_id)))

  # output_vectors <- c(paste(vars_vector, collapse = ', '),
  #                  paste(sites_vector, collapse = ', '))

  output_list <- list(vars_list,sites_list)

  full_object <- list(vars_vector, sites_vector, output_list)

  return(full_object)
}


## FORECAST LEVEL FUNCTIONS
generate_model_items <- function(){


  model_list <- theme_models$model.id

  x <- purrr::map(model_list, function(i)
    list(
      "rel" = 'item',
      'type'= 'application/json',
      'href' = paste0('models/',i,'.json'))
  )

  return(x)
}

pull_images <- function(theme, m_id, image_name){

  info_df <- arrow::open_dataset(info_extract$path(glue::glue("{theme}/model_id={m_id}/"))) |>
    collect()

  sites_vector <- sort(unique(info_df$site_id))

  base_path <- 'https://data.ecoforecast.org/neon4cast-catalog'

  image_assets <- purrr::map(sites_vector, function(i)
    #url_validator <- Rcurl::url.exists(file.path(base_path,theme,m_id,i,image_name))
    list(
      "href"= file.path(base_path,theme,m_id,i,image_name),
      "type"= "image/png",
      "title"= paste0('Latest Results for ', i),
      "description"= 'Image from s3 storage',
      "roles" = list('thumbnail')
    )
  )

  ## check if image rendered successfully on bucket. If not remove from assets
  item_remove <- c()

  if (image_name == 'latest_scores.png'){
    for (item in seq.int(1:length(image_assets))){
      url_validator = RCurl::url.exists(image_assets[[item]]$href)
      if(url_validator == FALSE){
        print(paste0('Removing ', image_assets[[item]]$title))
        item_remove <- append(item_remove,item)
        #image_assets <- image_assets[-item]
      }
    }
    if (length(item_remove) > 0){
      image_assets <- image_assets[-item_remove]
    }
  }

  return(image_assets)

}

get_site_coords <- function(theme, bucket, m_id){

  theme_select <- glue::glue('{theme}')

  theme_sites <- read_csv("https://raw.githubusercontent.com/eco4cast/neon4cast-targets/main/NEON_Field_Site_Metadata_20220412.csv", col_types = cols()) |>
    dplyr::filter(UQ(sym(theme_select)) == 1)

  if (is.null(m_id)){

    if (bucket == 'Forecasts'){
      bucket_sites <- read_csv(glue::glue('stac/{theme}/forecasts/all_forecast_sites.csv'))
    } else if (bucket == 'Scores'){
      bucket_sites <- read_csv(glue::glue('stac/{theme}/scores/all_scores_sites.csv'))
    } else {
      stop("Bucket name error. Must be 'Forecasts' or 'Scores'")
    }

    site_coords <- theme_sites |>
      filter(field_site_id %in% bucket_sites$site_id) |>
      distinct(field_site_id, field_longitude, field_latitude)

    #site_coords$site_lat_lon <- lapply(1:nrow(site_coords), function(i) c(site_coords$field_longitude[i], site_coords$field_latitude[i]))

    bbox_object <- c(min(site_coords$field_longitude), min(site_coords$field_latitude), max(site_coords$field_longitude), max(site_coords$field_latitude))

    return(bbox_object)

  }else{
    if (theme == 'ticks'){
      model_sites <- arrow::open_dataset(info_extract$path(glue::glue("{theme}/model_id={m_id}/"))) |>
      collect()
      if('siteID' %in% names(model_sites)){
        model_sites <- model_sites |>
          rename(site_id = siteID) |>
          distinct(site_id)
      }else{
        model_sites <- model_sites |>
          distinct(site_id)
      }
    }else{
      model_sites <- arrow::open_dataset(info_extract$path(glue::glue("{theme}/model_id={m_id}/"))) |>
        collect() |>
        distinct(site_id)
    }

    site_coords <- theme_sites |>
      filter(field_site_id %in% model_sites$site_id) |>
      distinct(field_site_id, field_longitude, field_latitude)

    site_coords$site_lat_lon <- lapply(1:nrow(site_coords), function(i) c(site_coords$field_longitude[i], site_coords$field_latitude[i]))

    return(list(site_coords$site_lat_lon, model_sites$site_id))
  }

}

build_forecast_scores <- function(table_schema,
                                  theme_id,
                           table_description,
                           start_date,
                           end_date,
                           id_value,
                           description_string,
                           about_string,
                           about_title,
                           theme_title,
                           model_documentation,
                           destination_path,
                           aws_download_path,
                           model_metadata_path
){

  aws_asset_link <- paste0("s3://anonymous@bio230014-bucket01/",
                           aws_download_path,
                           "?endpoint_override=sdsc.osn.xsede.org")

  aws_asset_description <-   aws_asset_description <- paste0("Use `arrow` for remote access to the database. This R code will return results for the NEON Ecological Forecasting Aquatics theme.\n\n### R\n\n```{r}\n# Use code below\n\nall_results <- arrow::open_dataset(",aws_asset_link,")\ndf <- all_results |> dplyr::collect()\n\n```
       \n\nYou can use dplyr operations before calling `dplyr::collect()` to `summarise`, `select` columns, and/or `filter` rows prior to pulling the data into a local `data.frame`. Reducing the data that is pulled locally will speed up the data download speed and reduce your memory usage.\n\n\n")
  forecast_score <- list(
    "id" = id_value,
    "description" = description_string,
    "stac_version"= "1.0.0",
    "license"= "CC0-1.0",
    "stac_extensions"= list("https://stac-extensions.github.io/scientific/v1.0.0/schema.json",
                            "https://stac-extensions.github.io/item-assets/v1.0.0/schema.json",
                            "https://stac-extensions.github.io/table/v1.2.0/schema.json"),
    'type' = 'Collection',
    'links' = c(generate_model_items(),
                list(
                  list(
                    "rel" = "parent",
                    "type"= "application/json",
                    "href" = '../collection.json'
                  ),
                  list(
                    "rel" = "root",
                    "type" = "application/json",
                    "href" = '../collection.json'
                  ),
                  list(
                    "rel" = "self",
                    "type" = "application/json",
                    "href" = 'collection.json'
                  ),
                  list(
                    "rel" = "cite-as",
                    "href" = "https://doi.org/10.1002/fee.2616"
                  ),
                  list(
                    "rel" = "about",
                    "href" = about_string,
                    "type" = "text/html",
                    "title" = about_title
                  ),
                  list(
                    "rel" = "describedby",
                    "href" = "https://projects.ecoforecast.org/neon4cast-dashboard/",
                    "title" = "NEON Ecological Forecast Challenge Dashboard",
                    "type" = "text/html"
                  )
                )),
    "title" = theme_title,
    "extent" = list(
      "spatial" = list(
        'bbox' = list(get_site_coords(theme_id, theme_title, m_id = NULL))),
      "temporal" = list(
        'interval' = list(list(
          paste0(start_date,"T00:00:00Z"),
          paste0(end_date,"T00:00:00Z"))
        ))
    ),
    "table:columns" = stac4cast::build_table_columns(table_schema, table_description),
    'assets' = list(
      # 'data' = list(
      #   "href"= model_documentation,
      #   "type"= "text/csv",
      #   "roles" = list('data'),
      #   "title"= "NEON Field Site Metadata",
      #   "description"= readr::read_file(model_metadata_path)
      # ),
      'data' = list(
        "href" = aws_asset_link,
        "type"= "application/x-parquet",
        "title"= 'Database Access',
        "roles" = list('data'),
        "description"= aws_asset_description
      )
    )
  )


  dest <- destination_path
  json <- file.path(dest, "collection.json")

  jsonlite::write_json(forecast_score,
                       json,
                       pretty=TRUE,
                       auto_unbox=TRUE)
  stac4cast::stac_validate(json)
}


build_theme <- function(start_date,end_date, id_value, theme_description, theme_title, destination_path, thumbnail_link, thumbnail_title){

  theme <- list(
    "id" = id_value,
    "type" = "Collection",
    "links" = list(
      list(
        "rel" = "child",
        "type" = "application/json",
        "href" = 'forecasts/collection.json',
        "title" = 'forecast item'
      ),
      list(
        "rel" = "child",
        "type" = "application/json",
        "href" = 'scores/collection.json',
        "title" = 'scores item'
      ),
      list(
        "rel"= "parent",
        "type"= "application/json",
        "href"= "../catalog.json",
        "title" = 'parent'
      ),
      list(
        "rel"= "root",
        "type"= "application/json",
        "href"= "../catalog.json",
        "title" = 'root'
      ),
      list(
        "rel"= "self",
        "type"= "application/json",
        "href" = 'collection.json',
        "title" = 'self'
      ),
      list(
        "rel" ="cite-as",
        "href"= "https://doi.org/10.1002/fee.2616",
        "title" = "citation"
      ),
      list(
        "rel"= "about",
        "href"= "https://projects.ecoforecast.org/neon4cast-docs/",
        "type"= "text/html",
        "title"= "NEON Forecast Challenge Documentation"
      ),
      list(
        "rel"= "describedby",
        "href"= "https://projects.ecoforecast.org/neon4cast-dashboard/",
        "title"= "NEON Forecast Challenge Dashboard",
        "type"= "text/html"
      )
    ),
    "title"= theme_title,
    'assets' = list(
      'thumbnail' = list(
        "href"= thumbnail_link,
        "type"= "image/JPEG",
        "roles" = list('thumbnail'),
        "title"= thumbnail_title
      )
    ),
    "extent" = list(
      "spatial" = list(
        'bbox' = list(list(-149.6106,
                           18.1135,
                           -66.7987,
                           68.6698))
      ),
      "temporal" = list(
        'interval' = list(list(
          paste0(start_date,'T00:00:00Z'),
          paste0(end_date,'T00:00:00Z'))
        ))
    ),
    "license" = "CC0-1.0",
    "keywords" = list(
      "Forecasting",
      "Data",
      "Ecology"
    ),
    "providers" = list(
      list(
        "url"= "https://data.ecoforecast.org",
        "name"= "Ecoforecast Data",
        "roles" = list(
          "producer",
          "processor",
          "licensor"
        )
      ),
      list(
        "url"= "https://ecoforecast.org",
        "name"= "Ecoforecast",
        "roles" = list('host')
      )
    ),
    "description" = theme_description,
    "stac_version" = "1.0.0",
    "stac_extensions" = list(
      "https://stac-extensions.github.io/scientific/v1.0.0/schema.json",
      "https://stac-extensions.github.io/item-assets/v1.0.0/schema.json",
      "https://stac-extensions.github.io/table/v1.2.0/schema.json"
    ),
    "publications" = list(
      "doi" = "https://doi.org/10.1002/fee.2616",
      "citation"= "Thomas, R.Q., C. Boettiger, C.C. Carey, M.C. Dietze, L.R. Johnson, M.A. Kenney, J.S. Mclachlan, J.A. Peters, E.R. Sokol, J.F. Weltzin, A. Willson, W.M. Woelmer, and Challenge Contributors. 2023. The NEON Ecological Forecasting Challenge. Frontiers in Ecology and Environment 21: 112-113."
    )
  )


  dest <- destination_path
  json <- file.path(dest, "collection.json")

  jsonlite::write_json(theme,
                       json,
                       pretty=TRUE,
                       auto_unbox=TRUE)
  stac4cast::stac_validate(json)
}


build_site_item <- function(theme_id,
                        start_date,
                        end_date,
                        destination_path,
                        theme_title,
                        collection_name,
                        thumbnail_link,
                        site_coords) {


  preset_keywords <- list("Forecasting", "NEON")

  meta <- list(
    "stac_version"= "1.0.0",
    "stac_extensions"= list('https://stac-extensions.github.io/table/v1.2.0/schema.json'),
    "type"= "Feature",
    "id"= collection_name,
    "bbox"=
      list(-156.6194, 17.9696, -66.7987,  71.2824),
    "geometry"= list(
      "type"= "MultiPoint",
      "coordinates"= site_coords
    ),
    "properties"= list(
      #'description' = model_description,
      "description" = 'NEON Site Information',
      "start_datetime" = start_date,
      "end_datetime" = end_date,
      "providers"= list(
        list(
          "url"= "https://ecoforecast.org",
          "name"= "Ecoforecast Challenge",
          "roles"= list(
            "host"
          )
        )
      ),
      "license"= "CC0-1.0",
      "keywords"= c(preset_keywords),
      "table:columns" = build_site_metadata()
    ),
    "collection"= collection_name,
    "links"= list(
      list(
        "rel"= "catalog",
        'href' = '../catalog.json',
        "type"= "application/json",
        "title"= theme_title
      ),
      list(
        "rel"= "root",
        'href' = '../catalog.json',
        "type"= "application/json",
        "title"= "EFI Forecast Catalog"
      ),
      list(
        "rel"= "parent",
        'href' = '../catalog.json',
        "type"= "application/json",
        "title"= theme_title
      ),
      list(
        "rel"= "self",
        "href" = 'collection.json',
        "type"= "application/json",
        "title"= "Raw JSON Text"
      ),
      list(
        "rel" ="cite-as",
        "href"= "https://doi.org/10.1002/fee.2616",
        "title" = "citation"
      ),
      list(
        "rel"= "about",
        "href"= "https://projects.ecoforecast.org/neon4cast-docs/",
        "type"= "text/html",
        "title"= "NEON Forecast Challenge Documentation"
      ),
      list(
        "rel"= "describedby",
        "href"= "https://www.neonscience.org/field-sites/explore-field-sites",
        "title"= "Explore the NEON Field Sites",
        "type"= "text/html"
      )),
    "assets"= list(
      'data' = list(
        "href" = "https://raw.githubusercontent.com/eco4cast/neon4cast-targets/main/NEON_Field_Site_Metadata_20220412.csv",
        "type"= "text/plain",
        "title"= 'NEON Sites Table',
        "roles" = list('data'),
        "description"= 'Table that includes information for all NEON sites'
      ),
      "thumbnail" = list(
        "href"= thumbnail_link,
        "type"= "image/png",
        "title"= 'NEON Sites Image',
        "description"= 'Image describing the NEON sites',
        "roles" = list('thumbnail')
      )
    )
  )


  dest <- destination_path
  json <- file.path(dest, "collection.json")

  jsonlite::write_json(meta,
                       json,
                       pretty=TRUE,
                       auto_unbox=TRUE)
  stac4cast::stac_validate(json)

  rm(meta)
}


build_site_metadata <- function(){
  site_test <- read_csv("https://raw.githubusercontent.com/eco4cast/neon4cast-targets/main/NEON_Field_Site_Metadata_20220412.csv", col_types = cols())

  schema_info <- sapply(site_test, class)

  description_create <- data.frame(field_domain_id = 'domain identifier',
                                   field_site_id = 'site identifier',
                                   field_site_name = 'site name',
                                   terrestrial = 'terrestrial theme indicator for site',
                                   aquatics = 'aquatics theme indicator for site',
                                   phenology = 'phenology theme indicator for site',
                                   ticks = 'ticks theme indicator for site',
                                   beetles = 'beetles theme indicator for site',
                                   phenocam_code = 'code for phenocam',
                                   phenocam_roi = 'phenocam region of interest',
                                   phenocam_vegetation = 'phenocam vegetation identifier',
                                   field_site_type = 'site theme type',
                                   field_site_subtype = 'site theme subtype',
                                   field_colocated_site = 'colocated field site',
                                   field_site_host = 'site host organization',
                                   field_site_url = 'site host organization URL',
                                   field_nonneon_research_allowed = 'indicate whether non-NEON research is allowed at this site',
                                   field_access_details = 'details for accessing the field site',
                                   field_neon_field_operations_office = 'NEON field operations office',
                                   field_latitude = 'field site latitude',
                                   field_longitude = 'field site longitude',
                                   field_geodetic_datum = 'geodetic datum for the field site',
                                   field_utm_northing = 'northing UTM coordinates',
                                   field_utm_easting = 'easting UTM coordinates',
                                   field_utm_zone = 'UTM zone for field site',
                                   field_site_county = 'county where field site is located',
                                   field_site_state = 'state where field site is located',
                                   field_site_country = 'country where field site is located',
                                   field_mean_elevation_m = 'mean elevation of field site in meters',
                                   field_minimum_elevation_m = 'minimum elevation of field site in meters',
                                   field_maximum_elevation_m = 'maximum elevation of field site in meters',
                                   field_mean_annual_temperature_C = 'mean annual temperaure of field site in degC',
                                   field_mean_annual_precipitation_mm= 'mean annual precipitation of field site in mm',
                                   field_dominant_wind_direction = 'the dominant wind direction at the field site',
                                   field_mean_canopy_height_m = 'mean canpoy height at the field site in meters',
                                   field_dominant_nlcd_classes = 'National Land Cover Database Class for field site',
                                   field_dominant_plant_species = 'dominant plant species at field site',
                                   field_usgs_huc = 'USGS Hydrologic Unit Code for the field site',
                                   field_watershed_name = 'watershed name for the field site',
                                   field_watershed_size_km2 = 'watershed size of field site in square kilometers',
                                   field_lake_depth_mean_m = 'mean lake depth of field site in meters',
                                   field_lake_depth_max_m = 'max lake depth of field site in meters',
                                   field_tower_height_m = 'height of tower at field site in meters',
                                   field_usgs_geology_unit = 'USGS geology unit for field site',
                                   field_megapit_soil_family = 'megapit soil family for field site',
                                   field_soil_subgroup = 'soild subgroup of field site',
                                   field_avg_number_of_green_days = 'average number of green days at field site',
                                   field_avg_green_increase_doy = 'day of year for average green increase at field site',
                                   field_avg_green_max_doy = 'average day of year with maximum green at field site',
                                   field_avg_green_decrease_doy = 'avergae day of year of green decrease at field site',
                                   field_avg_green_min_doy = 'average day of year with minimum green at field site',
                                   field_phenocams = 'details about phenocams located at each field site',
                                   field_number_tower_levels = 'number of tower levels at field site',
                                   neon_url = 'NEON URL for field site')





  x <- purrr::map(seq.int(1:ncol(site_test)), function(i)
    list(
      "name" = names(site_test)[i],
      'description'= description_create[,i],
      'type' = schema_info[[i]]
    )
  )

  return(x)
}
