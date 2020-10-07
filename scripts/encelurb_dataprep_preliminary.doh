** PRELIMINARY PROGRAMS FOR ENCELURB 2002, 2003, 2004, 2009
** !created June 7 2014
**  Preliminary programs used by ENCELURB dataprep do files

** LIST OF PROGRAMS TO CLEAN RAW ENCELURB DATA
**  localidades 
**  myzscore  
**  subclean 
**  clean   
**  clean9s 
**  postcollapse
**  sociodem
**  daywk_outliers
**  hhlevel
**  assetify
**  baselinify

cap program drop localidades
program define localidades
	confirm string variable ent mun loc
	rename ent ent // because in some years it is entidad
	rename mun mun
	rename loc loc
	cap drop localidad
	gen localidad = ent + mun + loc
	foreach x in ent mun loc localidad ageb manzana {
		cap confirm var `x'
		if !_rc {
			gen s_`x' = `x' // string version
			destring `x', replace // numerical version
		}
	}
	format localidad %10.0f
end

cap program drop subclean
program define subclean
	args var v
	
	// 998 and 999 to missing (998 is top code and 999 is no sabe)
	replace `v' = `v' + `var' if f2_`var'==0 
	replace `v' = . if f2_`var'==1 // missing if flag2 (=999 or =998)
end

cap program drop clean
program define clean 
	syntax varlist, l(numlist) [v(namelist)]
	cap confirm var `v'
	if _rc gen `v' = 0 // create variable if not already exist
	foreach var of varlist `varlist' {
		cap gen byte f1_`var'=0
		cap gen byte f2_`var'=0
	}
	foreach ll of local l {
		local _8 = "9"*`=`ll'-1' + "8" // so eg if l=4, `_8' = 9998, `_9' = 9999
		local _9 = "9"*`ll'
		foreach var of varlist `varlist' {
			recode `var' (. = 0) // those who didn't spend anything are coded as missing
			replace f1_`var' = 1 if (`var'==`_9') // flag 1: 999 (cap since may have already used var in other clean command)
			replace f2_`var' = 1 if (`var'==`_9' | `var'==`_8') // flag 2: 999 or 998
		}
	}
	foreach var of varlist `varlist' {
		subclean `var' `v'
	}
end

cap program drop clean9s
program define clean9s
	syntax varlist, l(numlist) v(namelist) nine(varlist)
	assert wordcount("`varlist'") == wordcount("`nine'")
	cap confirm var `v'
	if _rc gen `v' = 0 // create variable if not already exist
	local c = 1
	foreach var9 of varlist `nine' {
		local `c' `var9'
		local ++c
	} // manual tokenize since might include wildcards in varlist
	foreach var of varlist `varlist' {
		gen byte f1_`var'=0
		gen byte f2_`var'=0
	}
	foreach ll of local l {
		local _8 = "9"*`=`ll'-1' + "8" // so eg if l=4, `_8' = 9998, `_9' = 9999
		local _9 = "9"*`ll'
		local i=1
		foreach var of varlist `varlist' {
			recode `var' (. = 0) // those who didn't spend anything are coded as missing
			replace f1_`var' = 1 if (``i''==9)
			replace f2_`var' = 1 if (``i''==9 | `var'==`_8')
			local ++i
		}
	}
	foreach var of varlist `varlist' {
		subclean `var' `v'
	}
end

cap program drop postcollapse 
program define postcollapse
	syntax namelist, [v(namelist)]
	foreach var of local namelist {
		replace `v' = . if f2_`var'==1 
	}
end

