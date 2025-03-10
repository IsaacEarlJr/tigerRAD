# 12/2/24
# Changed pvol download route; refined subfolder processing preference options;
# Cleared code for local use. 
# Coleman, I.

# This script processes NEXRAD radar data to extract vertical profiles (vpts) and
# calculate Migration Traffic Rates (MTR) for avian studies. It utilizes the bioRad package
# and AWS CLI for data access. The workflow is structured into clearly defined steps:
#
#
# INDEX:
# ----------------------------------------
# 1. Load Packages
#    - Install and verify bioRad package
# 2. Set Directories
#    - Define working paths and set up folder structure
# 3. Connect to Data
#    - Access NOAA NEXRAD Level-II data using AWS CLI
# 4. Download Data
#    - Filter and save radar files locally
# 5. Process Data
#    - Convert polar volume (pvol) files into vertical profiles (vpts)
# 6. Vertical Profiles
#    - Create time-series plots of vpts
# 7. Calculate MTR
#    - Calculate Migration Traffic Rate (MTR) from vertical profiles
#
# Each section is demarcated for clarity and modularity, facilitating reuse and customization.
# Note: Ensure AWS CLI is installed and configured for data access.

# ----

##########################################
#           Step 1: Load Packages        #
##########################################

# Load the bioRad package
library(bioRad)

# Check the package version
packageVersion("bioRad")

# Optionally download and install the latest development version
library(devtools)
install_github("adokter/bioRad")

# Access help for the bioRad package
?bioRad

##########################################
#          End of Step 1                 #
##########################################





##########################################
#        Step 2: Set Directories         #
##########################################

# Set working directory (replace with your local path)
setwd("C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad")

# Test working directory
#getwd()

# Create subdirectories for future data storage
dir.create("./data_vpts")
dir.create("./data_pvol")

# Set the local time zone to UTC
Sys.setenv(TZ = "UTC")

##########################################
#          End of Step 2                 #
##########################################





##########################################
#        Step 3: Connect to Data         #
##########################################
#         Prep to Download Data          #
#            via AWS CLI                 #
#     AWS: Amazon Web Services           #
#     CLI: Command Line Interface        #
# *AWS must be installed on your machine #
##########################################


# Clear the AWS credentials from the environment
Sys.unsetenv("AWS_ACCESS_KEY_ID")
Sys.unsetenv("AWS_SECRET_ACCESS_KEY")

# Verify the bucket exists (noaa-nexrad-level2)
system("aws s3api head-bucket --bucket noaa-nexrad-level2 --no-sign-request")

# Fetch a List of Files available in the NOAA S3 Bucket
# Use the AWS CLI to list files from the specified radar station and date
# Bucket: noaa-nexrad-level2
# Radar Site: KHGX
# Date: 2024-05-01 (May 1)
system("aws s3 ls s3://noaa-nexrad-level2/2024/12/12/KDIX/ --no-sign-request --region us-east-1")

##########################################
#          End of Step 3                 #
##########################################



##########################################
#        Step 4: Download Data           #
##########################################


#FUNCTION#
#Function to download pvol data from AWS#
#created to insure a permanent connection with the pvol data;
#bioRad's download_pvolfiles function may be firewalled#



# Define the local base directory
# puts data into data_pvol folder.(sub folder created inside function MUST CHANGE SUBFOLDER FOR NEXT DATASET!!!!!!!!!!)
local_base_folder <- "C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad/data_pvol"

# Create the base directory if it doesn't exist
if (!dir.exists(local_base_folder)) {
  dir.create(local_base_folder, recursive = TRUE)
}

# Define the bucket path
bucket_path <- "s3://noaa-nexrad-level2/2024/12/12/KDIX/"

# List all files in the bucket
file_list <- system(
  sprintf("aws s3 ls %s --no-sign-request --region us-east-1", bucket_path),
  intern = TRUE
)

# Extract file names from the output
files <- sapply(file_list, function(line) {
  parts <- strsplit(line, " +")[[1]]
  parts[length(parts)] # File name is the last part of each line
})

# Define time range in GMT (09:00:00 to 18:00:00)
start_time <- as.numeric("000000")#GMT  # 4:00:00 AM EST
end_time <- as.numeric("235959")#GMT    # 2:00:00 PM EST

# Function to filter files by time range
filtered_files <- Filter(function(file) {
  # Extract the time portion (TTTTTT) from the filename
  time <- as.numeric(substr(file, 14, 19)) # Extract the 6-digit time
  return(time >= start_time & time <= end_time)
}, files)

# Define subfolder structure
subfolder <- "2024/12/12/KDIX"
local_folder <- file.path(local_base_folder, subfolder)

# Create the subfolder if it doesn't exist
if (!dir.exists(local_folder)) {
  dir.create(local_folder, recursive = TRUE)
}

# Loop to download each filtered file
for (file in filtered_files) {
  # Construct the AWS CLI command
  command <- sprintf(
    "aws s3 cp %s%s \"%s/%s\" --no-sign-request --region us-east-1",
    bucket_path, file, local_folder, file
  )
  
  # Execute the command
  system(command)
}

# Print the downloaded files
cat("Downloaded files:\n", paste(filtered_files, collapse = "\n"))

#   polar volumes are now downloaded to the local directory!!

##########################################
#          End of Step 4                 #
##########################################





###################################################################################

#Break


###################################################################################

# Now that you have polar volumes locally, you can run the code below to process 
# the data into vertical profiles (vpts) and migration traffic rate (MTR)

# Data source: KHGX radar site on May 1, 2024.
# Note: If you chose to download 24 hours of data, processing may take a while.
# Work is ongoing to expedite the process.


