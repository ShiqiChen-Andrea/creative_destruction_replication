*==============================================================================
* analysis.do : single-file replication of the whole project
*
* Research question: Has creative destruction in the US declined, 1980-2020?
* Data: Census Bureau Business Dynamics Statistics (BDS), 2021 release
*   data/bds2021_aggregate.csv   national aggregates
*   data/bds2021_fa.csv          aggregates by firm age
*
* Sections
*   0  Setup, paths, graph style
*   1  Data construction (measures, sanity checks)
*   2  Descriptive tables (decade means)
*   3  Tests of the "shift" hypothesis (e vs x), Newey-West trends, decomposition
*   4  Figures
*
* Written for Stata 15 or later. NOT yet run by the author of this file:
* compare your output with the reference values in the README.
*
* ---- Measurement decisions (document these in the research note) ------------
*  - Window 1980-2019 for trends; 2020-21 are plotted but excluded from
*    baseline trends: BDS measures changes to mid-March, so the pandemic is only
*    partly captured.
*  - Firm age 0-5 is identified from 1982 (the underlying LBD starts in 1976);
*    "X" cells in bds2021_fa.csv are structural missings, not random.
*  - Shares use total employment/firms from the aggregate file (identified age
*    classes sum to the aggregate total).
*  - Firm startup/exit rates: flow / average of firms in t and t-1 (BDS rule).
*
* ---- How the figures follow Schwabish (2014, JEP 28(1)) --------------------
*  Show the data
*    - The main series is the darkest and thickest line; context series lighter.
*    - Every data point is shown; no axis truncates the data.
*    - Small multiples (panels) instead of one crowded chart (Figures 1 and 4).
*  Reduce the clutter
*    - White background (overrides the Stata default); no plot-region border,
*      no y-axis line, no tick marks.
*    - Light horizontal gridlines; in Figure 5 the zero line is darker so it
*      serves as the baseline.
*    - No redundant "%" signs or rotated y-axis titles: units sit under the title.
*    - No markers on the line charts.
*  Integrate text and graph
*    - Descriptive titles that state the finding, top-left, with the unit in a
*      subtitle directly below.
*    - No legend boxes: series are labelled at the end of each line; Figure 5
*      puts its small legend directly under the title.
*    - Source and notes sit under each figure, so each can stand alone.
*  Colour: navy / orange / grey. Distinct in luminance (works in greyscale) and
*    free of the red-green pair that some readers cannot tell apart. Check with
*    ColorBrewer or Color Oracle if you want to be certain.
*  Font: Garamond is requested if installed (Schwabish suggests avoiding the
*    overused defaults); Stata falls back silently if it is missing.
*==============================================================================

*------------------------------------------------------------------------------
* 0. Setup
*------------------------------------------------------------------------------
clear all
set more off

* >>> edit once: folder that contains data/ <<<
cd "."

global data "data"
global out  "output"
capture mkdir "$out"

capture set scheme s1mono
capture graph set window fontface "Garamond"

* Colours (RGB)
global cDark "20 60 110"
global cOrng "217 95 2"
global cGray "140 140 140"

*------------------------------------------------------------------------------
* 1. Data construction
*------------------------------------------------------------------------------
* ---- 1a. Firm-age file: startups (age 0), young firms (0-5), alt young (0-2)
import delimited "bds2021_fa.csv", clear stringcols(_all)
destring firms estabs emp, replace force          // "X" (suppressed) -> missing
destring year, replace
gen code = substr(fage, 1, 1)                     // a) 0, b) 1, c) 2, ... f) 5

preserve                                          // startups
    keep if code == "a"
    keep year firms estabs emp
    rename (firms estabs emp) (startup_firms startup_estabs startup_emp)
    tempfile startups
    save `startups'
restore

preserve                                          // firms aged 0-5
    keep if inlist(code, "a", "b", "c", "d", "e", "f")
    collapse (sum) young_firms = firms young_emp = emp (count) n_obs = emp, by(year)
    replace young_firms = . if n_obs < 6
    replace young_emp   = . if n_obs < 6
    drop n_obs
    tempfile young
    save `young'
restore

preserve                                          // firms aged 0-2 (robustness)
    keep if inlist(code, "a", "b", "c")
    collapse (sum) y02_emp = emp (count) n_obs = emp, by(year)
    replace y02_emp = . if n_obs < 3
    keep year y02_emp
    tempfile y02
    save `y02'
restore

* ---- 1b. Aggregate file: merge and construct measures
import delimited "bds2021_aggregate.csv", clear
sort year
merge 1:1 year using `startups', nogenerate
merge 1:1 year using `young',    nogenerate
merge 1:1 year using `y02',      nogenerate
sort year

