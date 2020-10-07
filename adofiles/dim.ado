capture program drop dim
program define dim, rclass // like dim() in R
	if !strpos("`1'","'") confirm matrix `1'
	tempname _mat
	matrix `_mat' = `1' // this is to allow it to work with e.g. e(b)
	di as result rowsof(`_mat') _s colsof(`_mat')
	return scalar cols = colsof(`_mat')
	return scalar rows = rowsof(`_mat')
end
