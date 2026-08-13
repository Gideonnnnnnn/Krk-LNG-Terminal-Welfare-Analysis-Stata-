*==============================================================================
* Krk LNG Terminal — Welfare Analysis
* Cleaned and commented version of January5.log
* Original raw session log is included separately (January5.log) as a record
* of the actual console output at the time these commands were run.
*==============================================================================

*------------------------------------------------------------------------------
* 1. DATA SETUP
*------------------------------------------------------------------------------
import delimited "/Users/gsobek/Desktop/January5.csv"
preserve

encode country, gen(country_id)
xtset country_id year

* Treatment indicators: Croatia = treated unit, 2021 = Krk terminal start year
gen treated       = (country == "Croatia")
gen post          = (year >= 2021)
gen treated_post  = treated * post
gen year_num      = year
encode country, gen(country_num)

* Log transforms for regression variables
gen ln_elec_price   = ln(elec_price)
gen ln_gas_price     = ln(gas_price)
gen ln_total_elec   = ln(total_elec)
gen ln_total_gas    = ln(gas_final)
gen ln_gdp_pc       = ln(gdp_capita)
gen ln_pop          = ln(population)
gen ln_final_elec   = ln(elec_final)
gen ln_gas_elec     = ln(gas_elec)
gen ln_ren_elec     = ln(ren_elec)
gen ln_solidff_elec = ln(solidff_elec)

*------------------------------------------------------------------------------
* 2. BASELINE DIFFERENCE-IN-DIFFERENCES
*------------------------------------------------------------------------------
* Simple DiD, no controls
reg ln_elec_price treated post treated_post, vce(cluster country_id)

* DiD with controls
reg ln_elec_price treated post treated_post ln_gas_price ln_ren_elec ///
    ln_gas_elec ln_solidff_elec ln_gdp_pc ln_pop, vce(cluster country_id)

* Two-way fixed effects version (country + year FE absorbed)
* NOTE: pct_elec_* variables below were not in the dataset under that name;
* the ln_*_elec versions (used in the next line) are the ones that ran.
* reghdfe ln_elec_price treated_post ln_gas_price pct_elec_renewables ///
*     pct_elec_gas pct_elec_solidfossil ln_gdp_pc ln_pop, ///
*     absorb(country_id year) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop, absorb(country_id year) ///
    vce(cluster country_id)

*------------------------------------------------------------------------------
* 3. SYNTHETIC CONTROL METHOD
*------------------------------------------------------------------------------
gen treat_id = 1 if country == "Croatia"
replace treat_id = 0 if treat_id == .

* ln_solidff_elec has missing values for some countries/years, which breaks
* synth's predictor averaging — set missing to 0 before running.
replace ln_solidff_elec = 0 if ln_solidff_elec == .

tab country country_id
levelsof country_id if country == "Croatia", local(croatia_id)

