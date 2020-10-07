******************************************************************
** RUN DO FILE FOR
**  HOW DEBIT CARDS ENABLE THE POOR TO SAVE MORE
**  Pierre Bachas, Paul Gertler, Sean Higgins, Enrique Seira
**  Journal of Finance
******************************************************************

*****************
** DIRECTORIES **
*****************
if "`c(username)'"=="higgins" { // NBER server
	global main "/disk/bulkw/higgins/ATM"
}
else if "`c(username)'"=="skh2820" { // Kellogg Linux Cluster
	global main "/kellogg/proj/skh2820/ATM"
	global R_path "/software/R/3.6.3/lib64/R/bin/R" // to run R scripts from 00_run.do
	global Python_path "/software/python/3.8.4/bin/python3" // to run Python scripts from 00_run.do
}
else if "`c(username)'"=="pierrebachas" { // Pierre's laptop
	global main "/Users/pierrebachas/Dropbox/Bansefi/ATM"
	local sample "_sample1" // to use 1% sample on laptop
}	
else if strpos("`c(username)'","Sean") { // Sean's laptop
	global main "C:/Dropbox/FinancialInclusion/Bansefi/ATM"
	global R_path "C:/Dropbox/Programs/R/R-36~1.3/bin/x64/R.exe" // to run R scripts from 00_run.do
	global Python_path "C:/Dropbox/Python3/python.exe" // to run Python scripts from 00_run.do
	local sample "_sample1" // to use 1% sample on laptop
}
// To replicate on another computer simply uncomment the following lines by removing ** and change the path:
** global main "/path/to/replication/folder"
** global R_path "/path/to/R"
** global Python_path "/path/to/python"

// Create global macros for subfolder paths:
include "$main/scripts/server_header.doh"

*******************
** PRELIMINARIES **
*******************

** Auxiliary files in scripts/:
**  encelurb_dataprep_preliminary.doh // contains functions used by *encelurb_*.do
**  myfunctions.R          // contains the functions we've written used by our R code
**  server_header.doh      // creates globals for directories for Stata do files
**  tabulator/tab.R        // 'tabulator' R package: https://github.com/skhiggins/tabulator
**  tabulator/tabcount.R   //   Alternatively, can install through R with install_github("skhiggins/tabulator"))
**  tabulator/quantiles.R

** ado files required (already included in replication files)
** a) ado files we've written
**  time 
**  graph_options 
**  bimestrify 
**  uniquevals 
**  mydi 
**  exampleobs
**  stringify
**  spanishaccents
**  lower
**  dupcheck
**  cluster_permute // for randomization inference
**  putmatrix // send matrix to Mata
**  getmatrix // get matrix from Mata
**  dim // print dimensions of matrix
**  mtab // many tab
**  myzscore // calculate Z-score
**  latexify
** b) ado files written by others
**  extremes (Nicholas J. Cox)
**  sencode (Roger Newson)
**  _gbom (Nicholas J. Cox)
**  _geom (Nicholas J. Cox)
**  winsify (our modified version of winsor by Nicholas J. Cox)
**  fre (Ben Jann)
**  randcmd (Alwyn Young)
**  carryforward (David Kantor)
**  reghdfe (Sergio Correia)	[All files: r/reghdfe*.* and e/estfe.ado]
**  ftools (Sergio Correia) [All files: f/f*.*, l/local_inlist.*, m/ms_*.*, j/join.*]
**  svmat2 (Nicholas J. Cox)

** R packages required. All packages and dependencies requires are listed in renv.lock and can be installed with the renv package.
**  sf
**  tidyverse
**  data.table
**  dtplyr # Requires version 0.0.3 or earlier (1.0.0 breaks the code)
**   # To install: remotes::install_version("dtplyr", version = "0.0.3", repos = "http://cran.us.r-project.org")
**  magrittr
**  haven
**  assertthat
**  here
**  foreign
**  lubridate
**  readxl
**  plm
**  zoo
**  pbapply
**  wrapr
**  metafor
**  lfe
**  renv

** Python packages required
**  os (included in Python Standard Library)
**  re (included in Python Standard Library)

// To run on Kellogg server:
**  cd /kellogg/proj/skh2820/ATM
**  module load stata/15 
**  module load R/3.6.3
**  module load python/3.8.4
**  nohup stata-mp -b do scripts/00_run.do &

// CONTROL WHETHER EACH FILE RUNS
//  Set the local to 0 to not run that script; set to 1 to run the script

// DATA PREP

// Bansefi admin data prep
local 01_bansefi_saldos_dataprep      = 1
local 02_bansefi_generales_dataprep   = 1
local 03_bansefi_movimientos_dataprep = 1
local 04_bansefi_make_sample          = 1
local 05_bansefi_sucursales_dataprep  = 1
local 06_bansefi_bimswitch            = 1
local 07_bansefi_avgbal               = 1
local 08_bansefi_transactions_redef   = 1
local 09_bansefi_mechanical_effect    = 1
local 10_bansefi_net_savings          = 1
local 11_bansefi_balance_checks       = 1
local 12_bansefi_balance_checks_pos   = 1
local 13_branches_localities          = 1 // run on laptop or with sf environment on server
local 14_bansefi_baseline             = 1
local 15_ATM_use_dataprep             = 1
local 16_balance_checks_dataprep      = 1
local 17_balance_checks_pos_dataprep  = 1
local 18_withdrawals_dataprep         = 1
local 19_withdrawals_event_dataprep   = 1
local 20_savings_event_dataprep       = 1
local 21_bansefi_nonOp_transactions   = 1
local 22_bansefi_nonOp_endbalance     = 1

// ITER admin data prep               
local 23_iter_dataprep                = 1 
local 24_iter_merge                   = 1 

// Oportunidades/Prospera admin data prep
local 25_cards_read                   = 1
local 26_cards_read_2015plus          = 1
local 27_cards_combine                = 1
local 28_cards_dataprep               = 1
local 29_cards_panel                  = 1
local 30_cards_bybim                  = 1
local 31_cards_byyear                 = 1
local 32_cards_event_dataprep         = 1

// DENUE admin data prep
local 33_denue_unzip                  = 1
local 34_denue_combine                = 1
local 35_denue_codigos_postales       = 1

// SEPOMEX admin data prep
local 36_cp_municipio                 = 1

// Banco de Mexico BDU admin data prep
local 37_bdu_hist_read                = 1
local 38_bdu_hist_dataprep            = 1
local 39_bdu_cp_dataprep              = 1
local 40_bdu_cp_month_dataprep        = 1
local 41_bdu_cp_month_means           = 1
local 42_bdu_cp_month_read            = 1
local 43_bdu_allgiro_month            = 1
local 44_bdu_collapse                 = 1
local 45_bdu_allgiro_event_dataprep   = 1

// CNBV admin data prep
local 46_cnbv_read                    = 1 // run on laptop in Rstudio due to UTF-8 encoding issue
local 47_cnbv_baseline                = 1
local 48_cnbv_event_dataprep          = 1
local 49_cnbv_merge_locality          = 1
local 50_cnbv_bd_sucursales           = 1
local 51_cnbv_bm_sucursales           = 1
local 52_cnbv_supplyside_dataprep     = 1

// Elections admin data prep
local 53_elections_dataprep           = 1
local 54_elections_event_dataprep     = 1

// Locality-level dataprep
local 55_bimswitch_dataprep           = 1
local 56_locality_discrete_dataprep   = 1
local 57_iter_locality_dataprep       = 1
local 58_locality_dataprep            = 1

// ENCELURB household panel survey
local 59_encelurb_dataprep_2002       = 1
local 60_encelurb_dataprep_2003       = 1
local 61_encelurb_dataprep_2004       = 1
local 62_encelurb_dataprep_2009       = 1
local 63_encelurb_merge               = 1
local 64_encelurb_reg_dataprep        = 1
local 65_encelurb_bycategory_dataprep = 1

// ENOE labor force survey data prep
local 66_enoe_read                    = 1
local 67_enoe_convert                 = 1
local 68_enoe_collapse                = 1
local 69_enoe_event_dataprep          = 1

// CPI micro data prep
local 70_cpix_read                    = 1 // run on laptop in Rstudio due to UTF-8 encoding issue
local 71_cpix_collapse                = 1
local 72_cpix_event_dataprep          = 1

// Trust Survey (ENCASDU) data prep
local 73_encasdu_convert              = 1
local 74_encasdu_dataprep             = 1

// Medios de Pago data prep
local 75_medios_de_pago_dataprep      = 1

// RESULT REGRESSIONS
// Admin data
local 76_ATM_use_regs                 = 1
local 77_withdrawals_event_randinf    = 1
local 78_savings_event_randinf        = 1 
local 79_savings_takeup               = 1
local 80_balance_checks_event_randinf = 1
local 81_withdrawals_event            = 1
local 82_savings_event                = 1
local 83_balance_checks_event         = 1
local 84_balance_checks_pos_event     = 1
local 85_event_randinf_pvalues        = 1

// Survey data
local 86_encelurb_regs                = 1
local 87_encelurb_bycategory          = 1
local 88_encelurb_heterogeneity       = 1
local 89_medios_de_pago_regs          = 1 

// TABLES
local 90_locality_discrete_time_table = 1 // Table 2
local 91_encasdu_table                = 1 // Table 3a left panel; Table 7
local 92_medios_de_pago_table         = 1 // Table 3a right panel; Table B.4
local 93_encelurb_table               = 1 // Table 3b; Table 5
local 94_eventstudy_table             = 1 // Table 4; Tables B.2, B.3, B.4, B.5
local 95_encelurb_bycategory_table    = 1 // Table 6

