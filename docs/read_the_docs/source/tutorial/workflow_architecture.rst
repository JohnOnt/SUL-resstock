.. _workflow_architecture:

Workflow Architecture
=====================

The key ResStock workflow components are described below.

Projects
--------

At the top level of the ResStock repository you just downloaded, you will see two analysis project folders:

- ``project_national``
- ``project_testing``
 
The national project contains inputs describing the existing residential building stock.
The testing project contains inputs to test our OpenStudio workflows.
Within each project folder are sample "baseline" and "upgrades" input files that may serve as examples for how to set up different types of ResStock analyses.
The contents of the input file ultimately determines the set of workflow steps (i.e., OpenStudio measures) for each ResStock sample.
See :doc:`workflow_run` for more information about running ResStock analyses.

Sampling
--------
   
To run the sampling script yourself, from the command line execute, e.g. ``ruby resources/run_sampling.rb -p project_national -n 10000 -o buildstock.csv``, and a file ``buildstock.csv`` will be created in the ``resources`` directory. 
 
If a custom ``buildstock.csv`` file is located in a project's ``housing_characteristics`` directory when you run the project, it will automatically be used to generate simulations. If it’s not found, the sampling will be run automatically to create one. For each datapoint, the measure will then look up its building description from the sampled csv.
 
You can use this manual sampling process to downselect which simulations you want to run. For example, you can use the command above to generate a ``buildstock.csv`` for the entire U.S. and then open up this file in Excel and delete all of the rows that you don't want to simulate (e.g., all rows that aren't in New York). Keep in mind that if you do this, you will need to re-enumerate the "Building" column as "1" through the number of rows.

Measures
--------

ResStock uses a mixture of both OpenStudio "model" and "reporting" measures in its workflow.
The following depicts the order in which workflow measure steps are applied:

1. BuildExistingModel

  a. ResStockArguments
  b. BuildResidentialHPXML
  c. BuildResidentialScheduleFile

2. ApplyUpgrade

  a. ResStockArguments
  b. BuildResidentialHPXML
  c. BuildResidentialScheduleFile

3. HPXMLtoOpenStudio
4. *Other Model Measures*
5. ReportSimulationOutput
6. ReportHPXMLOutput
7. ReportUtilityBills
8. UpgradeCosts
9. *Other Reporting Measures*
10. ServerDirectoryCleanup

Model Measures
**************

Model measures are applied *before* the simulation is run.
The BuildResidentialHPXML, BuildResidentialScheduleFile, and HPXMLtoOpenStudio measures are located in the `OpenStudio-HPXML <https://github.com/NREL/OpenStudio-HPXML>`_ repository.

1. BuildExistingModel

  .. include:: ../../../../measures/BuildExistingModel/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../measures/BuildExistingModel/measure.xml
     :start-after: <modeler_description>
     :end-before: <

  It is a meta measure; meaning, it incrementally applies *other* measures (i.e., ResStockArguments, BuildResidentialHPXML, and BuildResidentialScheduleFile) to create "baseline" residential models.

  a. ResStockArguments

    .. include:: ../../../../measures/ResStockArguments/measure.xml
       :start-after: <description>
       :end-before: <

    .. include:: ../../../../measures/ResStockArguments/measure.xml
       :start-after: <modeler_description>
       :end-before: <

  b. BuildResidentialHPXML

    .. include:: ../../../../resources/hpxml-measures/BuildResidentialHPXML/measure.xml
       :start-after: <description>
       :end-before: <

    .. include:: ../../../../resources/hpxml-measures/BuildResidentialHPXML/measure.xml
       :start-after: <modeler_description>
       :end-before: <

  c. BuildResidentialScheduleFile

    .. include:: ../../../../resources/hpxml-measures/BuildResidentialScheduleFile/measure.xml
       :start-after: <description>
       :end-before: <

    .. include:: ../../../../resources/hpxml-measures/BuildResidentialScheduleFile/measure.xml
       :start-after: <modeler_description>
       :end-before: <

.. _tutorial-apply-upgrade:

2. ApplyUpgrade

  This measure can be optionally applied to the workflow.
  Like the BuildExistingModel measure, ApplyUpgrade is a meta measure; it, too, incrementally applies *other* measures (i.e., ResStockArguments, BuildResidentialHPXML, and BuildResidentialScheduleFile) to create "upgraded" residential models.

  .. include:: ../../../../measures/ApplyUpgrade/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../measures/ApplyUpgrade/measure.xml
     :start-after: <modeler_description>
     :end-before: <

  Each "Apply Upgrade" measure defines an upgrade scenario.
  An upgrade scenario is a collection of options exercised with some logic and costs applied.
  In the simplest case, we apply the new option to all housing units.
  The available upgrade options are in ``resources/options_lookup.tsv`` in your git repository.
  For this example, we will upgrade all windows by applying the ``Windows|Triple, Low-E, Non-metal, Air, L-Gain`` option to all houses across the country.
  We do this by entering that in the **Option 1** box on the Apply Upgrade measure.
  Also, we'll give the upgrade scenario a name: "Triple-Pane Windows" and a cost of $40/ft\ :superscript:`2` of window area by entering the number in **Option 1 Cost Value** and selecting "Window Area (ft^2)" for **Option 1 Cost Multiplier**.
  Like the **downselect logic**, excluded datapoints (i.e., datapoints for which the upgrade does not apply) will result in "completed invalid workflow".
  Note that using no downselect logic will apply the option to all housing units. For a full explanation of how to set up the options and logic surrounding them, see :doc:`../upgrade_scenario_config`.

3. HPXMLtoOpenStudio

  .. include:: ../../../../resources/hpxml-measures/HPXMLtoOpenStudio/measure.xml
     :start-after: <description>
     :end-before: <

  See also `OpenStudio-HPXML Workflow Inputs <https://openstudio-hpxml.readthedocs.io/en/latest/workflow_inputs.html>`_ for documentation on workflow inputs.

4. *Other Model Measures*

  Additional model measures can be optionally applied to the workflow.

Reporting Measures
******************

Reporting measures are applied *after* the simulation is run.
The ReportSimulationOutput, ReportHPXMLOutput, and ReportUtilityBills measures are located in the `OpenStudio-HPXML <https://github.com/NREL/OpenStudio-HPXML>`_ repository.

5. ReportSimulationOutput

  .. include:: ../../../../resources/hpxml-measures/ReportSimulationOutput/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../resources/hpxml-measures/ReportSimulationOutput/measure.xml
     :start-after: <modeler_description>
     :end-before: <

6. ReportHPXMLOutput

  .. include:: ../../../../resources/hpxml-measures/ReportHPXMLOutput/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../resources/hpxml-measures/ReportHPXMLOutput/measure.xml
     :start-after: <modeler_description>
     :end-before: <

7. ReportUtilityBills

  .. include:: ../../../../resources/hpxml-measures/ReportUtilityBills/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../resources/hpxml-measures/ReportUtilityBills/measure.xml
     :start-after: <modeler_description>
     :end-before: <

8. UpgradeCosts

  .. include:: ../../../../measures/UpgradeCosts/measure.xml
     :start-after: <description>
     :end-before: <

  .. include:: ../../../../measures/UpgradeCosts/measure.xml
     :start-after: <modeler_description>
     :end-before: <

9. *Other Reporting Measures*

  Additional reporting measures (e.g., QOIReport) can be optionally applied to the workflow.

10. ServerDirectoryCleanup

  .. include:: ../../../../measures/ServerDirectoryCleanup/measure.xml
     :start-after: <description>
     :end-before: <