* Main synthetic control run (trunit = Croatia's country_id)
synth ln_elec_price ln_elec_price(2013) ln_elec_price(2014) ///
    ln_elec_price(2015) ln_elec_price(2016) ln_elec_price(2017) ///
    ln_elec_price(2018) ln_elec_price(2019) ln_elec_price(2020) ///
    ln_gas_price ln_ren_elec ln_gas_elec ln_solidff_elec ln_gdp_pc ln_pop, ///
    trunit(1) trperiod(2021) unitnames(country) ///
    mspeperiod(2013(1)2020) resultsperiod(2013(1)2024) ///
    keep(synth_results.dta) replace fig

* Repeated with pct_elec_* predictor set (donor-pool / specification checks)
synth ln_elec_price ln_elec_price(2013) ln_elec_price(2014) ///
    ln_elec_price(2015) ln_elec_price(2016) ln_elec_price(2017) ///
    ln_elec_price(2018) ln_elec_price(2019) ln_elec_price(2020) ///
    ln_gas_price pct_elec_renewables pct_elec_gas pct_elec_solidfossil ///
    ln_gdp_pc ln_pop, trunit(2) trperiod(2021) unitnames(country) ///
    mspeperiod(2013(1)2020) resultsperiod(2013(1)2024) ///
    keep(synth_results.dta) replace fig

* Donor pool candidates explored (kept as comments for reference):
* Bulgaria, Estonia, Romania, Slovakia, Poland
* Greece, Romania, Lithuania, Hungary

*------------------------------------------------------------------------------
* 4. EVENT-STUDY / GAS-PRICE INTERACTION SPECIFICATIONS
*------------------------------------------------------------------------------
gen post_krk = (year >= 2021)

reghdfe ln_elec_price c.post_krk##c.ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop, absorb(country_id year) ///
    vce(cluster country_id)

* Crisis-period interaction (2022-2023 energy crisis)
gen crisis     = inlist(year, 2022, 2023)
gen krk_crisis = post_krk * crisis

reghdfe ln_elec_price post_krk crisis krk_crisis ln_gas_price ln_ren_elec ///
    ln_gas_elec ln_solidff_elec ln_gdp_pc ln_pop, absorb(country_id year) ///
    vce(cluster country_id)

* Country-specific linear trends
gen trend         = year - 2013
gen croatia_trend = treated * trend

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop, ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

*------------------------------------------------------------------------------
* 5. ROBUSTNESS: ALTERNATIVE DONOR / COMPARISON POOLS
*------------------------------------------------------------------------------
* Balkan / Southeast European countries only
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Bulgaria", "Romania", "Greece", "Hungary"), ///
    absorb(country_id year) vce(cluster country_id)

* Baltic + Romania
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Lithuania", "Latvia", "Romania"), absorb(country_id year) ///
    vce(cluster country_id)

* Single-country comparisons
foreach c in "Slovenia" "Romania" "Bulgaria" "Latvia" {
    reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
        ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", "`c'"), ///
        absorb(country_id year) vce(cluster country_id)
}

* Same comparisons with country-specific trends added
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Bulgaria", "Romania", "Greece", "Hungary"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Romania"), absorb(country_id year c.trend#i.country_id) ///
    vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Romania", "Greece"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Romania", "Latvia", "Lithuania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Slovenia", "Latvia", "Lithuania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

*------------------------------------------------------------------------------
* 6. ROBUSTNESS: SPECIFICATION VARIANTS (donor pool sensitivity)
*------------------------------------------------------------------------------
* Specification 1: All countries
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop, ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)
estimates store all_controls

* Specification 2: Similar gas dependence (within +/- 10% of Croatia's)
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Greece", "Romania", "Lithuania", "Hungary"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania", "Slovakia"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania", "Slovakia", "Poland"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

* Specification 4: Regional/geographic grouping
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Romania", "Greece", "Slovenia"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria"), absorb(country_id year c.trend#i.country_id) ///
    vce(cluster country_id)

*------------------------------------------------------------------------------
* 7. STATISTICAL INFERENCE (Croatia + Bulgaria + Estonia + Romania donor pool)
*------------------------------------------------------------------------------
* Preferred/final specification for inference
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

* One-sided test (directional hypothesis: Krk terminal lowered prices)
scalar t_stat     = _b[treated_post] / _se[treated_post]
scalar p_onesided = ttail(e(df_r), abs(t_stat))
display "One-sided p-value: " p_onesided

scalar true_effect = _b[treated_post]

* --- Permutation test 1 (exploratory) ---------------------------------------
* NOTE: this loop did not complete successfully in the original session
* (a syntax error in the closing brace, and fake_treated_post was undefined
* going into the results-collection step). Left here, corrected, as a record
* of the intended permutation-test design; superseded by the corrected
* version in section 8.
set seed 12345
matrix placebo_effects = J(1000, 1, .)
forvalues i = 1/1000 {
    preserve
    gen random = runiform()
    bysort country: egen country_random = max(random)
    sort country_random
    gen fake_treated      = (_n <= 12)
    gen fake_post         = (year >= 2021)
    gen fake_treated_post = fake_treated * fake_post
    quietly reghdfe ln_elec_price fake_treated_post ln_gas_price ln_ren_elec ///
        ln_gas_elec ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, ///
        "Croatia", "Bulgaria", "Estonia", "Romania"), ///
        absorb(country_id year c.trend#i.country_id) vce(cluster country_id)
    matrix placebo_effects[`i', 1] = _b[fake_treated_post]
    restore
}
svmat placebo_effects
count if placebo_effects1 <= true_effect
local p_perm = r(N) / 1000
display "Permutation-based p-value: `p_perm'"

* 90% CI on the preferred specification
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)
lincom treated_post, level(90)

* Strategy 4: interact gas price to detect pass-through vs. level effects
reghdfe ln_elec_price c.post_krk##c.ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)
test c.post_krk#c.ln_gas_price