// FIGURES
local 96_comparison_figure            = 1
local 97_comparison_figure_graph      = 1 // Figure 1
local 98_rollout_graph                = 1 // Figure 2a
local 99_loc_rollout_graph            = 1 // Figure 2b // run on laptop or with sf environment on server
local 100_enoe_event_graph            = 1 // Figure 3a left panel
local 101_cpix_event_graph            = 1 // Figure 3a middle panel
local 102_bdu_allgiro_event_graph     = 1 // Figure 3a right panel
local 103_cnbv_event_graph            = 1 // Figure 3b
local 104_bansefi_pre_graph           = 1 // Figure 3c
local 105_ATM_use_graph               = 1 // Figure 4
local 106_withdrawals_deposits_graph  = 1 // Figure 5
local 107_eventstudy_graph            = 1 // Figures 6, 8
local 108_savings_takeup_graph        = 1 // Figure 7

// APPENDIX TABLES
local 109_account_summary_stats_table = 1 // Table B.1
local 110_encelurb_heterog_table      = 1 // Table B.6
local 111_supplyside_table            = 1 // Table B.7

// APPENDIX FIGURES
local 112_encelurb_histogram_graph    = 1 // Figure B.1a
local 113_medios_histogram_graph      = 1 // Figure B.1b
local 114_encasdu_histogram_graph     = 1 // Figure B.1c
local 115_prospera_event_graph        = 1 // Figure B.2a
local 116_elections_event_graph       = 1 // Figure B.2b
local 117_withdrawals_control_graph   = 1 // Figure B.3
local 118_nonOportunidades_graph      = 1 // Figure B.4
local 119_balance_checks_pos_graph    = 1 // Figure B.6
local 120_balance_checks_corr_graph   = 1 // Figure B.7

************************************************************************************
// BEGINNING OF BANSEFI ADMIN DATA PREP	
************************************************************************************

