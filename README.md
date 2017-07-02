# Crops parser

This shell script parses data from the [Food and Agriculture Organization of the United Nations](http://www.fao.org/faostat/en/#data/QC) about the cultivated/planted plants/fruits on the world into a YAML file, which groups them per country to see the top 5.
It filters out non-perennial plans, like cereals by default. The [blacklist](./parseCrops.sh#L18) can be adjusted in the script.

It has been created for the OpenStreetMap mapping app [StreetComplete](https://github.com/westnordost/StreetComplete), see [this issue](https://github.com/westnordost/StreetComplete/issues/368) for details.

## How to run it?

The script is mostly POSIX-compliant, so it should work on all systems, but a CLI tool called [csvtool](https://github.com/Chris00/ocaml-csv) has to be installed as it is used as a CSV parser.

If this is done, you can just execute it:
```shell
$ ./parseCrops.sh source/FAOSTAT_data_2014.csv result/mostPlantedCrops_2014.yml
Prepare CSV…
Stripping unwanted data and commas…
Sort data…
Evaluate data…
Finish processing…
```

## What does it?

This is an overview of what happens:
* `Prepare CSV…` – It strips the table header and extracts the columns of interest.
* `Stripping unwanted data and commas…` – As it says, it strips commas for easier processing and applies the blacklist.
* `Sort data…` – It sorts the whole data according to the tonnes of produced crops, independent of the country.
* `Sort data…` – It extracts all crops for each country and transforms the first five crops listet into the YAML format. Additionally it replaces the country name with the 2-letter country code (ISO 3166).
* `Finish processing…` – It adds the header and default crops and sorts the YAML another time, so the countries are sorted.

## Result

The results can be seen in the directory [result](result). Both data from 2014 and from 2013/2014 are included, but in the end they do not differ that much for the top entries at least. (often the 5th entry or so differs)

I also have to admit that the script does not hanlde multiple data from multiple years very well, (I think it just uses the biggest number… :laughing:), but this is only needed for a small overview.