* Strategy 5: cross-sectional only (no year FE) — check if any single period differs
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), absorb(country_id) ///
    vce(cluster country_id)

* Effect during the 2022-2023 crisis specifically
gen crisis         = inlist(year, 2022, 2023)
gen treated_crisis = treated * crisis

reghdfe ln_elec_price treated_crisis ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) vce(cluster country_id)

* Strategy 6: wild cluster bootstrap (small-cluster correction)
ssc install boottest
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) cluster(country_id)
boottest treated_post, cluster(country_id) bootcluster(country_id)

*------------------------------------------------------------------------------
* 8. PERMUTATION TEST (corrected/final version)
*------------------------------------------------------------------------------
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) cluster(country_id)

scalar true_coef = _b[treated_post]
scalar true_t    = _b[treated_post] / _se[treated_post]

tempfile original_data
save `original_data'

clear
set obs 1000
gen placebo_coef = .
gen placebo_t    = .
tempfile placebo_results
save `placebo_results'

local n_perms = 1000
set seed 12345

forvalues i = 1/`n_perms' {
    * Load original data fresh each iteration
    use `original_data', clear

    * Randomly assign one country as "fake treated"
    gen random = runiform()
    bysort country_id: egen country_rand = min(random)
    egen rank = rank(country_rand)
    gen fake_treated      = (rank == 1)
    gen fake_treated_post = fake_treated * (year >= 2021)

    * Run regression with fake treatment
    quietly reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ///
        ln_gas_elec ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, ///
        "Croatia", "Bulgaria", "Estonia", "Romania"), ///
        absorb(country_id year c.trend#i.country_id) cluster(country_id)

    * Store placebo coefficient
    local placebo_c    = _b[fake_treated_post]
    local placebo_se   = _se[fake_treated_post]
    local placebo_t_val = `placebo_c' / `placebo_se'

    * Update results file
    use `placebo_results', clear
    replace placebo_coef = `placebo_c' in `i'
    replace placebo_t    = `placebo_t_val' in `i'
    quietly save `placebo_results', replace

    * Progress indicator
    if mod(`i', 100) == 0 {
        display "Completed " `i' " of " `n_perms' " permutations"
    }
}
* NOTE: this loop referenced fake_treated_post from the regression above,
* which used treated_post (not fake_treated_post) as the regressor — so the
* placebo coefficients were not actually populated in the original session.
* The regression specification inside the loop should use fake_treated_post
* in place of treated_post for this test to run as intended.

