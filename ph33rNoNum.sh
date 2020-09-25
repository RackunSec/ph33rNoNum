#!/usr/bin/env bash
# Simple script to glean information about a suspicous phone number.
# This script uses the following resources:
#
#   https://localcallingguide.com
#   https://www.telcodata.us
#   https://www.cyberbackgroundchecks.com
#   https://zabasearch.com
#   https://truepeoplesearch.com
#
#
# WeakNet Labs has no affiliation with the OSINT resources that this script
#  queries and is not responsible for abuse.
#  Douglas Berdeaux weaknetlabs@gmail.com
#
VERSION="0.9.24-1 (creepy meatball)"
#
# create /tmp/ph33rnonum.txt:
OUTFILE=/tmp/ph33rnonum.txt
# Colors for pretty text:
GRN="\e[92m"
RST="\e[0m"
RED="\e[91m"
BLU="\e[96m"
BOLD="\e[1m"
UNDR="\e[4m"
PHONE="\U260E" # phone emoji
# UA to use for all HTTP requests:
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:80.0) Gecko/20100101 Firefox/80.0"

function usage {
  printf "\n -- Usage: ${GRN}${BOLD}./ph33rNoNum.sh ${RST}--num ${BOLD}XXX-XXX-XXXX${RST} (--csv)\n\n"
  exit 1337 # done
}
export -f usage
# Check if number is correct format:
printf "${BLU}\n"
printf "    ____  __   __________           \n"
printf "   / __ \/ /_ |__  /__  /_____      \n"
printf "  / /_/ / __ \ /_ < /_ </ ___/ _______      \n"
printf " / ____/ / / /__/ /__/ / /    /______/     \n"
printf "/_/ _ /_/_/_/____/____/_/          \n"
printf "   / | / /___  / | / /_  ______ ___ \n"
printf "  /  |/ / __ \/  |/ / / / / __ \`__ \\ \n"
printf " / /|  / /_/ / /|  / /_/ / / / / / /\n"
printf "/_/ |_/\____/_/ |_/\__,_/_/ /_/ /_/ \n\n"
printf "${RST}${BOLD}       ${PHONE}  2020 WeakNet Labs\n${RST}"
printf " -- Version: ${VERSION}\n"

# Parse out arguments
while test $# -gt 0
do
    case "$1" in
        --num) NUM=$2
            ;;
        --csv) CSV=1
            ;;
    esac
    shift
done

# Did we get a valid phone number?
if [[ "$NUM" == "" ]]
then
  usage
else
  if [[ $(echo -n $NUM |egrep -E '[0-9]{3}-[0-9]{3}-[0-9]{4}'|wc -l) != "1" ]]
  then
    printf "[${RED}!${RST}] Format of ${UNDR}${RED}phone number${RST} is incorrect.\n"
    usage
    exit 1338 # done
  else
    # parse out the NPA && EXCH:
    NPA=$(echo -n $NUM|sed -r 's/^([0-9]{3}).*/\1/')
    EXCH=$(echo -n $NUM|sed -r 's/^[0-9]{3}-([0-9]{3}).*/\1/')
    # exit 1339 # debug
  fi
fi

# DEBUG:
printf " ${BLU}${PHONE}  NPA-NXX Provided as:${RST} ${NPA}-${EXCH}\n"
if [[ $CSV -eq 1 ]]
then
  CSVFILE=${NUM}.csv
  printf " ${BLU}${PHONE}  ${GRN}A CSV file will be created as: ${CSVFILE}${RST}\n"
  # This will blow away data in the file already for re-dos:
  echo "phone number,npa,exchange,region,block,switch,ocn,lata,switch name,switch type,switch address,gps coordinates,map uri,building clli,carriers served,date checked" > ${CSVFILE}
