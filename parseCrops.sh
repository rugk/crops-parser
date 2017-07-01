#!/bin/sh
# Parse the CSV crops to a YAML. Requires https://github.com/Chris00/ocaml-csv
# to be installed. It produces several .csv.* files in the temp dir showing
# each step performed.
# It also needs a ISO3166 database in CSV format to convert the country names
# to country codes.
# source: https://dev.maxmind.com/geoip/legacy/codes/iso3166/

# constants
TMPDIR="."
MAX_LIST=5
CROP_BLACKLIST="Total Fruit, Cereals Vegetables Wheat Barley"
ISO3166_DB="./iso3166.csv"

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
    grep "$1" "$ISO3166_DB" | cut -d , -f 1
}

input="$1"
tmpfile="$TMPDIR/data.csv"

echo "Extract/normalize CSV…"
# extract columns & remove header
csvtool namedcol Area,Item,Value "$input" > "$tmpfile.1"
# OR: csvtool col 4,8,12 "$input" > "$tmpfile.1"
csvtool drop 1 "$tmpfile.1" > "$tmpfile.2"

# replace , (comma) in file with different value to ease CSV processing
echo "Stripping unwanted data and commas…"
replacecomma() {
    # remove ignored fruits
    for blockedItem in $CROP_BLACKLIST; do
        if contains "$2" "$blockedItem"; then
            # echo "$2 is blacklisted by $blockedItem. Skip."
            return
        fi
    done
    
    # replace comma in area & item columns
    for col in "$1" "$2"; do
        # remove unneccessary informatioon in brackets
        col=$( echo "$col" | sed -e 's/(.*)\h*\(.*\)//g' )
        
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
export -f replacecomma

rm "$tmpfile.3" 2> /dev/null
csvtool call replacecomma "$tmpfile.2" 

echo "Sort data…"
# sort data by "value"
sort --field-separator=',' -n -r --key=3 "$tmpfile.3" > "$tmpfile.4"

echo "Evaluate data…"
# get country list
areas=$( cut -d , -f 1 "$tmpfile.4" | sort | uniq )

# output header
rm "$tmpfile.5" 2> /dev/null
{
    echo "# list of most produced/cultivated crops/fruits in the world"
    echo "# source: Food and Agriculture Organization of the United Nations, http://www.fao.org/faostat/en/#data/QC"
    echo "# created/parsed by script: <add link here>"
    echo "# updated at: $( date +'%F' )"
    echo "default: [Sugar cane, Potatoes, Sugar beet, Soybeans, Cassava, Tomatoes]" # source: https://en.wikipedia.org/wiki/Agriculture#Crop_statistics
} > "$tmpfile.5"

# set IFS to line break
IFS="
"
for area in $areas; do
    # (try to) get country code
    areaShort=$( convertCountryNameToCode "$area" )
    if [ "$areaShort" = "" ]; then
        echo "No language code for $area could be found. Skip."
        continue
    fi
    
    # extract data from file
    crops=$( grep -e "$area," < "$tmpfile.4" | cut -d , -f 2 | sort | uniq | head -n "$MAX_LIST" | tr '\n' ',' | sed -e 's/,/, /g' )
    
    if [ "$crops" = "" ]; then
        echo "No crops for $area could be found. Skip."
        continue
    fi
    
    
    # write data into new file
    # the stripping of the last characters (the last ", ") is not strictly POSIX-compilant, but works in all shells, nowadays
    printf "%s: [%s]\n" "$areaShort" "${crops:0:-2}" >> "$tmpfile.5"
done
