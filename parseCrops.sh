#!/bin/sh
# Parse the CSV crops to a YAML. Requires https://github.com/Chris00/ocaml-csv
# to be installed. It produces several .csv.* files in the temp dir showing
# each step performed.
# It also needs a ISO3166 database in CSV format to convert the country names
# to country codes.
# source: https://www.fao.org/faostat/en/#definitions, modified
#
# LICENSE: Copyright (c) 2017-2022 rugk, MIT license, see LICENSE.md
#
# use: parseCrop.sh input.csv cropsOutput.yml
#

# constants
TMPDIR="$( mktemp --tmpdir -d crops-parser-XXXXX )"
MAX_LIST=15
CROP_BLACKLIST=$( cat crop-blacklist.list )
ISO3166_DB="./fao-country-db.csv" # (modified, see the convertCountryNameToCode function for details)
OSM_CROP_KEY_DB="./osmcrops.csv"
# Convert to OSM keys? 0=no; 1=yes; 2=yes, and skip non-OSM keys
OSM_HANDLING="2"
# add path to file here to collect missing OSM keys, only works if OSM_HANDLING != 0
OSM_COLLECT_MISSING="result/missingOSM.list" # result/missingOSM.list

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
# simplifyCsvKey()
#
# Takes CSV keys (not the whole file!) as STDIN and converts it into a simpler
# format.
# It replaces , (commas) with - (dashes) and strips quotation marks.
simplifyCsvKey() {
    sed -e 's/,/-/g' | sed -e 's/"//g'
}

# getFromCsv(database, entry, resultColumn)
#
# Returns an entry for a simple key -> value CSV database. Note that it does not
# handle CSV files properly (commas and quotations), so the databases should
# be adjusted.
# If multiple values are present, only the first one is returned.
getFromCsv() {
    grep "$2" "$1" | head -n 1 | cut -d , -f "$3"
}

# convertCountryNameToCode(countryName)
#
# Using $ISO3166_DB this converts the country names to the corresponding country
# codes. If this fails, it returns an empty string.
#
# The database needs to satisfy the following conditions:
# * One column before the country name!
# * One column after the country name!
# * The column no. 4 should contain the short 2-letter ISO3166 code.
# * It must not have any quotes! Replace "," with the "-" sign.
convertCountryNameToCode() {
    getFromCsv "$ISO3166_DB" ",$1," 4
}

# convertCropToOsmKey(cropName)
#
# Using $OSM_CROP_KEY_DB this converts the full crop names to the corresponding
# OSM key describing the crop. If this fails, it returns an empty string.
convertCropToOsmKey() {
    getFromCsv "$OSM_CROP_KEY_DB" "^$1," 2
}

input="$1"
tmpfile="$TMPDIR/data.csv"
outfile="$2"

echo "Prepare CSV…"
# extract columns & remove header
csvtool namedcol Area,Item,Year,Value "$input" > "$tmpfile.1"
# OR: csvtool col 4,8,10,12 "$input" > "$tmpfile.1"
csvtool drop 1 "$tmpfile.1" > "$tmpfile.2"

# replace , (comma) in file with different value to ease CSV processing and
# apply blacklist
echo "Adjusting datasets…"
adjustdatasets() {
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

    # filter out 0 values
    if [ "$4" = "0" ] || [ "$4" = "" ]; then
        # echo "$2 is zero. Skip."
        return
    fi

    # replace comma in area & item columns
    area=$( printf "%s" "$1" | simplifyCsvKey )
    item=$( printf "%s" "$2" | simplifyCsvKey )

    # optionally, convert items to OSM keys
    if [ $OSM_HANDLING -ge 1 ]; then
        itemOsm=$( convertCropToOsmKey "$item" )

        if [ "$itemOsm" = "" ]; then
            if [ "$OSM_COLLECT_MISSING" != "" ]; then
                echo "$item" >> "$TMPDIR/osmmissing.csv"
            fi

            if [ $OSM_HANDLING -ge 2 ]; then
                # skip keys
                return
            # else
                # show warning
                # echo "WARNING: No OSM key found for $item. (counry: $area)"
            fi
        else
            # if successful -> use OSM key instead of real name
            item="$itemOsm"
        fi
    fi

    # numbers in value column do not need special handling
    printf "%s,%s,%s,%s\n" "$area" "$item" "$3" "$4" >> "$tmpfile.3"
}
export OSM_HANDLING
export OSM_CROP_KEY_DB
export CROP_BLACKLIST
export TMPDIR
export OSM_COLLECT_MISSING
export tmpfile
export -f contains
export -f getFromCsv
export -f simplifyCsvKey
export -f convertCropToOsmKey
export -f adjustdatasets

