** GET MATRIX FROM MATA TO STATA
**  Sean Higgins
**  March 27, 2016

cap program drop getmatrix
program define getmatrix
	mata : st_matrix("`1'",`1')
end
