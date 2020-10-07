** MERGE ENCELURB 2002, 2003, 2004, 2009
**  Sean Higgins
**  created July 7 2014

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 63_encelurb_merge
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local weeks_per_month = 30/7 // because they don't actually ask about last month, they ask
	// "en los últimos 30 días"
local weeks_per_month_precise = 4.34524 // goo.gl/lvFss5
local weeks_per_year = 52.1429 // goo.gl/3Ttao7

local preyearlist 2002 2003 2004
local yearlist `preyearlist' 2009

**************************
** PRELIMINARY PROGRAMS **
**************************
// Load in preliminary programs 
include "$scripts/encelurb_dataprep_preliminary.doh" // !include!

**********
** DATA **
**********
use "$proc/encel09_hh.dta", clear

************
** APPEND **
************
foreach year of local preyearlist {
	local yy = substr("`year'",3,4)
	append using "$proc/encel`yy'_hh.dta"
}
foreach year of local yearlist {
	tempvar y`year' 
	gen `y`year'' = (year==`year')
	sort folio year, stable
	by folio: egen y`year' = max(`y`year'')
}

// Descriptives on panel structure:
gen n_panel = y2002 + y2003 + y2004 + y2009
sort folio year
by folio: gen byte tag = (_n == 1)
tab n_panel if _n == 1
tab n_panel if _n == 1 & y2009==1 // result: 86% of the 6272 from 2009 have obs in all years; another 10% in 3 years, 4% in 2 years (all >=2 years)
tab n_panel if _n == 1 & y2009==1 & y2004==1 // 5777 meet if condition (=92% of 2009 obs): 94% have obs in all years, 6% in 3 years and 0.4% in 2 years

***********************
** FURTHER DATA PREP **
***********************
// OP BEN VARIABLE (USING SURVEY DATA, NOT ADMINISTRATIVE)
gen panel0203 = (y2002==1 & y2003==1) & (year==2002 | year==2003) 
gen panel0304 = (y2003==1 & y2004==1) & (year==2003 | year==2004) 
gen panel020304 = (y2002==1 & y2003==1 & y2004==1) & (year==2002 | year==2003 | year==2004)
gen panel02030409 = (y2002==1 & y2003==1 & y2004==1 & y2009==1) & (year==2002 | year==2003 | year==2004 | year==2009)
gen panel0409 = (y2004==1 & y2009==1) & (year==2004 | year==2009) // want =1 only for the obs in each year to get the right restriction on my DD reg
local i2003 1/2 
local i2004 1/4
local i2009 1/4
foreach y in 2003 2004 2009 { // not 2002 bc no op_ben in that year, 2003 only had op_ben1 and 3 (no folio Q)
	forval i=`i`y'' {
		tempvar op_ben`i'_`y'
		gen `op_ben`i'_`y'' = op_ben`i' if year==`y'
		bys folio: egen op_ben`i'_`y' = max(`op_ben`i'_`y'')
		di "`y' `i'"
		tab op_ben`i'_`y'
	}
}
forval i=1/4 {
	if `i'<=2 gen op_ben`i'_pre = max(op_ben`i'_2003,op_ben`i'_2004)
	else      gen op_ben`i'_pre = op_ben`i'_2004
}

forval i=1/4 {
	gen op_ben`i'_either = max(op_ben`i'_2004,op_ben`i'_2009) 
	gen op_ben`i'_both   = min(op_ben`i'_2004,op_ben`i'_2009) 
	if `i'<=2 {
		gen op_ben`i'_any = max(op_ben`i'_2003,op_ben`i'_2004,op_ben`i'_2009)
		gen op_ben`i'_all = min(op_ben`i'_2003,op_ben`i'_2004,op_ben`i'_2009)
	}
	foreach x in either both any all {
		di "`i' `x'"
		cap tab op_ben`i'_`x' // cap because op_ben`i'_all only exists for `i'<=2
	}
}

// EVERYTHING TO MONTHLY
foreach var of varlist *income* *totinc* { // income vars yearly
	replace `var' = `var'/12 // yearly to monthly
}
foreach var of varlist cons_* { // all cons_ variables were weekly
	replace `var' = `var'*`weeks_per_month_precise' 
}

// SQUARED VARS
foreach var in escolaridad_jefe edad_jefe {
	cap drop `var'_sq
	gen `var'_sq = `var'^2
}

// ASSET INDEX
#delimit ;
replace has_tv = max(has_tv_color, has_tv_cable) if year==2009;
replace has_electricos = 1 if has_compu==1
	| has_horno_elec==1
	| has_microonda==1
	| has_cafetera==1 ;
