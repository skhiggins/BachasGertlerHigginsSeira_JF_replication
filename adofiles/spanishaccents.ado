** PROGRAM TO SAVE LOCALS WITH SPANISH ACCENT LETTERS (FOR USING ACCENTS IN GRAPHS, ETC.)
** Sean Higgins

program define spanishaccents
	local _A_ : di _char(193)
	local _E_ : di _char(201)
	local _I_ : di _char(205)
	local _O_ : di _char(211)
	local _U_ : di _char(218)
	local _a_ : di _char(225)
	local _e_ : di _char(233)
	local _i_ : di _char(237)
	local _o_ : di _char(243)
	local _u_ : di _char(250)
	local _N_ : di _char(209)
	local _n_ : di _char(241)
	local _exclamation_ : di _char(161)
	local _question_    : di _char(191)
	foreach x in A E I O U N {
		local _x = lower("`x'")
		c_local _`x'_ `_`x'_'
		c_local _`_x'_ `_`_x'_'
	}	
	foreach x in exclamation question {
		c_local _`x'_ `_`x'_'
	}
end