gen avg_firms         = (firms  + firms[_n-1])  / 2
gen avg_estabs        = (estabs + estabs[_n-1]) / 2

* baseline indicators
gen firm_exit_rate    = 100 * firmdeath_firms / avg_firms
gen firm_startup_rate = 100 * startup_firms   / avg_firms
gen young_emp_share   = 100 * young_emp       / emp
gen young_firm_share  = 100 * young_firms     / firms
gen startup_emp_share = 100 * startup_emp     / emp
gen young02_emp_share = 100 * y02_emp         / emp
gen estab_turnover    = estabs_entry_rate + estabs_exit_rate
foreach v in young_emp_share young_firm_share young02_emp_share {
    replace `v' = . if year < 1982                // same start year for all age series
}

* e vs x proxies (see header of section 3)
gen entry_total       = estabs_entry_rate
gen entry_newfirms    = 100 * startup_estabs / avg_estabs     // establishments of age-0 firms
gen entry_incumbent   = entry_total - entry_newfirms          // new establishments of existing firms
gen share_new_entry   = 100 * startup_estabs / estabs_entry
gen exit_firmdeath    = 100 * firmdeath_estabs / avg_estabs
gen exit_incumbent    = estabs_exit_rate - exit_firmdeath     // closures by continuing firms
gen cont_creation     = 100 * job_creation_continuers    / denom
gen cont_destruction  = 100 * job_destruction_continuers / denom
gen cont_flows        = cont_creation + cont_destruction
gen births            = 100 * job_creation_births    / denom
gen deaths            = 100 * job_destruction_deaths / denom
gen flows_total       = job_creation_rate + job_destruction_rate

label var estabs_entry_rate    "Establishment entry rate"
label var estabs_exit_rate     "Establishment exit rate"
label var firm_startup_rate    "Firm startup rate"
label var firm_exit_rate       "Firm exit rate"
label var job_creation_rate    "Job creation rate"
label var job_destruction_rate "Job destruction rate"
label var reallocation_rate    "Reallocation rate"
label var young_firm_share     "Share of firms aged 0-5"
label var young_emp_share      "Share of employment in firms aged 0-5"
label var young02_emp_share    "Share of employment in firms aged 0-2"
label var startup_emp_share    "Share of employment in startups (age 0)"
label var entry_newfirms       "Entry: establishments of new firms"
label var entry_incumbent      "Entry: new establishments of existing firms"
label var exit_incumbent       "Exit: closures by continuing firms"
label var cont_flows           "Gross job flows, continuing establishments"
label var births               "Job creation, establishment births"
label var deaths               "Job destruction, establishment deaths"

* ---- 1c. Sanity checks
* (i) gross flows = continuers + births + deaths (up to rounding)
assert abs(flows_total - (cont_flows + births + deaths)) < 0.01 if inrange(year, 1980, 2021)
* (ii) residual definitions must be non-negative
count if (entry_incumbent < 0 | exit_incumbent < 0) & inrange(year, 1980, 2021)
assert r(N) == 0
* (iii) age series start in 1982
assert missing(young_emp_share) if year < 1982

tsset year
save "$out/constructed_series.dta", replace
export delimited using "$out/constructed_series.csv" if inrange(year, 1980, 2021), replace

*------------------------------------------------------------------------------
* 2. Descriptive tables: decade means
*------------------------------------------------------------------------------
local tabvars estabs_entry_rate estabs_exit_rate estab_turnover firm_startup_rate ///
              job_creation_rate job_destruction_rate reallocation_rate            ///
              young_emp_share young_firm_share young02_emp_share                  ///
              entry_newfirms entry_incumbent exit_incumbent                       ///
              cont_flows births deaths

preserve
    keep if inrange(year, 1980, 2019)
    gen decade = 10 * floor(year/10)
    collapse (mean) `tabvars', by(decade)
    format `tabvars' %9.2f
    list, noobs clean
    export delimited using "$out/table_decades.csv", replace
restore

*------------------------------------------------------------------------------
* 3. Tests of the "shift" hypothesis
*
* Framework (Lecture 5): tau = e + x
*   e proxies (new entrants):  entry_newfirms, firm_startup_rate, births
*   x proxies (incumbents):    entry_incumbent, exit_incumbent, cont_flows
* H_shift: e proxies fall, x proxies do NOT fall.   H_broad: both fall.
* Decision rule (fixed in advance): "falling" if the 95% CI of the trend
* (pp per decade) lies entirely below zero; "rising" if entirely above.
* ~40 annual observations, serially correlated: Newey-West standard errors,
* lags 2, 3 and 5 (the lag is a judgement call). Windows: 1980-2019 baseline,
* 1980-2000 and 2000-2019 (split motivated by the post-2000 changes in
* Decker et al. 2016), and 1980-2021 (COVID sensitivity).
* Inference is descriptive, not a formal test of causal claims.
*------------------------------------------------------------------------------
tempname H
tempfile hac
postfile `H' str24 variable str10 window int nwlag double(slope lo hi) using `hac', replace

local epx entry_newfirms firm_startup_rate births
local xpx entry_incumbent exit_incumbent cont_flows

foreach v in `epx' `xpx' {
    foreach w in "1980 2019" "1980 2000" "2000 2019" "1980 2021" {
        local lo : word 1 of `w'
        local hi : word 2 of `w'
        foreach L in 2 3 5 {
            quietly newey `v' year if inrange(year, `lo', `hi'), lag(`L')
            local b  = _b[year]
            local se = _se[year]
            local tc = invttail(e(df_r), 0.025)
            post `H' ("`v'") ("`lo'-`hi'") (`L') (10*`b') (10*(`b'-`tc'*`se')) (10*(`b'+`tc'*`se'))
        }
    }
}
foreach v in young_emp_share young_firm_share young02_emp_share {
    foreach w in "1982 2019" "1982 2000" "2000 2019" "1982 2021" {
        local lo : word 1 of `w'
        local hi : word 2 of `w'
        foreach L in 2 3 5 {
            quietly newey `v' year if inrange(year, `lo', `hi'), lag(`L')
            local b  = _b[year]
            local se = _se[year]
            local tc = invttail(e(df_r), 0.025)
            post `H' ("`v'") ("`lo'-`hi'") (`L') (10*`b') (10*(`b'-`tc'*`se')) (10*(`b'+`tc'*`se'))
        }
    }
}
postclose `H'

preserve
    use `hac', clear
    gen verdict = cond(hi < 0, "falling", cond(lo > 0, "rising", "no clear trend"))
    format slope lo hi %9.2f
    export delimited using "$out/table_tests_trends.csv", replace
    di _n "Trends per decade (Newey-West lag 3):"
    list variable window slope lo hi verdict if nwlag == 3, sepby(variable) noobs