fi
printf '════════════════════════════════════════════════\n'
# Make 1st HTTP request
curl "https://localcallingguide.com/lca_prefix.php?npa=$NPA&nxx=$EXCH&x=&ocn=&region=&lata=&lir=&switch=&pastdays=&nextdays=" -s > $OUTFILE
NPANXX=$(egrep 'el="NPA-NXX' $OUTFILE|head -n 1|sed -r 's/.*>([^<]+)<.*/\1/')
BLOCK=$(egrep -E '=.Block' $OUTFILE |head -n 1|sed -r 's/.*>([^>]+)<.*/\1/')
EXCHANGE=$(egrep -E 'rs="exchange' $OUTFILE |head -n 1|sed -r 's/.*>([^>]+)<.*/\1/')
OREGION=$(egrep -E 'rs="oregion' $OUTFILE |head -n 1|sed -r 's/.*>([^>]+)<.*/\1/')
OSWITCH=$(egrep -E 'rs="oswitch' $OUTFILE |head -n 1|sed -r 's/.*>([^>&]+)<.*/\1/')
OOCN=$(egrep -E 'rs="oocn' $OUTFILE |head -n 1|sed 's/&amp;/\&/g'|sed -r 's/.*>([^>]+)<.*/\1/')
OLATA=$(egrep -E 'rs="olata' $OUTFILE |head -n 1|sed -r 's/.*>([^>&]+)<.*/\1/')

## OUTPUT to terminal
printf " ${BLU}${PHONE}  NPA-NXX:${RST} $NPANXX\n"
printf " ${BLU}${PHONE}  Block:${RST} $BLOCK\n"
printf " ${BLU}${PHONE}  Exchange:${RST} $EXCHANGE\n"
printf " ${BLU}${PHONE}  Region:${RST} $OREGION\n"
printf " ${BLU}${PHONE}  Switch:${RST} $OSWITCH\n"
printf " ${BLU}${PHONE}  OCN:${RST} $OOCN\n"
printf " ${BLU}${PHONE}  LATA:${RST} $OLATA\n"

## OUTPUT to CSV file:
if [[ $CSV -eq 1 ]]
then
  echo -n "$NUM,$NPA,$EXCH,$OREGION,$BLOCK,$OSWITCH,$OOCN,$OLATA" >> $CSVFILE
fi

# Make second HTTP call if the CLLI is not NULL:
if [[ "$OSWITCH" != "" ]]
then
  curl -s "https://www.telcodata.us/search-switches-by-clli-code?cllicode=$OSWITCH" > $OUTFILE
  NAME=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '1p'|sed -r 's/.*>([^<]+)<.*/\1/')
  TYPE=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '2p'|sed -r 's/.*>([^<]+)<.*/\1/')
  STADDR=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '3p'|sed -r 's/.*>([^<]+)<.*/\1/')
  CITYADDR=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '4p'|sed -r 's/.*>([^<]+)<.*/\1/')
  STATEADDR=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '5p'|sed -r 's/.*>([^<]+)<.*/\1/')
  ZIPADDR=$(egrep -E 'class="results"' $OUTFILE |sed -r 's/(.\/td.)/\1\\\n/g'|egrep -E '^<'|sed -n '6p'|sed -r 's/.*>([^<]+)<.*/\1/')
  printf " ${BLU}${PHONE}  Switch Name:${RST} $NAME\n"
  printf " ${BLU}${PHONE}  Switch Type:${RST} $TYPE\n"
  printf '════════════════════════════════════════════════\n'
  printf " ${BLU}${PHONE}  Address:${RST}\n"
  printf "  $STADDR\n"
  printf "  $CITYADDR\n"
  printf "  $STATEADDR\n"
  printf "  $ZIPADDR\n"
  # OUTPUT to file:
  if [[ $CSV -eq 1 ]]
  then
    echo -n ",$NAME,$TYPE,$STADDR $CITYADDR $STATEADDR $ZIPADDR" >> $CSVFILE
  fi
else
  printf "[!] No Switch information was discovered.\n"
fi

# Make a third HTTP call if the
# View Switch information by CLLI:
curl -s --cookie "PHPSESSID=3290847239847293874423" -L \
 -A "${UA}" "https://www.telcodata.us/view-switch-detail-by-clli?clli=$OSWITCH" > $OUTFILE
EXCHSERVD=$(egrep -E '^\s+<tr><th\s' $OUTFILE |grep 'Exchanges Served'|sed -r 's/[^0-9]//g')
BUILDINGCLLI=$(egrep -E '^\s+<tr><th\s' $OUTFILE |grep 'Building CLLI'|sed -r 's/.*><td>([A-Z]+).*/\1/')
# Build the Maps URI:
LATLONG=$(egrep -E '^\s+<tr><th\s' $OUTFILE |grep 'Lat.Long'|sed -r 's/.*td>([0-9., -]+).*/\1/'|sed -r 's/\s+//g')
GMAPSLINK=https://www.google.com/maps/place/${LATLONG}
CARRIER=$(egrep -E '^\s+<tr><th\s' $OUTFILE |grep 'Served Comp'|sed -r 's/.*<a[^>]+>([^<]+)<.*<a/\1/'|sed -r 's/href.*//')
if [[ "$CARRIER" =~ "N/A" ]]
then
  CARRIER="N/A"
