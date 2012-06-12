#create initial JSON file
touch  ${1%.*}.json
echo '{ "BlueButtonData" : {' > ${1%.*}.json
echo '"Conversion Data": "Converted by BlueConverter",' >> ${1%.*}.json

#read ASCII data file
blackcats="MY HEALTHEVET PERSONAL INFORMATION REPORT,DOWNLOAD REQUEST SUMMARY"
arraykeys="Contact First Name:Contacts,Provider Name:Providers,Facility Name:Facilities,Health Insurance Company:Companies,Date/Time:Appointments,Medication:Medications,Category:Medications,Allergy Name:Allergies,Medical Event:Events,Immunization:Immunizations,Test Name:Tests,Measurement Type:Measurements,Event Title:Events"

militarycategories="Regular Active Service,Reserve/Guard Association Periods,Reserve/Guard Activation Periods,Deployment Periods,DoD MOS/Occupation Codes,Military/Combat Pay Details,Separation Pay Details,Retirement Periods,DoD Retirement Pay"
servicefields="Service,Begin Date,End Date,Character of Service,Rank"
activationfields="Service,Begin Date,End Date,Activated Under"
locationfields="Service,Begin Date,End Date,Conflict,Location"
occupationfields="Service,Begin Date,Enl/Off,Type,Svc Occ Code,DoD Occ Code"
payfields="Service,Begin Date,End Date,Military Pay Type,Location"
payfields2="Service,Begin Date,End Date,Separation Pay Type"
retirementfields="Service,Begin Date,End Date,Retirement Type,Rank"
retirementpayfields="Service,Begin Date,End Date,Dsblty %,Pay Stat,Term Rsn,Stop Pay Rsn"

categoryfound=false
inArray=false
inDODArray=false


currentfieldset="$servicefields"