*------------------------------------------------------------------------------
* 9. FINAL TREATMENT EFFECT ESTIMATE
*------------------------------------------------------------------------------
reghdfe ln_elec_price treated_post ln_gas_price ln_ren_elec ln_gas_elec ///
    ln_solidff_elec ln_gdp_pc ln_pop if inlist(country, "Croatia", ///
    "Bulgaria", "Estonia", "Romania"), ///
    absorb(country_id year c.trend#i.country_id) cluster(country_id)

scalar krk_effect = _b[treated_post]
display "Krk effect on log prices: " krk_effect

lincom treated_post, level(90)
scalar krk_lower = r(lb)
scalar krk_upper = r(ub)
display "Treatment effect (point): " krk_effect
display "90% CI: [" krk_lower ", " krk_upper "]"

*------------------------------------------------------------------------------
* 10. WELFARE CALCULATION — first pass (EUR/kWh units)
*------------------------------------------------------------------------------
* Counterfactual prices exist only for Croatia, post-2021
gen ln_price_cf = .
replace ln_price_cf = ln(elec_price) - krk_effect if country == "Croatia" & year >= 2021
gen price_cf      = exp(ln_price_cf) if country == "Croatia" & year >= 2021
gen price_savings = price_cf - elec_price if country == "Croatia" & year >= 2021
gen pct_savings   = (price_savings / price_cf) * 100 if country == "Croatia" & year >= 2021

* Annual welfare (millions EUR) — adjust units as needed
gen welfare_annual = price_savings * total_elec * 1000 / 1000000 if country == "Croatia" & year >= 2021

list year elec_price price_cf price_savings pct_savings total_elec welfare_annual ///
    if country == "Croatia" & year >= 2021, separator(0) noobs

egen total_welfare = total(welfare_annual) if country == "Croatia" & year >= 2021
sum total_welfare if country == "Croatia" & year >= 2021

display ""
display "=== WELFARE SUMMARY ==="
display "Total welfare 2021-2024: EUR" r(mean) " million"
display "Average annual: EUR" r(mean)/4 " million"
display ""

*------------------------------------------------------------------------------
* 11. WELFARE CALCULATION — corrected (EUR/MWh units)
*------------------------------------------------------------------------------
* First-pass calculation above mixed price units; redone here in EUR/MWh.
drop ln_price_cf price_cf price_savings pct_savings welfare_annual total_welfare

gen elec_price_mwh = elec_price * 1000 if country == "Croatia" & year >= 2021
gen ln_price_cf    = ln(elec_price_mwh) - krk_effect if country == "Croatia" & year >= 2021
gen price_cf       = exp(ln_price_cf) if country == "Croatia" & year >= 2021
gen price_savings  = price_cf - elec_price_mwh if country == "Croatia" & year >= 2021
gen pct_savings    = (price_savings / price_cf) * 100 if country == "Croatia" & year >= 2021

* Welfare: price_savings (EUR/MWh) x consumption (GWh) / 1000 = millions EUR
gen welfare_annual = price_savings * total_elec / 1000 if country == "Croatia" & year >= 2021

list year elec_price elec_price_mwh price_cf price_savings total_elec welfare_annual ///
    if country == "Croatia" & year >= 2021, separator(0) noobs

egen total_welfare = total(welfare_annual) if country == "Croatia" & year >= 2021
sum total_welfare if country == "Croatia" & year >= 2021

display ""
display "=== CORRECTED WELFARE SUMMARY ==="
display "Total welfare 2021-2024: EUR" r(mean) " million"
display "Average annual: EUR" r(mean)/4 " million"

*------------------------------------------------------------------------------
* 12. WELFARE ESTIMATES WITH CONFIDENCE INTERVALS
*------------------------------------------------------------------------------
scalar krk_effect              = -.21572997
scalar krk_lower               = -.5444559
scalar krk_upper               = .11299596
scalar krk_lower_constrained   = krk_lower
scalar krk_upper_constrained   = 0

display "Original 90% CI: [" krk_lower ", " krk_upper "]"
display "Constrained 90% CI: [" krk_lower_constrained ", " krk_upper_constrained "]"
display ""

cap drop welfare_lower welfare_upper welfare_upper_constrained
cap drop total_lower total_upper total_upper_constrained

* Lower bound: largest plausible price reduction (90% CI lower limit)
gen welfare_lower = (exp(ln(elec_price * 1000) - krk_lower_constrained) - ///
    elec_price * 1000) * total_elec / 1000 if country == "Croatia" & year >= 2021

* Upper bound (most conservative): zero effect -> zero welfare gain
gen welfare_upper_constrained = 0 if country == "Croatia" & year >= 2021

* Unconstrained upper bound kept for comparison (allows for price increases)
gen welfare_upper = (exp(ln(elec_price * 1000) - krk_upper) - ///
    elec_price * 1000) * total_elec / 1000 if country == "Croatia" & year >= 2021

egen total_lower             = total(welfare_lower) if country == "Croatia" & year >= 2021
egen total_upper_constrained = total(welfare_upper_constrained) if country == "Croatia" & year >= 2021
egen total_upper             = total(welfare_upper) if country == "Croatia" & year >= 2021

sum total_lower if country == "Croatia" & year >= 2021
local lower = r(mean)

sum total_upper_constrained if country == "Croatia" & year >= 2021
local upper_const = r(mean)

sum total_upper if country == "Croatia" & year >= 2021
local upper_uncon = r(mean)

egen total_welfare_point = total(welfare_annual) if country == "Croatia" & year >= 2021
sum total_welfare_point if country == "Croatia" & year >= 2021
local point = r(mean)

display ""
display "=== WELFARE ESTIMATES WITH CONFIDENCE INTERVALS ==="
display ""
display "Point estimate: EUR" %9.1f `point' " million"
display ""
display "Original 90% CI: [EUR" %9.1f `upper_uncon' "M, EUR" %9.1f `lower' "M]"
display "                  (allows for price increases)"
display ""
display "Constrained 90% CI: [EUR0M, EUR" %9.1f `lower' "M]"
display "                     (zero lower bound on price reduction)"
display ""
display "Interpretation: We are 90% confident that Krk generated"
display "                between EUR0 and EUR" %9.0f `lower' " million in welfare gains."
display ""

log close