fi
# Print to the userland:
printf " ${BLU}${PHONE}  Carrier: ${RST}$CARRIER\n"
printf " ${BLU}${PHONE}  Building CLLI: ${RST}$BUILDINGCLLI\n"
printf " ${BLU}${PHONE}  Exchanges Served: ${RST}$EXCHSERVD\n"
printf " ${BLU}${PHONE}  GPS: ${RST}${LATLONG}\n"
printf " ${BLU}${PHONE}  MAP LINK: ${RST}${UNDR}${BLU}${GMAPSLINK}${RST}\n"

# Make a fourth HTTP request to cyberbackgroundchecks and parse out the result(s):
curl -s --cookie "PHPSESSID=3290847239847293874423" -L \
  -A "${UA}" "https://www.cyberbackgroundchecks.com/phone/${NUM}" > $OUTFILE # recycle file
CBCHK=$(egrep -E -i '<strong.*results' $OUTFILE |sed -r 's/(^\s+|<[^>]+>)//g')
printf " ${BLU}${PHONE}  Cyber Background Check: ${RST}${CBCHK}\n"

# Make a fifth HTTP request to glean any owner/address of the phone number provided.
PHONEDEC=$(echo ${NUM}| sed -r 's/[^0-9]+//g') # drop the hyphens essentially making this decimal.
curl -s --cookie "PHPSESSID=3290847239847293874423" -L -A "${UA}" -s https://www.zabasearch.com/phone/${PHONEDEC} > $OUTFILE
sed -i ':a;N;$!ba;s/\n/ /g' $OUTFILE # removes all newlines (this HTML is messy...)

if [[ "$(egrep -i '&firstName=' $OUTFILE|wc -l)" -ne 0 ]]
then
  # Parse out any names (just the first one will do):
  SUBSCRIBER=$(sed -r 's/.*&firstName=([A-Za-z]+)[^&]+&lastName=([A-Za-z]+).*/\1 \2/g' $OUTFILE)
  SUBSCRIBERADDR=$(sed -r 's/.*Street Address:([^<]+).*/\1/g' $OUTFILE)
  if [[ "$SUBSCRIBER" != "" ]]
  then
    printf " ${BLU}${PHONE}  Subscriber Name:${RST} ${SUBSCRIBER}\n"
    if [[ "$SUBSCRIBERADDR" != "" ]]
    then
      printf " ${BLU}${PHONE}  Subscriber Address:${RST} ${SUBSCRIBERADDR}\n"
    fi
  fi
else
  printf " ${BLU}${PHONE}  ${RST}No Subscriber information discovered in search.\n"
fi
printf " ${BLU}${PHONE}  Additional family information:\n${RST}"
# Make a 6th HTTP request using the phone number:
# parse the number correctly and build the URI:
#(412)882-4898
PHONEPARENS=$(echo $NUM|sed -r 's/(^[0-9]{3})-/\(\1\)/g')
URI="https://www.truepeoplesearch.com/resultphone?phoneno=$PHONEPARENS"
curl -s --cookie "PHPSESSID=0329482039847209837443534" -A 'Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0' "${URI}" > $OUTFILE
# Parse out the results:
egrep -E '^[A-Za-z0-9]' $OUTFILE|sed -r 's/..span>//g'|egrep -E -v '([^A-Za-z0-9 ]|Report.*|Filter)' | sed -r 's/^([0-9]+)/Age: \1\n-------------------/g' | sed -r 's/^/  /'

printf "\n${BLU}${PHONE}  ${RST}Script completed.\n"

# OUTPUT to file:
if [[ $CSV -eq 1 ]]
then
  echo ",$LATLONG,$GMAPSLINK,$BUILDINGCLLI,$CARRIER,$(date)" >> $CSVFILE
fi # :wq lol
# EOS
printf "\n"
