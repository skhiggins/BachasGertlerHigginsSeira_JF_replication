# Replication instructions for "How Debit Cards Enable the Poor to Save More"

_Pierre Bachas, Paul Gertler, Sean Higgins, Enrique Seira_

## Introduction
This document explains how to replicate the results in Bachas, Pierre, Paul Gertler, Sean Higgins, and Enrique Seira, "How Debit Cards Enable the Poor to Save More," _Journal of Finance_.

The paper's main data sources are confidential, and thus replicating most results in the paper requires obtaining access to these confidential data.

## Data 

The data sets used by this replication package are either confidential or publicly available. For confidential data sets, contact information to request access is provided below. For publicly available data sets, information to download the data are provided below. All raw data included in the analysis falls into one of the folders included below, and a comprehensive list of all of the raw and processed data sets and the files that use them as inputs and outputs can be found in `scripts/00_run.do`.

The `data/` folder contains the following subfolders; the subsections below describe the source for the data that go into each subfolder.

  - `Bansefi`
  - `BDU`
  - `CNBV`
  - `comparison`
  - `CONEVAL`
  - `CPI`
  - `DENUE`
  - `ENCASDU`
  - `ENCELURB`
  - `ENOE`
  - `INE`
  - `INEGI`
  - `ITER`
  - `MCC`
  - `Medios_de_Pago`
  - `Prospera`
  - `SEPOMEX`
  - `shapefiles`

### Bansefi administrative data
Administrative data from Bansefi in the `data/Bansefi/` folder are confidential. The contact person to request access is Ana Lilia Urquieta, alurquieta@bansefi.gob.mx. 

### BDU administrative data from Banco de México
Administrative data from Banco de México in the `data/BDU/` folder are confidential. These data were accessed on-site on a Banco de México server, and hence the corresponding scripts can only be run on Banco de México's server. The contact person to request access is Othón Moreno, omoreno@banxico.org.mx.
  
### CNBV administrative data
Administrative data from CNBV in the `data/CNBV/` folder are publicly available from http://portafolioinfo.cnbv.gob.mx/PortafolioInformacion/. The contact person to obtain further information about these publicly available data sets is Diana Radilla, dradilla@cnbv.gob.mx.

### Comparison to other studies
We use microdata from the replication files from other studies to compare the effect size in our study to those of other studies. Specifically, we use the following replication data sets from the following studies:
  - `data/comparison/Drexler_et_al_2014_AEJApplied/kisDataFinal.dta` is from the replication package for Drexler, Fisher, and Schoar (2014) available here: https://www.openicpsr.org/openicpsr/project/113888/version/V1/view.
  - `data/comparison/Dupas_Robinson_2013_AER/HARP_ROSCA_final.dta` is from the replication package for Dupas and Robinson (2013) available here: https://www.openicpsr.org/openicpsr/project/116115/version/V1/view.
  - `data/comparison/Karlan_etal_2016_MgmtSci/analysis_dataallcountries.dta` is from the replication package for Karlan, McConnell, Mullainathan, Zinman (2016) available here: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/UJD5OP. (Note: download `analysis_dataallcountries.tab` and select "Original File Format (Stata 14 Binary)").
  - `data/comparison/Karlan_Zinman_2017/proc/dreamfinal_for_analysis.dta` is a file created by running the replication package for Karlan and Zinman (2018) available here: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/STTNUF.
  - `data/comparison/Prina_2015_JDE/Nepal_JDE_R1.dta` is from the replication package for Prina (2015) available here:
  https://ars.els-cdn.com/content/image/1-s2.0-S0304387815000061-mmc1.zip (or click the "Download zip file" link at the article page https://www.sciencedirect.com/science/article/pii/S0304387815000061#s0075).
  
For other studies included in our comparison, we used the point estimates and standard errors from the paper; see `scripts/96_comparison_figure.do` for more detail.

The file `data/comparison/savings_rates_metadata.xlsx` was created by the authors and includes metadata about the studies included in our comparison folder. It is included with the replication data.

### CONEVAL locality-level data
Locality-level data from CONEVAL, `data/CONEVAL/rezago_social_localidad.dta`, are publicly available from https://www.coneval.org.mx/rw/resource/Rezago_social_-_localidad_-_stata.rar. Inside the .rar file downloaded from that link is a file `Rezago social - localidad - stata.dta` which should be renamed `rezago_social_localidad.dta` and placed inside the `data/CONEVAL/` folder to run the relevant replication scripts.

### CPI (consumer price index)
Microdata on Mexico's consumer price index in the `data/CPI/` folder are confidential. The contact person to request access is Natalia Volkow, natalia.volkow@inegi.org.mx.

