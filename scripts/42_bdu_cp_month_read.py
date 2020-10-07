
# coding: utf-8

# Read in the data on number of POS by zip code by month, which is printed in a log file
#  Sean Higgins
#  24nov2018

# PACKAGES

import os
import re

# FUNCTIONS

def read_write_data(indata, outfile):
    passed_averages = 0
    passed_varnames = 0
    
    with open(outfile, 'w') as out_write:
        for line in indata:
            if passed_averages == 0:
                if "averages" in line:
                    passed_averages = passed_averages + 1
                    continue
                else: 
                    continue
            else:
                if passed_varnames == 0 and "cp" in line and "n_cp" not in line: # varnames row
                    line_to_print = re.sub(r"^\s+", "", line)
                    line_to_print = re.sub("\s+", ",", line_to_print)
                    line_to_print = re.sub(",$", "\n", line_to_print)
                    out_write.write(line_to_print) # initial spaces
                    passed_varnames = passed_varnames + 1
                elif "cp" in line:
                    continue
                elif ":" in line: # line with data
                    line_to_print = re.sub(r"^.{1,2}\:\s+", "", line)
                    line_to_print = re.sub("\s+", ",", line_to_print)
                    line_to_print = re.sub(",$", "\n", line_to_print)
                    out_write.write(line_to_print)
                else: 
                    continue

# DATA
										
# For all giros:
# (Saved in the file "bdu_cp_month_means_allgiro_....log")
# New version with merge:
to_read_new = os.path.join("logs", "bdu_cp_month_means_allgiro_20190121_111839.log")
to_write_new = os.path.join("proc", "bdu_cp_month_means_new.csv")

with open(to_read_new, 'r') as raw_allgiro_new:
    allgiro_new = raw_allgiro_new.readlines()

# Read and write the data
read_write_data(allgiro_new, to_write_new)

