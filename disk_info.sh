#!/bin/bash
#Definisition des variables
OLDLANG=$LANG ; LANG="en-US"

> /tmp/diskfull
tempdir="/tmp"

printdf() 
{
df=(`df -h --total | grep "unrecognized"`)
        if [[ ! -n "$df" ]]; then
                df -h --total | grep -Ev 'udev|tmpfs|none' > /tmp/disk_df.tmp && cat /tmp/disk_df.tmp
        else
                df -h | grep -Ev 'udev|tmpfs|none' > /tmp/disk_df.tmp && cat /tmp/disk_df.tmp
        fi
}


checkos()
{
if [[ -f /etc/debian_version ]]; then
	debian=1
else
	debian=0
fi
}

checksmarttools()
{
if [[ ! -f /usr/sbin/smartctl ]]; then
#Installation de smartools
	if [[ $debian = 1 ]]; then
		echo "smartctl non present"
        	echo -n "Installation en cours..."
        	apt-get -y install smartmontools &> /dev/null && echo "OK - rechargement du script" && ./$0 && exit 0|| echo "ERREUR, verifier l'installation de smarttools"; exit 0
	else
		echo "OS non supporté pour l'instalation automatique de SmartMonTools"
		echo "Merci de bien vouloir installer smartmontools et relancer le programme"
		exit 0
	fi
fi
}

checkctrl()
{
if [[ -d /dev/cciss ]]; then
	controler=hp
else
	controler=std
fi
}


recupstd()
{
	numdisk=-1
	unset stats_array
	unset line_array
	stats_array=()
	for d in `lsblk -l -d -n -o NAME`; do
		(( numdisk++ ))
		echo  "------------------- Disk $numdisk ($d) -------------------"	
		smartctl -i -g all /dev/$d | sed -e 1d -e 2d -e 3d -e 4d
			while read line; do 
				line_array=( $line)
				[[ $line =~ Temperature_Celsius ]] && temp+=(${line_array[9]})  && tempstats+=("Disque $d"  ${line_array[9]})
				[[ $line =~ Power_On_Hours      ]] && power+=(${line_array[9]}) && powerstats+=("Disque $d" ${line_array[9]})
				[[ $line =~ Power_Cycle_Count   ]] && cycle+=(${line_array[9]}) && cyclestats+=("Disque $d" ${line_array[9]})
			
			done  < <(echo "`smartctl -A /dev/$d`")
		if [[ ${temp[$numdisk]} || ${power[$numdisk]} || ${cycle[$numdisk]} ]]; then
			echo "####### Statistiques ###########"
		fi
		
		if [[ ${temp[$numdisk]} ]]; then
			echo "Temperature is:   "${temp[$numdisk]}" degrees"
		fi

		if [[ ${power[$numdisk]} ]]; then
			echo "Powered hours is: ${power[$numdisk]} h"
		fi

		if [[ ${cycle[$numdisk]} ]]; then
			echo "Power cycle is:   ${cycle[$numdisk]}"
		fi		
	echo
	echo
	done
}