restore

* ---- Decomposition of changes between 1980s and 2010s means
capture program drop dmean
program define dmean, rclass
    syntax varname, lo(integer) hi(integer)
    quietly summarize `varlist' if inrange(year, `lo', `hi')
    return scalar m = r(mean)
end

tempname D
tempfile dec
postfile `D' str24 total str24 component double(change share_pct) using `dec', replace
foreach grp in "entry_total entry_newfirms entry_incumbent" ///
               "flows_total cont_flows births deaths" {
    local tot : word 1 of `grp'
    dmean `tot', lo(1980) hi(1989)
    local t0 = r(m)
    dmean `tot', lo(2010) hi(2019)
    local dT = r(m) - `t0'
    post `D' ("`tot'") ("TOTAL") (`dT') (100)
    local n : word count `grp'
    forvalues i = 2/`n' {
        local c : word `i' of `grp'
        dmean `c', lo(1980) hi(1989)
        local c0 = r(m)
        dmean `c', lo(2010) hi(2019)
        local dC = r(m) - `c0'
        post `D' ("`tot'") ("`c'") (`dC') (100 * `dC' / `dT')
    }
}
postclose `D'
preserve
    use `dec', clear
    format change share_pct %9.2f
    export delimited using "$out/table_tests_decomp.csv", replace
    di _n "Decomposition of the change between the 1980-89 and 2010-19 means:"
    list, noobs sepby(total)
restore

*------------------------------------------------------------------------------
* 4. Figures (Schwabish 2014 style, see header)
*------------------------------------------------------------------------------
* Shared options. Axis labels are set in each graph via these sub-options.
local sty  graphregion(color(white) lcolor(white)) plotregion(color(white) lcolor(white)) ///
           yscale(noline) ytitle("") xtitle("") legend(off)
local ysub angle(0) noticks grid glcolor(gs14) glwidth(vthin) labsize(small)
local xsub noticks labsize(small)
local src  "Source: US Census Bureau, Business Dynamics Statistics (2021 vintage); author's calculations."
local cov  "Dashed line marks 2020; BDS data for 2020-21 only partly capture the pandemic (mid-March to mid-March)."

* Helper: keep two end-of-line labels at least `gap' apart
capture program drop spread
program define spread, rclass
    args a b gap
    if abs(`a' - `b') >= `gap' {
        return scalar a = `a'
        return scalar b = `b'
    }
    else {
        local mid = (`a' + `b') / 2
        if `a' >= `b' {
            return scalar a = `mid' + `gap'/2
            return scalar b = `mid' - `gap'/2
        }
        else {
            return scalar a = `mid' - `gap'/2
            return scalar b = `mid' + `gap'/2
        }
    }
end

* Decade means used in the descriptive titles
foreach v in reallocation_rate cont_flows {
    quietly summarize `v' if inrange(year, 1980, 1989)
    local `v'_80 = string(r(mean), "%3.0f")
    quietly summarize `v' if inrange(year, 2010, 2019)
    local `v'_10 = string(r(mean), "%3.0f")
}
quietly summarize young_emp_share if inrange(year, 1982, 1989)
local young_80 = string(r(mean), "%3.0f")
quietly summarize young_emp_share if inrange(year, 2010, 2019)
local young_10 = string(r(mean), "%3.0f")

* ---------------- Figure 1: entry and exit (two panels) -----------------------
* Panel A: establishments
quietly summarize estabs_entry_rate if year == 2021
local a = r(mean)
quietly summarize estabs_exit_rate if year == 2021
local b = r(mean)
spread `a' `b' 0.7
local ya = r(a)
local yb = r(b)
twoway (line estabs_entry_rate year, lcolor("$cDark") lwidth(thick))              ///
       (line estabs_exit_rate  year, lcolor("$cOrng") lwidth(thick))              ///
       if inrange(year, 1980, 2021),                                              ///
       `sty' xscale(range(1980 2029) lcolor(gs8))                                 ///
       xlabel(1980(10)2020, `xsub') ylabel(, `ysub')                              ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`ya' 2021.5 "Entry", place(e) size(small) color("$cDark"))            ///
       text(`yb' 2021.5 "Exit",  place(e) size(small) color("$cOrng"))            ///
       title("A. Establishments", size(medsmall) position(11))                    ///
       subtitle("(percent of establishments)", size(small) position(11))          ///
       name(g1a, replace) nodraw

