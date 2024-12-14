#!/bin/bash

validate_threads() {
    local threads=$1
    if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
      return 1
    fi
}

set_threads() {
  if [ $# -lt 2 ]; then
    echo -e "\033[33m Usage: $0 <TRANSCRIPT_LINK> <THREADS> <RNA_LINK...>\033[0m"
    return 1
  fi

  TRANSCRIPT_LINK=$1

  validate_threads $2
  if [ $? -ne 0 ]; then
    echo -e "\033[33m THREADS not provided. Defaulting to the number of CPU cores: $(nproc)\033[0m"
    THREADS=$(nproc)
    shift 1
  else
    THREADS=$2
    shift 2
  fi
  RNA_LINKS=("$@")
}

download_rna() {
  local rna_link=$1
  local file_name=$(basename "$rna_link")
  if [ ! -f "rna_data/$file_name" ]; then
    echo -e "\033[32m Downloading RNA data from: $rna_link \033[0m"
    wget -q "$rna_link" -P rna_data/
    if [ $? -ne 0 ]; then
      echo -e "\033[31m Failed to download $rna_link \033[0m"
      return 1
    fi
  else
    echo -e "\033[32m RNA file '$file_name' already exists! \033[0m"
  fi
  return 0
}

calculate_mean_and_std() {
  local file_name="$1"

  if [ ! -f "rna_data/$file_name" ]; then
    echo -e "\033[31m Error: File 'rna_data/$file_name' not found.\033[0m"
    return 1
  fi

  gunzip -c "rna_data/$file_name" | head -n 1000000 | awk '{if(NR%4 == 2){print length($0);}}' > fragment_lengths.txt
  if [ $? -ne 0 ]; then
    echo -e "\033[31m Error: Failed to process the file 'rna_data/$file_name'.\033[0m"
    rm -f fragment_lengths.txt
    return 1
  fi

  MEAN=$(awk '{sum+=$0}END{if(NR>0){print sum/NR}else{print "NaN"}}' fragment_lengths.txt)
  if [[ "$MEAN" == "NaN" ]]; then
    echo -e "\033[31m Error: Unable to calculate mean. Empty or invalid data.\033[0m"
    rm -f fragment_lengths.txt
    return 1
  fi

  STD=$(awk '{x+=$0;y+=$0^2}END{if(NR>0){print sqrt(y/NR-(x/NR)^2)}else{print "NaN"}}' fragment_lengths.txt)
  if [[ "$STD" == "NaN" ]]; then
    echo -e "\033[31m Error: Unable to calculate standard deviation. Empty or invalid data.\033[0m"
    rm -f fragment_lengths.txt
    return 1
  fi

  echo -e "\033[32m Average Length: $MEAN, Standard Deviation: $STD \033[0m"
  rm -f fragment_lengths.txt
  return 0
}

main() {
  set_threads "$@"
  if [ $? -ne 0 ]; then return 1; fi

  source index_transcript.sh "$TRANSCRIPT_LINK"
  if [ $? -ne 0 ]; then
    echo -e "\033[31m Transcript indexing failed! \033[0m"
    return 1
  fi
  echo -e "\033[32m Transcript indexed successfully! \033[0m"

  for link in "${RNA_LINKS[@]}"; do
    download_rna "$link"
    if [ $? -ne 0 ]; then
      echo -e "\033[31m Error processing $link. Exiting... \033[0m"
      return 1
    fi
  done
  echo -e "\033[32m All RNA links processed successfully! \033[0m"

  if [ ${#RNA_LINKS[@]} -eq 1 ]; then
    calculate_mean_and_std "$(basename "${RNA_LINKS[0]}")"
    if [ $? -ne 0 ]; then
      echo -e "\033[31m Error calculating mean and std for $RNA_LINKS[0]. Exiting... \033[0m"
      return 1
    fi
    echo -e "\033[32m Mean and Std calculated successfully! \033[0m"
  fi

  local datetime=$(date +"%Y-%m-%d_%H-%M-%S")
  local kallisto_command="kallisto quant -i transcripts/$(basename $TRANSCRIPT_LINK).idx -o output/$datetime -t $THREADS"

  if [ ${#RNA_LINKS[@]} -eq 1 ]; then
    kallisto_command="$kallisto_command --single -l $MEAN -s $STD rna_data/$(basename "${RNA_LINKS[0]}")"
  else
    for link in "${RNA_LINKS[@]}"; do
      kallisto_command="$kallisto_command rna_data/$(basename "$link")"
    done
  fi

  $kallisto_command
  if [ $? -ne 0 ]; then
    echo -e "\033[31m Error: Kallisto quantification failed. \033[0m"
    return 1
  fi

  echo -e "\033[32m Kallisto quantification completed successfully! \033[0m"
  return 0
}

main "$@"
