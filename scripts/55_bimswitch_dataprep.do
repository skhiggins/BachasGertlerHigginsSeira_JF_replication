** USING DATA ON PAYMENT METHOD EACH BIMESTER IN EACH LOCALITY TO DETERMINE WHEN SWITCHED
**  created April 25 2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 55_bimswitch_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
use "$proc/fams_prosp.dta", clear // cards_read.R 
merge m:1 localidad using "$proc/iter_urban.dta" // iter_merge.R // to get population
keep if _merge==3
	// can not match from master if small loc not in ITER?
	// can not match from using if not a Prospera locality
uniquevals localidad if pobtot_2005 > 15000 & !missing(pobtot_2005) // 550
uniquevals localidad if pobtot_2010 > 15000 & !missing(pobtot_2010) // 626, lost a few

sort localidad year bim 

// mark the bimester the locality switched:
gen switch = strpos(descrip,"TARJETA DE D") & !strpos(descrip[_n-1],"TARJETA DE D") & localidad==localidad[_n-1]
by localidad: replace switch = 1 if strpos(descrip,"TARJETA DE D") & _n==1 // newly incorporated localities
// payment method before switch
by localidad : egen anyswitch = max(switch)
sort localidad year bim 
tab anyswitch if year=="2014" & bim=="6" // all =1
gen ybim = year + bim
destring ybim, replace
by localidad : egen minswitch = min(ybim) if switch==1
tab ybim minswitch if switch==1 & minswitch!=ybim 

replace switch = 0 if switch==1 & minswitch!=ybim
drop minswitch
duplicates report localidad switch if switch==1
tab switch
cap gen last = ybim==20146

tempvar preswitch
gen `preswitch' = descrip[_n-1] if switch==1 & ybim[_n-1]!=ybim[_n] & localidad[_n-1]==localidad[_n] // payment method before switch
replace `preswitch' = descrip[_n-2] if switch==1 & ybim[_n-1]==ybim[_n] & ybim[_n-1]!=ybim[_n] & localidad[_n-2]==localidad[_n]
assert !(ybim[_n-2]==ybim[_n] & localidad[_n-2]==localidad[_n])
replace `preswitch' = "new" if switch==1 & localidad[_n-1]!=localidad[_n] // new to program
sort localidad `preswitch'
by localidad : gen preswitch = `preswitch'[_N] // same value for all bimester-obs within locality
sort localidad year bim
local start 20096
forval year = 2007/2014 {
	forval bim = 1/6 {
		if `year'`bim' < `start' continue
		tempvar descrip`year'`bim'
		gen `descrip`year'`bim'' = descripcio if ybim==`year'`bim'
		sort localidad `descrip`year'`bim''
		by localidad : gen descrip`year'`bim' = `descrip`year'`bim''[_N]
		
		replace preswitch = descrip`year'`bim' if anyswitch==0 & mi(preswitch)
	}
} 

** * for creating a data set with the bimester in which each locality switched, fams each bimester:
tempvar bimswitch
gen `bimswitch' = ybim if switch==1
by localidad : egen bimswitch = min(`bimswitch')
tab bimswitch

by localidad : gen tag = (_n==1)
tab bimswitch if tag

gen wave = 0
replace wave = 1 if bimswitch<=20096 // because of the +2
replace wave = 2 if wave!=1 & bimswitch<=20106 // with delay this includes the first bim 2011 from Pierre's data

// not part of control if didn't have savings accounts pre-card:
replace bimswitch = . if wave == 0 & !(strpos(preswitch,"ABONO"))
replace wave = . if wave == 0 & !(strpos(preswitch,"ABONO")) 

tab bimswitch if tag

bys wave: tab preswitch
** replace wave = . if !strpos(preswitch,"ABONO")
tab wave if tag // last is a tag
tab preswitch
tab bimswitch if tag & pobtot_2005 > 15000

sort localidad ybim
foreach x in descrip instpaga {
	cap by localidad : gen `x'20146 = `x'[_N] // the final (end 2014) payment method for each locality
}

** collapse to a data set with one observation for each locality, bimester of switch, families each bimester, ending payment method
local klist localidad ybim wave bimswitch preswitch *20146 pobtot* fams ///
	pct_* pro_c_vp ln_* n_bansefi*
local constlist = subinstr("`klist'","ybim","",.)
local constlist = subinstr("`constlist'","fams","",.)
keep `klist' 
order `klist'
collapse (sum) fams, by(`constlist' ybim) // this is because some locality-bimester pairs have 2 obs if 2 payment methods that bimester
dupcheck localidad ybim, assert

// 1) Create family level wide data set:
preserve
local klist localidad ybim wave bimswitch preswitch *20146 pobtot* fams
local constlist = subinstr("`klist'","ybim","",.)
local constlist = subinstr("`constlist'","fams","",.)
reshape wide fams, i(`constlist') j(ybim)
dupcheck localidad, assert

// for merge with ENCELURB data
destring localidad, gen(localidad04)

**********
** SAVE **
**********
save "$proc/familias_loc.dta", replace

// 2) Create locality-level characteristics data set
restore
sort localidad
by localidad: gen tag = (_n==1)
keep if tag // everything needed is constant within localidad except ybim
drop ybim

**********
** SAVE **
**********
cap drop __*
save "$proc/locality_chars.dta", replace

*************
** WRAP UP **
*************
log close
exit
