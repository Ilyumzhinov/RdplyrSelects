# LOCAL FILES
# selects() - Combines SELECT, MUTATE into 1 function. Helps with formula processing.
source("selects.R")

# DATA
usEconomy <- read.table("data_usEconomy.csv", header = TRUE, sep = ",")

# SELECT by column name or slice or exclusion
usEconomy |> selects(Year, GDP) # c=2. Column names old
usEconomy |> selects(1:5) # c=5. Column names old
usEconomy |> selects(except = 1) # c=n_c-1. Column names old

# MUTATE by expression or label with expression
usEconomy |> selects(Year - 1960, Federal.Funds * 100, GDP / (GDP.deflator / 100)) # c=3. Column names generated
usEconomy |> selects(index = Year - 1960, Federal.Funds.perc = Federal.Funds * 100, GDP_real = GDP / (GDP.deflator / 100)) # c=3. Column names new

# Use everything at once
usEconomy |> selects(Year, Year - 1960, 2:5, GDP_nominal = GDP, GDP_real = GDP_nominal / (GDP.deflator / 100)) # c=8. Column names old and generated and new