* Panel B: firms
quietly summarize firm_startup_rate if year == 2021
local a = r(mean)
quietly summarize firm_exit_rate if year == 2021
local b = r(mean)
spread `a' `b' 0.7
local ya = r(a)
local yb = r(b)
twoway (line firm_startup_rate year, lcolor("$cDark") lwidth(thick))              ///
       (line firm_exit_rate    year, lcolor("$cOrng") lwidth(thick))              ///
       if inrange(year, 1980, 2021),                                              ///
       `sty' xscale(range(1980 2029) lcolor(gs8))                                 ///
       xlabel(1980(10)2020, `xsub') ylabel(, `ysub')                              ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`ya' 2021.5 "Startup", place(e) size(small) color("$cDark"))          ///
       text(`yb' 2021.5 "Exit",    place(e) size(small) color("$cOrng"))          ///
       title("B. Firms", size(medsmall) position(11))                             ///
       subtitle("(percent of firms)", size(small) position(11))                   ///
       name(g1b, replace) nodraw

graph combine g1a g1b, cols(2) ycommon graphregion(color(white) lcolor(white))    ///
       title("Entry and exit rates both fell between 1980 and 2019",              ///
             size(medium) position(11))                                           ///
       note("Note: rates are flows divided by the average stock in t and t-1. `cov'" ///
            "`src'", size(vsmall) span)
graph export "$out/fig1_entry_exit.png", width(2400) replace
capture graph export "$out/fig1_entry_exit.pdf", replace

