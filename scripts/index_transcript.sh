#!/bin/bash

check_args() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <TRANSCRIPT_LINK>"
        exit 1
    fi
}

initialize_vars() {
    local transcript_link=$1
    local trans_dir="transcripts"
    local arch_name=$(basename "$transcript_link")
    
    echo "$transcript_link $trans_dir $arch_name"
}

download_transcript() {
    local transcript_link=$1
    local trans_dir=$2
    local arch_name=$3

    cd "$trans_dir" || { echo "Failed to cd into $trans_dir"; return 1; }

    if [ ! -f "arch/$arch_name" ]; then
        echo -e "\033[33mDownloading transcript from $transcript_link...\033[0m"
        wget -q "$transcript_link" 
        if [ $? -ne 0 ]; then
            echo "Failed to download the transcript."
            return 1
        fi
    else
        echo -e "\033[32mTranscript file already exists, moving to arch directory...\033[0m"
        mv "arch/$arch_name" .
    fi

    echo -e "\033[33mCreating kallisto index for $arch_name...\033[0m"
    kallisto index -i "$arch_name.idx" "$arch_name"
    if [ $? -ne 0 ]; then
        echo "Failed to create the index."
        mv "$arch_name" arch/
        return 1
    fi

    mv "$arch_name" arch/
    cd ..

    return 0
}

main() {
    check_args "$@" 

    IFS=" " read -r TRANSCRIPT_LINK TRANS_DIR ARCH_NAME <<< $(initialize_vars "$1")

    if [ ! -f "$TRANS_DIR/$ARCH_NAME.idx" ]; then
        echo -e "\033[33m$ARCH_NAME.idx not found. Downloading and creating the index...\033[0m"
    
        download_transcript "$TRANSCRIPT_LINK" "$TRANS_DIR" "$ARCH_NAME"
        if [ $? -ne 0 ]; then
            echo -e "\033[31mFailed to download or create the index. Exiting...\033[0m"
            return 1
        else
            echo -e "\033[32mIndex created and transcript file moved.\033[0m"
        fi
    else
        echo -e "\033[32m$ARCH_NAME.idx already exists. Skipping download and index creation.\033[0m"
    fi
}

main "$@"
