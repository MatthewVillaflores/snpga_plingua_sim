#!/bin/bash

# $1 = file input
function parseAndSimulateSNP 
{
	log "start parsing"

	in_count=0

	while read line; do
		if [[ "$line" = "" ]]
		then
			continue
		fi

		log "Got bit string $line"
		bit_string=`echo $line | tr -d '[:space:]'`
		echo "bit string length: ${#bit_string}"
		num_neurons=$(bc <<< "scale=0; sqrt(${#bit_string})")
		num_neurons=`expr $num_neurons`
		log "Number of Neurons: $num_neurons"

		file_suffix=$in_count
		pli_file=$PLI_FILE.$file_suffix.pli

		# Create empty file
		> $pli_file

		####
		# Form Pli Header
		#
		echo "@model<spiking_psystems>" >> $pli_file
		echo "def main(){" >> $pli_file

		###
		# Form buffer
		#
		echo "	@mu = buff1, buff2;" >> $pli_file
		echo " 	@marcs = (buff1, buff2), (buff2, buff1);" >> $pli_file
		echo "	@ms(buff1) = a;" >> $pli_file
		echo "	[a --> a]'buff1 :: 0;" >> $pli_file
		echo "	[a --> a]'buff2 :: 0;" >> $pli_file	
	
		####	
		# Form Neurons
		#
		neuron_labels=()
		snp_neurons="@mu += "

		for ((i=0;i<$num_neurons;i++))
		do
			neuron_labels+=("nr$i")
			snp_neurons+="nr$i,"
		done

		snp_neurons=`echo $snp_neurons | sed -e 's/,$/;/g'`
		echo "	$snp_neurons" >> $pli_file

		####
		# Input/Output Neuron
		echo "	@min = ${neuron_labels[0]};" >> $pli_file
		num_neurons_m1=`expr $num_neurons - 1`
		echo "	@mout = ${neuron_labels[$num_neurons_m1]};" >> $pli_file
		output_neuron_label=${neuron_labels[$num_neurons_m1]}

		####
		# Form Rules
		#
		for i in ${neuron_labels[@]}
		do
			echo "	$DEFAULT_RULE" | sed -e 's/NEURON_LABEL/'"$i"'/g' >> $pli_file
		done	
		
		echo "	[a*2 --> a*2]'$output_neuron_label :: 0;" >> $pli_file
		echo "  [a*3 --> a*3]'$output_neuron_label :: 0;" >> $pli_file
		echo "  [a*4 --> a*4]'$output_neuron_label :: 0;" >> $pli_file

		####
		# Form Synapses
		#
		bits_counter=0
		echo "$bit_string" | grep -o . | while read bit
		do
			if [ "$bit" == "1" ]
			then
				lneuron_i=`expr $bits_counter / $num_neurons`
				rneuron_i=`expr \( $bits_counter % $num_neurons \)`
				lneuron_label=${neuron_labels[$lneuron_i]}
				rneuron_label=${neuron_labels[$rneuron_i]}
			
				echo "	@marcs += ($lneuron_label, $rneuron_label);" >> $pli_file	
			fi
			bits_counter=`expr $bits_counter + 1`
		done	

		###
		# Form Input Spike Train
		#
		in_spike_train_raw=`head $SNP_CONFIG_FILE -n1`
		in_spike_count=1

		while [[ `echo "$in_spike_train_raw" | grep -o 'a' | head -1` != "" ]]
		do
			in_spike_train_raw=`echo "$in_spike_train_raw" | sed -e 's/a/'"),($in_spike_count,"'/'`
			in_spike_count=`expr $in_spike_count + 1`
		done
		echo $in_spike_train_raw | sed -e 's/^),/@minst = /g' | sed -e 's/$/);/g' >> $pli_file

		echo "}" >> $pli_file
		in_count=`expr $in_count + 1`	

		####
		#
		# Run plingua core
		execution_steps=10
		log "Running P-Lingua simulation"
		java -jar $PLINGUA_JAR plingua_sim -pli $pli_file -o $PLI_SIM_OUTPUT_FOLDER/$PLI_FILENAME.$file_suffix.pli.out -st $execution_steps > $PLI_SIM_OUTPUT_FOLDER/$PLI_FILENAME.$file_suffix.pli.log


	done < "$1"

	log "done parsing and simulation"
}

function produceSpikeTrainOutput
{
	> "$1"
	tail -n15 "$PLI_SIM_OUTPUT_FOLDER/"*.log | grep -A2 'Binary Sequence' | grep -o '{.*}' | sed -e 's/{.*\[//g' | sed -e 's/\]}//g' | sed -e 's/^/a/g' | sed -e 's/, /a/g' >> "$1"
}

function log
{
	log_time=`date "+%Y-%m-%d %H:%M:%S"`
	echo [$log_time] $1
}

function cleanPliFolders
{
	mv $PLI_FILES_FOLDER/*.pli $PLI_FILES_FOLDER/old/
}

function cleanSimulationOutputFolder
{
	mv "$PLI_SIM_OUTPUT_FOLDER/"* $PLI_SIM_OUTPUT_FOLDER/old/
}
