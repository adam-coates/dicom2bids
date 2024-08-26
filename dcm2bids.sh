#!/usr/bin/env bash

#DICOM to BIDS bash script
#Dependencies: 
#dcm2niix 
#dcmunpack

#Script works best with siemens DICOMS but might also work for Philips scanners (this is not tested)
#

#TODO
#add option to convert dicoms using a json conffiguration for advanced dicom to bids 
#
#resize if possible
printf '\033[8;37;95t'

clear
green='\e[32m'
red='\e[31m'
purple='\033[0;35m'
clear='\e[0m'

ColorGreen(){
    echo -e $green$1$clear
}

ColorRed(){
    echo -e $red$1$clear
}

ColorPurple(){
    echo -e $purple$1$clear
}

spinner() {
    # Spinner characters
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local charwidth=3
    # Make sure we use non-unicode character type locale 
    # (that way it works for any locale as long as the font supports the characters)
    local LC_CTYPE=C

    # Run the command passed as arguments and capture its PID
    "$@" &
    local pid=$!

    local i=0
    tput civis # Cursor invisible
    while kill -0 $pid 2>/dev/null; do
        local i=$(((i + $charwidth) % ${#spin}))
        printf "\e[32m%s\e[m" "${spin:$i:$charwidth}"  # Green font color
        printf "\033[1D"  # Move the cursor back one position
        sleep .1
    done
    tput cnorm # Cursor visible
    wait $pid # Capture exit code
    return $?
}

menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
    printf "$prompt\n"
    while true
    do
        # list all options (option list is zero-based)
        index=0 
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]
            then echo -e " >\e[7m$o\e[0m" # mark & highlight the current option
            else echo "  $o"
            fi
            (( index++ ))
        done
        read -s -n3 key # wait for user to key in arrows or ENTER
        if [[ $key == $esc[A ]] # up arrow
        then (( cur-- )); (( cur < 0 )) && (( cur = 0 ))
        elif [[ $key == $esc[B ]] # down arrow
        then (( cur++ )); (( cur >= count )) && (( cur = count - 1 ))
        elif [[ $key == "" ]] # nothing, i.e the read delimiter - ENTER
        then break
        fi
        echo -en "\e[${count}A" # go up to the beginning to re-render
    done
    # export the selection to the requested output variable
    printf -v $outvar "${options[$cur]}"
}
#see https://askubuntu.com/questions/1705/how-can-i-create-a-select-menu-in-a-shell-script

checkforsyntax() {
    if command -v dcm2niix &> /dev/null; then
        DCM2NIIX_STATUS=$(ColorGreen "INSTALLED")
    else
        DCM2NIIX_STATUS=$(ColorRed "NOT INSTALLED")
    fi

    if python3 -c "import pydicom" &> /dev/null; then
        PYDICOM_STATUS=$(ColorGreen "INSTALLED")
    else
        PYDICOM_STATUS=$(ColorRed "NOT INSTALLED")
    fi

    if command -v dcmunpack &> /dev/null; then
        DCMUNPACK_STATUS=$(ColorGreen "INSTALLED")
    else
        DCMUNPACK_STATUS=$(ColorRed "NOT INSTALLED")
    fi
    if command -v dcm2bids_scaffold &> /dev/null; then
        DCM2BIDS_SCAFFOLD_STATUS=$(ColorGreen "INSTALLED")
    else
        DCM2BIDS_SCAFFOLD_STATUS=$(ColorRed "NOT INSTALLED")
    fi
    if [ -x ~/"jq" ]; then
        JQ_STATUS=$(ColorGreen "INSTALLED")
        jq=~/jq
    else
        JQ_STATUS=$(ColorRed "NOT INSTALLED")
     fi
    
}

syntax() {
cat << EOF

[1;31m ____ ___ ____ ___  __  __   ____    ____ ___ ____  ____  [0m
[1;32m|  _ \_ _/ ___/ _ \|  \/  | |___ \  | __ )_ _|  _ \/ ___| [0m
[1;33m| | | | | |  | | | | |\/| |   __) | |  _ \| || | | \___ \ [0m
[1;34m| |_| | | |__| |_| | |  | |  / __/  | |_) | || |_| |___) |[0m
[1;35m|____/___\____\___/|_|  |_| |_____| |____/___|____/|____/ [0m

[1;36mAdam.C[0m
[1;34mv.2.5[0m
***************************************************************************
[1;32mRelease Notes v2.5:         		       						       
• Add a check for the nifti directory when the dicom  
   directory does not contain any session folder[0m 
***************************************************************************
____________________________________________________________________________

• A helper script to convert dicoms into BIDS format [1;39mquickly and easily![0m

Script uses:
	‣ dcm2niix: ${DCM2NIIX_STATUS}
	‣ pydicom: ${PYDICOM_STATUS} (faster than dcmunpack) OR
	‣ dcmunpack: ${DCMUNPACK_STATUS}
	‣ dcm2bids_scaffold: ${DCM2BIDS_SCAFFOLD_STATUS} 
	‣ jq (to edit/add intendedfor to fmap json): ${JQ_STATUS}
____________________________________________________________________________
EOF
}

checkmodules() {
    if [[ $1 == dcm2niix ]]; then
        command -v dcm2niix &> /dev/null || { 
            echo "$(ColorRed 'dcm2niix could not be found. Please install it before running this script.')"
            exit 1
        }
    elif [[ $1 ==  dcm2bids_scaffold ]]; then 
        command -v dcm2bids_scaffold &> /dev/null || {
            echo "$(ColorRed 'dcm2bids_scaffold could not be found. Please install it before running this script.')"
            exit 1
        }
    elif [[ $1 == jq ]]; then
        [ -f ~/"jq" ] || {
            echo "[1;31mModule ${1} is not installed.[0m"
            read -p "Do you want to install it now? (y/n): " choice
    curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 > ~/jq
    chmod +x ~/jq
    checkforsyntax
    syntax
    }
    else
        python3 -c "import ${1}" &> /dev/null || {
            echo "[1;31mModule ${1} is not installed.[0m"
            read -p "Do you want to install it now? (y/n): " choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                python3 -m pip install ${1}
                echo "[1;32m Done! [0m"
                sleep 1
                clear
                checkforsyntax
                syntax
            fi
        }
    fi
}

get_dir() {
read -p "Enter the full path to the $1 directory: "  dir
echo $dir
}

check_dir() {
if [ $2 == "dicom" ]; then
[ ! -d "$1" ] && { echo "Dicom directory needs to exist first: ${1}"; exit 1; }
fi
if [ ! -d "$1" ]; then
    read -p "Directory $1 does not exist. Do you want to create it? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        mkdir -p "$1"
        echo "Directory $1 created."
    else
        echo "Directory $1 not created."
        exit 1
    fi
else
    echo -ne "[1;32m $2 directory exists \u2714[0m"
    echo
fi
}

getdicompath() {
dicomname_tmp=($(find "$dicomdir" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;))

echo "_____________________________________________________________"
menu "Please choose dicom name:" dicom_sub "${dicomname_tmp[@]}"

sessions_folders=($(find "$dicomdir/$dicom_sub" -maxdepth 1 -type d -not -path "$dicomdir/$dicom_sub" | grep -v "/DICOMS$" | sed "s|^$dicomdir/$dicom_sub/||"))

if [ "${#sessions_folders[@]}" -gt 1 ] && [ "${sessions_folders[0]}" != "DICOM" ]; then
    echo "_____________________________________________________________"
    echo Number of subdirectories found: "${#sessions_folders[@]}" 
    menu "Select a folder:" ses "${sessions_folders[@]}"
    dicom_path=$dicomdir/$dicom_sub/$ses
else
    checksessions=1
    ses="ses-1"
    dicom_path=$dicomdir/$dicom_sub/
fi
echo "_____________________________________________________________"
}


getbidssubject() {
subject=$(generate_subject_id "$dicom_sub")

echo "The BIDS subject ID is: $subject"
read -p "Is this correct? (y/n): " response
if [[ "$response" != "y" ]]; then
    read -p "Please enter the correct subject ID (e.g., sub-1181004): " new_subject
    if [[ -z "$new_subject" ]]; then
        echo "No new subject ID entered. Keeping the previous subject ID: $subject"
    else
        echo "Subject ID updated to: $new_subject"
        subject=$new_subject
    fi
fi
}

doublecheckses() {
clear
cat << EOF
[1;31m The current path to search dicoms is ${dicom_path} but this might not reflect which session the dicoms are for!

Currently the dicoms will be unpacked to: ${nifti_dir}/${subject}/${ses}[0m

EOF

read -p "Would you like to change the sessions folder from $ses to another session in the nifti directory (this will not effect the dicom unpacking from $dicom_path):   " response
    if [[ "$response" == "y" ]]; then
        read -p "Enter the ses (e.g. ses-1 ses-2 etc.)  " ses
    fi
    
}

generate_subject_id() {
    dicom_sub=$1
    nnsubject=$(echo "$dicom_sub" | tr -d '_')
    firstnums="${nnsubject:0:3}"
    lastnums="${nnsubject: -3}"
    echo "sub-${firstnums}1${lastnums}"
}

dicomsearch() {
#check pydicom installed. Can be used to probe dicoms and a lot faster than dcmunpack
if python3 -c "import pydicom" &> /dev/null; then
    echo "pydicom is installed."
    echo "Starting searching for dicoms..."
    sleep 1
    spinner python3 probedicom.py $dicom_path $niidir/${dicom_sub}_${ses}-dicominfo.txt 
else
    echo "dcmunpack is installed. This takes longer than pydicom"
    dcmunpack -src $dicom_path -scanonly $niidir/${dicom_sub}_${ses}-dicominfo.txt
fi
}

extractdicominfo() {

mkdir -p $niidir/$subject/$ses
echo "Roughly unpacking dicoms"
spinner /storage/adam/CLAUS_3T/dcm2niix/dcm2niix -z y -f %p_%s  -o $niidir/$subject/$ses $dicom_path
#
}

syntaxforrenaming() {
cat << "EOF"

[1;31m 
        _                                          _ 
  _ __ | | ___  __ _ ___  ___   _ __ ___  __ _  __| |
 | '_ \| |/ _ \/ _` / __|/ _ \ | '__/ _ \/ _` |/ _` |
 | |_) | |  __/ (_| \__ \  __/ | | |  __/ (_| | (_| |
 | .__/|_|\___|\__,_|___/\___| |_|  \___|\__,_|\__,_|
 |_|                                                 
[0m



Renaming files to fit the BIDS standard is important the naming convention is:
	{subjectname}_{session}_{task-type}_{run}_{acquisitiontype}
	
e.g:
	sub-1201001_ses-1_task-illusion_run-1_bold.nii.gz
	
OR
	sub-1201001_ses-1_acq-highres_T1w.nii.gz
	
_____________________________________________________________


The files should be placed in directory names e.g. 

anat
func
fmap

The files should adhere to this structure otherwise fMRIprep might fail!

NOTE: if a dicom doesn't fit in a directory name you can rename the folder to e.g. 'extra'
EOF
read -p "Press enter to continue" 

clear
}

modify() {
    modified_names=()
    y=0

    total_dicoms=$(ls "$niidir/$subject/$ses" | awk -F. '{print $1}' | sort | uniq | wc -l)

    names=($(ls "$niidir/$subject/$ses" | awk -F. '{print $1}' | sort | uniq))



    echo ""
    echo "******************"
    echo "${#names[@]} dicoms found"
    echo "******************"
    echo ""
    echo "Generally you might want to remove: -anat-scout"

    # Iterate over the names array to let the user select and modify
    for ((i=0; i<${#names[@]}; i++)); do
        echo ""
        echo "******************"
        echo "$total_dicoms dicoms remaining"
        echo "******************"
        echo ""
        
        name=${names[$i]}
        new_type=$(echo "$name" | awk -F'[-_]' '{print $1}')
        json_file="$niidir/$subject/$ses/${name}.json"
        nii_file="$niidir/$subject/$ses/${name}.nii.gz"
        name_cut="${name:4}"
        name_suggestion="${subject}_${ses}_${name_cut}"

        menu "Select an option for the dicom '${name}':" user_choice "Keep" "Modify Name" "Delete (do not convert)"
        
        case $user_choice in
            "Keep")
                name=$name
                ;;
            "Modify Name")
                read -e -i "${name_suggestion}" -p "Please edit the name: " modified_name
                name=("$modified_name")
                # Rename both files if they exist
                if [[ -e $json_file ]]; then
                    mv -i "$json_file" "$niidir/$subject/$ses/${name}.json"
                    json_file="$niidir/$subject/$ses/${name}.json"
                fi
                if [[ -e $nii_file ]]; then
                    mv -i "$nii_file" "$niidir/$subject/$ses/${name}.nii.gz"
                    nii_file="$niidir/$subject/$ses/${name}.nii.gz"
                fi
                ;;
            "Delete (do not convert)")
                # Delete both files if they exist
                if [[ -e $json_file ]]; then
                    rm "$json_file"
                fi
                if [[ -e $nii_file ]]; then
                    rm "$nii_file"
                fi
                sleep 1
                clear
                y=1
                ;;
        esac

        if [ "$y" -ne 1 ]; then
            echo "_____________________________________________________________"
            echo "_____________________________________________________________"
            menu "Select an option for the dicom: '${name}' in folder '$new_type':" user_choice "Keep folder name" "Modify folder name"
            
            case $user_choice in
                "Keep folder name")
                    mkdir -p "$niidir/$subject/$ses/$new_type"
                    if [[ -e $json_file ]]; then
                        mv -i "$json_file" "$niidir/$subject/$ses/$new_type/"
                    fi
                    if [[ -e $nii_file ]]; then
                        mv -i "$nii_file" "$niidir/$subject/$ses/$new_type/"
                    fi
                    clear
                    ;;
                "Modify folder name")
                    read -e -i "$new_type" -p "Please edit the folder type: " new_type
                    mkdir -p "$niidir/$subject/$ses/$new_type"
                    if [[ -e $json_file ]]; then
                        mv -i "$json_file" "$niidir/$subject/$ses/$new_type/"
                    fi
                    if [[ -e $nii_file ]]; then
                        mv -i "$nii_file" "$niidir/$subject/$ses/$new_type/"
                    fi
                    clear
                    ;;
            esac
        fi
        y=0
        ((total_dicoms--))
    done
}

fmapjsonfix() {

nii_files=($(ls  $niidir/$subject/$ses/func/*.nii.gz ))

bidsuriout="$niidir/$subject-bidsurifmap.txt"

for json_file in $niidir/$subject/$ses/fmap/*.json ; do

    intended_for="\"IntendedFor\": ["
    
    for nii_file in "${nii_files[@]}"; do
        # Get the filename from the path
        nii_filename=$(basename "$nii_file")
        intended_for="$intended_for
        \"$ses/func/$nii_filename\","
        echo "\"bids::$subject/$ses/func/$nii_filename\"" >> "$bidsuriout"
    done

    # Remove the last comma and close the array
    intended_for="${intended_for%,}
    ]"

    ~/jq --argjson intended_for "{$intended_for}" \
       '. + $intended_for' \
       "${json_file}" > tmp.json && mv tmp.json "${json_file}"

    echo "Updated ${json_file} with IntendedFor field"
done
}


#Check installation
checkforsyntax

#Print start screen
syntax

#Check modules (if not prompt to install)
checkmodules dcm2niix
checkmodules pydicom
checkmodules dcm2bids_scaffold
checkmodules jq

#Get and check nifti dir
niidir=$(get_dir "nifti")
check_dir $niidir "nifti"
#Get and check dicom dir
dicomdir=$(get_dir "dicom")
#check dicom dir
check_dir $dicomdir "dicom"

#Get full dicom path (in case there are sessions or other subdirectories)
getdicompath

#Convert dicom subject into a suitable BIDS subject name
getbidssubject

#Double check the session 
[ $checksessions -eq 1 ] && doublecheckses

# Create BIDS structure if not already created 
[ -f "$niidir/participants.tsv" ] || dcm2bids_scaffold -o $niidir

# Start dicom search using pydicom or dcmunpack
[ -f "$niidir/${dicom_sub}_${ses}-dicominfo.txt" ]  || dicomsearch


#Extract info from the dicom search, name, folder and path
if ls $niidir/$subject/$ses/*.nii.gz /dev/null 2>&1; then
    read -p "Extracted nifitis found, would you like to still roughly extract dicoms?    " response 
    	if [[ "$response" =~ ^[Yy]$ ]]; then
    	     extractdicominfo
    	fi
  else
  extractdicominfo
fi


#Information for user about renaming and BIDS naming conventions

syntaxforrenaming

#Start the modification of names and folders, or deletion
modify

fmapjsonfix