##########################################
#           Step 5: Process Data         #
##########################################
#         (Vertical profiles)            #
#           pvols to vpts                #
##########################################


# This step involves integrating:
# - Density
# - Reflectivity
# - Migration Traffic Rate (MTR)
# - Vertical averaging of ground speed and direction weighted by density
# (Based on methods described in Dokter et al.)

# Output:
# - vpts: Profiles over time and height
# - MTR: Migration Traffic Rate

##########################################
#         Begin Data Processing          #
##########################################

# Previous method:
# my_vplist <- read_vpfiles("C:/Users......")

# Updated method:
# Read and process polar volume (pvol) files, and save the resulting vertical profile (vpts)
# to a local directory with the updated "vpts" root structure.


# List all pvol files in the specified directory
my_files <- list.files(
  "C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad/data_pvol/2024/12/12/KDIX",
  full.names = TRUE,
  recursive = TRUE # Recursively include files in subdirectories
)

# Exclude files that end with '_MDM'
my_files <- my_files[!grepl("_MDM$", basename(my_files))]

# Print the filenames to verify
print(my_files)

# Define base directories for input and output
base_input_dir <- "C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad/data_pvol"
base_output_dir <- "C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad/data_vpts"

# Loop over the files and generate profiles
for (file_in in my_files) {
  # Get the relative path from the base input directory
  relative_path <- gsub(paste0("^", base_input_dir), "", dirname(file_in))
  
  # Construct the corresponding output directory
  output_subdir <- file.path(base_output_dir, relative_path)
  
  # Ensure the output directory exists
  if (!dir.exists(output_subdir)) {
    dir.create(output_subdir, recursive = TRUE)
  }
  
  # Define the output filename for each input file
  file_out <- file.path(output_subdir, paste0(basename(file_in), "_vp.h5"))
  
  # Use tryCatch to handle errors and continue with the next file
  tryCatch({
    # Generate the vertical profile using calculate_vp
    vp <- calculate_vp(file_in, file_out, autoconf = TRUE)
    #(Dokter et al. 2011 doi:10.1098/rsif.2010.0116 ).
    # Print status for each file processed
    cat("Processed:", file_in, "->", file_out, "\n")
  }, error = function(e) {
    # Print an error message and skip to the next file
    cat("Error processing file:", file_in, "\nError message:", e$message, "\n")
  })
}

# Completion message
cat("All files have been processed (with errors skipped) and saved to:", base_output_dir, "\n")

#------------------------------------------------------------#
# Specify the Subdirectory(ies)/Dates to Load Processed Files #
################################################################

# Define base output directory for processed files
base_output_dir <- "C:/Users/isaac/Documents/Grad School/CLASSES/SPRING_24/GIS 5083C/BioRad/data_vpts"

# Specify subdirectory or subdirectories to load processed files
# Uncomment and modify the example below as needed
# For a specific day:
subdirs <- "2024/12/12/KDIX"

# Specify subdirectories for the entire range of interest (April 23 to May 11, 2023)
#subdirs <- c("2023/04", "2023/05")
# For a specific month:
# subdirs <- "2024/05"
# For multiple subdirectories:
# subdirs <- c("2024/05", "2024/05/02/KHGX")

# Check if subdirs is defined; toggle behavior based on its value
if (is.null(subdirs)) {
  # Load all files recursively from the base directory
  my_vpfiles <- list.files(base_output_dir, full.names = TRUE, recursive = TRUE)
} else {
  # Load files only from the specified subdirectories
  my_vpfiles <- unlist(lapply(subdirs, function(subdir) {
    # Construct the full path for the subdirectory
    subdir_path <- file.path(base_output_dir, subdir)
    # Check if the subdirectory exists
    if (dir.exists(subdir_path)) {
      list.files(subdir_path, full.names = TRUE, recursive = TRUE)
    } else {
      warning(sprintf("Subdirectory '%s' does not exist and will be skipped.", subdir))
      NULL
    }
  }))
}

# Print the loaded files to verify
cat("Loaded files:\n", paste(my_vpfiles, collapse = "\n"))


 
# Print .h5 files to verify (and count)
my_vpfiles
##############################################################
#------------------------------------------------------------#

##########################################
#           End of Step 5                #
##########################################



##########################################
#        Step 6: Vertical Profiles       #
##########################################
#    Process Vertical Profile by Time    #
##########################################

# Read 'vpfiles' into a list 
# to make a time series of profiles
my_vplist <- read_vpfiles(my_vpfiles)

# Make a time series of combined profiles
my_vpts <- bind_into_vpts(my_vplist)#

# Plot them between 0 - 3 km altitude:
plot(my_vpts, ylim = c(0, 3000))



##########################################
#           Step 7: Calculate MTR        #
##########################################
#        Migration Traffic Rate (MTR)    #
##########################################


# Integrate profiles function to calculate MTR 
# from a list of vertical profiles over time
# (time window is specified/requested above)
my_vpi <- integrate_profile(my_vpts)
# # View the MTR data in new window
# View(my_vpi)
# # Save the MTR data to a CSV file
# write.csv(my_vpi, "my_vpi_full.csv", row.names = FALSE)

# Plot the MTR
plot(my_vpi, quantity = "mtr", main = "Migration Traffic Rate (MTR)")
## Plot the vertical average direction (dd)
#plot(my_vpi, quantity = "dd", main = "Vertical Average Direction (dd)")
## Plot the verticaly integrated density (vid)
#plot(my_vpi, quantity = "vid", main = "Vertical Integrated Density (vid)")
#testing code
#get_quantity(my_vpts)


View(my_vpi)