* ---------------- Figure 2: job flows ----------------------------------------
quietly summarize job_creation_rate if year == 2021
local ycr = r(mean)
quietly summarize job_destruction_rate if year == 2021
local yds = r(mean)
quietly summarize reallocation_rate if year == 2021
local yre = r(mean)
spread `ycr' `yds' 1.2
local ycr = r(a)
local yds = r(b)
twoway (line job_creation_rate    year, lcolor("$cOrng") lwidth(medium))          ///
       (line job_destruction_rate year, lcolor("$cGray") lwidth(medium))          ///
       (line reallocation_rate    year, lcolor("$cDark") lwidth(thick))           ///
       if inrange(year, 1980, 2021),                                              ///
       `sty' xscale(range(1980 2030) lcolor(gs8))                                 ///
       xlabel(1980(10)2020, `xsub') ylabel(, `ysub')                              ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`yre' 2021.5 "Reallocation", place(e) size(small) color("$cDark"))    ///
       text(`yds' 2021.5 "Destruction",  place(e) size(small) color("$cGray"))    ///
       text(`ycr' 2021.5 "Creation",     place(e) size(small) color("$cOrng"))    ///
       title("Job reallocation fell from `reallocation_rate_80'% of employment in the 1980s" ///
             "to `reallocation_rate_10'% in the 2010s", size(medium) position(11)) ///
       subtitle("(percent of employment)", size(small) position(11))              ///
       note("Note: reallocation = job creation + job destruction - |net job creation|. `cov'" ///
            "`src'", size(vsmall) span)                                           ///
       name(g2, replace)
graph export "$out/fig2_job_flows.png", width(2400) replace
capture graph export "$out/fig2_job_flows.pdf", replace

* ---------------- Figure 3: young firms --------------------------------------
quietly summarize young_firm_share if year == 2021
local yf = r(mean)
quietly summarize young_emp_share if year == 2021
local ye = r(mean)
quietly summarize startup_emp_share if year == 2021
local ys = r(mean)
twoway (line young_firm_share   year, lcolor("$cGray") lwidth(medium))            ///
       (line young_emp_share    year, lcolor("$cDark") lwidth(thick))             ///
       (line startup_emp_share  year, lcolor("$cOrng") lwidth(medium))            ///
       if inrange(year, 1982, 2021),                                              ///
       `sty' xscale(range(1982 2032) lcolor(gs8))                                 ///
       xlabel(1985(10)2015 2020, `xsub') ylabel(0(10)50, `ysub')                  ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`yf' 2021.5 "Share of firms",       place(e) size(small) color("$cGray")) ///
       text(`ye' 2021.5 "Share of employment",  place(e) size(small) color("$cDark")) ///
       text(`ys' 2021.5 "Startups (age 0)",     place(e) size(small) color("$cOrng")) ///
       title("Firms aged 0-5 account for a shrinking share of employment:"        ///
             "`young_80'% in the 1980s, `young_10'% in the 2010s",                ///
             size(medium) position(11))                                           ///
       subtitle("(percent of total; firms aged 0-5 unless labelled otherwise)",   ///
                size(small) position(11))                                         ///
       note("Note: firm age 0-5 is identified from 1982 (the underlying data begin in 1976); the 1980s figure averages 1982-89. `cov'" ///
            "`src'", size(vsmall) span)                                           ///
       name(g3, replace)
graph export "$out/fig3_young_firms.png", width(2400) replace
capture graph export "$out/fig3_young_firms.pdf", replace

* ---------------- Figure 4: who drives the fall? (two panels) -----------------
* Panel A: establishment entry by source
quietly summarize entry_newfirms if year == 2021
local yn = r(mean)
quietly summarize entry_incumbent if year == 2021
local yi = r(mean)
spread `yn' `yi' 0.8
local yn = r(a)
local yi = r(b)
twoway (line entry_newfirms  year, lcolor("$cDark") lwidth(thick))                ///
       (line entry_incumbent year, lcolor("$cOrng") lwidth(thick))                ///
       if inrange(year, 1980, 2021),                                              ///
       `sty' xscale(range(1980 2032) lcolor(gs8))                                 ///
       xlabel(1980(10)2020, `xsub') ylabel(0(2)12, `ysub')                        ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`yn' 2021.5 "New firms",      place(e) size(small) color("$cDark"))   ///
       text(`yi' 2021.5 "Existing firms", place(e) size(small) color("$cOrng"))   ///
       title("A. Establishment entry, by source", size(medsmall) position(11))    ///
       subtitle("(percent of establishments)", size(small) position(11))          ///
       name(g4a, replace) nodraw

