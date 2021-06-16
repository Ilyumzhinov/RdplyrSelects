## Overview

`selects()` is a wrapper around dplyr's `select()` and `mutate()` that combines their functionality into a single step and strives to ease up development.

It produces the same output type that `select()` and `mutate()` functions produced.

The main benefits are:

```R
# Simplifies the common pattern
data |>
	select(COLS_SELECT) |>
	mutate(COLS_MUTATE)
# to just
data |>
	selects(COLS_SELECT, COLS_MUTATE)
```

and

```R
# Allows to preserve the order of mutate columns within select columns
data |>
	selects(SOME_COLS_SELECT, SOME_COLS_MUTATE, SOME_MORE_COLS_SELECT, SOME_MORE_COLS_MUTATE)
# Output: Columns are ordered in a sequence they were written.
```

## Install

1. Just copy everything from the `selects.R` file:
   1. File contains required packages and the `selects()` function.
2. Enjoy.

## Argument => Function evaluation

|               | evaluation OK | evaluation OK' | evaluation OK_SF | evaluation FAIL |
| ------------- | ------------- | -------------- | ---------------- | --------------- |
| **label YES** | MUTATE        | MUTATE         | -                | MUTATE          |
| **label NO**  | SELECT        | SELECT         | SELECT           | MUTATE          |

```
evaluation OK <= NUMBER || NUMBERVECTOR

evaluation OK' <= COLNAME

evaluation OK_SF <= "all_of()" || "any_of()" || "contains()" || "ends_with()" || "everything()" || "last_col()" || "matches()" || "num_range()" || "one_of()" || "starts_with()"

evaluation FAIL <= EXPRESSION
```

## Examples

```R
# DATA
usEconomy <- read.table("data_usEconomy.csv", header = TRUE, sep = ",")

# SELECT by column name or slice or exclusion
usEconomy |>
	selects(Year, GDP) # c=2. Column names old
usEconomy |>
	selects(3:7) # c=5. Column names old
usEconomy |>
	selects(except = 1) # c=n_c-1. Column names old

# MUTATE by expression or label with expression
usEconomy |>
	selects(Year - 2016, Federal.Funds * 100, GDP / (GDP.deflator / 100)) # c=3. Column names generated
usEconomy |>
	selects(index = Year - 2016, Federal.Funds.perc = Federal.Funds * 100, GDP_real = GDP / (GDP.deflator / 100)) # c=3. Column names new

# Use everything at once
usEconomy |>
	selects(Year, Year - 2016, 6:7, FF.perc = Federal.Funds * 100, GDP_real = GDP / (GDP.deflator / 100), ends_with("ployment")) # c=8. Column names old and generated and new
```