if (`01_bansefi_saldos_dataprep') do "$scripts/01_bansefi_saldos_dataprep.do"
	** Import raw average balance data from newer data dump
	** INPUTS
	**  $data/Bansefi/SP_`year'.txt forval year=2007/2015 // Raw data from Bansefi
	** OUTPUTS
	**  $proc/SP_`year'.dta // average balances by year
	**  $proc/SP.dta // all merged together

if (`02_bansefi_generales_dataprep') do "$scripts/02_bansefi_generales_dataprep.do"
	** Import raw account-level data 
	** INPUTS
	**  $data/Bansefi/DatosGenerales.txt // Raw data from Bansefi
	** OUTPUTS
	**  $proc/DatosGenerales.dta

if (`03_bansefi_movimientos_dataprep') do "$scripts/03_bansefi_movimientos_dataprep.do"
	** Import raw transactions data
	** INPUTS
	**  $data/Bansefi/MOV`year'.txt forval year=2007/2015 // Raw data from Bansefi
	** OUTPUTS 
	**  $proc/MOV`year'.dta
	
if (`04_bansefi_make_sample') do "$scripts/04_bansefi_make_sample.do"
	** Create 1% sample for saldos, datos generales, movimientos
	** INPUTS
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	**  $proc/MOV`year'.dta // 03_bansefi_movimientos_dataprep
	**  $proc/SP_`year'.dta // 01_bansefi_saldos_dataprep
	** OUTPUTS
	**  $proc/DatosGenerales_sample1.dta
	**  $proc/MOV`year'_sample1
	**  $proc/MOV_sample1.dta
	**  $proc/SP_`year'_sample1
	**  $proc/SP_sample1.dta
	
if (`05_bansefi_sucursales_dataprep') do "$scripts/05_bansefi_sucursales_dataprep.do"
	** Create a data set with client (integranteid), account (cuenta), and branch (sucadm)
	** INPUTS
	**  $proc/SP.dta // 1_bansefi_saldos_dataprep
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	** OUTPUTS
	**  $proc/cuenta_sucursal.dta // account level
	**  $proc/integrante_sucursal.dta // client level

if (`06_bansefi_bimswitch') do "$scripts/06_bansefi_bimswitch.do"
	** Calculate bimester of switch (use bimester of last Op payment in old account + 1)
	** INPUTS
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	**  $proc/MOV`year'.dta // 03_bansefi_movimientos_dataprep
	** INTERMEDIATE OUTPUTS
	**  $proc/bim_switch_cuentahorro.dta // bimester of switch by cuenta but 
	**		// only includes the cuentahorro (i.e. the pre-switch account)
	** OUTPUTS
	**  $proc/bim_switch_integrante.dta // bimester of switch by integrante (client)

if (`07_bansefi_avgbal') do "$scripts/07_bansefi_avgbal.do"
	** Create data set with average balances 
	** INPUTS
	**  $proc/SP_2007.dta // average balances 2007 (from 2015 data dump) // 01_bansefi_saldos_dataprep
	**  $proc/SP_2008.dta // average balances 2008 (from 2015 data dump) // 01_bansefi_saldos_dataprep
	**  $data/Bansefi/Saldos Promedio Cuentahorro.dta // Raw data from Bansefi: average balances 2009-2011
	**		// cuentahorro accounts (raw from 2012 data dump) 
	**	$data/Bansefi/Saldos Promedio Debicuenta.dta // Raw data from Bansefi: average balances 2009-2011
	**		// debicuenta accounts (raw from 2012 data dump) 
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	** INTERMEDIATE OUTPUTS
	**  $proc/avgbal_cuenta_bimester.dta
	** OUTPUTS
	**  $proc/avgbal_integrante_bimester.dta 
	
if (`08_bansefi_transactions_redef') do "$scripts/08_bansefi_transactions_redef.do" 
	** Transactions data with redefined periods
	**  (where redefined periods refers to coding a shifted deposit from 
	**   period t to period t-1 as happening in period t; also codes any transactions
	**   after that date as period t) 
	** INPUTS
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	**  $proc/MOV`year'.dta forval year=2007/2011 // 03_bansefi_movimientos_dataprep
	** OUTPUTS
	**  $proc/transactions_redef_bim.dta
	**  $proc/OpDeposits_redef_bim.dta //! 
	**  $proc/account_bimredef_transactions.dta
	**  $proc/shift_dates.dta 
	
if (`09_bansefi_mechanical_effect') do "$scripts/09_bansefi_mechanical_effect.do"
	** Calculate account-level mechanical effect by (redefined) bimester
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef
	**  $proc/shift_dates.dta // 08_bansefi_transactions_redef
	** INTERMEDIATE OUTPUTS
	**  $waste/transactions_redef_working.dta
	**  $waste/transactions_patterns_`bi'.dta (for each bimester)
	** OUTPUTS
	**  $proc/mechanical_effect.dta
	
if (`10_bansefi_net_savings') do "$scripts/10_bansefi_net_savings.do" 
	** Create data set with net savings variables (subtracting mechanical effect)
	**  (Note on redefined bimesters: in average balance data there is no concept
	**   of redefined bimesters; we merge bimester from average balance data with
	**   redefined bimester from transactions data.)
	** INPUTS
	**  $proc/mechanical_effect.dta // 09_bansefi_mechanical_effect
	**  $proc/avgbal_integrante_bimester.dta // 07_bansefi_avgbal
	** OUTPUTS
	**  $proc/netsavings_integrante_bimester.dta // net savings by client-bimester

if (`11_bansefi_balance_checks') do "$scripts/11_bansefi_balance_checks.do"
	** Creates a transaction dataset which measures balance checks and time between transactions and balance checks.
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef
	**  $proc/avgbal_integrante_bimester.dta // 07_bansefi_avgbal
	** OUTPUTS
	**  $proc/balance_checks.dta // balance check identified in transaction data

if (`12_bansefi_balance_checks_pos') do "$scripts/12_bansefi_balance_checks_pos.do"
	** Number of balance checks, ATM withdrawals, POS transactions by account by day
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef
	**  $proc/avgbal_integrante_bimester.dta // 07_bansefi_avgbal
	** OUTPUTS
	**  $proc/transactions_by_day.dta // number of balance checks, ATM withdrawals, POS transactions by account by dayo

if (`13_branches_localities') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/13_branches_localities.R" "$logs/13_branches_localities.log"
	** Read in Bansefi branch geocoordinates (to merge branches to localities for correct clustering)
	** INPUTS:
	**  read_sf(here::here("data", "shapefiles", "bansefi_geocoordinates"), "suc_bansefi_2008ccl")
	**   // raw shapefiles with Bansefi branch geocoordinates, provided by Prospera
	** OUTPUTS:
	**  here::here("proc", "branches.rds") # entire sf
	**  here::here("proc", "branches_nogeom.rds") # without geometry
	**  here::here("proc", "branch_loc.rds") # (and dta) just branch and loc
	**  here::here("proc", "n_bansefi.rds")

if (`14_bansefi_baseline') do "$scripts/14_bansefi_baseline.do"
	** Prepare account-level baseline covariates for appendix table and as controls
	** INPUTS
	**  $proc/netsavings_integrante_bimester.dta // 10_bansefi_net_savings
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/integrante_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	**  $proc/account_bimredef_transactions.dta // 08_bansefi_transactions_redef
	** OUTPUTS
	**  $proc/bansefi_baseline.dta // at account level
	**  $proc/bansefi_baseline_loc.dta // collapsed to locality level

if (`15_ATM_use_dataprep') do "$scripts/15_ATM_use_dataprep.do"
	** Prepare data on use of ATMs
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/integrante_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	** OUTPUTS 
	**  $proc/ATM_use.dta
	
if (`16_balance_checks_dataprep') do "$scripts/16_balance_checks_dataprep.do"
	** Data prep for study graph of number of balance checks by time period after switch (as compared to last period) 
	** INPUTS
	**  $proc/balance_checks.dta  // 11_bansefi_balance_checks
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/branch_loc.dta // 13_branches_localities
	** OUTPUTS
	**  $proc/balance_checks_forreg.dta
	**  $proc/balance_checks_forreg_permutations.dta // for randomization inference
	**  $proc/balance_checks_forreg_withperm.dta // for randomization inference
	
if (`17_balance_checks_pos_dataprep') do "$scripts/17_balance_checks_pos_dataprep.do"
	** Data prep on balance checks before a POS transaction
	** INPUTS
	**  $proc/transactions_by_day.dta // 12_bansefi_balance_checks_pos
	** OUTPUTS
	**  transactions_by_day_forreg.dta

if (`18_withdrawals_dataprep') do "$scripts/18_withdrawals_dataprep.do"
	** Data prep for withdrawals and deposits
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef 
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/integrante_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	**  $proc/bansefi_baseline.dta // 14_bansefi_baseline
	** OUTPUTS
	**  $proc/account_withdrawals_deposits.dta
	
if (`19_withdrawals_event_dataprep') do "$scripts/19_withdrawals_event_dataprep.do"
	** Data prep to generate graphs of withdrawal and deposit distributions; event study for withdrawals
	** INPUTS
	**  $proc/account_withdrawals_deposits.dta // 18_withdrawals_dataprep
	** OUTPUTS
	**  $proc/account_withdrawals_forreg.dta
	**  $proc/account_withdrawals_forreg_permutations.dta // permuted cuat_switch by locality
	**  $proc/account_withdrawals_forreg_withperm.dta // with those permutations merged back in
	
if (`20_savings_event_dataprep') do "$scripts/20_savings_event_dataprep.do"
	** Data prep for event study of savings
	** INPUTS
	**  $proc/netsavings_integrante_bimester.dta // 10_bansefi_net_savings
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/integrante_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	**  $proc/bansefi_baseline.dta // 14_bansefi_baseline
	** OUTPUTS
	**  $proc/netsavings_forreg.dta
	**  $proc/netsavings_forreg_permutations.dta // permuted cuat_switch by locality
	**  $proc/netsavings_forreg_withperm.dta // with those permutations merged back in
	
if (`21_bansefi_nonOp_transactions') do "$scripts/21_bansefi_nonOp_transactions.do"
	** INPUTS 
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	**  $proc/MOV`year'.dta // 03_bansefi_movimientos_dataprep
	** OUTPUTS
	**  $proc/nonOp_transactions.dta
	
if (`22_bansefi_nonOp_endbalance') do "$scripts/22_bansefi_nonOp_endbalance.do"
	** INPUTS
	**  $proc/nonOp_transactions.dta // 21_bansefi_nonOp_transactions
	** OUTPUTS
	**  $proc/nonOp_endbalance.dta

************************************************************************************
// END OF BANSEFI ADMIN DATA PREP	
************************************************************************************	

*********************************************************************
// BEGINNING AUXILIARY ADMINISTRATIVE DATA PREP
*********************************************************************
// BEGIN ITER (population by locality) DATA PREP
if (`23_iter_dataprep') shell "$R_path" CMD BATCH --vanilla -q /// 
	"$scripts/23_iter_dataprep.R" "$logs/23_iter_dataprep.log"
	** Get locality population from ITER
	** INPUTS
	**  here::here("data", "ITER", "2010", "ITER_NALTXT10.TXT") # raw ITER data from INEGI
	**  here::here("data", "ITER", "2005", "ITER_NALTXT05.txt") # raw ITER data from INEGI
	**  here::here("data", "ITER", "2005", "fd_iter_2005.xlsx") # column names for 2005 ITER 
	**   # fd_iter_2005.xlsx prepared by RA Nils Lieber based on INEGI documentation
	** OUTPUTS
	**  here::here("proc", "iter2010.rds")
	**  here::here("proc", "iter2010_urban.rds")
	**  here::here("proc", "iter_mun.rds") and .dta # corresponds to 2010 ITER
	**  here::here("proc", "iter2005.rds")
	**  here::here("proc", "iter2005_urban.rds")
	
if (`24_iter_merge') shell "$R_path" CMD BATCH --vanilla -q /// //! check if needed
	"$scripts/24_iter_merge.R" "$logs/24_iter_merge.log"
	** Merge 2005 and 2010 ITER waves to have both in one file (wide format)
	** INPUTS 
	**  here::here("proc", "iter2005.rds") # 23_iter_dataprep
	**  here::here("proc", "iter2010.rds") # 23_iter_dataprep
	**  here::here("proc", "n_bansefi.rds") # 13_branches_localities
	** OUTPUTS
	**  here::here("proc", "iter.rds") # and .dta
	**  here::here("proc", "iter_urban.rds") # and .dta	
// END ITER DATA PREP

// BEGIN OPORTUNIDADES/PROSPERA ADMIN DATA PREP
if (`25_cards_read') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/25_cards_read.R" "$logs/25_cards_read.log"
	** Read in .dbf files with number of families and payment type (e.g. debit card) by locality
	**  shared by Prospera in 2015
	**  (formerly called dbf_familias_loc.R)
	**  INPUTS
	**   list.files(here::here("data", "Prospera"),
	**     pattern = "fams_prosp_[0-9]{5}\\.dbf$",
	**     recursive = TRUE,
	**     ignore.case = TRUE,
	**     full.names = TRUE
	**   ) # raw data from Prospera on beneficiaries and payment method by locality over time
	**  OUTPUTS
	**   here::here("proc", "fams_prosp.rds") and .dta

if (`26_cards_read_2015plus') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/26_cards_read_2015plus.R" "$logs/26_cards_read_2015plus.log"
	** Read in .dbf files with number of families and payment type (e.g. debit card) by locality
	**  for 2015 and beyond (different data format)
	**  shared by Prospera in 2017
	**  INPUTS
	**   list.files( # 2015-2016 (different format)
	**     here::here("data", "Prospera"),
	**     pattern = "localidades_punto_entrega_bim_op_[0-9]{1}_[0-9]{4}\\.dbf$",
	**     recursive = TRUE, 
	**     ignore.case = TRUE,
	**     full.names = TRUE
	**   ) # raw data from Prospera for 2015-2016
	**  OUTPUTS
	**   here::here("proc", "fams_prosp_2015plus.rds")

if (`27_cards_combine') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/27_cards_combine.R" "$logs/27_cards_combine.log"
	** Combine older and newer Prospera data on families and payment type over time
	**  INPUTS
	**   here::here("proc", "fams_prosp.rds") # 25_cards_read
	**   here::here("proc", "fams_prosp_2015plus.rds") # 26_cards_read_2015plus
	**  OUTPUTS
	**   here::here("proc", "fams_prosp_combined.rds")

if (`28_cards_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/28_cards_dataprep.R" "$logs/28_cards_dataprep.log"
	** Create data set with rollout of debit cards
	**  (formerly called cards_graph.R as it also graphs rollout)
	**  INPUTS
	**   here::here("proc", "fams_prosp_combined.rds") # 27_cards_combine
	**  OUTPUTS
	**   here::here("proc", "fams_prosp_bal.rds") # all Prospera localities

if (`29_cards_panel') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/29_cards_panel.R" "$logs/29_cards_panel.log" 
	**  Balanced panel of localities that received debit cards
	**  INPUTS 
	**   here::here("proc", "fams_prosp_bal.rds") # 28_cards_dataprep
	**   here::here("proc", "iter2010.rds") # 23_iter_dataprep
	**  OUTPUTS
	**   here::here("proc", "cards_pob.rds")
	**   here::here("proc", "cards_mun.rds") # and .dta

if (`30_cards_bybim') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/30_cards_bybim.R" "$logs/30_cards_bybim.log" 
	**  Balanced panel of localities that received debit cards
	**  INPUTS 
	**   here::here("proc", "fams_prosp_bal.rds") # 28_cards_dataprep
	**   here::here("proc", "cards_pob.rds") # 29_cards_panel
	**  OUTPUTS
	**   here::here("proc", "cards_bybim.rds")
	**   here::here("proc", "cards_bybim_urban.rds")
	
if (`31_cards_byyear') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/31_cards_byyear.R" "$logs/31_cards_byyear.log" 
	** INPUTS
	**  list.files(
	**    here::here("data", "Prospera", "by_year"),
  **    pattern = "\\.dbf",
  **    full.names = TRUE
	**  ) # raw from Prospera
	**  here::here("proc", "iter2010.rds") # 23_iter_dataprep
	** OUTPUTS
	**  here::here("proc", "cards_byyear.rds")
	**  here::here("proc", "cards_byyear_urban.rds")
	
if (`32_cards_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/32_cards_event_dataprep.R" "$logs/32_cards_event_dataprep.log"
	** INPUTS
	**  here::here("proc", "cards_bybim_urban.rds") # 30_cards_bybim
	**  here::here("proc", "cards_byyear_urban.rds") # 31_cards_byyear
	**  here::here("proc", "cards_pob.rds") # 29_cards_panel
	** OUTPUTS
	**  here::here("proc", "prospera_forreg.rds")

// END OPORTUNIDADES/PROSPERA ADMIN DATA PREP

// BEGIN DENUE (geocoordinates of firms in Mexico)
if (`33_denue_unzip') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/33_denue_unzip.R" "$logs/33_denue_unzip.log"
	** Unzip DENUE data
	** # Raw DENUE data
	** INPUTS
	**  list.files(path = here::here("data", "DENUE", "2017"), 
	**    pattern = "_csv.zip$", # not the shapefiles which are "_shp.zip$"
	**    full.names = TRUE, 
	**    recursive = FALSE
	**  ) # zipped DENUE files (raw data from INEGI)
  ** OUTPUTS
	**  unzipped DENUE files
	
if (`34_denue_combine') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/34_denue_combine.R" "$logs/34_denue_combine.log"
	** Read and combine DENUE data
	** INPUTS
	**  unzipped DENUE files # 33_denue_unzip
	**  folders <- list.dirs(path = here::here("data", "DENUE", "2017"),
  **    full.names = TRUE, 
  **    recursive = TRUE
	**  )
  **  folders <- folders[str_detect(folders, "conjunto_de_datos$")]
	** OUTPUTS
	**  here::here("proc", "denue.rds")
	
if (`35_denue_codigos_postales') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/35_denue_codigos_postales.R" "$logs/35_denue_codigos_postales.log"	
  ** Zip code to locality mapping based on firms in DENUE
	** INPUTS
  **  here::here("proc", "denue.rds") # 34_denue_combine
  ** OUTPUTS
  **  here::here("proc", "cp_loc.rds") # postal code to locality mapping
	**  here::here("proc", "ageb_cp.rds") # ageb to postal code mapping
	**  here::here("proc", "bus_by_cp_rama.rds") # number of businesses by postal code by rama (4-digit NAICS)
// END DENUE

// BEGIN SEPOMEX (Mexico's postal service)
if (`36_cp_municipio') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/36_cp_municipio.R" "$logs/36_cp_municipio.log"
	** Get data set with postal code and corresponding municipality
	** INPUTS
	**  here::here("data", "SEPOMEX", "CPdescarga.txt") # raw data from SEPOMEX
	** OUTPUTS
	**  here::here("proc", "cp_mun.rds")
// END SEPOMEX

// BEGIN BANCO DE MEXICO BDU (POS ADOPTION DATA FROM MEXICO'S CENTRAL BANK)
//  Note: initial files can only run on Banco de Mexico server

//  BEGIN RUN ON BANCO DE MEXICO SERVER ------------------------------------------------------
if (`37_bdu_hist_read') shell "$R_path" CMD BATCH --vanilla -q /// 
	"$scripts/37_bdu_hist_read.R" "$logs/37_bdu_hist_read.log"
	** Read in raw BDU historico, clean
  ** INPUTS
  **  here::here("data", "BDU", "bdu_historico_sean.rds") # raw masked data prepared by Banxico
  **  here::here("data", "MCC", "mcc_codes.csv") # MCC codes with text category description
  ** OUTPUTS
  **  here::here("proc", "bdu_hist.rds")
	
if (`38_bdu_hist_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/38_bdu_hist_dataprep.R" "$logs/38_bdu_hist_dataprep.log"
  ** Create data set with existing number of POS at beginning of 2006
  ** INPUTS
  **  here::here("data", "BDU","bdu_actual_sean.rds") # Raw BDU active POS from Banxico
  **  here::here("proc", "bdu_hist.rds") # 37_bdu_hist_read
  ** OUTPUTS
  **  here::here("proc", "bdu_by_cp_mcc_t0.rds") # number of POS by postal code by merchant category code in 2006
  **  here::here("proc", "bdu_by_loc_mcc_t0.rds")	# number of POS by lcoality by merchant category code in 2006
	
if (`39_bdu_cp_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/39_bdu_cp_dataprep.R" "$logs/39_bdu_cp_dataprep.log"
	** Adoption of POS terminals: data prep
	** INPUTS
	**  here::here("proc", "bdu_hist.rds") # 37_bdu_hist_read
	**  here::here("proc", "bdu_by_cp_mcc_t0.rds") # 38_bdu_hist_dataprep
	** OUTPUTS
	**  here::here("proc", "bdu_altas_by_cp_mcc.rds") 
	**  here::here("proc", "bdu_altas_by_cp_mcc_month.rds")
	
if (`40_bdu_cp_month_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/40_bdu_cp_month_dataprep.R" "$logs/40_bdu_cp_month_dataprep.log"
	** Number of POS terminals by postal code by MCC by month
	** INPUTS
	**  here::here("proc", "bdu_altas_by_cp_mcc_month.rds") # 39_bdu_cp_dataprep
	**  here::here("proc", "cp_mun.rds") # 36_cp_municipio
	**  here::here("proc", "iter_mun.rds") # 23_iter_dataprep
	** OUTPUTS
	**  here::here("proc", "bdu_cp_month_urban.rds")

if (`41_bdu_cp_month_means') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/41_bdu_cp_month_means.R" "$logs/41_bdu_cp_month_means.log"
	** Print means by month for Banxico to send
	** INPUTS
	**  here::here("proc", "bdu_cp_month_urban.rds") # 40_bdu_cp_month_dataprep
	** OUTPUTS
	**  here::here("logs", str_c("bdu_cp_month_means_allgiro", time_stamp(), ".log"))
	**  here::here("logs", str_c("bdu_cp_month_means_CS", time_stamp(), ".log"))
//  END RUN ON BANCO DE MEXICO SERVER ------------------------------------------------------
	
// Note: run remainder of BDU on own server
if (`42_bdu_cp_month_read') shell "$Python_path" "$scripts/42_bdu_cp_month_read.py"
	** Read in data on number of POS by postal code by month printed in log file
	** INPUTS
	**  os.path.join("logs", "bdu_cp_month_means_allgiro_20190121_111839.log") # 41_bdu_cp_month_means
	** OUTPUTS
	**  os.path.join("proc", "bdu_cp_month_means_new.csv")

if (`43_bdu_allgiro_month') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/43_bdu_allgiro_month.R" "$logs/43_bdu_allgiro_month.log"
	** Create data set with all POS (across all giros) per month 
	** INPUTS
	**  here::here("proc", "bdu_cp_month_means_new.csv") # 42_bdu_cp_month_read
	**  here::here("proc", "cp_loc.rds") # 35_denue_codigos_postales
	** OUTPUTS
	**  here::here("proc", "bdu_loc_long_allgiro.rds") # POS by locality
	**  here::here("proc", "bdu_cp_long_allgiro.rds") # POS by postal code

if (`44_bdu_collapse') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/44_bdu_collapse.R" "$logs/44_bdu_collapse.log"	
	** Collapse to baseline number of POS by locality (to use as control in cross-section survey regressions)
	** INPUTS
	**  here::here("proc", "bdu_loc_long_allgiro.rds") # 43_bdu_allgiro_month
	** OUTPUTS
	**  here::here("proc", "bdu_baseline.rds") and dta
	
if (`45_bdu_allgiro_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/45_bdu_allgiro_event_dataprep.R" "$logs/45_bdu_allgiro_event_dataprep.log"
	** Data prep for POS adoption event study
	** INPUTS
	**  here::here("proc", "bdu_loc_long_allgiro.rds") # 43_bdu_allgiro_month
	**  here::here("proc", "bdu_cp_long_allgiro.rds") # 43_bdu_allgiro_month
	**  here::here("proc", "cards_pob.rds") # 29_cards_panel
	**  here::here("proc", "iter2010.rds") # 23_iter_dataprep 
	** OUTPUTS
	**  here::here("proc", "bdu_loc_allgiro_forreg.rds")
	**  here::here("proc", "bdu_cp_allgiro_forreg.rds")
	**  here::here("proc", "bdu_loc_allgiro_wide.rds") # and .dta
// END BANCO DE MEXICO BDU

// BEGIN CNBV
// Note: run cbnv_read on laptop in RStudio because relies on utf-8 character matching
if (`46_cnbv_read') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/46_cnbv_read.R" "$logs/46_cnbv_read.log"
	** Read CNBV data on number of cards, POS, etc.
	** INPUTS
	**  list.files(
	**    here::here("data", "CNBV"), pattern = "BM_Operativa"
	**  ) # raw data from CNBV
	** OUTPUTS
	**  here::here("proc", "cnbv_mun.rds")

// Note: run remainder of CNBV on own server
if (`47_cnbv_baseline') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/47_cnbv_baseline.R" "$logs/47_cnbv_baseline.log"
	** Create baseline CNBV data set
	** INPUTS
	**  here::here("proc", "cnbv_mun.rds") # 46_cnbv_read
	** OUTPUTS
	**  here::here("proc", "cnbv_baseline_mun.rds") and .dta

if (`48_cnbv_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/48_cnbv_event_dataprep.R" "$logs/48_cnbv_event_dataprep.log"
  ** Data prep for event study pre-trends of effect of Prospera expansion on number of cards
	** INPUTS
  **  here::here("proc", "cnbv_mun.rds")  # 46_cnbv_read
  **  here::here("proc", "iter_mun.rds")  # 23_iter_dataprep
  **  here::here("proc", "cards_mun.rds") # 29_cards_panel
  ** OUTPUTS
  **  here::here("proc", "cnbv_forreg.rds") 
	
if (`49_cnbv_merge_locality') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/49_cnbv_merge_locality.R" "$logs/49_cnbv_merge_locality.log"	
	** Prepare locality-level CNBV data from select periods for discrete time hazard
	** INPUTS
	**  here::here("data", "CNBV", "BM_Operativa_200612.xls") # raw CNBV data
	**  here::here("data", "CNBV", "BM_Operativa_200812.xls") # raw CNBV data
	** OUTPUTS 
	**  here::here("proc", "cnbv_branch_mun.rds") # and .dta
	**  here::here("proc", "cnbv_accounts_mun.rds") # and .dta
	**  here::here("proc", "cnbv_checking_mun.rds") # and .dta
	**  here::here("proc", "cnbv_atms.rds") # and .dta
	
if (`50_cnbv_bd_sucursales')	do "$scripts/50_cnbv_bd_sucursales.do"
	** Data prep for testing expansion of sucursales, branches, savings accounts in CNBV data
	** INPUTS
	**  dir "$data/CNBV/BancaDesarrollo/" files "*`var'*" // raw CNBV files prepared by Isaac Meza
	** OUTPUTS 
	**  $proc/bd_*_month.dta
	
if (`51_cnbv_bm_sucursales') do "$scripts/51_cnbv_bm_sucursales.do"
	** Data prep for testing expansion of sucursales, branches, savings accounts in CNBV data
	** INPUTS
	**  dir "$data/CNBV/BancaMultiple/" files "*.csv" // raw CNBV files prepared by Isaac Meza
	** OUTPUTS 
	**  $proc/bm_*_month.dta
	
if (`52_cnbv_supplyside_dataprep') do "$scripts/52_cnbv_supplyside_dataprep.do"
	** Data prep for testing expansion of sucursales, branches, savings accounts in CNBV data
	** INPUTS
	**  $proc/bd_*_month.dta // 50_cnbv_bd_sucursales
	**  $proc/bm_*_month.dta // 51_cnbv_bm_sucursales
	**  $proc/cards_mun.dta // 29_cards_panel
	** OUTPUTS 
	**  $proc/cnbv_supply.dta

// END CNBV

// BEGIN ELECTORAL DATA
if (`53_elections_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/53_elections_dataprep.R" "$logs/53_elections_dataprep.log"	
	** INPUTS
	**  here::here("data", "INE", "elecciones_long.dta")
	**   # raw data, hand-coded by Enrique's RA
	** OUTPUTS
	**  here::here("proc", "elections_party_by_year.rds")
	**  here::here("proc", "elections_vote_shares.rds")
	**  here::here("proc", "elections_party_wide.rds") // and .dta

if (`54_elections_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/54_elections_event_dataprep.R" "$logs/54_elections_event_dataprep.log"	
	** INPUTS
	**  here::here("proc", "elections_party_by_year.rds") # 53_elections_dataprep
	**  here::here("proc", "iter_mun.rds") # 23_iter_dataprep
	**  here::here("proc", "cards_mun.rds") # 29_cards_panel
	** OUTPUTS
	**  here::here("proc", "elections_forreg.rds") 
// END ELECTORAL DATA

// BEGIN LOCALITY-LEVEL DATA
if (`55_bimswitch_dataprep') do "$scripts/55_bimswitch_dataprep.do"
	** INPUTS
	**  $proc/fams_prosp.dta // 25_cards_read
	**  $proc/iter_urban.dta // 24_iter_merge
	** OUTPUTS
	**  $proc/familias_loc.dta
	**  $proc/locality_chars.dta

if (`56_locality_discrete_dataprep') do "$scripts/56_locality_discrete_dataprep.do"
	** Prepare locality-level data for discrete time hazard
  ** INPUTS
  **  $proc/locality_chars.dta // 55_bimswitch_dataprep
  **  $proc/bdu_loc_allgiro_wide.dta // 45_bdu_allgiro_event_dataprep
  **  $proc/cnbv_branch_mun.dta // 49_cnbv_merge_locality
  **  $proc/cnbv_accounts_mun.dta // 49_cnbv_merge_locality
  **  $proc/cnbv_checking_mun.dta // 49_cnbv_merge_locality
  **  $proc/cnbv_atms.dta // 49_cnbv_merge_locality
	**  $proc/cnbv_baseline_mun.dta // 49_cnbv_merge_locality
	**  $proc/elections_party_wide.dta // 53_elections_dataprep
	** OUTPUTS
	**  $proc/locality_for_discretetime.dta 
	
if (`57_iter_locality_dataprep') do "$scripts/57_iter_locality_dataprep.do"
	** INPTUS
	**  "$data/Prospera/1. Modelo_Urbano_263-Locs.csv" // raw from Prospera
	**  "$data/ITER/ITER_NALTXT`yy'.txt" // raw INEGI data
	** OUTPUTS
	**  "$proc/iter05u.dta"
	
if (`58_locality_dataprep') do "$scripts/58_locality_dataprep.do"
	** INPUTS:
	**  $data/CONEVAL/rezago_social_localidad.dta // raw data from CONEVAL (see data/CONEVAL/Notes.txt for download details)
	**  $proc/iter05u.dta // 57_iter_locality_dataprep
	** OUTPUTS:
	**  $proc/urban_locs.dta
// END LOCALITY-LEVEL DATA

************************************************************************************
// END OF AUXILIARY ADMINISTRATIVE DATA PREP
************************************************************************************	

*********************************************************************
// BEGINNING OF SURVEY DATA PREP 
*********************************************************************
// BEGIN HOUSEHOLD PANEL SURVEY (ENCELURB)
if (`59_encelurb_dataprep_2002') do "$scripts/59_encelurb_dataprep_2002.do"
	** INPUTS
	**  Raw data from Prospera (ENCELURB):
	**  $data/ENCELURB/`year'/socio_monetarias_desde_hogar.dta // `year' = 2002
	**  $data/ENCELURB/`year'/socio_especie_desde_hogar.dta
	**  $data/ENCELURB/`year'/socio_monetarias_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_especie_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_personas_soc.dta
	**  $data/ENCELURB/`year'/socio_hogares_soc.dta
	** OUTPUTS
	**  "$proc/encel`yy'_hh.dta" // `yy' = 02

if (`60_encelurb_dataprep_2003') do "$scripts/60_encelurb_dataprep_2003.do"
	** INPUTS
	**  Raw data from Prospera (ENCELURB):
	**  $data/ENCELURB/`year'/socio_monetarias_desde_hogar.dta // `year' = 2003
	**  $data/ENCELURB/`year'/socio_especie_desde_hogar.dta
	**  $data/ENCELURB/`year'/socio_monetarias_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_especie_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_personas_soc.dta
	**  $data/ENCELURB/`year'/socio_hogares_soc.dta
	** OUTPUTS
	**  "$proc/encel`yy'_hh.dta" // `yy' = 03
	
if (`61_encelurb_dataprep_2004') do "$scripts/61_encelurb_dataprep_2004.do"
	** INPUTS
	**  Raw data from Prospera (ENCELURB):
	**  $data/ENCELURB/`year'/socio_monetarias_desde_hogar.dta // `year' = 2004
	**  $data/ENCELURB/`year'/socio_especie_desde_hogar.dta
	**  $data/ENCELURB/`year'/socio_monetarias_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_especie_hacia_hogar.dta
	**  $data/ENCELURB/`year'/socio_personas_soc.dta
	**  $data/ENCELURB/`year'/socio_hogares_soc.dta
	** OUTPUTS
	**  "$proc/encel`yy'_hh.dta" // `yy' = 04

if (`62_encelurb_dataprep_2009') do "$scripts/62_encelurb_dataprep_2009.do"
	** INPUTS
	**  Raw data from Prospera (ENCELURB):
	**  $data/ENCELURB/`year'/panel_integrantes_febrero_2010.dta // `year' = 2009
	**  $data/ENCELURB/`year'/panel_hogar_febrero_2010.dta
	**  $data/ENCELURB/`year'/entrevistas_panel_febrero_2010.dta
	** OUTPUTS
	**  $proc/encel`yy'_hh.dta // `yy' = 09

if (`63_encelurb_merge') do "$scripts/63_encelurb_merge.do"
	** INPUTS:
	**  $proc/encel02_hh.dta // 59_encelurb_dataprep_2002
	**  $proc/encel03_hh.dta // 60_encelurb_dataprep_2003
	**  $proc/encel04_hh.dta // 61_encelurb_dataprep_2004
	**  $proc/encel09_hh.dta // 62_encelurb_dataprep_2009
	**  $proc/urban_locs.dta // 58_locality_dataprep
	**  $proc/familias_loc.dta // 55_bimswitch_dataprep
	**  $data/Prospera/Transfers/Encel_sample/encelurb_trans_2002_2010.dta 
	**   // raw transfer data 2002-2010 provided by Prospera
	**  $data/Prospera/Transfers/Encel_sample/encelurb_trans`year'`b'.dta
	**   // forval year=2010/2013 forval b=1/6 
	**   // raw transfer data 2010-2013 provided by Prospera	
	** OUTPUTS:
	**  $data/encel_merged.dta
	
if (`64_encelurb_reg_dataprep') do "$scripts/64_encelurb_reg_dataprep.do"
	** INPUTS 
	**  $proc/encel_merged.dta // 63_encelurb_merge
	** OUTPUTS
	**  $proc/encel_forreg.dta
	
if (`65_encelurb_bycategory_dataprep') do "$scripts/65_encelurb_bycategory_dataprep.do"
	** INPUTS 
	**  $proc/encel_forreg.dta // 64_encelurb_reg_dataprep
	** OUTPUTS
	**  $proc/encel_forreg_bycategory.dta
// END HOUSEHOLD PANEL SURVEY (ENCELURB)

// BEGIN ENOE (LABOR FORCE SURVEY)
if (`66_enoe_read') do "$scripts/66_enoe_read.do"
	** INPUTS:
	**  "data/ENOE/employ_survey_dataset.dta"
		// raw merged ENOE sent by Laura Chioda (through 2016Q4)
	** OUTPUTS:
	**  "proc/enoe_all.dta" // _all refers to all sectors kept in the data

if (`67_enoe_convert') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/67_enoe_convert.R" "$logs/67_enoe_convert.log"
	** INPUTS:
	**  here::here("proc", "enoe_all.dta") // 68_enoe_read
	** OUTPUTS:
	**  here::here("proc", "enoe_all.rds")
	**  here::here("proc", "enoe_baseline.rds") // 2008Q1, to add as controls
	
if (`68_enoe_collapse') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/68_enoe_collapse.R" "$logs/68_enoe_collapse.log"
	** INPUTS: 
	**  here::here("proc", "enoe_baseline.rds") // 69_enoe_convert
	** OUTPUTS:
	**  here::here("proc", "enoe_baseline_mun.rds") and .dta
	
if (`69_enoe_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/69_enoe_event_dataprep.R" "$logs/69_enoe_event_dataprep.log"
	** INPUTS:
	**  here::here("proc", "enoe_all.rds") // 67_enoe_convert
	**  here::here("proc", "iter_mun.rds") // 23_iter_dataprep
	**  here::here("proc", "cards_mun.rds") // 29_cards_panel
	** OUTPUTS:
	**  here::here("proc", "enoe_cards_all.rds")
// END ENOE

// BEGIN CPI MICRODATA 
//  Note: run on laptop in RStudio; 
//   UTF-8 encoding not working properly on server for matching by municipality name
if (`70_cpix_read') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/70_cpix_read.R" "$logs/70_cpix_read.log"
  ** Read in the Banxico micro CPI data
  ** INPUTS
  **  here::here("data", "CPI", "INPC_02_14_Workhorse_MuniByMonth_02_14_d.dta")
  **   Banxico micro-CPI data from Atkin, Faber, Gonzalez-Navarro
  **  here::here("data", "INEGI", "cat_municipio_NOV2017.dbf")
  **   INEGI municipality catalog to merge on string municipality names
  ** OUTPUTS
  **  here::here("proc", "cpix.rds")
	**  here::here("proc", "cpix_baseline.rds") 
	
if (`71_cpix_collapse') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/71_cpix_collapse.R" "$logs/71_cpix_collapse.log"
	** Collapse data to municipality level to add as controls in regressions
	** INPUTS
	**  here::here("proc", "cpix_baseline.rds") # 70_cpix_read
	** OUTPUTS
	**  here::here("proc", "cpix_baseline_mun.rds") and .dta
	
if (`72_cpix_event_dataprep') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/72_cpix_event_dataprep.R" "$logs/72_cpix_event_dataprep.log"
  ** # Prepare micro CPI data for event study
  ** # INPUTS
  ** #  here::here("proc", "cpix.rds") # 70_cpix_read
	**    here::here("proc", "cards_mun.rds") # 29_cards_panel
	**    here::here("proc", "iter_mun.rds") # 23_iter_dataprep
  ** # OUTPUTS
  ** #  here::here("proc", "cpix_bim.rds")
// END CPI MICRODATA

// BEGIN ENCASDU (TRUST SURVEY)
if (`73_encasdu_convert') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/73_encasdu_convert.R" "$logs/73_encasdu_convert.log"	
	** Convert raw data from Prospera from .sav to .dta
	** INPUTS:
	**  list.files(path = here::here("data", "ENCASDU"), pattern = "*\\.sav") # raw ENCASDU data from Prospera
	** OUTPUTS
	**  here::here("proc", "ENCASDU", dta) # .dta of the same files
	
if (`74_encasdu_dataprep') do "$scripts/74_encasdu_dataprep.do"
	** INPUTS
	**  $proc/hogar_mapo_noviembre_2010.dta            // 73_encasdu_convert
	**  $proc/entrevistas_mapo_noviembre_2010.dta      // 73_encasdu_convert
	**  $proc/integrantes_mapo_noviembre_2010.dta      // 73_encasdu_convert
	**  $proc/hogar_educacion_diciembre_2010.dta       // 73_encasdu_convert
	**  $proc/entrevistas_educacion_noviembre_2010.dta // 73_encasdu_convert
	**  $proc/integrantes_educacion_diciembre_2010.dta // 73_encasdu_convert
	**  $proc/bdu_baseline.dta // 44_bdu_collapse
	**  $proc/bansefi_baseline_loc.dta // 14_bansefi_baseline
	**  $proc/cnbv_baseline_mun.dta // 49_cnbv_merge_locality
	**  $proc/cpix_baseline_mun.dta // 71_cpix_collapse
	**  $proc/enoe_baseline_mun.dta // 68_enoe_collapse
	** OUTPUTS
	**  $proc/encasdu_forreg.dta
// END ENCASDU (TRUST SURVEY)

// BEGIN MEDIOS DE PAGO (PAYMENT METHODS) 
if (`75_medios_de_pago_dataprep') do "$scripts/75_medios_de_pago_dataprep.do"
** Prepare data from Payment Methods survey
	** INPUTS
	**  $data/Medios_de_Pago/medios_pago_titular_beneficiarios.dta // raw data from Prospera: Medios de Pago survey
	**  $proc/bdu_baseline.dta // 44_bdu_collapse
	**  $proc/bansefi_baseline_loc.dta // 14_bansefi_baseline
	**  $proc/cnbv_baseline_mun.dta // 49_cnbv_merge_locality
	**  $proc/cpix_baseline_mun.dta // 71_cpix_collapse
	**  $proc/enoe_baseline_mun.dta // 68_enoe_collapse
	** OUTPUTS
	**  $proc/medios_de_pago.dta
// END MEDIOS DE PAGO (PAYMENT METHODS) 

*********************************************************************
// END SURVEY DATA PREP 
*********************************************************************

*********************************************************************
// BEGIN ADMIN DATA RESULTS
*********************************************************************
if (`76_ATM_use_regs') do "$scripts/76_ATM_use_regs.do"
	** Withdrawals at ATMs over time
	** INPUTS
	**  $proc/ATM_use.dta // ATM_use_dataprep.do 
	** OUTPUTS
	**  $proc/`outcome'.dta // foreach outcome in used_ATM used_POS
	**  $proc/`outcome'_N.dta

// Note the randomization inference do files are manually parallelized; 
//  in practice better to run many at once on the server rather than in this loop 
//  from the 00_run.do file.
// For example, simultaneously run:
//  nohup stata-mp -b do scripts/77_withdrawals_event_randinf.do 1 100 N_withdrawals & 
//  nohup stata-mp -b do scripts/77_withdrawals_event_randinf.do 101 200 N_withdrawals & 
//  nohup stata-mp -b do scripts/77_withdrawals_event_randinf.do 201 300 N_withdrawals & 
// etc.
local N_perm = 2000

if (`77_withdrawals_event_randinf') {
	** INPUTS
	**  $proc/account_withdrawals_forreg_withperm.dta // 19_withdrawals_event_dataprep
	** OUTPUTS 
	**  $proc/`mat_name'_`start_perm'_`end_perm'.dta 
	local start_perm = 1
	while `start_perm' < `N_perm' { // note actually ran these in parallel on server, not loop
		local end_perm = `start_perm' + 100 - 1
		do "$scripts/77_withdrawals_event_randinf.do" ///
			`start_perm' `end_perm' N_withdrawals	// defined at top of do file in args
		local start_perm = `end_perm' + 1
	}
}
	
if (`78_savings_event_randinf') {
	** INPUTS
	**  "$proc/netsavings_forreg_withperm.dta // 20_savings_event_dataprep
	** OUTPUTS 
	**  $proc/`mat_name'_`start_perm'_`end_perm'.dta 
	local start_perm = 1
	while `start_perm' < `N_perm' { // note actually ran these in parallel on server, not loop
		local end_perm = `start_perm' + 100 - 1
		do "$scripts/78_savings_event_randinf.do" ///
			`start_perm' `end_perm' net_savings_ind_0_w5 // defined at top of do file in args
		local start_perm = `end_perm' + 1 
	}
}	

if (`79_savings_takeup') do "$scripts/79_savings_takeup.do"
	** Indicator for when saving
	** INPUTS
	**  $proc/netsavings_forreg.dta // 20_savings_event_dataprep
	** OUTPUTS
	**  $proc/proportion_saving.dta
	**  $proc/proportion_saving_N.dta
	**  $proc/savings_st.dta
	**  $proc/savings_st_N.dta

if (`80_balance_checks_event_randinf') {
	** INPUTS
	**  $proc/balance_checks_forreg_withperm.dta // 16_balance_checks_dataprep
	** OUTPUTS 
	**  $proc/`mat_name'_`start_perm'_`end_perm'.dta 
	local start_perm = 1
	while `start_perm' < `N_perm' { // note actually ran these in parallel on server, not loop
		local end_perm = `start_perm' + 100 - 1
		do "$scripts/80_balance_checks_event_randinf.do" ///
			`start_perm' `end_perm' // defined at top of do file in args
			// for this one there are multiple variables in the do file
		local start_perm = `end_perm' + 1 
	}
}	

if (`81_withdrawals_event') do "$scripts/81_withdrawals_event.do"
	** INPUTS
	**  $proc/account_withdrawals_forreg.dta // withdrawals_eventstudy_dataprep.do
	** OUTPUTS
	**  $proc/`depvar'`_controls'.dta // event study results
	**  $proc/`depvar'`_controls'_N.dta // N for tables 
	**  $proc/`mat_name'_permuted_t.dta // permuted test statistics for randomization inference
	**  $proc/`depvar'`_controls'_teststat.dta
	
if (`82_savings_event') do	"$scripts/82_savings_event.do"
	** Event study of savings variables
	** INPUTS
	**  $proc/netsavings_forreg.dta // 20_savings_event_dataprep
	** OUTPUT GRAPHS
	**  $proc/`depvar'`_controls'.dta // event study results
	**  $proc/`depvar'`_controls'_N.dta // N for tables 
	**  $proc/`mat_name'_permuted_t.dta // permuted test statistics for randomization inference
	**  $proc/`depvar'`_controls'_teststat.dta
	
if (`83_balance_checks_event') do "$scripts/83_balance_checks_event.do"
	** Event study of savings variables
	** INPUTS
	**  $proc/balance_checks_forreg.dta // 16_balance_checks_dataprep
	** OUTPUT GRAPHS
	**  $proc/`depvar'`_controls'.dta // event study results
	**  $proc/`depvar'`_controls'_N.dta // N for tables 
	**  $proc/`mat_name'_permuted_t.dta // permuted test statistics for randomization inference
	**  $proc/`depvar'`_controls'_teststat.dta
	
if (`84_balance_checks_pos_event') do "$scripts/84_balance_checks_pos_event.do"
	** INPUTS
	**  "$proc/transactions_by_day_forreg.dta" // 17_balance_checks_pos_dataprep
	** OUTPUTS
	**  $proc/`outcome'_`trans_type'_`mm'.dta
		
if (`85_event_randinf_pvalues') do "$scripts/85_event_randinf_pvalues.do"
	** INPUTS
	**  $proc/`mat_name'_permuted_t.dta // 81_withdrawals_event, 82_savings_event, 83_balance_checks_event
	**  $proc/`depvar'_teststat.dta // 81_withdrawals_event, 82_savings_event, 83_balance_checks_event
	** OUTPUTS
	**  "$proc/`depvar'_ri_p.dta" // vector of randomization inference p-values

*********************************************************************
// END ADMIN DATA RESULTS
*********************************************************************

*********************************************************************
// BEGIN HOUSEHOLD PANEL SURVEY RESULTS
*********************************************************************
if (`86_encelurb_regs') do "$scripts/86_encelurb_regs.do"
	** Effect of debit cards from household panel survey
	** INPUTS
	**  "$proc/encel_forreg_bycategory.dta" // 65_encelurb_bycategory_dataprep
	** OUTPUTS
	**  "$proc/encel_`mat'.dta" 

if (`87_encelurb_bycategory') do "$scripts/87_encelurb_bycategory.do" 
	** INPUTS
	**  "$proc/encel_forreg_bycategory.dta" // 65_encelurb_bycategory_dataprep
	** OUTPUTS 
	**  $proc/encel_bycategory_results.dta
	
if (`88_encelurb_heterogeneity') do "$scripts/88_encelurb_heterogeneity.do"
	** INPUTS
	**  $proc/encel_forreg_bycategory.dta // 65_encelurb_bycategory_dataprep
	** OUTPUTS
	**  $proc/encel_heterogeneity_`var'.dta

if (`89_medios_de_pago_regs') do "$scripts/89_medios_de_pago_regs.do"
	** INPUTS 
	**  "$proc/medios_de_pago.dta" // 75_medios_de_pago_dataprep
	** OUTPUTS
	**  "$proc/medios_de_pago_results.dta"
	**  "$proc/medios_de_pago_pvalues.dta"
	**  "$proc/medios_de_pago_balance_results.dta"
	**  "$proc/medios_de_pago_balance_pvalues.dta"

*********************************************************************
// END HOUSEHOLD PANEL SURVEY RESULTS
*********************************************************************
	
*********************************************************************
// BEGIN TABLES
*********************************************************************	
	
*************
** TABLE 1 **
*************
** Table 1 contains information about each survey; created manually

*************
** TABLE 2 **
*************
if (`90_locality_discrete_time_table') do "$scripts/90_locality_discrete_time_table.do"
	** INPUTS
	**  $proc/locality_for_discretetime.dta // 56_locality_discrete_dataprep
	** OUTPUTS
	**  $tables/locality_discrete_time.tex // Table 2
	
**********************************
** TABLE 3a left panel, TABLE 7 **
**********************************
if (`91_encasdu_table') do "$scripts/91_encasdu_table.do"
	** INPUTS
	** 	"$proc/encasdu_forreg.dta" // 74_encasdu_dataprep
	** OUTPUTS
	**  $tables/encasdu_balance_`time'.tex // Table 3a right panel
	**  $tables/encasdu_`time'.tex // Table 7
		
*************************************
** TABLE 3a right panel, TABLE B.8 **
*************************************
if (`92_medios_de_pago_table') do "$scripts/92_medios_de_pago_table.do"
	** INPUTS
	**  "$proc/medios_de_pago_results.dta" // 89_medios_de_pago_regs
	**  "$proc/medios_de_pago_pvalues.dta" // 89_medios_de_pago_regs
	**  "$proc/medios_de_pago_balance_results.dta" // 89_medios_de_pago_regs
	**  "$proc/medios_de_pago_balance_pvalues.dta" // 89_medios_de_pago_regs
	** OUTPUTS
	**  $tables/medios_de_pago_balance_`time'.tex // Table 3a left panel
	**  $tables/medios_de_pago_`time'.tex // Table B.8
	
***********************
** TABLE 3b, TABLE 5 **
***********************
if (`93_encelurb_table') do "$scripts/93_encelurb_table.do"
	** Effect of debit cards from household panel survey
	** INPUTS
	**  "$proc/encel_`mat'.dta" // 86_encelurb_regs
	** OUTPUTS
	**  $tables/encelurb_parallel_`time'.tex // Table 3b
	**  $tables/encelurb_`time'.tex // Table 5

****************************************
** TABLE 4, TABLES B.2, B.3, B.4, B.5 **
****************************************
if (`94_eventstudy_table') do "$scripts/94_eventstudy_table.do"
	** INPUTS
	**  $proc/`depvar'.dta 
	**  $proc/`depvar'_N.dta 
		// 81_withdrawals_event
		// 82_savings_event
		// 83_balance_checks_event
		// 76_ATM_use_regs
		// 79_savings_takeup
	**  $proc/`depvar'_ri_p.dta // 85_event_randinf_pvalues
	** OUTPUTS
	**  $tables/eventstudy_`time'.tex // Table 4
	**  $tables/`depvar'_`time'.tex // Tables B.2, B.3
	**  $tables/event_means_`time'.tex // Table B.4
	**  $tables/savings_since_takeup_`time'.tex // Table B.5

*************
** TABLE 6 **
*************
if (`95_encelurb_bycategory_table') do "$scripts/95_encelurb_bycategory_table.do"
	** INPUTS
	**  $proc/encel_bycategory_results.dta // encelurb_bycategory
	** OUTPUTS
	**  $tables/encel_bycategory_`time'.tex // Table 6
	
*********************************************************************
// END TABLES
*********************************************************************	

*********************************************************************
// BEGIN FIGURES
*********************************************************************	
	
**************
** FIGURE 1 **
**************
if (`96_comparison_figure') do "$scripts/96_comparison_figure.do"
	** Compares our effect size to those from other studies
	**  (Note: uses replication data when available, or coefficients and 
	**   standard errors from papers otherwise)
	** INPUTS
	**  $data/comparison/savings_rates_metadata.xlsx // metadata on studies
	**  $data/Drexler_etal_2014_AEJApplied/kisDataFinal.dta
	**		// Replication data for Drexler et al. (AEJ Applied)
	**	$data/Dupas_Robinson_2013_AER/HARP_ROSCA_final.dta
	**  	// Replication data for Dupas and Robinson (AER)
	**  $data/Karlan_etal_2016_MgmtSci/analysis_dataallcountries.dta
	**		// Replication data for Karlan et al. (Mgmt Sci)
	**  $data/Karlan_Zinman_2017/proc/dreamfinal_for_analysis.dta
	**		// Replication data for Karlan and Zinman
	**  $data/Prina_2015_JDE/Nepal_JDE_R1.dta
	**		// Replication data for Prina (JDE)
	**  $data/Sayinzoga_etal_2016_EJ/Panel_FL.dta
	**		// Replication data for Sayinzoga et al. (EJ)
	**  (Used coefficients and standard errors from papers when replication
	**   data not available)
	** OUTPUTS
	**  $proc/savings_rates.csv

if (`97_comparison_figure_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/97_comparison_figure_graph.R" "$logs/97_comparison_figure_graph.log"
	** Produce comparison figure (using R's forest() function)
	** INPUTS
	**  $proc/savings_rates.csv // 96_comparison_figure
	** OUTPUTS
	**  here::here("graphs", "comparison_figure.eps") # Figure 1
	
**************
** FIGURE 2 **
**************		
** PANEL A
if (`98_rollout_graph') do "$scripts/98_rollout_graph.do"
	** Timing of rollout using admin data from Bansefi
	** INPUTS
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	** OUTPUTS
	**  $graphs/timing_bansefi_`lang'`pres'.eps # Figure 2a

** PANEL B 
if (`99_loc_rollout_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/99_loc_rollout_graph.R" "$logs/99_loc_rollout_graph.log"
** source(here::here("scripts", "loc_rollout.R")) # X
** # INPUTS
** #  Locality shapefiles: here::here("data", "shapefiles", "INEGI", state), suffix "_localidad_urbana_y_rural_amanzanada"
** #  State shapefiles: here::here("data", "shapefiles", "INEGI", state), suffix "_entidad"
** #  here::here("proc", "cards_pob.rds") # 29_cards_panel
** # OUTPUTS
** #  here::here("graphs", "rollout.eps") # Figure 2b
	
**************
** FIGURE 3 **	
**************
** PANEL A1) Log wage
if (`100_enoe_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/100_enoe_event_graph.R" "$logs/100_enoe_event_graph.log"
	** Event study of effect of Prospera expansion on wages: pre-trends
	** INPUTS:
	**  here::here("proc", "enoe_cards_all.rds") // 69_enoe_event_dataprep
	** OUTPUTS
	**  # Figure 3a left

** PANEL A2) Log food prices
if (`101_cpix_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/101_cpix_event_graph.R" "$logs/101_cpix_event_graph.log"
  ** Event study with micro CPI data: pre-trends
  ** INPUTS
  **  here::here("proc", "cpix_bim.rds") # 72_cpix_event_dataprep
  ** OUTPUTS
  **  # Figure 3a middle

** PANEL A3) Log POS terminals
if (`102_bdu_allgiro_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/102_bdu_allgiro_event_graph.R" "$logs/102_bdu_allgiro_event_graph.log"
	** POS adoption event study: pre-trends
	** INPUTS
	**  here::here("proc", "bdu_cp_allgiro_forreg.rds") # 45_bdu_allgiro_event_dataprep
	** OUTPUTS 
	**  # Figure 3a right

** PANEL B) Municipality-level data from CNBV
if (`103_cnbv_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/103_cnbv_event_graph.R" "$logs/103_cnbv_event_graph.log"
	** CNBV event study: pre-trends
	** INPUTS
	**  here::here("proc", "cnbv_forreg.rds") # 48_cnbv_event_dataprep
	** OUTPUTS
	**  # Figure 3b left, middle, right

** PANEL C) Microdata from Bansefi
if (`104_bansefi_pre_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/104_bansefi_pre_graph.R" "$logs/104_bansefi_pre_graph.log"
	** INPUTS
	**  here::here("proc", "net_savings_ind_0_w5.dta") # 82_savings_event
	**  here::here("proc", "net_savings_ind_0_ln_event.dta") # 82_savings_event
	**  here::here("proc", "N_withdrawals.dta") # 81_withdrawals_event
	** OUTPUTS
	**  # Figure 3c left, middle, right
	
**************
** FIGURE 4 **
**************		
if (`105_ATM_use_graph') do "$scripts/105_ATM_use_graph.do"
	** INPUTS
	**  "$proc/used_ATM.dta" foreach outcome in used_ATM used_POS // 76_ATM_use_regs
	** OUTPUTS
	**  $graphs/used_ATM_event_`time'.pdf // Figure 4
	
**************
** FIGURE 5 **
**************
if (`106_withdrawals_deposits_graph') do "$scripts/106_withdrawals_deposits_graph.do"
	** INPUTS
	**  $proc/account_withdrawals_deposits.dta // 18_withdrawals_dataprep
	** OUTPUTS
	**  $graphs/dist_withdrawal_deposits_`time'.eps // Figure 5
		
*****************
** FIGURE 6, 8 **
*****************
if (`107_eventstudy_graph') do "$scripts/107_eventstudy_graph.do"
	** INPUTS
	**  $proc/`depvar'.dta 
		// 81_withdrawals_event
		// 82_savings_event
		// 83_balance_checks_event
	** OUTPUTS 
	**  $graphs/`depvar'_event_`time'.pdf // Figures 6, 8

**************
** FIGURE 7 **
**************
if (`108_savings_takeup_graph') do "$scripts/108_savings_takeup_graph.do"
	** INPUTS
	**  $proc/proportion_saving.dta // 79_savings_takeup
	**  $proc/savings_st.dta // 79_savings_takeup
	** OUTPUTS
	**  $graphs/proportion_saving_`time'.pdf // Figure 7a
	**  $graphs/saving_since_takeup_`time'.pdf // Figure 7b
	
*********************************************************************
// END FIGURES
*********************************************************************	
	
*********************************************************************
// BEGIN APPENDIX TABLES
*********************************************************************	

**************
** TABLE B1 **
**************	
if (`109_account_summary_stats_table') do "$scripts/109_account_summary_stats_table.do"
	** INPUTS
	**  $proc/bansefi_baseline.dta // 14_bansefi_baseline
	** OUTPUTS
	**  $tables/account_summary_stats.tex // Table B.1

***************************
** TABLES B2, B3, B4, B5 **
***************************
** see above

**************
** TABLE B6 **
**************
if (`110_encelurb_heterog_table') do "$scripts/110_encelurb_heterog_table.do"
	** INPUTS
	**  $proc/encel_heterogeneity_totcons.dta // encelurb_heterogeneity
	** OUTPUTS
	**  $tables/encel_heterogeneity_totcons_`time'.tex // Table B.6

**************
** TABLE B7 **
**************
if (`111_supplyside_table') do "$scripts/111_supplyside_table.do"
	** INPUTS
	**  $proc/cnbv_supply.dta // 52_cnbv_supplyside_dataprep
	** OUTPUTS
	**  $tables/supplyside_`date'.tex // Table B.7

**************
** TABLE B8 **
**************
** see above

*********************************************************************
// END APPENDIX TABLES
*********************************************************************

*********************************************************************
// BEGIN APPENDIX FIGURES
*********************************************************************	

***************
** FIGURE B1 **
***************
** A) HOUSEHOLD PANEL SURVEY
if (`112_encelurb_histogram_graph') do "$scripts/112_encelurb_histogram_graph.do"
	** INPUTS 
	**  $proc/encel_forreg_bycategory.dta // 65_encelurb_bycategory_dataprep
	** OUTPUTS
	**  $graphs/hist_encel.eps // Figure B.1a
	
if (`113_medios_histogram_graph') do "$scripts/113_medios_histogram_graph.do"
	** INPUTS
	**  $data/Medios_de_Pago/medios_pago_titular_beneficiarios.dta // raw data
	** OUTPUTS
	**  $graphs/hist_medios_de_pago.eps // Figure B.1b

if (`114_encasdu_histogram_graph') do "$scripts/114_encasdu_histogram_graph.do"	
	** INPUTS
	**  $proc/encasdu_forreg.dta // 74_encasdu_dataprep
	** OUTPUTS
	**  $graphs/hist_encasdu.eps // Figure B.1c

***************
** FIGURE B2 **
***************
** NUMBER OF BENEFICIARIES
if (`115_prospera_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/115_prospera_event_graph.R" "$logs/115_prospera_event_graph.log"
	** Event study of number of beneficiaries by year
	** INPUTS
	**  here::here("proc", "prospera_forreg.rds") # 32_cards_event_dataprep
	** OUTPUTS
	**  Figure B.2a
	
** POLITICAL PARTY IN POWER
if (`116_elections_event_graph') shell "$R_path" CMD BATCH --vanilla -q ///
	"$scripts/116_elections_event_graph.R" "$logs/116_elections_event_graph.log"
** # INPUTS
** #  here::here("proc", "elections_forreg.rds") # 54_elections_event_dataprep
** # OUTPUTS
** #  Figure B.2b

***************
** FIGURE B3 **
***************
if (`117_withdrawals_control_graph') do "$scripts/117_withdrawals_control_graph.do"
	** Number of withdrawals over calendar time in the control group
	** INPUTS
	**  $proc/transactions_redef_bim.dta // 08_bansefi_transactions_redef
	**  $proc/bim_switch_integrante.dta // 06_bansefi_bimswitch
	**  $proc/integrante_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	** OUTPUTS
	**  $graphs/timeline_withdrawals_control`sample'_`time'.eps // Figure B.3

***************
** FIGURE B4 **
***************
if (`118_nonOportunidades_graph') do "$scripts/118_nonOportunidades_graph.do"
	** Savings among non-beneficiaries
	** INPUTS
	**  $proc/nonOp_endbalance.dta // 48_bansefi_nonOp_endbalance
	**  $proc/cuenta_sucursal.dta // 05_bansefi_sucursales_dataprep
	**  $proc/DatosGenerales.dta // 02_bansefi_generales_dataprep
	**  $proc/branch_loc.dta // 13_branches_localities
	** OUTPUTS
	**  $graphs/nonOportunidades_saving_`time'.eps

***************
** FIGURE B5 **
***************
** Stylistic illustration done in Tikz

***************
** FIGURE B6 **
***************
if (`119_balance_checks_pos_graph') do "$scripts/119_balance_checks_pos_graph.do"
	** Number of balance checks within 7 days
	** INPUTS
	**  $proc/n_day_bc_POS_means.dta // 84_balance_checks_pos_event
	** OUTPUTS
	**  $graphs/n_day_bc_POS_means_`time'.pdf // Figure B.6

***************
** FIGURE B7 **
***************
if (`120_balance_checks_corr_graph') do "$scripts/120_balance_checks_corr_graph.do"
	** Within account correlation between balance checks and savings
	** INPUTS	
	**  $proc/balance_checks_forreg.dta // 16_balance_checks_dataprep
	**  $proc/netsavings_forreg.dta // 20_savings_event_dataprep
	** OUTPUTS
	**  $graphs/`var'_corr_`time'`sample'.eps // Figure B.7

*********************************************************************
// END APPENDIX FIGURES
*********************************************************************	

