// Cluster permutation that creates data sets of permutation values by cluster.
//  Minimizes the number of sorts, since this slows down both randcmd and ritest on large datasets.
cap program drop cluster_permute
program define cluster_permute
	#delimit ;
	syntax varname [using/], 
		[
			CLuster(string)
			N_perm(integer 2000) /* 2000 suggested by simulations in Young (2019) */
			Gen(string)
			gentype(string)
			keep(string) /* to keep additional variables */
		]
	;
	#delimit cr
	
	local varname `varlist'
	if "`gen'"=="" local gen `varname'
	
	keep `cluster' `varname' `keep'
	
	if "`cluster'"!="" {
		// Because there might not be constant treatment assignment within cluster (e.g. 
		//  due to misreporting; moving), take most common treatment assignment within cluster 
		//  as that cluster's treatment status. Note ritest and randcmd don't handle this use case
		tempvar neg_N_cluster_treatment 
		sort `cluster' `varname', stable
		by `cluster' `varname': gen `neg_N_cluster_treatment' = -_N
				// negative so largest on top
		sort `cluster' `neg_N_cluster_treatment', stable
		qui by `cluster': keep if _n == 1 // duplicates drop
	}
	tempvar nn
	gen `nn' = _n // original order

	_dots 0, title("Permutations") reps(`n_perm')
	forval i = 1/`n_perm' {	
		// Reshuffle
		tempvar random 
		gen `random' = runiform()	
		sort `random', stable
		// Take the treatment status from the observation which was at this position before
		gen `gentype' `gen'`i' = `varname'[`nn'] // trick taken from ritest.ado permute_simple function		
		
		_dots `i' 0
	}
	
	keep `cluster' `gen'?*
	
	if "`using'"!="" save `using', replace // cluster-level data set
end