local assets_bothsurveys 
	has_auto
	has_camion
	has_moto
	has_tv 
	has_video
	has_radio
	has_lavadora
	has_estufa_gas
	has_refrig
	;
#delimit cr
myzscore `assets_bothsurveys', replace
pca `assets_bothsurveys' 
predict assetindex

// OTHER ADULT IN HOUSEHOLD (FOR DECISION MAKING)


// BASELINE
** vars from baseline
#delimit ;
local baselinelist
	p_*
	d_*
	piso* 
	sin_*
	oc_*
	trabajo_jefe
	escolaridad_jefe*
	edad_jefe*
	*head*
	has_other*
	cuenta_bancaria
	n_*
;
local power_vars
	edad_?
	escolaridad_?
	analfabeto_?
;
#delimit cr
// Baseline version of each variable
baselinify `baselinelist' `power_vars'

replace localidad=301310001 if localidad==301240159
	// Poza Rica, Papantla, Veracruz incorporated into Poza Rica de Hidalgo, Poza Rica de Hidalgo, Veracruz
	// (see http://goo.gl/jvOjev)
	// result: (72 real changes made) - those living in this locality
uniquevals localidad // 179 localities
de
merge m:1 localidad using "$proc/urban_locs.dta", gen(m_locs)
fre T
uniquevals localidad if T!=. & m_locs==3 // 81 localities
gen after = (year==2009)
foreach var in localidad ent mun loc T {
	forval n=2/4 {
		tempvar `var'0`n'
		gen double ``var'0`n'' = `var' if year==200`n'
		bys folio: egen double `var'0`n' = max(``var'0`n'') // confirmed for T04 that max(.,.) is .; . only treated as 0 if other non-zero in max()
	}
	** T04 for those that were not in 2004:
	replace `var'04 = `var'03 if y2003==1 & y2004==0 
	replace `var'04 = `var'02 if y2002==1 & y2003==0 & y2004==0
}
** test above:
tab T T04 if year==2009, m

gen DD = T04*after
gen DDold = T*after

drop if mi(year) // extra localities
cap drop grd_rez v2 v4 v6 // strings

// individual and locality baseline controls for regressions
#delimit ;
local X trabajo_jefe 
	escolaridad_jefe  escolaridad_jefe_sq 
	edad_jefe  edad_jefe_sq 
	cuenta_bancaria 
	p_derechohabiencia 
	 p_analfabeta_15_
	p_no_asiste_6_14
	p_basica_inc_15_ 
	d_menos9_15_29  
	piso_tierra
	sin_sanitario 
	sin_agua
	sin_drenaje
	oc_por_cuarto   
	n_schoolage  n_elderly 
	;
local Wj 
	ianalf-inoelec 
	inolav
	inoref
	indice_rezago
	poblacion_total
	;
#delimit cr
foreach var of varlist `X' {
	gen `var'xafter = `var'*after
	foreach year in `preyearlist' _bl {
		cap confirm number `year'
		if !_rc local yy = substr("`year'",3,2)
		else local yy `year'
		cap drop `var'`yy'xafter
		gen `var'`yy'xafter = `var'`yy'*after
	}
}
foreach var of varlist `Wj' {
	gen `var'xafter = `var'*after
	local Wjxafter `Wjxafter' `var'xafter
}

// HH FE
set matsize 10000
cap drop folio_num
encode folio, gen(folio_num)
xtset folio_num year

