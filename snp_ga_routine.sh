#!/bin/bash

. ./config.sh

working_dir=`pwd`
iterations=5

for i in $(seq 1 $iterations)
do
				date_simulation=`date "+%Y-%m-%d %H:%M:%S"`
				echo "[$date_simulation] Running simulations" >> $EVOLUTION_LOG

				# Run P-Lingua Simulation
				cd $PLINGUA_SIM_DIR
				# To ensure all bitstrings are read, insert newline at end
				echo "" >> $SNP_GA_NEW_POPULATION
				$PLINGUA_SIM_MAIN $SNP_GA_NEW_POPULATION $SNP_GA_SIMULATION_INPUT
				
				# Run SNP GA to generate new Population
				cd $SNP_GA_DIR
				$SNP_GA_BIN
	
				cd $working_dir
				cat $SNP_GA_SIMULATION_INPUT	
				cat $SNP_GA_SIMULATION_INPUT >> $EVOLUTION_LOG
done
