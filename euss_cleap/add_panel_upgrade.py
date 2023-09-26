# import packages
from pathlib import Path
import sys
import numpy as np
import pandas as pd
import csv
import re
import math
from itertools import chain
import logging

from postprocess_electrical_panel_size_nec import (
	apply_standard_method, 
	apply_optional_method,
	apply_new_load_method_220_83,
	calculate_new_loads,
	)

from apply_panel_regression_model import (
	load_model,
	apply_model_to_results
	)


def setup_logging(
        name, filename, file_level=logging.INFO, console_level=logging.INFO
        ):
    global logger
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    fh = logging.FileHandler(filename, mode="w")
    fh.setLevel(file_level)
    ch = logging.StreamHandler()
    ch.setLevel(console_level)
    formatter = logging.Formatter(
        "%(asctime)s - %(levelname)s - %(message)s"
    )
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    # add the handlers to the logger
    logger.addHandler(fh)
    logger.addHandler(ch)

## func
def format_housing_parameter_name(hc):
	return "_".join([x for x in chain(*[re.split('(\d+)',x) for x in hc.lower().split(" ")]) if x not in ["", "-"]])


def min_amperage_main_breaker(x):
    """Convert min_amperage_nec_standard into standard panel size
    http://www.naffainc.com/x/CB2/Elect/EHtmFiles/StdPanelSizes.htm
    """
    if pd.isnull(x):
        return np.nan

    standard_sizes = np.array([50, 60, 70, 100, 125, 150, 200, 300, 400, 600]) # it is not permitted to size service below 100 A (NEC 230.79(C))
    factors = standard_sizes / x

    cond = standard_sizes[factors >= 1]
    if len(cond) == 0:
        logger.info(
            f"WARNING: {x} is higher than the largest standard_sizes={standard_sizes[-1]}, "
            "double-check NEC calculations"
        )
        return math.ceil(x / 100) * 100

    return cond[0]


## -- main --
community_name = "san_jose" # <--
baseline_panel_calc_method = "regression" # <--- ["peak", "nec", "regression"]

datadir = Path(".").resolve() / "data_" / "community_building_samples_with_upgrade_cost_and_bill"
setup_logging(community_name, datadir / f"output__panel_upgrade__{community_name}.log")

### baseline
df_b = pd.read_parquet(datadir / community_name / f"up00__{community_name}.parquet")
df_b = df_b.loc[df_b["completed_status"]=="Success"].set_index("building_id")

baseline_amps = []
dff = apply_standard_method(df_b)

# [1] Peak = peak x 4
use_qoi_for_peak = True ## Always use QOI (applicable to peak)
if use_qoi_for_peak:
	metric = "qoi_report.qoi_peak_magnitude_use_kw"
	baseline_peak_kw = df_b[metric]
else:
	metrics = [
		"report_simulation_output.peak_electricity_winter_total_w",
		"report_simulation_output.peak_electricity_summer_total_w"
		]
	baseline_peak_kw = df_b[metrics].max(axis=1) / 1000

baseline_amp = (baseline_peak_kw * 1000 / 240).apply(math.ceil) # W/V =[A]
baseline_amps.append(baseline_amp)

# according to "HEA data 15-min peak vs. panel amperage" from Brennan Less, peak ~ 1/4 of panel amp
baseline_panel_amp = (baseline_amp * 4).apply(lambda x: min_amperage_main_breaker(x)).rename("peak_predicted_panel_amp")

# correct vacant home baseline panel size by using NEC method
cond = df_b["build_existing_model.vacancy_status"]=="Vacant"
baseline_panel_amp.loc[cond] = dff.loc[cond, "std_m_nec_min_amp"].apply(lambda x: min_amperage_main_breaker(x))
baseline_amps.append(baseline_panel_amp)

# [2] NEC calc - standard method
baseline_panel_amp = dff["std_m_nec_min_amp"].apply(lambda x: min_amperage_main_breaker(x))
baseline_amps.append(baseline_panel_amp)

