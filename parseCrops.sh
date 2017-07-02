#!/bin/sh
# Parse the CSV crops to a YAML. Requires https://github.com/Chris00/ocaml-csv
# to be installed. It produces several .csv.* files in the temp dir showing
# each step performed.
# It also needs a ISO3166 database in CSV format to convert the country names
# to country codes.
# source: https://github.com/lukes/ISO-3166-Countries-with-Regional-Codes,
# modified
# 
# LICENSE: Copyright (c) 2017 rugk, MIT license, see LICENSE.md
# 
# use: parseCrop.sh FAQSTAT_input.csv cropsOutput.yml
# 

# constants
TMPDIR="/tmp/cropsGenerator"
MAX_LIST=5
CROP_BLACKLIST=$( cat crop-blacklist.list )
ISO3166_DB="./iso3166.csv" # (modified)

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
# 
# thanks https://stackoverflow.com/questions/2829613/how-do-you-tell-if-a-string-contains-another-string-in-unix-shell-scripting#8811800
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

# convertCountryNameToCode(countryName)
#
# Using $ISO3166_DB this converts the country names to the corresponding country
# codes. If this fails, it returns an empty string.
convertCountryNameToCode() {
    grep "$1" "$ISO3166_DB" | head -n 1 | cut -d , -f 2
}

if [ ! -e "$TMPDIR" ]; then
    mkdir -p "$TMPDIR"
fi

input="$1"
tmpfile="$TMPDIR/data.csv"
outfile="$2"

echo "Prepare CSV…"
# extract columns & remove header
csvtool namedcol Area,Item,Value "$input" > "$tmpfile.1"
# OR: csvtool col 4,8,12 "$input" > "$tmpfile.1"
csvtool drop 1 "$tmpfile.1" > "$tmpfile.2"

# replace , (comma) in file with different value to ease CSV processing and
# apply blacklist
echo "Stripping unwanted data and commas…"
filteritems() {
    # remove ignored crops
    # set IFS to line break
    IFS='
'
    for blockedItem in $CROP_BLACKLIST; do
        if contains "$2" "$blockedItem"; then
            # echo "$2 is blacklisted by $blockedItem. Skip."
            return
        fi
    done
    
    # replace comma in area & item columns
    for col in "$1" "$2"; do
        # remove " and ,
        col=$( echo "$col" | sed -e 's/,/-/g' )
        col=$( echo "$col" | sed -e 's/"//g' )
        printf "%s," "$col" >> "$tmpfile.3"
    done    

    # numbers in value column do not need special handling
    printf "%s\n" "$3" >> "$tmpfile.3"
}
export CROP_BLACKLIST
export tmpfile
export -f contains
export -f filteritems

rm "$tmpfile.3" 2> /dev/null
csvtool call filteritems "$tmpfile.2" 

echo "Sort data…"
# sort data by "value"
sort --field-separator=',' -n -r --key=3 "$tmpfile.3" > "$tmpfile.4"

echo "Evaluate data…"
# get country list
areas=$( cut -d , -f 1 "$tmpfile.4" | sort | uniq )
areasOriginal=$( csvtool col 1 "$tmpfile.2" | sed -e 's/,/-/g' | sed -e 's/"//g' | sort | uniq )
areasNoData=$(echo "$areas
$areasOriginal" | sort | uniq -u )

rm "$tmpfile.5" 2> /dev/null

# set IFS to line break
IFS='
'

for area in $areas; do
    # (try to) get country code
    areaShort=$( convertCountryNameToCode "$area" )
    if [ "$areaShort" = "" ]; then
        echo "No language code for $area could be found. Skip."
        continue
    fi
    
    # extract data from file, form it into one line separated with commas
    crops=$( grep "$area," "$tmpfile.4" | cut -d , -f 2 | uniq | head -n "$MAX_LIST" | tr '\n' ',' | sed -e 's/,/, /g' )
    
    # write data into new file
    # the stripping of the last characters (the last ", ") is not strictly POSIX-compliant, but works in all shells, nowadays
    printf "%s: [%s]\n" "$areaShort" "${crops:0:-2}" >> "$tmpfile.5"
done

# final steps
echo "Finish processing…"

# add header
{
    echo "# list of most produced/cultivated crops/fruits in the world"
    echo "# source: Food and Agriculture Organization of the United Nations, http://www.fao.org/faostat/en/#data/QC"
    echo "# created/parsed by script: https://github.com/rugk/crop-parser"
    echo "# updated at: $( date +'%F' )"
    echo "default: [Sugar cane, Potatoes, Sugar beet, Soybeans, Cassava, Tomatoes]" # source: https://en.wikipedia.org/wiki/Agriculture#Crop_statistics
} > "$outfile"

# append sorted data
sort "$tmpfile.5" >> "$outfile"

if [ "$areasNoData" != "" ]; then
    {
        echo "# For these countries, there was data in the source, but due to filtering no crops remained. They were thus skipped."
        printf "# Ignored: "
        printf "%s" "$areasNoData" | tr '\n' ',' | sed -e 's/,/, /g'
    } >> "$outfile"
fi

# rm -rf "$TMPDIR"