### DENUE administrative data
Administrative data from INEGI's DENUE in the `data/DENUE/` folder, used to create a locality to postal code mapping, are publicly available from https://www.inegi.org.mx/app/descarga/. The contact to obtain further information about these publicly available data sets is atencion.usuarios@inegi.org.mx.

### ENCASDU survey data
Survey data from ENCASDU in the `data/ENCASDU` is confidential. The contact person to request access is Rogelio Grados, rogelio.grados@prospera.gob.mx. 

### ENCELURB survey data
Survey data from ENCELURB in the `data/ENCELURB/` folder is confidential. The contact person to request access is Rogelio Grados, rogelio.grados@prospera.gob.mx. 

### ENOE survey data
The ENOE is used as an auxiliary data set; the raw ENOE data are available from https://www.inegi.org.mx/programas/enoe/15ymas/default.html#Microdatos. The version of the data used in the replication files is a cleaned version of the data provided to the authors by Laura Chioda, lchioda@berkeley.edu.

### INE electoral data
Local elections data were prepared by a research assistant of Enrique Seira's based on confidential data from INE. The contact person to request access is Enrique Seira, enrique.seira@itam.mx.

### INEGI auxiliary administrative data
Auxiliary administrative data from INEGI in the `data/INEGI/` folder are publicly available from https://www.inegi.org.mx/app/ageeml/#.

### ITER locality-level data
Auxiliary survey data from INEGI's ITER, based on the Population Census, in the `data/ITER/` folder are confidential. The contact person to request access is Natalia Volkow, natalia.volkow@inegi.org.mx.

### Merchant category codes
Auxiliary data on merchant category codes in `data/MCC/mcc_codes.csv` are publicly available from https://github.com/greggles/mcc-codes.

### Medios de Pago (Payment Methods Survey)
Survey data from the Medios de Pago survey in `data/Medios_de_Pago/medios_pago_titular_beneficiarios.dta` are publicly available from https://evaluacion.prospera.gob.mx/es/eval_cuant/p_bases_cuanti.php. The contact person to obtain further information about these publicly available data is Rogelio Grados, rogelio.grados@prospera.gob.mx.

### Prospera administrative data
Administrative data from Oportunidades (now Prospera) in the `data/Prospera/` folder is confidential. The contact person to request access is Rogelio Grados, rogelio.grados@prospera.gob.mx.

### SEPOMEX 
Auxiliary administrative data from SEPOMEX, Mexico's postal service, in `data/SEPOMEX/CPdescarga.txt` are publicly available from https://www.correosdemexico.gob.mx/SSLServicios/ConsultaCP/CodigoPostal_Exportar.aspx. Select TXT to obtain the data in the same format as used in the replication files.

### Shapefiles

#### Bansefi geocoordinates
Data on the geocoordinates of Bansefi branches in the `data/shapefiles/bansefi_geocoordinates/` folder, compiled by Oportunidades (now Prospera), are confidential. The contact person to request access is José Solis, jose.solis@prospera.gob.mx.

#### INEGI shapefiles
Shapefiles from INEGI in the `data/shapefiles/INEGI/` folder are publicly available; we use the version that has been compiled by Diego Valle Jones. To download them, go to https://blog.diegovalle.net/2013/06/shapefiles-of-mexico-agebs-manzanas-etc.html and enter your email to receive the files in your email (note: check your spam folder for the email). Once you receive the email, you must click a link to confirm that you want to receive the shapefiles. In the subsequent email you receive, click the link to download "2010 Census AGEBs, Manzanas, Municipios, States, etc". The file you download after clicking this link should be called `agebsymas.zip` and should have a subfolder called `scince_2010/shps/`. Within this folder are subfolders corresponding to each state in Mexico, `ags`, `bc`, etc. Place the folders corresponding to each state in Mexico directly inside the folder `data/shapefiles/INEGI/` to run the relevant parts of the replication package.

## Computational requirements
Most of the code was run on a server node with 28 CPU cores and 1.5 TB of RAM.

### Software requirements
The following software programs and packages are required.

#### Stata 15.1
Earlier versions of Stata (13 or newer) should work as well but have not been tested. 
The Stata code was run using 4-core Stata-MP 15.1.
All user-written .ado files required for replication are included in the `adofiles/` folder, so they do not need to be separately installed to run the replication package. They include:
- .ado files we've written
  - `time`
  - `graph_options` 
  - `bimestrify` 
  - `uniquevals` 
  - `mydi` 
  - `exampleobs`
  - `stringify`
  - `spanishaccents`
  - `winsify`, including modified code from `winsor` by Nicholas J. Cox
  - `lower`
  - `dupcheck`
  - `cluster_permute` 
  - `putmatrix` 
  - `getmatrix` 
  - `dim`  
  - `mtab` 
  - `myzscore` 
  - `latexify`
