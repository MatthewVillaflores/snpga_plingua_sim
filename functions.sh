#!/bin/bash

# TODO set input/output neurons (no more virtual neuron)

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
		num_neurons=`sed '3q;d' $SNP_CONFIG_FILE`
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
		# Form Rules
		#
		n_ctr=0
		for i in ${neuron_labels[@]}
		do
			cfg_rule_line_n=`expr $n_ctr + 4`
			cfg_rule=`sed $cfg_rule_line_n'q;d' $SNP_CONFIG_FILE`
			for rule in `echo "$cfg_rule" | sed -s 's/\\$/\n/g'`
			do
				echo $rule | sed -e 's/\(.*\)/\[\1\]/g' | sed -e 's/\(a\)\([0-9]\)/\1*\2/g' | sed -e 's/-/--/g' | sed -e "s/$/'$i :: 0;/" >> $pli_file
			done

			n_ctr=`expr $n_ctr + 1`
		done	

		####
		# Input/Output Neuron
		num_neurons_m1=`expr $num_neurons - 1`
		echo "	@mout = ${neuron_labels[$num_neurons_m1]};" >> $pli_file
		output_neuron_label=${neuron_labels[$num_neurons_m1]}

		####
		# Form Synapses/input/output neuron
		#
		bits_counter=0
		echo "$bit_string" | grep -o . | while read bit
		do
			if [ "$bit" == "1" ]
			then
				lneuron_i=`expr $bits_counter / \( $num_neurons + 1 \)`
				rneuron_i=`expr $bits_counter % \( $num_neurons + 1 \)`
								
				# input neuron
				if [[ $lneuron_i == 0 ]]
				then
						echo "	@min = ${neuron_labels[$rneuron_i]};" >> $pli_file
						log "Input neuron: ${neuron_labels[$rneuron_i]}"
						continue
				fi

				# output neuron
				if [[ $rneuron_i == $num_neurons ]]
				then 
						nneuron_i=`expr $lneuron_i - 1`
						echo "	@mout = ${neuron_labels[$nneuron_i]};" >> $pli_file
						log "Output neuron: ${neuron_labels[$nneuron_o]}"
						continue
				fi
				nneuron_i=`expr $lneuron_i - 1`
				lneuron_label=${neuron_labels[$nneuron_i]}
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
	curr_dir=`pwd`
	cd "$PLI_FILES_FOLDER"
	clean_date=`date "+%Y%m%d%H%M%S"`
	for filename in *.pli; do mv "$filename" "$filename.$clean_date"; done
	for filename in *.pli*; do tar czf "$filename.gz" "$filename"; done
	mv *.gz old/.
	rm *.pli*
	cd "$curr_dir"
}

function cleanSimulationOutputFolder
{
	curr_dir=`pwd`
	cd "$PLI_SIM_OUTPUT_FOLDER"
	clean_date=`date "+%Y%m%d%H%M%S"`
	for filename in *.log; do mv "$filename" "$filename.$clean_date"; done
	for filename in *.log*; do tar czf "$filename.gz" "$filename"; done
	mv *.gz old/.
	rm *.log*

	for filename in *.txt; do mv "$filename" "$filename.$clean_date"; done
	for filename in *.txt*; do tar czf "$filename.gz" "$filename"; done
	mv *.gz old/.
	rm *.txt*

	cd "$curr_dir"
}

function archiveInputFile
{
	curr_date=`date "+%Y%m%d%H%M%S"`
	cp "$1" "$PLI_FILES_FOLDER/old/$1.$curr_date"	

}
