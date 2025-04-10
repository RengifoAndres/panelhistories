clear all

program define panelstories
    version 18
    syntax [if] [in], ID(varname) TIME(varname) [MAXperiod(integer -1)]

    * Step 1: Preserve the original dataset
   * preserve

    * Step 2: Restrict sample if specified
    if "`if'" != "" | "`in'" != "" {
        keep `if' `in'
    }


    * Step 3: Check for panel structure and determine T
    quietly xtset `id' `time'
    if "`r(panelvar)'" == "" {
        display as error "Dataset must be a panel with ID and TIME variables."
        exit 198
    }
    if `maxperiod' == -1 {
        quietly summarize `time'
        local T = r(max)
    }
    else {
        local T = `maxperiod'
    }

    * Step 4: Create a wide dataset with presence indicators
    
    keep `id' `time'
    qui gen w_t= `time'
    quietly reshape wide w_t, i(`id') j(`time')
    foreach v of varlist w_t* {
        quietly replace `v' = 1 if !missing(`v')
        quietly replace `v' = 0 if missing(`v')
    }

    * Step 5: Generate a string representing each story
    gen story = ""
    forvalues t = 1/`T' {
        capture confirm variable w_t`t'
        if !_rc {
            quietly replace story = story + string(w_t`t')
        }
        else {
            quietly replace story = story + "0"
        }
    }

    * Step 6: Collapse to unique stories and calculate proportions
    collapse (count) n_ids=`id', by(story)
    quietly summarize n_ids
    gen prop = n_ids / r(sum)
    label var prop "Proportion of IDs"
    gen story_id = _n

    * Step 7: Reshape for plotting
    gen row = -story_id  // Negative to stack rows upward
    local rows = _N
    expand `T'
    bysort story_id: gen col = _n
    gen observed = real(substr(story, col, 1))
    label var observed "Observed"
	gen observed1= col if observed==1
	gen  observed0= col if observed==0
	
	gen base =0
    * Step 8: Create the graph
    twoway (rbar base observed1 row  if observed == 1, horizontal) ///
           (rbar base  observed0 row if observed == 0, horizontal), ///
           ytitle("Observation Patterns") xtitle("Time Periods") ///
           ylabel(`=-1'(`=-1')`=-`rows'', valuelabel labsize(small)) ///
           xlabel(1(1)`T') legend(off) 

    * Step 9: Restore original dataset
    *restore
end

clear
set seed 12345  // For reproducibility

* Step 1: Set parameters
local N = 1000  // Number of IDs
local T = 10    // Maximum number of time periods

* Step 2: Generate full panel (N x T)
set obs `=`N' * `T''
gen id = ceil(_n / `T')
gen time = mod(_n - 1, `T') + 1

* Step 3: Simulate a value (e.g., random outcome with ID-specific effect)
gen id_effect = rnormal(0, 2) if time == 1  // Random effect per ID
bysort id: replace id_effect = id_effect[1]
gen value = 5 + id_effect + 0.5 * time + rnormal(0, 1)  // Trend + noise

* Step 4: Introduce unbalancedness by randomly dropping observations
gen drop_prob = runiform()
drop if drop_prob > 0.7  // Keep ~70% of observations, drop ~30% randomly

* Step 5: Clean up and set as panel
drop drop_prob
xtset id time
sort id time

* Step 6: Summarize the dataset


panelstories, id(id) time(time) maxperiod(5)