# [3] LBNL regression model
model = load_model("prelim_panel_model.p")
df_b = apply_model_to_results(df_b, model, predict_proba=False, retain_proba=False)
baseline_panel_amp = df_b["predicted_panel_amp"]
baseline_amps.append(baseline_panel_amp)

del dff
baseline_amps = pd.concat(baseline_amps, axis=1)

# Map regressed results to single panel size
baseline_amps["reg_predicted_panel_amp"] = baseline_amps["predicted_panel_amp"]
baseline_amps.loc[baseline_amps["predicted_panel_amp"] == "101-199", "reg_predicted_panel_amp"] = "150"
cond = baseline_amps["predicted_panel_amp"] == "200+"
baseline_amps.loc[cond, "reg_predicted_panel_amp"] = baseline_amps.loc[cond].apply(lambda x: min_amperage_main_breaker(
	max(201, x["qoi_report.qoi_peak_magnitude_use_kw"], x["std_m_nec_min_amp"])
	), axis=1)
baseline_amps["reg_predicted_panel_amp"] = baseline_amps["reg_predicted_panel_amp"].astype(int)

if baseline_panel_calc_method == "peak":
	baseline_panel_amp = baseline_amps["peak_predicted_panel_amp"]
elif baseline_panel_calc_method == "nec":
	baseline_panel_amp = baseline_amps["std_m_nec_min_amp"]
elif baseline_panel_calc_method == "regression":
	baseline_panel_amp = baseline_amps["reg_predicted_panel_amp"]
else:
	raise ValueError(f"Unsupported baseline_panel_calc_method={baseline_panel_calc_method}")


