** PUT MATRIX FROM STATA TO MATA
**  Sean Higgins
**  March 27, 2016

cap program drop putmatrix
program define putmatrix
	mata : `1' = st_matrix("`1'")
end
