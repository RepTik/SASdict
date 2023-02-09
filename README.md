# Project - SASdict

### The **SASdict** project builds a tool to create a SAS Data Dictionary on one or more or all datasets from a SAS data library. This tool helps assessing unfamiliar datasets, boosting analyses speed, and sharing data information across stakeholders.  

#### The generated data dictionary is in Excel and contains rich summary information on: 

- All Datasets: e.g. name, number of variables, records, and unique keys.
- All Variables: e.g. name, position, length, format, N(%) of missing /non-null /unique values.
- Optional: first 15 obs, and basic statistics (Min, P1, P25, Median, P75, P99, Max, Mean, Mode) of all numeric variables.
- Optional: frequencies - N(%) - for each unique values of all variables. 
- Optional: remove the display of unique values for specific variables.
- Optional: create a separate Excel data dictionary for each dataset.

#### Example Use Cases:

- Explore a new set of data tables that you work for first time, get overview of tables, variables, unique values, statistics, etc.
- Generate table/variable/value overviews on a project specific datacut, substantially boost your analyses speed!
- Produce a catalog of information (so called "data dictionary") on a specific set of data tables, for other people to use, e.g. periodic deliveries.

Note 1: The program can be used in both Windows and Unix environment. 
Note 2: There're 5 macros in this file, where %SAS_Data_Dict() is the main macro and the others are supportive.
