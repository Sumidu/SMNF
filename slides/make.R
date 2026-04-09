# This file runs all test documents

start_at <- 1
#start_at <- 16

library(stringr)
# run test files
base_path <- here::here("slides")
files <- dir(path = base_path, pattern = "*.Rmd")

# remove the readme
files <- files[!files %in% c("README.Rmd", "header.Rmd")]

output <- str_replace(files, ".Rmd", ".html")
output <- paste0("output/", output)


for (i in start_at:length(files)) {
  message(paste0("Rendering document ", i, ": ", files[i]))
  rmarkdown::render(input = paste0(base_path, "/", files[i]))
}

