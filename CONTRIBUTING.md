# Quick notes for development

* Libre Office Calc (or any other spreadsheet calculation software) is your friend! Use it to open the different CSV files, compare and check or modify them (e.g. to replace all commas in fields, you can easily use the built-in search and replace functionality).
* All the temporary files of this script are saved in a directory in `/tmp/crops-parser-...` (see the `TMPDIR` constant in the script). You can check the files and steps there to debug the script.
* Further manual adjustments made to the `fao-country-db.csv`:
  * Due to the way YAML treats Norway (yes, search for that, it's funny), the `NO` 2-letter-key was quoted. See [issue 48](https://github.com/rugk/crops-parser/issues/48).
  * Palestine was manually assigned the `PS` code [as per this source](https://github.com/lukes/ISO-3166-Countries-with-Regional-Codes/blob/master/all/all.csv), so it could be mapped without an alpha-3 code.
  * That you get an error for "WARNING: No language code for China could be found. Skip." is to be expected, because the FAQ language mapping defines no 2-letter language for this entry, but for `China, mainland` instead. To not wrongly aggregate already aggregated data again, this should stay like it is. (I.e. we should not define the `CN` for "China" again, because it has been assigned to `China, mainland` according to the FAO data.)
