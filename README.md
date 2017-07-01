# Crops parser

This shell script parses data from the [Food and Agriculture Organization of the United Nations](http://www.fao.org/faostat/en/#data/QC) about the cultivated/planted plants/fruits on the world into a YAML file, which groups them per country to see the top 5.

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

## Result

The results can be seen in the directory [result](result). Both data from 2014 and from 2013/2014 are included, but in the end they do not differ that much: 
```shell
$ diff mostPlantedCrops_2014.yml mostPlantedCrops_2014+2013.yml
33c33
< BW: [Cotton lint, Cottonseed, Groundnuts- with shell, Maize, Millet]
---
> BW: [Cotton lint, Cottonseed, Fibre Crops Primary, Groundnuts- with shell, Maize]
144c144
< NC: [Bananas, Cassava, Coconuts, Coffee- green, Lemons and limes]
---
> NC: [Bananas, Cassava, Coconuts, Coffee- green, Eggplants (aubergines)]
178c178
< SH: [Fibre crops nes]
---
> SH: [Fibre crops nes, Fibre Crops Primary]
```

I also have to admit that the script does not hanlde multiple data from multiple years very well, (I think it just uses the biggest number… :laughing:), but this is only needed for a small overview.
