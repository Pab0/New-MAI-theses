#!/bin/bash
# Usage: ./scan_for_new_theses.sh
# Keeps track of theses for the KU Leuven MAI programme, and looks for new ones added to the site.
# The new thesis' descriptions are automatically downloaded once discovered.
# To be run once a day.

# Prerequisites: bash, wget

# 0. Set up directory

list_location="$(pwd)/MAI_thesis_list" # the script's working directory, may be set to something else
mkdir -p "$list_location"
cd "$list_location"

URL="https://wms.cs.kuleuven.be/cs/studeren/master-artificial-intelligence/MAI_SIP/masters-thesis/thesis-topic-proposals"

tmp_file_name="latest_list.tmp" 	# file to save list initially, before any comparing
list_file_name="$(date +%Y.%m.%d).list" 	# filename to save today's list is set to current date

# 1. Get current theses listing

wget -qO - "$URL" | 	# Get Theses page
	grep "state-missing-value contenttype-file" | # filter for theses lines
	sed -e 's/<\/a.*//g' -e 's/.*>//g' | 		# extract title
	sort > "$tmp_file_name" 	# sort alphabetically and save to file 

theses_count=$(wc -l "$tmp_file_name" | sed 's/ .*//')
echo "Got new theses listing from the website, found $theses_count theses topics."

# 2. Find latest saved listing to compare to

meta_list="$(ls 2>/dev/null *.list)"
if [[ -z "$meta_list" ]]; then
	echo "No previous listings found, creating new one."
	mv "$tmp_file_name" "$list_file_name"
	exit 0
else
	last_listing=$(echo "$meta_list" | sort | tail -n1)
	# Disregard possible previous runs from today
	if [[ "$last_listing" == "$tmp_file_name" || "$last_listing" == "$list_file_name" ]] ; then 
		last_listing=$(echo "$meta_list" | sort | tail -n2 | head -n1)
	fi
fi

# 3. Compare latest list to newest daily list
new_theses="$(comm -23 "$tmp_file_name" "$last_listing" )"
if [[ -z $new_theses ]]; then
	echo "No new theses found since ${last_listing%.list}."
	exit 0
else
	echo "Found new theses since ${last_listing%.list}:"
	echo "$new_theses"
fi

# 4. Download new theses' descriptions
new_theses_dir="New theses discovered on $(date +%Y.%m.%d)"
mkdir -p "$new_theses_dir"
cd "$new_theses_dir"

while read -r title; do
	wget -qO - "$URL" | 	# Get Theses page
		grep "$title" | 	# filter for thesis' title
		sed -e 's/.*href="//g' -e 's/pdf".*>/pdf/g' | 		# extract URL
		wget -i -  --no-clobber	# download file
done <<< "$new_theses"

echo "Downloaded new thesis descriptions to $new_theses_dir"

# 5. Exit
exit 0