rm "$tmpfile.3" 2> /dev/null
csvtool call adjustdatasets "$tmpfile.2"

echo "Sum up duplicate elements…"
sort "$tmpfile.3" > "$tmpfile.4"
rm "$tmpfile.5" 2> /dev/null

# reeading file in shell and loop through (sorted) lines
summedCount=0
lastkey=""
while read -r line; do
    key=$( echo "$line" | awk -F ',' '{ print $1","$2","$3 }' )
    value=$( echo "$line" | awk -F ',' '{ print $4 }' )

    if [ "$key" = "$lastkey" ]; then
        summedCount=$(( summedCount + 1 ))
        # if key is the same as last one, sum up values
        value=$(( lastvalue + value ))
    else
        # otherwise write last data
        [ "$lastkey" != "" ] && printf "%s,%s\n" "$lastkey" "$lastvalue" >> "$tmpfile.5"
        # and remember/save new values
        lastkey="$key"
        lastvalue="$value"
    fi
done < "$tmpfile.4"
# last remembered value still needs to be written
printf "%s,%s\n" "$lastkey" "$lastvalue" >> "$tmpfile.5"
echo "Summed up $summedCount duplicates."

echo "Calculate yearly average…"
rm "$tmpfile.6" 2> /dev/null

# reading file in shell and loop through lines
count=1
lastkey=""
while read -r line; do
    key=$( echo "$line" | awk -F ',' '{ print $1","$2 }' )
    value=$( echo "$line" | awk -F ',' '{ print $4 }' )

    if [ "$key" = "$lastkey" ]; then
        count=$(( count + 1 ))
        # calculate average
        valuesum="$(( valuesum + value ))"
    else
        # otherwise write last data
        [ "$lastkey" != "" ] && printf "%s,%s\n" "$lastkey" "$(( valuesum / count ))" >> "$tmpfile.6"
        # and remember/save new values
        count=1
        lastkey="$key"
        valuesum="$value"
    fi
done < "$tmpfile.5"
# last remembered value still needs to be written
printf "%s,%s\n" "$lastkey" "$(( valuesum / count ))" >> "$tmpfile.6"

echo "Sort data…"
# first remove duplicates from different
# sort data by "value"
sort --field-separator=',' -n -r --key=3 "$tmpfile.6" > "$tmpfile.7"

echo "Evaluate data…"
# get country list
areas=$( cut -d , -f 1 "$tmpfile.7" | sort | uniq )
areasOriginal=$( csvtool col 1 "$tmpfile.2" | simplifyCsvKey | sort | uniq )
areasNoData=$(echo "$areas
$areasOriginal" | sort | uniq -u )

# set IFS to line break
IFS='
'

for area in $areas; do
    # (try to) get country code
    areaShort=$( convertCountryNameToCode "$area" )
    if [ "$areaShort" = "" ]; then
        echo "WARNING: No language code for $area could be found. Skip."
        continue
    fi

    # extract data from file, form it into one line separated with commas
    crops=$( grep "$area," "$tmpfile.7" | cut -d , -f 2 | uniq | head -n "$MAX_LIST" | tr '\n' ',' | tr '|' ',' | sed -e 's/,/, /g' )

    # write data into new file
    # the stripping of the last characters (the last ", ") is not strictly POSIX-compliant, but works in all shells, nowadays
    printf "%s: [%s]\n" "$areaShort" "${crops:0:-2}" >> "$tmpfile.8"
done

# final steps
echo "Finish processing…"

# add header
{
    echo "# list of most produced/cultivated crops/fruits in the world"
    echo "# source: Food and Agriculture Organization of the United Nations, https://www.fao.org/faostat/en/#data/QCL"
    echo "# created/parsed by script: https://github.com/rugk/crops-parser"
    echo "# updated at: $( date +'%F' )"
    echo "default: []"
} > "$outfile"

# append sorted data
sort "$tmpfile.8" >> "$outfile"

if [ "$areasNoData" != "" ]; then
    {
        echo "# For these countries, there was data in the source, but due to filtering no crops remained. They were thus skipped."
        printf "# Ignored: "
        printf "%s" "$areasNoData" | tr '\n' ',' | sed -e 's/,/, /g'
        echo
    } >> "$outfile"
fi

# sort missing OSM
if [ "$OSM_COLLECT_MISSING" != "" ]; then
    sort < "$TMPDIR/osmmissing.csv" | uniq -c | sort -n -r > "$OSM_COLLECT_MISSING"
fi

#rm -rf "$TMPDIR"