cap drop __*
tempfile mergemaster
save `mergemaster', replace

*************************
** MERGE TRANSFER DATA **
*************************
// 2002-2010
use "$data/Prospera/Transfers/Encel_sample/encelurb_trans_2002_2010.dta", clear
	// raw data sent by Raul Perez at Prospera in Mar 2015
lower
foreach var of varlist * {
	local x : type `var'
	if !(strpos("`x'","str")) /// i.e., if not a string var
		replace `var'=0 if `var'<0 // a few negative transfer amounts for some reason
}
rename id_hogar folio
sort folio
tempvar tag
qui bys folio: gen `tag' = (_N>1) // 178
** br if tag // looks like pure duplicates
** to check if pure duplicates:
qui count if `tag'==1
local Ntag = r(N)
foreach var of varlist tot_* {
	tempvar temptag
	qui bysort folio `var': gen `temptag' = (_N>1)
	qui count if `temptag'==1
	assert r(N) == `Ntag'
}
bys folio: drop if _n>1 // drop duplicates
cap drop __*
tempfile mergeusing
save `mergeusing', replace // 5936 obs, 314 vars

// 2010-2013 
local m=0
forval year=2010/2013 {
	local yy = substr("`year'",3,2)
	forval b=1/6 {
		// earliest is 3rd bimester 2010, latest is 3rd bimester 2013
		if (`year'==2010 & `b'<3) | (`year'==2013 & `b'>3) continue // break this iteration of loop
		// (Earlier 2010 was merged in in the 2002-2010 file above, 
		//  and data ends in third bimester of 2013)
		local ++m // did at top of loop rather than bottom because after loop I use `m'
		use "$data/Prospera/Transfers/Encel_sample/encelurb_trans`year'`b'.dta", clear
			// raw data sent by Raul Perez at Prospera in Feb 2015
		lower // Sean's user written ado file
		rename monto_to tot // monto_total renamed to tot to match 2002-2010 data set
		foreach var of varlist * {
			local x : type `var'
			if !(strpos("`x'","str")) /// i.e., if not a string var
				replace `var'=0 if `var'<0 // a few negative transfer amounts for some reason
			rename `var' `var'_`b'_`yy' // so that the varnames match 2002-2010 data
		}
		rename id_hogar folio
		sort folio tot
		tempvar tag tag2
		bys folio: gen `tag' = (_N>1)
		count if `tag'==1
		by folio tot: gen `tag2' = (_N>1)
		count if `tag2'==1
		// result: not all pure duplicates like in 2002-2010, but vast majority are
		// check with Raul what might explain these;
		// in the meantime drop duplicates 
		bys folio: drop if _n<_N // (using obs with higher value for tot since I sorted by folio tot above)
		drop bim // not needed since varnames now contain bimester
		tempfile mergeusing`m'
		save `mergeusing`m'', replace
	}
}
di "`m'"
use `mergemaster', clear // 53175 obs, 1930 vars
merge m:1 folio using `mergeusing', gen(m_transfers2002_2010) assert(1 3) 
	** // NOTE got rid of assert(1 3) above when dropped hh's that didnt exist in personas data
	** // which means now there are some obs in transfers data without matches
forval i=1/`m' { // `m' is total number of bimesters for 2010-2013 from above loops
	merge m:1 folio using `mergeusing`i'', gen(m_transfers`i') assert(1 3)
		** // NOTE got rid of assert(1 3) above when dropped hh's that didnt exist in personas data
		** // which means now there are some obs in transfers data without matches
}
local i=1
foreach var of varlist m_transfers* {
	if `i'==1 local m_transfers_list `var'
	else local m_transfers_list `m_transfers_list', `var' // did as separate lines because needs comma
	local ++i
}
gen m_transfers = max(`m_transfers_list') // =3 if merged with at least one of the files
drop m_transfers?* // all except m_transfers (that's why the ? wildcard is included)
gen op_ben = (m_transfers==3)

// DATE OF INTERVIEW
tempvar dateint
gen `dateint' = date(fecha,"DMY")
format `dateint' %td
bys folio: egen dateint = max(`dateint') // for all panel obs
format dateint %td
gen fechay = year(dateint) // just the year (2009 or 2010)

// RECIPIENT OF OPORTUNIDADES? (USING ADMINISTRATIVE DATA ON TRANSFERS)
sort folio
gen rec_pre09 = 0
gen rec_post09 = 0
forval n=2/13 { // years of transfer data
	if `n'<10 local n = "0" + "`n'"
	gen rec_`n' = 0
	forval i=1/6 {
		if (`n'==10 & `i'==2) | (`n'==13 & `i'>3) continue // break out of loop
			// for bimesters I don't have the data
		gen rec_`i'_`n' = (tot_`i'_`n'!=. & tot_`i'_`n'!=0)
		replace rec_`n' = 1 if rec_`i'_`n'==1
	}
	if `n'<9 {
		replace rec_pre09 = 1 if rec_`n'==1
	}
	if `n'>9 {
		replace rec_post09 = 1 if rec_`n'==1
	}
}