while read LINE
do
	NLINE=$( echo $LINE | sed -e 's/.$//g') #decode line	
	if [[ $NLINE == *---* ]] #detect category name
		then
	  	catname=$( echo $NLINE | sed 's/\-//g' ) #remove -
		catname=$( echo $catname | sed -e 's/^[ \t]*//') #remove extra spaces
		
		#check to see if this is a category we should ignore
		IFS=',' read -ra blacklist <<< "$blackcats" 
		categoryfound=true
		for b in "${blacklist[@]}"
			do
				if [ "$b" = "$catname" ]
				#if [ "DOD MILITARY SERVICE INFORMATION" = "$catname" ]
					then
					categoryfound=false
				fi
			done
		
		if [[ ${#catname} > 1 ]] 
			then
		if $categoryfound
			then
			if $inArray
				then
				echo "\"eoa\" : true } ]," >> ${1%.*}.json 
			fi
			echo "\"eoc\" : true }, " >> ${1%.*}.json
			echo "\"${catname}\" : {
					"  >> ${1%.*}.json
			echo "Converting ${catname} ..."
			inArray=false
		fi
		fi
	else
		if $categoryfound
			then
			
			#read incoming line into either key value pairs
			#or determine if this should be treated like an object array
			IFS=':' read -ra KEYVALUE <<< "$NLINE"
			IFS=',' read -ra arrays <<< "$arraykeys" #pull arrays string to determine object arrays
			
			if [ "$catname" = "DOD MILITARY SERVICE INFORMATION" ] #Military has completely different formatting
				then
					subcatname=$( echo ${KEYVALUE[0]} | sed 's/\-//g' )
					subcatname=$( echo $subcatname | sed -e 's/^[ \t]*//')
					
					if [ "${subcatname}" = "Translations of Codes Used in this Section" ] #we're done here
						then
						catname="END"
						inDODArray=false
						echo "
							{\"eoa\":true }], " >> ${1%.*}.json
					fi
					
					#echo $subcatnane
					IFS=',' read -ra subcats <<< "$militarycategories"
					for a in "${subcats[@]}"
						do
							if [ "$a" = "${subcatname}" ]
								then
								echo ">${a}"
								if $inDODArray
									then
									echo "{\"eoa\" : true} ],
									\"${a}\" : [" >> ${1%.*}.json
									else
									echo "	\"${a}\" : [" >> ${1%.*}.json
								fi
								
								
								inDODArray=true
								
								if [ "${a}" = "${subcats[0]}" ]
									then	
									currentfieldset=$servicefields
								fi
								if [ "${a}" = "${subcats[1]}" ]
									then	
									currentfieldset=$servicefields
								fi
								if [ "${a}" = "${subcats[2]}" ]
									then	
									currentfieldset=$activationfields
								fi
								if [ "${a}" = "${subcats[3]}" ]
									then	
									currentfieldset=$locationfields
								fi
								if [ "${a}" = "${subcats[4]}" ]
									then	
									currentfieldset=$occupationfields
								fi
								if [ "${a}" = "${subcats[5]}" ]
									then	
									currentfieldset=$payfields
								fi
								if [ "${a}" = "${subcats[6]}" ]
									then	
									currentfieldset=$payfields2
								fi
								if [ "${a}" = "${subcats[7]}" ]
									then	
									currentfieldset=$retirementfields
								fi
								if [ "${a}" = "${subcats[8]}" ]
									then	
									currentfieldset=$retirementpayfields
								fi
								
							fi
						done
					fi
					valuelinecompressed=$(echo ${KEYVALUE[0]} | sed -e 's/^[ \t]*//')
					
					IFS=' ' read -ra values <<< "$valuelinecompressed"
					IFS=',' read -ra fieldset <<< "$currentfieldset"
					
					if $inDODArray && [ "${values[0]}" != "Service" ] && [ "${values[0]}" != "-" ] && [ "${values[0]}" != "--" ] #data row
						then
						echo "{ "  >> ${1%.*}.json
						index=0
						if [ "${values[1]}" = "Reserve" ]
							then
							values[0]="${values[0]} ${values[1]}"
							values[1]=${values[2]}
							values[2]=${values[3]}
							values[3]=${values[4]}
							values[4]=${values[5]}
							values[5]=${values[6]}
							values[6]=${values[7]}
						fi
						for a in "${values[@]}"
							do
								echo "	\"${fieldset[index]}\" : \"${a}\"," >> ${1%.*}.json
								index=`expr $index + 1`
							done
						echo "	\"eor\" : true }, " >> ${1%.*}.json
					fi
			#else
			#echo "!${catname}"
			#Not Military History, continue with normal field/value split/layout
			if $inArray
				then
				for a in "${arrays[@]}"
					do
						IFS=':' read -ra array <<< "$a"
						if [ "${array[0]}" = "${KEYVALUE[0]}" ]
							then
							echo "		\"eoa\":false },
								{" >> ${1%.*}.json
						fi
					done
			fi
			
			for a in "${arrays[@]}"
				do
					IFS=':' read -ra array <<< "$a"
					if [ "${array[0]}" = "${KEYVALUE[0]}" ]
						then
						if [ $inArray = false ]
							then
							echo "		\"${array[1]}\": [ {"  >> ${1%.*}.json
							inArray=true
						fi
					fi
				done
			
			
			if [ ${#KEYVALUE[@]} = 2 ]
				then
				value=$( echo ${KEYVALUE[1]} | sed 's/\"//g' )
				if  [ "$catname" != "DOD MILITARY SERVICE INFORMATION" ] && [ "$catname" != "END" ]
					then
					if $inArray
						then
						echo "		\"${KEYVALUE[0]}\":\"$value\","  >> ${1%.*}.json
					else 
						echo "			\"${KEYVALUE[0]}\":\"$value\","  >> ${1%.*}.json
					fi
				fi
			else
				value=$( echo ${KEYVALUE[0]} | sed 's/\"//g' )
				value=$( echo ${value} | sed 's/\=//g' )
				value=$( echo ${value} | sed 's/\-//g' )
				
				if [ "$value" != "" ] && [ "$catname" != "DOD MILITARY SERVICE INFORMATION" ] && [ "$catname" != "END" ]
					then
					echo "		\"Note\":\"$value\","  >> ${1%.*}.json
				fi
			fi
		fi
	fi


done < $1

echo '"eoc": true
   }, "eof" : true }' >> ${1%.*}.json

echo "${1%.*}.json written"
echo "Completed"