### upgrade
DF_by_peak_delta, DF_by_nec = [], []
for upn in range(1, 11):
	df = pd.read_parquet(datadir / community_name / f"up{upn:02d}__{community_name}.parquet")
	df = df.loc[df["completed_status"]=="Success"].set_index("building_id").sort_index()

	idx = sorted(set(df_b.index).intersection(set(df.index)))
	df = df.reindex(idx)
	dfb = df_b.reindex(idx)
	bl_panel_amp = baseline_panel_amp.reindex(idx)
	bl_peak_kw = baseline_peak_kw.reindex(idx)

	upgrade_name = df["apply_upgrade.upgrade_name"].unique()[0]
	n_applicable = df["sample_weight"].sum()

	if use_qoi_for_peak:
		up_peak_kw = df[metric]
	else:
		up_peak_kw = df[metrics].max(axis=1) / 1000

	upgrade_amp = up_peak_kw * 1000 / 240 # W/V =[A]

	peak_delta_kw = (up_peak_kw - baseline_peak_kw)
	peak_delta_pct = peak_delta_kw / baseline_peak_kw * 100 # [%]

	delta_thresholds = [25, 50, 75, 100, 125, 150]
	delta_pct_above = []
	# check delta:
	for min_delta in delta_thresholds:
		cond_high_delta = peak_delta_pct >= min_delta
		n_high_delta = df.loc[cond_high_delta, "sample_weight"].sum()
		pct_high_delta = n_high_delta / n_applicable
		delta_pct_above.append(pct_high_delta)

	df_delta = pd.Series(
		[int(n_applicable)]+delta_pct_above, 
		index=["n_applicable"]+[f"peak_increase>={x}%" for x in delta_thresholds]
		).rename(upgrade_name)
	DF_by_peak_delta.append(df_delta)

	# --- new load calc ---
	df_new_meta = dfb[[x for x in dfb.columns if x.startswith("build_existing_model.")]]
	option_name_cols = [x for x in df.columns if "upgrade_costs.option" in x and "name" in x]

	dfs_new_hvac_loads = pd.Series(False, index=df.index)
	for col in option_name_cols:
		cond = df[col].str.contains("|").fillna(False)
		if cond.sum() > 0:
			dfs = df.loc[cond, col]
			up_para, up_optn = dfs.str.split("|").iloc[0] # take only one entry
			up_para = "build_existing_model." + format_housing_parameter_name(up_para)

			# if heating is electrified, record
			if (up_para == "build_existing_model.hvac_heating_efficiency") & (
				("ASHP" in up_optn) | ("MSHP" in up_optn) | ("GSHP" in up_optn) | ("Electric" in up_optn)
				):
				cond2 = cond & dfb["build_existing_model.heating_fuel"] != "Electricity"
				dfs_new_hvac_loads.loc[cond2] = True

			if (up_para == "build_existing_model.hvac_shared_efficiencies") & ("Electricity" in up_optn):
				cond2 = cond & dfb["build_existing_model.heating_fuel"] != "Electricity"
				dfs_new_hvac_loads.loc[cond2] = True

			# if cooling is upgraded from None, record
			if (up_para == "build_existing_model.hvac_cooling_efficiency") & (up_optn != "None"):
				cond2 = cond & dfb[up_para]=="None"
				dfs_new_hvac_loads.loc[cond2] = True

			# temp bypass (TODO)
			if up_para == "build_existing_model.infiltration_reduction":
				continue

			assert up_para in df_new_meta.columns, f"Unknown up_para: {up_para} from {col}"
			df_new_meta.loc[cond, up_para] = up_optn

	dfu = df.join(df_new_meta, how="inner").reindex(idx)
	
	# --- NEC 220.83 (New Load (optional) Method) ---
	dfb = apply_new_load_method_220_83(dfb, dfs_new_hvac_loads)
	dfu = apply_new_load_method_220_83(dfu, dfs_new_hvac_loads)
	delta_loads = (dfu["new_load_demand_load_total_VA"] - dfb["new_load_demand_load_total_VA"]).clip(lower=0)
	new_panel_amp  = dfu["new_load_nec_min_amp"]

	cond_replace = (delta_loads > 0) & (new_panel_amp >= bl_panel_amp)
	n_replace = dfu.loc[cond_replace, "sample_weight"].sum()
	pct_replace = n_replace / n_applicable
	
	# --- NEC 220.87 (Load Study) ---
	new_loads = calculate_new_loads(dfb, dfu, upgrade_name=upgrade_name)
	new_panel_amp_load_study = (bl_peak_kw*1000*1.25 + new_loads) / 240 # W/V = [A] # TODO: new load should be at 100% DF

	cond_replace_load_study = (new_loads > 0) & (new_panel_amp_load_study >= bl_panel_amp)
	cond_replace_load_study = dfu.loc[cond_replace_load_study, "sample_weight"].sum()
	pct_replace_load_study = cond_replace_load_study / n_applicable


	# if upgrade_name not in ["Basic enclosure", "Enhanced enclosure"]:
	# 	breakpoint()


	# combine
	df_replace = pd.Series(
		[int(n_applicable), pct_replace, pct_replace_load_study], 
		index=["n_applicable", "220.83 new_loads", "load_study"]
		).rename(upgrade_name)
	DF_by_nec.append(df_replace)


DF_by_peak_delta = pd.concat(DF_by_peak_delta, axis=1).transpose()
DF_by_peak_delta.index.name = "upgrade_name"
logger.info(f"\nOf those applicable to each upgrade package, the fraction seeing electric peak increase post-upgrade: \n{DF_by_peak_delta}")

DF_by_peak_delta.to_csv(datadir / community_name /  f"fraction_of_peak_increase_{community_name}.csv", index=True)

# Based on NEC calc, assuming baseline_amp
DF_by_nec = pd.concat(DF_by_nec, axis=1).transpose()
DF_by_nec.index.name = "upgrade_name"
DF_by_nec["average"] = DF_by_nec[DF_by_nec.columns[1:]].mean(axis=1)
logger.info(f"\nOf those applicable to each upgrade package, the fraction likely requiring panel upgrade based on NEC calculation: \n{DF_by_nec}")

DF_by_nec.to_csv(datadir / community_name / f"fraction_of_panel_upgrade_nec_{community_name}.csv", index=True)
