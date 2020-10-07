* HEADER FILE FOR USE ON SERVER 

***************
* DIRECTORIES *
***************
#delimit ;
local folders
	adofiles
	data
	graphs
	logs
	proc
	scripts 
	tables
	waste
;
#delimit cr

foreach folder of local folders {
	global `folder' $main/`folder'
}

************************
* PRELIMINARY PROGRAMS *
************************
adopath ++ $adofiles // user-written ado files saved here