- .ado files written by others
  - `extremes` (Nicholas J. Cox)
  - `_gbom` (Nicholas J. Cox)
  - `_geom` (Nicholas J. Cox)
  - `fre` (Ben Jann)
  - `randcmd` (Alwyn Young)
  - `carryforward` (David Kantor)
  - `reghdfe` (Sergio Correia). All files: `r/reghdfe*.*` and `e/estfe.ado`
  - `ftools` (Sergio Correia). All files: `f/f*.*`, `l/local_inlist.*`, `m/ms_*.*, j/join.*`
  - `svmat2` (Nicholas J. Cox)

#### R 3.6.3
The following list includes the R packages used and the version used; all of these packages and their dependencies are listed in the `renv.lock` file and can be installed using the `renv` package (installation instructions below).
  - `sf` (0.8.0)
  - `tidyverse` (1.3.0)
  - `data.table` (1.13.0)
  - `dtplyr` (0.0.3). Note: requires version 0.0.3 or earlier (1.0.0 breaks the code). To install, if not using `renv` to install the full set of packages needed for this replication package: 
    ```r
    remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
    ```
  - `magrittr` (1.5)
  - `haven` (2.2.0)
  - `assertthat` (0.2.1)
  - `here` (0.1)
  - `foreign` (0.8.75)
  - `lubridate` (1.7.8)
  - `readxl` (1.3.1)
  - `plm` (2.2.0)
  - `zoo` (1.8.6)
  - `pbapply` (1.4.2)
  - `wrapr` (2.0.2)
  - `metafor` (2.4.0)
  - `lfe` (2.8.5.1)
  - `renv` (0.12.0)

#### Python 3.8.4
The only Python packages needed are `os` and `re` which are included in the Python Standard Library.

## Folder structure

After downloading the replication code and data, unzip it into a folder on your computer. After unzipping, the project root directory containing the folders described below should be thought of as the `main` folder when editing the `00_run.do` script to run on another machine. The folders inside of the zipped replication file should be placed in a folder that you will denote as `global main` in `00_run.do`. These folders are:

  - `adofiles` contains the `.ado` files required to run our Stata scripts.
  - `data` and its subfolders are for raw data.
  - `graphs` (initially empty) is the folder to which graphs produced by the scripts will be written.
  - `logs` (initially empty) is the folder in which log files will be written.
  - `proc` (initially empty) is the folder in which processed data sets will be saved.
	- `renv` contains the information needed to install all needed R packages and dependencies.
  - `scripts` contains the replication code.
  - `tables` (initially empty) is the folder to which tables produced by the scripts will be written.
  - `waste` (initially empty) saves temporary files produced as part of the data preparation.
	
Initially empty folders include a 0-byte `blank.txt` text file so that the folder structure is maintained on the GitHub repository for the replication package.
  
### Additional files
The project root directory contains the following files:
  - `.here` is included to enable R's `here::here()` function to work with relative file paths.
  - `.Rprofile` contains information to install all needed R packages and dependencies.
  - `LICENSE.md` describes that this repository is licensed under a CC BY 4.0 License, which allows reuse with attribution. The license applies to the entirety of this repository _with the exception_ of the files in the `adofiles/` folder listed under ".ado files written by others" above.
  - `README.md` is a markdown README file for the replication package.
  - `README.txt` is identical to `README.md` but included for those unsure how to open an `.md` file.
  - `renv.lock` contains information to install all needed R packages and dependencies.

## Instructions

### Set up
All the needed Stata packages (.ado files) are included in the `adofiles/` folder and do not need to be installed. The list of needed R packages, including their versions and dependencies, are included in `renv.lock`, `.Rprofile`, and the `renv/` folder, and can be installed by opening R from the project's root directory (or, equivalently, opening R and setting the working directory as the project's root directory), then running:
```r 
renv::restore()
```

