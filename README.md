## Overview

`selects()` is a wrapper around dplyr's `select()` and `mutate()` that combines their functionality into a single operation and strives to ease up development.

It produces the same output type that `select()` and `mutate()` functions produce.

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
	selects(COLS_SELECT, COLS_MUTATE, MORE_COLS_SELECT, MORE_COLS_MUTATE)
# Output: Columns are ordered in a sequence they were written.
```

## Install

1. Just copy everything from the `selects.R` file:
   - File contains required packages and the `selects()` function itself.
2. Enjoy.

## Argument → Function

For each argument, `selects()` chooses a corresponding dplyr function based on conditions below.

|               | evaluation OK | evaluation OK' | evaluation OK_SF | evaluation FAIL |
| ------------- | ------------- | -------------- | ---------------- | --------------- |
| **label YES** | MUTATE        | MUTATE         | -                | MUTATE          |
| **label NO**  | SELECT        | SELECT         | SELECT           | MUTATE          |

```
evaluation OK			= number | numbervector

evaluation OK' 		= colname

evaluation OK_SF	= all_of() | any_of() | contains() | ends_with() | everything() | last_col() | matches() | num_range() | one_of() | starts_with()

evaluation FAIL 	= expression
```

## Examples

Select and mutate at once.

```R
usEconomy |>
    selects(
        Year,
        Year - 2016,
        6:7,
        FF.perc = Federal.Funds * 100,
        GDP_real = GDP / (GDP.deflator / 100),
        ends_with("ployment")
    ) # c=8. Column names old and generated and new
#   Year Year - 2016      X      M FF.perc GDP_real Employment Unemployment
# 1 2016           0 2227.2 2739.7   0.395 17730.56     151436         7751
# 2 2017           1 2374.6 2930.1   1.002 18144.09     153335         6982
# 3 2018           2 2528.7 3138.2   1.832 18687.80     155759         6314
# 4 2019           3 2514.8 3125.2   2.160 19091.61     157536         6001
# 5 2020           4 2091.1 2695.4   0.370 18397.88     147794        12948
```

Use `except` argument (without minus) to exclude columns.

```R
usEconomy |> selects(except = 1) # c=n_c-1. Column names old
```