* Panel B: job flows of continuing establishments
quietly summarize cont_flows if year == 2021
local yc = r(mean)
quietly summarize births if year == 2021
local yb = r(mean)
quietly summarize deaths if year == 2021
local yd = r(mean)
spread `yb' `yd' 1.8
local yb = r(a)
local yd = r(b)
twoway (line cont_flows year, lcolor("$cDark") lwidth(thick))                     ///
       (line births     year, lcolor("$cOrng") lwidth(medium))                    ///
       (line deaths     year, lcolor("$cGray") lwidth(medium))                    ///
       if inrange(year, 1980, 2021),                                              ///
       `sty' xscale(range(1980 2032) lcolor(gs8))                                 ///
       xlabel(1980(10)2020, `xsub') ylabel(0(5)25, `ysub')                        ///
       xline(2019.5, lcolor(gs12) lpattern(dash) lwidth(thin))                    ///
       text(`yc' 2021.5 "Continuing", place(e) size(small) color("$cDark"))       ///
       text(`yb' 2021.5 "Births",     place(e) size(small) color("$cOrng"))       ///
       text(`yd' 2021.5 "Deaths",     place(e) size(small) color("$cGray"))       ///
       title("B. Gross job flows", size(medsmall) position(11))                   ///
       subtitle("(percent of employment)", size(small) position(11))              ///
       name(g4b, replace) nodraw

graph combine g4a g4b, cols(2) graphregion(color(white) lcolor(white))            ///
       title("The fall in entry comes from new firms, and churn at continuing"    ///
             "establishments has fallen too", size(medium) position(11))          ///
       note("Note: new firms = establishments of firms aged 0 (approximation); existing firms = remainder of establishment entry. Panel B: continuing = job creation + destruction at continuing establishments; births and deaths = job creation at establishment births and job destruction at establishment deaths. `cov'" ///
            "`src'", size(vsmall) span)
graph export "$out/fig4_decomposition.png", width(2400) replace
capture graph export "$out/fig4_decomposition.pdf", replace

* ---------------- Figure 5: trends of e and x proxies --------------------------
preserve
    use `hac', clear
    keep if nwlag == 3 & inlist(window, "1980-2000", "2000-2019")
    keep if inlist(variable, "entry_newfirms", "firm_startup_rate", "births", ///
                             "entry_incumbent", "exit_incumbent", "cont_flows")
    gen order = .
    replace order = 6 if variable == "entry_newfirms"
    replace order = 5 if variable == "firm_startup_rate"
    replace order = 4 if variable == "births"
    replace order = 3 if variable == "entry_incumbent"
    replace order = 2 if variable == "exit_incumbent"
    replace order = 1 if variable == "cont_flows"
    gen ypos = order + cond(window == "2000-2019", -0.15, 0.15)

    twoway (rcap lo hi ypos if window == "1980-2000", horizontal                  ///
                  lcolor("$cDark") lwidth(medthick))                              ///
           (scatter ypos slope if window == "1980-2000",                          ///
                  mcolor("$cDark") msymbol(O) msize(medlarge))                    ///
           (rcap lo hi ypos if window == "2000-2019", horizontal                  ///
                  lcolor("$cOrng") lwidth(medthick))                              ///
           (scatter ypos slope if window == "2000-2019",                          ///
                  mcolor("$cOrng") msymbol(D) msize(medlarge)),                   ///
           graphregion(color(white) lcolor(white))                                ///
           plotregion(color(white) lcolor(white))                                 ///
           yscale(noline) ytitle("") xtitle("")                                   ///
           xline(0, lcolor(gs6) lwidth(medium))                                   ///
           xlabel(, noticks grid glcolor(gs14) glwidth(vthin) labsize(small))     ///
           ylabel(6 "(e) Entry, new-firm establishments"                          ///
                  5 "(e) Firm startup rate"                                       ///
                  4 "(e) Job creation, births"                                    ///
                  3 "(x) Entry, existing firms"                                   ///
                  2 "(x) Exit, continuing firms"                                  ///
                  1 "(x) Job flows, continuing establishments",                   ///
                  angle(0) noticks labsize(small))                                ///
           title("After 2000, proxies for both entrant and incumbent replacement fall" ///
                 , size(medium) position(11))                                     ///
           subtitle("(trend in percentage points per decade; bars show 95% confidence intervals)", ///
                    size(small) position(11))                                     ///
           legend(order(2 "1980-2000" 4 "2000-2019") rows(1) position(11) ring(1) ///
                  size(small) region(lcolor(white)))                              ///
           note("Note: (e) = proxy for replacement by entrants; (x) = proxy for replacement among incumbents. Newey-West standard errors, 3 lags." ///
                "`src'", size(vsmall) span)                                       ///
           name(g5, replace)
    graph export "$out/fig5_e_vs_x_trends.png", width(2400) replace
    capture graph export "$out/fig5_e_vs_x_trends.pdf", replace
restore

di _n "Done. Tables and figures are in $out."
di "Check every figure title against table_tests_trends.csv and table_tests_decomp.csv before submitting."