### Scripts
- The entire replication package can be run to go from raw data to final figures and tables by running `scripts/00_run.do`. 
- Individual scripts are numbered 01 through 120 and should be run in order; if you run scripts by running `00_run.do` they will automatically be run in order. (To determine exceptions when they can be run out of order, each script listed `00_run.do` describes its input data sets and output data sets.)
- To only run part of the replication package, there are local macros corresponding to each script on lines 113-272 that can be edited to only run certain scripts. Set the local macro to 1 for that script to run when running `00_run.do` or set it to 0 for that script to not run when running `00_run.do`.
- Note that all of the do files should be run by running `00_run.do` since that file assigns the global macros for file paths (with a few exceptions described below). For example, if running just one .do file, set the local macro for that script equal to 1 in `00_run.do` and set the local macros for all of the other scripts equal to 0, then run `00_run.do`.
- Due to computational reasons, in practice it is unlikey you would run the entire replication package at once. Some specifics to note about certain scripts:
  - Scripts 37 to 41 use confidential data from Banco de México accessed on-site; those scripts were thus run on a Banco de México server.
  - Scripts 13 and 99 use the `sf` package in R, which were run in a separate conda environment due to issues installing the dependencies of the `sf` package on the Kellogg Linux Cluster.
  - Scripts 46 and 70 process data that contains accent marks. Thus, they were run in RStudio on a laptop rather than with `00_run.do`.
  - Scripts 77, 78, and 80 are particularly computationally intensive because they conduct randomization inference on a large data set. These files are designed to be manually parallelized; see the instructions in lines 1105-1111 of `00_run.do`.
- `scripts/00_run.do` also contains:
  - Details on all of the raw and processed data sets used in the replication package, including which data sets are inputs and outputs of which scripts.
  - Details on which tables and figures are produced by which scripts.
- In addition to the scripts `00_run.do` and the scripts numbered 01 through 120, there are a few additional files in the `scripts/` folder:
  - `encelurb_dataprep_preliminary.doh` contains functions used by the scripts that clean the ENCELURB data.
  - `myfunctions.R` contains functions used by the R scripts.
  - `tabulator/` folder contains functions that make up the tabulator package by Sean Higgins. Alternatively, the package can be installed through R with:
    ```r
    remotes::install_github("skhiggins/tabulator")
    ```

### Details
- Download and unzip the replication file.
- Obtain confidential replication data and place it in the corresponding `data/` subfolders described above. Download publicly available data from the links above and place it in the corresponding `data/` subfolders described above.
- Uncomment line 30 in `scripts/00_run.do` by deleting the `**`, and changing `"/path/to/replication/folder"` to the parent directory for the replication on your local machine (i.e. the folder that immediately contains the folders `adofiles`, `data`, etc. that were zipped in the replication file).
- If the scripts you are running with `00_run.do` include R scripts, uncomment line 31 in `scripts/00_run.do` by deleting the `**` and replacing `"/path/to/R"` with the path to your R program. On Windows, it should include the `.exe` extension.
- If the scripts you are running with `00_run.do` include Python scripts, uncomment line 32 in `scripts/00_run.do` by deleting the `**` and replacing `"/path/to/python"` with the path to your Python program. On Windows, it should include the `.exe` extension.
- If you are running scripts 77, 78, and 80 through `00_run.do`, those files also specify the main file path since they are designed to be able to be manually parallelized as described above. Hence, uncomment line 33 in each of these scripts by deleting the `**`, and changing `"/path/to/replication/folder"` to the parent directory for the replication (i.e. the folder that immediately contains the folders `adofiles`, `data`, etc.)
- (Optional) To run only some of the scripts, edit the local macros on lines 113-272 of `00_run.do` to control which scripts run.
- Run `00_run.do`, for example on a Linux server with Stata-MP it can be run in the command line with:
  ```linux
  nohup stata-mp -b do scripts/00_run.do &
  ```

## References

Bachas, Pierre, Paul Gertler, Sean Higgins, Enrique Seira, "How debit cards enable the poor to save more," _Journal of Finance_, forthcoming.

Drexler, Alejandro, Greg Fischer, and Antoinette Schoar, "Keeping it simple: Financial literacy and rules of thumb," _American Economic Journal: Applied Economics_, 6 (2014), 1–31. 

Dupas, Pascaline and Jonathan Robinson, "Why don’t the poor save more? Evidence from health savings experiments," _American Economic Review_, 103 (2013), 1138–1171. 

Karlan, Dean, Margaret McConnell, Sendhil Mullainathan, and Jonathan Zinman, "Getting to the top of mind: How reminders increase saving," _Management Science_, 62 (2016), 3393– 3411.

Karlan, Dean and Jonathan Zinman, "Price and control elasticities of demand for savings," _Journal of Development Economics_, 130 (2018), 145–149.

Prina, Silvia, "Banking the poor via savings accounts: Evidence from a field experiment," _Journal of Development Economics_, 115 (2015), 16–31.