cap program drop sociodem // clean sociodemographic vars
program define sociodem
	#delimit ;
	syntax , 
		edad(varname) 
		sexo(varname) 
		jefe(varname)
		casado(varname)
		asistio(varname)
		nivel(varname)
		grado(varname)
		leer(varname)
		trabajo(varname)
		trabajo2(varname)
		[
			casado_vals(string)
			encel02
			encel03
			encel04
			encel09
			encasdu
			salud(varname)
		]
	;
	#delimit cr	
	
	// SOCIODEM CHAR
	rename `edad' edad
	rename `sexo' sexo
	gen byte jefe=(`jefe'==1) // no missing
	gen byte conyuge=(`jefe'==2)
	gen byte kid = (edad<18)
	gen byte elderly = (edad>=65)
	gen byte schoolage = (edad>=6 & edad<18)
	if "`casado_vals'"=="" local casado_vals "1,2"
	gen byte married = inlist(`casado',`casado_vals') // union libre or casado(a)
		// other categories (married==0): viudo, sperado, divorciado, soltero
	** for hh-equivalent of vars used at locality level:
	gen byte age_15_ = (edad>=15)
	gen byte age_6_14 = (edad>=6 & edad<=14)
	gen byte age_15_29 = (edad>=15 & edad<=29)

	// for decision-making power, determine whether there is another adult in hh
	if "`encasdu'"!="" | "`encel09'"!="" {
		** Jefe o jefa                             01
		** Esposo(a) o cónyuge                     02 (ADULT)
		** Hijo(a)                                 03
		** Hijastro(a) (adoptivo o entenado)       04
		** Padre o madre                           05 (ADULT)
		** Padrasto o madrastra                    06 (ADULT)
		** Abuelo(a)                               07 (ADULT)
		** Hermano(a)                              08 (ADULT)
		** Suegro(a)                               09 (ADULT)
		** Yerno o nuera                           10
		** Nieto(a)                                11
		** Trabajador(a) doméstico(a)              12 (is another adult but not one with decision power)
		** Pariente del trabajador(a) doméstico(a) 13
		** Otro parentesco                         14 (not clear whether adult)
		** No tiene parentesco                     15 (not clear whether adult)
		gen other_adult = inlist(`jefe',2,5,6,7,8,9) | (inlist(`jefe',14,15) & edad>=18)
	}
	else { // encel 02, 03, 04
		** Jefe o jefa                             01
		** Esposo(a) o pareja                      02
		** Hijo(a)                                 03
		** Padre o madre                           04
		** Abuelo(a)                               05
		** Hermano(a)                              06
		** Nieto(a)	                               07
		** Otro parentesco 			               08 (not clear whether adult)
		** No tiene parentesco					   09 (not clear whether adult)
		** Trabajador(a) doméstico(a)              10 (is another adult but not one with decision power)
		** Pariente del trabajador(a) doméstico(a) 11
		gen other_adult = inlist(`jefe',2,4,5,6) | (inlist(`jefe',8,9) & edad>=18)
	} // !LOH!
	
	// ESCOLARIDAD
	gen analfabeto = (`leer'==2 | `leer'==9)
	** `leer' ¿(NOMBRE) sabe leer y escribir un recado? 1 Si 2 No 9 No Sabe (only 0.1% have ==9)

	** h30b3a = nivel
	** 0 Ninguno
	** 1 Kinder o preescolar
	** 2 Primaria
	** 3 Secundaria
	** 4 Preparatoria o Bachillerato
	** 5 Normal
	** 6 Carrera técnica o Comercial
	** 7 Profesional o Superior
	** 8 Maestría o Doctorado
	** 9 No sabe

	rename `nivel' nivel
	rename `grado' grado
	tab nivel grado

	** adapting code for escolaridad var in ENNVIH on SobreMexico
	if "`encasdu'"!="" | "`encel09'"!="" {
		
		replace grado=4 if (nivel==5 | nivel==6 | nivel==7) & (grado==5 | grado==6)                 // >=5 años en normal/profesional: set to 4 //
		** (note in 2009 all the "no sabe" grado only occur for "no sabe" escuela)
		tab nivel grado
		gen     escolaridad= 0          if nivel==0 | nivel==1
		replace escolaridad=     grado  if nivel==2				//Primaria//
		replace escolaridad= 6 + grado  if nivel==3         		//Secundaria//
		replace escolaridad= 9 + grado  if nivel==4      		//Prepa//
		replace escolaridad= 12+ grado  if nivel==5 | nivel==6 | nivel==7 	//Normal/Licenciatura/Professional//
		replace escolaridad= 16+ grado  if nivel==8               //Posgrado//
		else if "`encel09'"!="" {
			replace escolaridad= 0 if `asistio'==2
			assert edad<=2 if `asistio'==.
			replace escolaridad=0 if `asistio'==.
			assert escolaridad != . if nivel!=9 & `asistio'!=9
		}
		
	}
	else  { // encel 02, 03, 04
		replace grado=3 if (nivel==3 | nivel==4) & (grado==4 | grado==5 | grado==6) // >=4 años en secundaria/prepa: set to 3 //
		replace grado=4 if (nivel==5 | nivel==6 | nivel==7) & (grado==5 | grado==6) // >=5 años en normal/profesional: set to 4 //     
		replace grado=4 if nivel==2 & grado==9										// no sabe en prim: set to 4 //
		replace grado=2 if (nivel==3 | nivel==4) & (grado==9)						// no sabe en secundaria/prepa: set to 2 //
		replace grado=3 if (nivel==5 | nivel==6 | nivel==7) & (grado==9)            // no sabe en normal/profesional: set to 3
		replace grado=2 if (nivel==8) & (grado==9)                                  // no sabe en maestria/doctorado: set to 2

		tab nivel grado
		gen     escolaridad= 0          if nivel==0 | nivel==1  // Ninguno/Kinder
		replace escolaridad=     grado  if nivel==2				// Primaria
		replace escolaridad= 6 + grado  if nivel==3         	// Secundaria
		replace escolaridad= 9 + grado  if nivel==4      		// Prepa
		replace escolaridad= 12+ grado  if nivel==5 | nivel==6 | nivel==7 	// Normal/Carrera tecnica/Professional
		replace escolaridad= 16+ grado  if nivel==8             // Maestria o Doctorado
		assert nivel==. & grado==. if edad<5
		replace escolaridad= 0 if edad<5 // that was the cutoff used this year for the educ questions
		// now all missing escolaridad are "no sabe" nivel or missing nivel+grado (271 obs missing escolaridad)
	} // !LOH!
	
	// TRABAJO
	tab `trabajo' 
	gen byte trabajo = 0
	replace trabajo = 1 if `trabajo'==1 | `trabajo'==2
		// La semana pasada, (NOMBRE) principalmente...
		   ** 1 trabajó?
		   ** 2 tenía trabajo, pero no trabajó?
		   ** 3 buscó trabajo?
		   ** 4 es estudiante?
		   ** 5 se dedica a los quehaceres de su hogar?
		   ** 6 es jubilado(a) o pensionado(a)?
		   ** 7 no trabajó?
		   ** 8 está incapacitado(a) permanentemente para trabajar?
	replace trabajo = 1 if inlist(`trabajo2',1,2,3,4,5)
		// (if `trabajo' != 1|2) Ademas de (`trabajo') la semana pasada...
		   ** 1 vendió algunos productos (ropa, cosméticos, alimentos, etc.)
		   ** 2 hizo algún producto para vender (alimentos, artesanías, ropa
		   ** 3 a cambio de un pago lavó, planchó o cosió?
		   ** 4 ayudó a trabajar en algún negocio, en las actividades agríco
		   ** 5 realizó otro tipo de trabajo (actividad) le hayan pagado o n
		   ** 6 no trabajó?
	** NOTE: these questions are about last week; if instead want to use last year,
	**  h403-404 ask those who didn't work in last week whether worked in last year
	
	// SEGURO DE SALUD
	if "`salud'"!="" gen byte seguro_salud = (`salud'==1)
	
end
	
cap program drop daywk_outliers
program define daywk_outliers
	local allposs `1'==998 | `1'==999 | `1'==9998 | `1'==9999 | ///
				  `1'==99998 | `1'==99999 | `1'==999998 | `1'==999999
	local wkperquincenal = (52/12)/2
	cap confirm var drop
	if _rc gen byte drop = 0
	local cut 3000
	local daysperwk 5
	replace drop = 1 if (`1'>`cut' & (`2'==1))  & !(`allposs') // daily with super large amounts
	replace drop = 1 if (`1'>`cut'*`daysperwk' & (`2'==2)) & !(`allposs') // weekly with super large amounts (assuming 5 workdays/wk)
	replace drop = 1 if (`1'>`cut'*`daysperwk'*`wkperquincenal' & (`2'==3)) & !(`allposs') // quincenal with super large amounts (assuming 2 work weeks per quincenal)
end

cap program drop hhlevel // household level variables from individual data
program define hhlevel

	sort folio, stable
	
	if "`1'"=="encasdu" { // optional command argument, for ENCASDU compatibility
		local asistio ""
	}
	else local asistio "asistio"

	// age of household head
	tempvar edad_jefe
	gen `edad_jefe'	= 0
	replace `edad_jefe' = edad if jefe==1
	by folio: egen edad_jefe = max(`edad_jefe')	

	gen member = 1 // to count number of members
	foreach x in kid schoolage elderly member `asistio' {
		by folio: egen n_`x' = sum(`x')
	}

	// education level of household head
	tempvar escolaridad_jefe // o conyuge
	** if "`1'"=="encasdu" {
		** gen `escolaridad_jefe' = escolaridad if jefe==1 | conyuge==1
		** by folio: egen escolaridad_jefe = min(`escolaridad_jefe')	
	** }
	** else {
	if "`1'"=="encasdu"	gen `escolaridad_jefe' = escolaridad if jefe == 1 
	else gen `escolaridad_jefe' = escolaridad
	by folio: egen escolaridad_jefe = max(`escolaridad_jefe')
	** }
	
	// household head is male
	tempvar head_male
	gen `head_male' = (jefe==1 & sexo==1)
	by folio: egen head_male = max(`head_male')
	
	// household head is married 
	//  (note there are 32 couples where one reported married and esposo(a)/conyuge reported
	//  not married; count these as married)
	tempvar head_married
	gen `head_married' = married if jefe==1 | conyuge==1
	by folio: egen head_married = max(`head_married') 
	
	// max age of non-head (to determine if another adult)
	tempvar age_not_head max_age_not_head
	gen `age_not_head' = edad if jefe==0
	by folio: egen max_age_not_head = max(`age_not_head') 
		// will be missing for 1-person households (3% of households in ENCELURB)
		
	// status of non-head (to determine if another adult)
	by folio: egen has_other_adult = max(other_adult)
	
	// to determine if a male adult in household in addition to beneficiary
	tempvar other_male_adult
	gen `other_male_adult' = (other_adult==1 & sexo==1)
	gen has_other_male_adult = (`head_male'==1) | (`head_male'==0 & `other_male_adult'==1)
		// if head_male==1, the (female) Op beneficiary is not household head, so there
		//  is at least one male adult
		// if head_male==0, check if `other_male_adult'==1
		
	// age and education of man and woman (for "power" measure in Schaner 2016)
	if "`1'"=="" | "`1'"=="encel09" { // not ENCASDU
		foreach x in m f {
			foreach var in escolaridad edad analfabeto {
				tempvar `var'_`x' 
				by folio: egen ``var'_`x'' = max(`var'_`x')
					// note these vars will only be defined for one member in hh; here we are
					//  just getting the value for the whole hh
				replace `var'_`x' = ``var'_`x''
			}
		}
		
		if "`1'"=="encel09" local female "female??"
		else local female ""

		// proportion age>=15 illiterate
		tempvar analfabeta_15_ 
		gen `analfabeta_15_' = .
		replace `analfabeta_15_' = 0 if age_15_==1 & analfabeto==0
		replace `analfabeta_15_' = 1 if age_15_==1 & analfabeto==1
		by folio: egen p_analfabeta_15_ = mean(`analfabeta_15_') // confirmed that mean() ignores missing, 
			// still places the mean of the obs for that hh in all members of the hh
		replace p_analfabeta_15_=0 if p_analfabeta_15_==. // hh's with no members >15 (unlikely)

		// number ages 6-14 that don't attend school
		tempvar no_asiste_6_14
		gen `no_asiste_6_14' = .
		replace `no_asiste_6_14' = 0 if age_6_14==1 & asiste==1
		replace `no_asiste_6_14' = 1 if age_6_14==1 & asiste==0
		by folio: egen p_no_asiste_6_14 = mean(`no_asiste_6_14')
		replace p_no_asiste_6_14 = 0 if p_no_asiste_6_14 == . // hh's with no members 6-14

		// proportion age>=15 with incomplete basic education
		tempvar basica_inc_15_
		gen `basica_inc_15_' = .
		replace `basica_inc_15_' = 0 if age_15_==1 & menos_9==0
		replace `basica_inc_15_' = 1 if age_15_==1 & menos_9==1
		by folio: egen p_basica_inc_15_ = mean(`basica_inc_15_')
		replace p_basica_inc_15_ = 0 if p_basica_inc_15_ == . // hh's with no members >15 (unlikely)

		// proportion ages 15-29 with less than 9 years of schooling
		tempvar menos9_15_29 // =1 si el hogar tiene algun habitante con menos de 9 años de educ ages 15-29
		gen `menos9_15_29' = .
		replace `menos9_15_29' = 0 if age_15_29==1 & menos_9==0
		replace `menos9_15_29' = 1 if age_15_29==1 & menos_9==1
		by folio: egen d_menos9_15_29 = max(`menos9_15_29')
		replace d_menos9_15_29 = 0 if d_menos9_15_29==.
		// note p is for proportion and d for dummy

		// proportion with access to health insurance
		by folio: egen p_derechohabiencia = mean(healthinsurance) // proportion with health insurance
		cap confirm variable seguropopular
		if !_rc by folio: egen p_seguropopular = mean(seguropopular)
		
		// female bargaining power (2009 survey; in 2002 survey it was in hh module)
		if "`1'"=="encel09" {
			foreach var of varlist female?? {
				tempvar `var'_
				by folio: egen ``var'_' = max(`var')
				drop `var'
				rename ``var'_' `var'
			}
		}
	
		#delimit ;
		local keep_encel 
			p_*
			d_*
			escolaridad_?
			edad_?
			analfabeto_?
			`female'
		;
		#delimit cr
	}
	
	// household head illiterate
	tempvar head_illiterate
	gen `head_illiterate' = ((jefe==1 | conyuge==1) & analfabeto==1) 
	by folio: egen head_illiterate = max(`head_illiterate')

	// household head or spouse works
	tempvar trabajo_jefe // o conyuge
	gen `trabajo_jefe' = 0
	replace `trabajo_jefe' = trabajo if jefe==1 | conyuge==1
	by folio: egen trabajo_jefe = max(`trabajo_jefe')

	// household education spending
	cap confirm var educ_spend
	local has_educspend = !_rc
	if `has_educspend' {
		by folio: egen educ_spend_hh = sum(educ_spend)
		local educ_spend educ_spend_*
	}
	
	// seguro de salud
	cap confirm var seguro_salud
	if !_rc {
		tempvar head_seguro
		gen `head_seguro' = 0
		replace `head_seguro' = seguro_salud if jefe==1 | conyuge==1
		by folio: egen head_seguro = max(`head_seguro')
		by folio: egen p_seguro = mean(seguro_salud) // average over hh
	
		local seguro "*seguro*"
	}
		
	#delimit ;
	keep
		folio 
		/* totalinc_*
		incflag_*_hh */
		p_*
		n_*
		*_jefe
		*head*
		`seguro'
		has_other*
		`keep_encel'
	;
	#delimit cr	
	
	by folio : drop if _n>1 // faster than duplicates drop

end 

cap program drop assetify // coding "other (specify)" asset variables
program define assetify
	syntax [varlist], p(string) [pre post] // varname is the "otro (especificar)" variable and p is the prefix
	local es `varlist'
	if "`pre'"!="" & "`post'"!="" {
		di as error in smcl "Only one option {bf:pre} or {bf:post} can be specified"
		exit
	}
	if "`pre'"=="" & "`post'"=="" {
		di as error in smcl "Must specify either {bf:pre} or {bf:post} option"
		exit
	}
	local pp `pre' `post' // will either be "pre" or "post"
	// Note asset questions changed in 2009, which is why the below has assets_list_pre and _post
	#delimit ;
	local assets_list_pre
		property /* casas, locales, terrenos, parcelas o fincas, etc. aparte de esta vivienda */
		auto /* automovil propio */
		camion /* camion o camioneta propio */
		moto /* motos, tractores u otros vehículos motorizados */
		tv /* televisión */
		video /* videocasetera */
		electricos /* otros aparatos eléctricos o electrónicos 
					(computadora, plancha, horno de microondas, licuadora, etc.)? */
		radio 
		refrig
		estufa_gas
		estufa_otro /* estufa de otro combustible o parrilla electrica */
		lavadora /* lavadora automatica para ropa */
		secadora /* secadora para ropa */
		boiler /* calentador de gas para agua (boiler) */
		tinaco
		animales /* animales de tiro o de consumo (caballos, gallinas, vacas, cerdos, borregos, etc) */
		;
	local assets_list_post
		auto /* automovil propio */
		camion /* camion o camioneta propio */
		moto /* motos, tractores u otros vehículos motorizados */
		tv_color /* televisión a color */
		tv_cable /* televisión por cable o de paga */
		video /* DVD y/o videocasetera */
		radio /* tocadiscos, modular o equipo de discos compactos */
		tele_fijo /* teléfono fijo */
		tele_cel /* teléfono celular */
		compu 
		internet
		ventilador /* ventilador o abanico electrico */
		aire /* enfriador de aire o clima */
		lavadora /* lavadora automatica para ropa */
		aspiradora /* [vacuum] */
		coser /* maquina de coser */
		estufa_gas 
		refrig
		cafetera /* cafetera electrica */
		horno_elec 
		microonda
	;
	local new_pre
		ventilador
		coser 
	;
	local animales
		`"
		"CONEJO"
		"GALLINA"
		"PEDRO"
		"PERRO"
		"TOTOL"
		"GALLO"
		"CANARIOS"
		"PAJAROS"
		"PATOS"
		"PERICOS"
		"LOROS"
		"'
	;
	local tinaco 
		`"
		"BOMBA DE AGUA"
		"TANQUE"
		"'
	;
	local ventilador 
		`"
		"VENTILADOR"
		"VENYILADOL"
		"'
	;
	local coser 
		`"
		"COSER"
		"COCER"
		"'
	;
	local electricos 
		`"
		"MAQUINA DE ESCRIBIR"
		"MAQUINA TORTILLAS"
		"COMPUTADORA"
		"MAQUINA     "
		"MAQUINA DE SOLDAR"
		"MICROHONDAS"
		"ELECTRICO"
		"'
	;
	local radio 
		`"
		"STEREO"
		"GRABADORA"
		"GRAVADORA"
		"DISCOS COMPACTOS"
		"MINICOMPONENTE"
		"'
	;	
	local estufa_otro 
		`"
		"ESTUFA DE PETROLEO"
		"PARRILLA"
		"PARRILA"
		"ANAFRE"
		"COMAL"
		"FOGON"
		"'
	;
	local video
		`"
		"DVD"
		"DUD"
		"'
	;
	local camion
		`"
		"MICROBUS"
		"'
	;
	#delimit cr
	local i=1
	foreach asset of local assets_list_`pp' {
		if length("`i'")==1 local i 0`i'
		gen byte has_`asset' = (`p'`i'==1)
		if "`pre'"!="" /// if 2002, 2003, or 2004
		foreach str of local `asset' {
			replace has_`asset' = 1 if strpos(`es',"`str'")
		}
		local ++i
	}
	if "`pre'"!="" foreach asset of local new_pre {
		gen byte has_`asset' = 0
		foreach str of local `asset' {
			replace has_`asset' = 1 if strpos(`es',"`str'")
		}
	}
	
	// otro (especificar) responses -- printed in encelurb_encasdu_especificar.R -- with my notes after //
	** > as.matrix(unique(hog02$s25a0218)) #as.matrix is to get it to list as a column vector
		  ** [,1]                        
	 ** [1,] "                          "
	 ** [2,] "PERRO                     " // animal
	 ** [3,] "HERRAMIENTA DE CARPINTERIA" // none 
	 ** [4,] "PERROS  ( S)              " // animal
	 ** [5,] "CONEJOS                   " // animal
	 ** [6,] "PEDRO                     " // animal (typo of PERRO)
	 ** [7,] "2                         " // none
	 ** [8,] "GALLINAS                  " // animal
	 ** [9,] "VITRINAS  Y ESTANTES      " // none
	** [10,] "BOMBA DE AGUA             " // tinaco (water tank)
	** [11,] "TOTOLES                   " // animal
	** [12,] "MODULAR                   " // none (dresser -- furniture)
	** [13,] "CONGELADOR                " // none 
	** [14,] "CAMA. VENTILADOR ROPERO   " // ventilador
	** [15,] "CONEJO                    " // animal
	** [16,] "BICICLETA                 " // none
	** [17,] "PERROS                    " // animal
	** [18,] "UN GALLO                  " // animal
	** > as.matrix(unique(hog03$s22b0218)) 
		  ** [,1]                                                                                                  
	 ** [1,] "                                                                                                    "
	 ** [2,] "VENTILADOR                  // ventilador                                                                       "
	 ** [3,] "BICICLETA                   // none                                                                        "
	 ** [4,] "VENTILADOR PEDESTAL         // ventilador                                                                       "
	 ** [5,] "ROPERO                      // none (furniture)                                                                        "
	 ** [6,] "VENTILADOR DE TECHO         // ventilador                                                                        "
	 ** [7,] "GRABADORA                   // radio (like a stereo)                                                                      "
	 ** [8,] "PERROS                      // animal                                                                        "
	 ** [9,] "PERRO                       // animal                                                                        "
	** [10,] "DVD                         // video                                                                        "
	** [11,] "VENTILADOR, MODULAR         // ventilador                                                                        "
	** [12,] "MAQUINA DE COSER            // coser                                                                        "
	** [13,] ".                                                                                                   "
	** [14,] "MAQUINA DE ESCRIBIR         // electricos                                                                        "
	** [15,] "GRABADORA VENTILADOR        // radio, ventilador                                                                        "
	** [16,] "MODULAR                     // none (furniture)                                                                            "
	** [17,] "VENTILADOR, GRABADORA       // radio, ventilador                                                                             "
	** [18,] "MODULAR, VENTILADOR         // ventilador                                                                        "
	** [19,] "VENTILADOR MODULAR          // ventilador                                                                        "
	** [20,] "MODULAR VENTILADOR          // ventilador                                                                         "
	** [21,] "VENTILADOR, MODULAR, MAQUINA DE COSER   // ventilador, coser                                                             "
	** [22,] "VENTILADOR, MAQUINA DE COSER, GRABADORA // ventilador, radio                                                            "
	** [23,] "TRICICLO, COMPUTADORA       // electricos [computadora explicitly mentioned in electricos]                                                                        "
	** [24,] "GRABADORA, VENTILADOR       // radio, ventilador                                                                         "
	** [25,] "TRICICLO                    // none                                                                        "
	** [26,] "ESTUFA DE PETROLEO          // estufa_otro                                                                        "
	** [27,] "CONEJOS                     // animal                                                                        "
	** [28,] "TRICICLO, CARRO DE HOG DOGS // none                                                                        "
	** [29,] "CANARIOS                    // animal                                                                        "
	** [30,] "GALLOS DE PELEA             // animal                                                                        "
	** [31,] "PAJAROS                     // animal                                                                        "
	** [32,] "CARROS DE HAMBURGUESAS      // none                                                                        "
	** [33,] "PATOS                       // animal                                                                        "
	** [34,] "-                                                                                                   "
	** [35,] "HERRAMIENTAS                // none                                                                        "
	** [36,] "**                                                                                                   "
	** [37,] "DISCOS COMPACTOS            // radio (assuming its a tocadiscos)                                                                        "
	** [38,] "PARRILA DE GAS              // estufa_otro                                                                         "
	** [39,] "CAMA                        // none (furniture)                                                                        "
	** [40,] "SU CAMA                     // none (furniture)                                                                        "
	** [41,] "CAMA Y TOCADOR              // none (furniture)                                                                        "
	** [42,] "PARRILLA LEÑA               // estufa_otro                                                                        "
	** [43,] "PARRILLA DE GAS             // estufa_otro                                                                          "
	** [44,] "STEREO                      // radio                                                                        "
	** [45,] "PERICOS AUSTRALIANOS        // animal                                                                        "
	** [46,] "NO DIJO                                                                                             "
	** [47,] "COMAL DE LEÑA               // estufa_otro                                                                        "
	** [48,] "COMEDOR Y SALA NUEVOS       // none (part of house)                                                                        "
	** [49,] "GRAVADORA                   // radio                                                                        "
	** [50,] "0                                                                                                   "
	** [51,] "ESTEREO                     // radio                                                                        "
	** [52,] "TANQUE ESTACIONARIO         // tinaco (water tank)                                                                        "
	** [53,] "NO SABE                                                                                             "
	** [54,] "NO  SABE                                                                                            "
	** [55,] "PARRILLA                    // estufa_otro                                                                        "
	** [56,] "MAQUINA TORTILLAS           // electricos                                                                       "
	** [57,] "PERICOS                     // animal                                                                       "
	** [58,] "ENSERES  DOMESTICOS (OLLAS CAMA, MESA  // none                                                      "
	** > as.matrix(unique(hog04$s22c0218)) 
		   ** [,1]                                                                                                  
	  ** [1,] "                                                                                                    "
	  ** [2,] "VENTILADOR                  // ventilador                                                                         "
	  ** [3,] "COMODA                      // none (furniture)                                                                        "
	  ** [4,] "MAQUINA DE COSER DE MESA    // coser                                                                        "
	  ** [5,] "BICICLETA Y VENTILADOR      // ventilador                                                                        "
	  ** [6,] "ROPERO                      // none (furniture)                                                                         "
	  ** [7,] "COMEDOR                     // none (furniture)                                                                            "
	  ** [8,] "CAMA                        // none (furniture)                                                                       "
	  ** [9,] "MUEBLES PARA EL HOGAR       // none (furniture)                                                                      "
	 ** [10,] "MODULAR                     // none (furniture)                                                                          "
	 ** [11,] "MAQUINA                     // electricos                                                                        "
	 ** [12,] "TRICICLO                    // none                                                                        "
	 ** [13,] "SILLA INFANTIL              // none (furniture)                                                                        "
	 ** [14,] "UN LIBRERO                  // none (furniture)                                                                        "
	 ** [15,] "ESTEREO                     // radio                                                                        "
	 ** [16,] ".                                                                                                   "
	 ** [17,] "COLCHON TRICICLO            // none                                                                         "
	 ** [18,] "BICICLETA                   // none                                                                        "
	 ** [19,] "MUEBLES Y ROPERO            // none (furniture)                                                                         "
	 ** [20,] "MOLINO                      // none                                                                        "
	 ** [21,] "BICIVLETA VENTILADORE       // ventilador                                                                        "
	 ** [22,] "LUISA VANESA AMAYA ROSADO   // ?                                                                        "
	 ** [23,] "ABANICO                     //                                                                        "
	 ** [24,] "VENYILADOL                  // ventilador (typos?)                                                                        "
	 ** [25,] "LITERA                      // none (furniture)                                                                         "
	 ** [26,] "VENTILADOR/BICICLETA        // ventilador                                                                        "
	 ** [27,] "MAQUINA DE QUITAR CABELLO Y VENTILADOR // ventilador                                                             "
	 ** [28,] "NO SABE                                                                                             "
	 ** [29,] "GRABADORA Y MODULAR         // radio                                                                        "
	 ** [30,] "GRABADORA  MAQUINA DE COCER // radio, coser                                                                        "
	 ** [31,] "HONDULAR                    // ?                                                                       "
	 ** [32,] "MAQUINA DE COCER            // coser                                                                        "
	 ** [33,] "GRABADORA                   // radio                                                                        "
	 ** [34,] "MAQUINA DE COSER            // coser                                                                        "
	 ** [35,] "LOROS                       // animal                                                                        "
	 ** [36,] "COLCHON                     // none (furniture)                                                                        "
	 ** [37,] "HERRAMIENTA DE CARPINTERIA  // none                                                                        "
	 ** [38,] "DVD                         // video                                                                        "
	 ** [39,] "COMPUTADORA                 // electricos [computadora explicitly mentioned in electricos]                                                                        "
	 ** [40,] "TIENDA                      // none                                                                        "
	 ** [41,] "BICICLETAS                  // none                                                                          "
	 ** [42,] "RECAMARA                    // none (furniture)                                                                        "
	 ** [43,] "MAQUINA DE SOLDAR           // electricos                                                                        "
	 ** [44,] "222221FERNANDO JIMENEZ SALAZAR  // ?                                                                    "
	 ** [45,] "LIBRERO                     // none (furniture)                                                                         "
	 ** [46,] "ANAFRE                      // estufa_otro                                                                       "
	 ** [47,] "PERROS                      // animal                                                                        "
	 ** [48,] "CANARIOS                    // animal                                                                        "
	 ** [49,] "MICROBUS                    // camion                                                                        "
	 ** [50,] "VITRINA                     // none (furniture)                                                                         "
	 ** [51,] "MUEBLE PARA MICROONDAS      // none (furniture)                                                                        "
	 ** [52,] "PARRILLA                    // estufa_otro                                                                        "
	 ** [53,] "BICICLETA Y ROPERO          // none                                                                        "
	 ** [54,] "STEREO                      // radio                                                                        "
	 ** [55,] "GABINETE                    // electricos [ computadora explicitly mentioned in electricos; gabinete is computer tower]                                                                       "
	 ** [56,] "FOGON PARA COCINAR          // estufa_otro                                                                      "
	 ** [57,] "FOGON                       // estufa_otro                                                                           "
	 ** [58,] "UNA CAJONERA                // none (furniture)                                                                          "
	 ** [59,] "DUD                         // video                                                                        "
	 ** [60,] "MESA DE CENTRO              // none (furniture)                                                                        "
	 ** [61,] "CAMA Y SILLON               // none (furniture)                                                                        "
	 ** [62,] "PARRILLA DE GAS             // estufa_otro                                                                        "
	 ** [63,] "LITERAS                     // none (furniture)                                                                        "
	 ** [64,] "UN ROPERO                   // none (furniture)                                                                        "
	 ** [65,] "OLLAS                       // none                                                                        "
	 ** [66,] "CAMAS                       // none (furniture)                                                                        "
	 ** [67,] "COMPRO UN COMEDOR           // none (furniture)                                                                        "
	 ** [68,] "JUGUETERO                   // none                                                                        "
	 ** [69,] "MUEBLE                      // none (furniture)                                                                         "
	 ** [70,] "SILLAS NUEVAS               // none (furniture)                                                                         "
	 ** [71,] "COOLER                      // none                                                                        "
	 ** [72,] "JUEGO DE SALA               // none                                                                         "
	 ** [73,] "UN JUEGO DE SALA            // none                                                                         "
	 ** [74,] "UN COBERTOR Y UNA BATERIA DE COCINA // none                                                               "
	 ** [75,] "UNA CAMA                    // none (furniture)                                                                         "
	 ** [76,] "UNA SALA                    // none (part of house)                                                                         "
	 ** [77,] "SALA                        // none (part of house)                                                                        "
	 ** [78,] "JUEGO DE MUEBLES            // none (furniture)                                                                        "
	 ** [79,] "UNA COMODA                  // none (furniture)                                                                        "
	 ** [80,] "CLOSEET                     // none (furniture)                                                                        "
	 ** [81,] "VASOS                       // none                                                                        "
	 ** [82,] "MICROHONDAS                 // electricos [microonda explicitly listed]                                                                       "
	 ** [83,] "MOLINO ELECTRICO            // electricos                                                                        "
	 ** [84,] "COMAC                       // ?                                                                        "
	 ** [85,] "CAMA ANAFRE                 // estufa_otro                                                                        "
	 ** [86,] "VENTILADOR DVD              // ventilador, video                                                                        "
	 ** [87,] "MUEBLES                     // none (furniture)                                                                         "
	 ** [88,] "ESTEREO SILLAS              // radio                                                                        "
	 ** [89,] "LIBRERO SALA                // none (furniture)                                                                         "
	 ** [90,] "CAMA SALA                   // none (furniture)                                                                         "
	 ** [91,] "BATERIA DE COCINA           // none                                                                        "
	 ** [92,] "CAMA ROPERO                 // none (furniture)                                                                         "
	 ** [93,] "CLOSET                      // none (furniture)                                                                         "
	 ** [94,] "MINICOMPONENTE              // radio                                                                        "
	 ** [95,] "CAMA Y ROPERO               // none (furniture)                                                                         "
	 ** [96,] "COMODA DE SEGUNDA MANO      // none (furniture)                                                                         "
	 ** [97,] "MESAS TANQUE DE GAS         // not sure if this tank would be for a estufa de gas or boiler so leaving as none                                                                        "
	 ** [98,] "CAMA COMODA                 // none (furniture)                                                                        "
	 ** [99,] "CAMA ROPERO COMERDOR        // none (furniture)
end

capture program drop baselinify
program define baselinify 
	syntax varlist, [yearlist(string)]
	if "`preyearlist'"=="" local yearlist 2002 2003 2004 2009
	foreach var of local varlist {
		foreach year of local yearlist {
			local yy=substr("`year'",3,2)
			tempvar `var'`yy'
			gen ``var'`yy'' = `var' if year==`year'
			sort folio, stable
			by folio: egen `var'`yy' = max(``var'`yy'') // confirmed that . ignored if other non-zero in max(); max(.,.) is missing
		}
		// most recent pre-treatment preferred for baseline, unless the family missed that wave of survey
		gen `var'_bl = `var'04 if y2004==1 
		replace `var'_bl = `var'03 if y2004==0 & y2003==1
		replace `var'_bl = `var'02 if y2004==0 & y2003==0 & y2002==1	
	}
end
