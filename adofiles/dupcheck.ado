* CHECK FOR DUPLICATES
*  (Runs much faster than duplicates report)
* Sean Higgins

cap program drop dupcheck
program define dupcheck, byable(recall, noheader)
	syntax varlist [if] [in] [, NOConfirm ALLsame assert Sorted]
	preserve
	if wordcount("`if' `in'")>0 {
		qui keep `if' `in'
	}
	if _by()==1 {
		qui drop if `_byindex' != _byindex()
		foreach x of local _byvars {
			qui summ `x', meanonly
			local _`x' = r(mean)
			local list "`list' `x'==" as result "`_`x''"
		}
		local myby "for`list'"
	}
	qui count
	if r(N)==1 {
		if "`noconfirm'"=="" di as text "Only one observation `myby'"
		exit // only exits this iteration of by
	}

	qui uniquevals `varlist', count `sorted' // uses another user-written ado file of mine
	if "`allsame'"=="" {
		if r(unique)!=r(N) {
			di as error "`=`r(N)'-`r(unique)'' duplicates of " as result "`varlist' " as error "`myby'"
			if "`assert'"!="" {
				di as error "assertion is false"
				error 9
			}
		}
		else if "`noconfirm'"=="" {
			di as text "No duplicates of " as result "`varlist' " as text "`myby'"
		}
	}
	else { // allsame
		if r(unique)==1 {
			if "`noconfirm'"=="" di as text "All values of " as result "`varlist' " as text "same `myby'"
		}
		else {
			di as error "`r(unique)' unique values of " as result "`varlist' " as error "`myby'"
			if "`assert'"!="" {
				di as error "assertion is false"
				error 9
			}
		}
	}

end