// GEOGRAPHIC VARS
** region
foreach yy in "" "02" "03" "04" {
	gen region`yy' = .
	// Regions from https://es.wikipedia.org/wiki/Regiones_de_M%C3%A9xico
	replace region`yy' = 1 if /// Noroeste
		ent`yy'==26  | /// Sonora
		ent`yy'==25     // Sinaloa
	replace region`yy' = 2 if /// Noreste
		ent`yy'==28   // Tamaulipas
	replace region`yy' = 3 if /// Oeste
		ent`yy'==7  | /// Colima
		ent`yy'==15    // Michoacan
	replace region`yy' = 4 if ///  Este
		ent`yy'==13 | /// Hidalgo	
		ent`yy'==21 | /// Puebla
		ent`yy'==29 | /// Tlaxcala	
		ent`yy'==30    // Veracruz
	replace region`yy' = 5 if /// Centronorte
		ent`yy'==11 | /// Guanajuato
		ent`yy'==24    // San Luis Potosi
	replace region`yy' = 6 if /// Centrosur
		ent`yy'==17 | /// Mexico	
		ent`yy'==16    // Morelos
	replace region`yy' = 7 if /// Suroeste 
		ent`yy'==6  | /// Chiapas
		ent`yy'==12    // Guerrero
	replace region`yy' = 8 if /// Sureste
		ent`yy'==4  | /// Campeche
		ent`yy'==27   //  Tabasco
}
foreach x in region ent mun {
	replace `x'02 = `x'03 if mi(`x'02) & !mi(`x'03)
	replace `x'02 = `x'04 if mi(`x'02) & mi(`x'03) & !mi(`x'04)
}

** municipality
gen muncode = ent*1000 + mun
foreach yy in 02 03 04 {
	gen muncode`yy' = ent`yy'*1000 + mun`yy'
}
	
// DROP
sort folio year
** for drop var (dealing with extreme outliers on individual questions)
tempvar drop
gen byte `drop' = (drop==1)
by folio : egen byte m_drop_before = min(`drop') if year<=2004 // only =1 if missing ALL before
gen m_drop_after = drop if year==2009
tempvar m_drop
gen `m_drop' = max(m_drop_before,m_drop_after)
by folio : egen m_drop = max(`m_drop')

de localidad*

************************************************************
** MERGE WITH LOCALITY SWITCH DATA OBTAINED IN APRIL 2015 **
************************************************************
cap drop _m
merge m:1 localidad04 using "$proc/familias_loc.dta", keepusing(bimswitch* wave* instpaga) 
	// _m==1 not matched from master are semi-urban localities (2500-15000)
	// _m==2 not matched from using (localities not in sample) or
	// _m==3 matched 
keep if _m==3
drop _m

// Correcting bimswitch based on Oportunidades documentation
//  about delays in receiving cards relative to when reported
gen year_switch = real(substr(string(bimswitch),1,4))
gen bim_of_year_switch = real(substr(string(bimswitch),5,1))

tab bimswitch
gen earliest = (bimswitch==20086 | bimswitch==20091)
#delimit ;
replace bim_of_year_switch = 
	bim_of_year_switch - 2
	if bimswitch>20092 & bimswitch<=20094 ; 
replace bim_of_year_switch = 6 
	if year_switch==2009 & bimswitch<=20092;
replace year_switch = year_switch - 1 
	if year_switch==2009 & bimswitch<=20092;
#delimit cr

drop bimswitch
gen bimswitch = real(string(year_switch) + string(bim_of_year_switch))
drop *_switch
tab bimswitch

// TREATMENT LOCALITIES BY TIME OF LAST SURVEY WAVE
gen lastbim=20095 // due to 1-bimester delay

cap drop *T04s DD04s *earlyT
gen T04s = 1 if (bimswitch<=lastbim & !missing(bimswitch)) & T04!=.
replace T04s = 0 if T04!=. & T04s!=1
// leave those who never switched as T04s==. so they will be excluded from reg
gen DD04s = T04s*after

** double check:
cap drop __* // was getting an error
sort folio_num
by folio_num : egen max_T04s = max(T04s)
by folio_num : egen min_T04s = min(T04s)
assert max_T04s==min_T04s

// IDENTIFYING BENEFICIARIES
foreach x in pre post {
	cap drop rec_`x'_s
	gen rec_`x'_s = rec_`x'09
}
local opben ((rec_5_09==1 & fechay==2009) | (rec_6_09==1 & fechay==2010))
forval i=1/4 {
	replace rec_pre_s = 1 if rec_`i'_09==1
}
forval i=6/6 {
	replace rec_post_s = 1 if rec_`i'_09==1
}
replace rec_09 = max(rec_1_09,rec_2_09,rec_3_09,rec_4_09,rec_5_09,rec_6_09)
assert !mi(rec_post09) 

// Rename consump vars
rename cons_week totcons

*************
** WRAP UP **
*************
drop if mustdrop==1 // weren't interviewed
cap drop __* // any remaining temporary variables
drop v? v?? v??? f?_* // variables I don't need
compress
save "$proc/encel_merged.dta", replace
cap log close
exit