recupcciss()
{
        unset stats_array
        unset line_array
        stats_array=()
	for z in {0..11}; do
		(( numdisk++ ))
                echo  "------------------- Disk $d -------------------"
                                smartctl  -a -d cciss,$z /dev/ciss0
				
                                exitcode=$?
		done

}
printtemp()
{
        if [[ -n "${tempstats}" ]]; then
                echo "<-------------------  Temperatures  ----------------------->"
                # recuperation dans un tableau des temperatures des disques
                nbvar=${#tempstats[*]}
		nbtempstats=$((($nbvar)/2))
		t=0
                #Affiche la temperature pour chaque disque
                        while [ $t != $nbvar ]; do	
                                echo -n "${tempstats[$t]} : "
                                let t++
				moyennetemp="$moyennetemp+${tempstats[$t]}"
				echo "${tempstats[$t]} degree(s)"
				let t++
                        done
			echo
                # calcul de la moyenne de temperature  des disques.i
		echo "=> Temperature Moyenne des Disques: $(((0 $moyennetemp )/$nbtempstats)) C"
                echo
                echo
        fi
}

printpowerup()
{
        if [[ -n "${powerstats}" ]]; then
                echo "<------------------  Fonctionnement  ---------------------->"
                nbvar=${#powerstats[*]}
		nbpowerstats=$((($nbvar)/2))
                u=0
                #Affiche le nombre d'heure pour chaque disque
                        while [ $u != $nbvar ]; do
				echo -n  "${powerstats[$u]} : "
				let u++ 
				moyennepower="$moyennepower+${powerstats[$u]}"
                                days=$((${powerstats[$u]}/24))
                                if [[ $days -gt 365 ]]; then
                                        year=$(($days/365))
                                        restdays=`printf "%.0f" $(echo "scale=4;(365*($days/365-$year))" | bc)`
                                        echo   "${powerstats[$u]} heure(s) soit $days jour(s)  ou $year an(s) et $restdays jour(s)"
                                else
                                        echo   "${powerstats[$u]} heure(s) soit $days jour(s)"
                                fi
				let u++
                        done
                        echo

                fi
                #Calcule la moyenne d'heures de fonctionnement
		nbpowerstats=$((($nbvar)/2))
		heure=`echo "((0$moyennepower)/$nbpowerstats)" | bc`
                        days=$(($heure/24))
			year=$(($days/365))
                        if [[ $days -gt 365 ]]; then
                                restdays=`printf "%.0f" $(echo "scale=8;(365*($days/365-$year))" | bc)`
                                echo "=> Temps moyen de fonctionnement: $heure heures soit $days Jours ou $year an(s) et $restdays jour(s))"
                        else
                                echo "=> Temps moyen de fonctionnement: $heure heures soit $days Jours"
                        fi
                echo
                echo

}


printcycle()
{
        if [[ -n "${cyclestats}" ]]; then
                echo "<-----------------  Cycle start/stop  --------------------->"
                nbvar=${#cyclestats[*]}
		nbcyclestats=$((($nbvar)/2))
                c=0
                #Affiche la temperature pour chaque disque
                        while [ $c != $nbvar ]; do
                                echo -n "${cyclestats[$c]} : "
				let c++
				moyennecycle="$moyennecycle+${cyclestats[$c]}"
				echo "${cyclestats[$c]} cycle(s)"
				let c++
				
                        done
			echo
                fi
                # calcul de la moyenne de temperature  des disques
		cycle=`echo "((0$moyennecycle)/$nbcyclestats)" | bc`
                echo "=> Nombre moyen de Cycle: $cycle"
                echo
                echo
}

### Programme generation HTML ###
html()
{
echo '
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">

<html>
<head>
        <meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
        <title>Disque info</title>
</head>
<body>
<center>
<H1>Informations des disques dur</br></H1>
' > /tmp/html.tmp
echo "<table border=1><tr><th>Serveur</th><th>Type</th><th>Kernel</th></tr>
      <tr><td>$HOSTNAME</td><td>`uname -s`</td><td>`uname -r`</td></tr></table></br></br><h2>Moutpoint and usage</h2>" >> /tmp/html.tmp
cat /tmp/disk_df.tmp | sed s/Mounted\ on/Moutpoint/g | awk 'BEGIN{ print("<table border=1><tr>") }
			{ 
				for ( i = 1; i<=NF ; i++ ) { 
					printf "<td> %s </td> ", $i
				}
			print "</tr>"
			}
			END{ 
			print("</table>")
			}' >> /tmp/html.tmp


}




### Programme de lecture ###
play()
{


### programme principal
> /tmp/diskfull

echo "
###################################################################################
                         Informations des disques dur
            Serveur : $HOSTNAME  type : `uname -s`  kernel : `uname -r`

=> Utilisez les touches de defilements ou espace pour defiller dans les informations
=> Appuyez sur q puis entrer pour quiter
##################################################################################
"
html





checkctrl
echo "<------------------ Points de montages -------------------->"
printdf
echo
echo "<-------------------  Informations  ----------------------->"
if [[ $controler = hp ]]; then
	recuphp
else
	recupstd
fi
printtemp
printpowerup
printcycle
}
checkos && checksmarttools && play | less  
LANG=$OLDLANG
